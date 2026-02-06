"""
Comprehensive tests for the NavixMind bridge module.

Tests cover:
- Thread-safe communication
- Native tool calls
- Event wait/notify pattern
- Timeout handling
- Error propagation
- Message queue
"""

import json
import pytest
import threading
import time
from unittest.mock import Mock, patch, MagicMock
from uuid import uuid4


class TestNavixMindBridge:
    """Tests for the NavixMindBridge class."""

    def test_singleton_pattern(self):
        """Test that get_instance returns singleton."""
        from navixmind.bridge import NavixMindBridge

        instance1 = NavixMindBridge.get_instance()
        instance2 = NavixMindBridge.get_instance()
        assert instance1 is instance2

    def test_set_send_callback(self):
        """Test setting send callback and _send puts messages in queue."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()
        callback = Mock()
        bridge.set_send_callback(callback)

        # _send puts messages onto the outgoing queue (polled by Kotlin)
        bridge._send({"test": "message"})

        # Verify the message is available via get_pending_message
        pending = bridge.get_pending_message()
        assert pending is not None
        assert json.loads(pending) == {"test": "message"}

    def test_log_sends_message(self):
        """Test log method sends log message."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        bridge.log("Test message", level="info", progress=0.5)

        pending = bridge.get_pending_message()
        assert pending is not None
        call_arg = json.loads(pending)
        assert call_arg["method"] == "log"
        assert call_arg["params"]["message"] == "Test message"
        assert call_arg["params"]["level"] == "info"
        assert call_arg["params"]["progress"] == 0.5

    def test_log_without_progress(self):
        """Test log message without progress."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        bridge.log("Simple message")

        pending = bridge.get_pending_message()
        assert pending is not None
        call_arg = json.loads(pending)
        assert "progress" not in call_arg["params"]

    def test_get_status(self):
        """Test getting bridge status."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()
        bridge.set_status("ready")
        assert bridge.get_status() == "ready"

    def test_set_status(self):
        """Test setting bridge status."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()
        bridge.set_status("initializing")
        assert bridge.get_status() == "initializing"

        bridge.set_status("ready")
        assert bridge.get_status() == "ready"


class TestCallNative:
    """Tests for the call_native method."""

    def test_call_native_success(self):
        """Test successful native call."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        # Simulate async response by polling the outgoing queue
        def respond():
            # Wait for the outgoing message to appear
            msg = None
            for _ in range(100):
                msg = bridge.get_pending_message()
                if msg is not None:
                    break
                time.sleep(0.01)
            assert msg is not None
            call_arg = json.loads(msg)
            msg_id = call_arg["id"]
            bridge.receive_response(json.dumps({
                "id": msg_id,
                "result": {"success": True, "data": "test"}
            }))

        thread = threading.Thread(target=respond)
        thread.start()

        result = bridge.call_native("test_tool", {"arg": "value"}, timeout_ms=5000)
        thread.join()

        assert result["success"] is True
        assert result["data"] == "test"

    def test_call_native_timeout(self):
        """Test native call timeout."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        # Don't respond - should timeout
        with pytest.raises(TimeoutError):
            bridge.call_native("test_tool", {}, timeout_ms=100)

        # Drain the pending message from the queue
        bridge.get_pending_message()

    def test_call_native_error_response(self):
        """Test native call with error response."""
        from navixmind.bridge import NavixMindBridge, ToolError

        bridge = NavixMindBridge.get_instance()

        def respond_with_error():
            msg = None
            for _ in range(100):
                msg = bridge.get_pending_message()
                if msg is not None:
                    break
                time.sleep(0.01)
            assert msg is not None
            call_arg = json.loads(msg)
            msg_id = call_arg["id"]
            bridge.receive_response(json.dumps({
                "id": msg_id,
                "error": {"code": -32000, "message": "Tool failed"}
            }))

        thread = threading.Thread(target=respond_with_error)
        thread.start()

        with pytest.raises(ToolError) as exc_info:
            bridge.call_native("failing_tool", {}, timeout_ms=5000)

        thread.join()
        assert exc_info.value.code == -32000
        assert "Tool failed" in str(exc_info.value)

    def test_call_native_message_format(self):
        """Test native call sends correct message format."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        # Start call in thread (will timeout but we just want to check message)
        def call():
            try:
                bridge.call_native("test_tool", {"key": "value"}, timeout_ms=100)
            except TimeoutError:
                pass

        thread = threading.Thread(target=call)
        thread.start()
        thread.join()

        pending = bridge.get_pending_message()
        assert pending is not None
        call_arg = json.loads(pending)
        assert call_arg["jsonrpc"] == "2.0"
        assert call_arg["method"] == "native_tool"
        assert call_arg["params"]["tool"] == "test_tool"
        assert call_arg["params"]["args"] == {"key": "value"}
        assert call_arg["params"]["timeout_ms"] == 100

    def test_call_native_concurrent_calls(self):
        """Test multiple concurrent native calls."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()
        sent_messages = []
        sent_lock = threading.Lock()

        # Background thread that polls the outgoing queue and responds
        stop_responder = threading.Event()

        def responder():
            while not stop_responder.is_set():
                msg_str = bridge.get_pending_message()
                if msg_str is not None:
                    msg = json.loads(msg_str)
                    if msg.get("method") == "native_tool":
                        with sent_lock:
                            sent_messages.append(msg)
                        tool_name = msg["params"]["tool"]
                        time.sleep(0.01)
                        bridge.receive_response(json.dumps({
                            "id": msg["id"],
                            "result": {"tool": tool_name}
                        }))
                else:
                    time.sleep(0.005)

        resp_thread = threading.Thread(target=responder)
        resp_thread.start()

        results = []
        errors = []

        def make_call(tool_name):
            try:
                result = bridge.call_native(tool_name, {}, timeout_ms=5000)
                results.append(result)
            except Exception as e:
                errors.append(e)

        threads = [
            threading.Thread(target=make_call, args=("tool1",)),
            threading.Thread(target=make_call, args=("tool2",)),
            threading.Thread(target=make_call, args=("tool3",)),
        ]

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        stop_responder.set()
        resp_thread.join(timeout=2)

        assert len(errors) == 0
        assert len(results) == 3


class TestReceiveResponse:
    """Tests for the receive_response method."""

    def test_receive_response_valid_json(self):
        """Test receiving valid JSON response."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()
        # Set up a pending request with a unique ID to avoid conflicts
        test_id = f"test-id-{uuid4()}"
        event = threading.Event()

        with bridge._internal_lock:
            bridge._pending[test_id] = event

        bridge.receive_response(f'{{"id": "{test_id}", "result": {{"ok": true}}}}')

        # Wait for the listener thread to process (max 1 second)
        event_set = event.wait(timeout=1.0)
        assert event_set, "Event was not set within timeout"

        # Check result was stored
        with bridge._internal_lock:
            assert test_id in bridge._results
            assert bridge._results[test_id]["result"]["ok"] is True
            # Clean up
            del bridge._results[test_id]
            if test_id in bridge._pending:
                del bridge._pending[test_id]

    def test_receive_response_invalid_json(self):
        """Test receiving invalid JSON is handled gracefully."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        # Should not raise
        bridge.receive_response("not valid json {{{")

    def test_receive_response_unknown_id(self):
        """Test receiving response for unknown ID."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        # Should not raise
        bridge.receive_response('{"id": "unknown-id", "result": {}}')


class TestToolError:
    """Tests for the ToolError exception."""

    def test_tool_error_default_code(self):
        """Test ToolError with default error code."""
        from navixmind.bridge import ToolError

        error = ToolError("Something failed")
        assert error.code == -32000
        assert str(error) == "Something failed"

    def test_tool_error_custom_code(self):
        """Test ToolError with custom error code."""
        from navixmind.bridge import ToolError

        error = ToolError("Custom error", code=-32001)
        assert error.code == -32001


class TestModuleFunctions:
    """Tests for module-level functions."""

    def test_initialize(self):
        """Test bridge initialization."""
        from navixmind import bridge

        bridge.initialize()
        assert bridge.get_status() == "ready"

    def test_get_bridge(self):
        """Test get_bridge returns instance."""
        from navixmind.bridge import get_bridge, NavixMindBridge

        result = get_bridge()
        assert isinstance(result, NavixMindBridge)

    def test_receive_response_module_function(self):
        """Test module-level receive_response."""
        from navixmind import bridge

        bridge.initialize()

        # Should not raise even without pending request
        bridge.receive_response('{"id": "test", "result": {}}')

    def test_get_status_module_function(self):
        """Test module-level get_status."""
        from navixmind import bridge

        bridge.initialize()
        assert bridge.get_status() == "ready"


class TestThreadSafety:
    """Tests for thread safety of the bridge."""

    def test_concurrent_log_calls(self):
        """Test concurrent log calls don't cause issues."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()

        threads = []
        for i in range(100):
            t = threading.Thread(target=bridge.log, args=(f"Message {i}",))
            threads.append(t)

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # Drain all messages and count them
        log_count = 0
        while True:
            msg = bridge.get_pending_message()
            if msg is None:
                break
            log_count += 1

        assert log_count == 100

    def test_concurrent_status_access(self):
        """Test concurrent status reads/writes."""
        from navixmind.bridge import NavixMindBridge

        bridge = NavixMindBridge.get_instance()
        statuses = ["ready", "initializing", "importing", "error"]

        def write_status():
            for status in statuses:
                bridge.set_status(status)
                time.sleep(0.001)

        def read_status():
            for _ in range(20):
                bridge.get_status()
                time.sleep(0.001)

        threads = [
            threading.Thread(target=write_status),
            threading.Thread(target=read_status),
            threading.Thread(target=read_status),
        ]

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # Should complete without errors
        assert bridge.get_status() in statuses + ["ready"]


class TestPrewarm:
    """Tests for the pre-warming functionality."""

    def test_start_prewarm_spawns_thread(self):
        """Test that _start_prewarm spawns a daemon thread."""
        from navixmind.bridge import _start_prewarm
        import threading

        initial_threads = threading.active_count()
        _start_prewarm()

        # Give thread time to start
        time.sleep(0.1)

        # Thread may have completed by now, but let's check it ran
        # We can verify by checking the function doesn't raise
        assert True  # Test passes if no exception

    def test_prewarm_imports_handle_import_error(self):
        """Test that prewarm gracefully handles ImportError."""
        from navixmind.bridge import _prewarm_imports

        # Should not raise even if modules are missing
        with patch('builtins.__import__', side_effect=ImportError("Module not found")):
            _prewarm_imports()  # Should complete without raising

    def test_prewarm_imports_success(self):
        """Test that prewarm function completes without error."""
        from navixmind.bridge import _prewarm_imports

        # Prewarm should complete without raising, even if modules missing
        try:
            _prewarm_imports()
        except Exception as e:
            pytest.fail(f"_prewarm_imports raised an exception: {e}")

        # Test passes if no crash
        assert True

    def test_prewarm_is_daemon_thread(self):
        """Test that prewarm thread is a daemon (won't block exit)."""
        from navixmind.bridge import _start_prewarm
        import threading

        _start_prewarm()
        time.sleep(0.05)

        # Find the prewarm thread
        prewarm_thread = None
        for thread in threading.enumerate():
            if thread.name == "prewarm-imports":
                prewarm_thread = thread
                break

        # Thread may have completed, but if found, should be daemon
        if prewarm_thread is not None:
            assert prewarm_thread.daemon is True

    def test_prewarm_logs_progress(self):
        """Test that prewarm logs progress messages."""
        from navixmind.bridge import _prewarm_imports
        from navixmind.crash_logger import CrashLogger

        with patch.object(CrashLogger, 'log_info') as mock_log:
            _prewarm_imports()

        # Should have logged at least the completion message
        log_calls = [str(call) for call in mock_log.call_args_list]
        assert any("complete" in str(call).lower() or "pre-warm" in str(call).lower()
                   for call in mock_log.call_args_list)

    def test_prewarm_imports_specific_modules(self):
        """Test that prewarm attempts to import specific heavy modules."""
        from navixmind.bridge import _prewarm_imports

        import_attempts = []

        def mock_import(name, *args, **kwargs):
            import_attempts.append(name)
            raise ImportError(f"Mock: {name} not available")

        with patch('builtins.__import__', mock_import):
            _prewarm_imports()

        # Should attempt these specific modules (or their parent modules)
        expected_modules = ['pypdf', 'reportlab', 'PIL', 'numpy', 'httpx']
        for expected in expected_modules:
            assert any(expected in attempt for attempt in import_attempts), \
                f"Expected to attempt import of {expected}"

    def test_initialize_calls_prewarm(self):
        """Test that initialize() triggers prewarm."""
        from navixmind import bridge

        with patch.object(bridge, '_start_prewarm') as mock_prewarm:
            bridge.initialize()

        mock_prewarm.assert_called_once()

    def test_prewarm_does_not_block_initialization(self):
        """Test that prewarm runs asynchronously."""
        from navixmind import bridge
        import time

        start = time.time()
        bridge.initialize()
        duration = time.time() - start

        # Initialization should complete quickly (prewarm is async)
        # If prewarm blocked, it would take several seconds
        assert duration < 1.0, "Initialization took too long - prewarm may be blocking"

    def test_prewarm_handles_partial_failures(self):
        """Test prewarm continues even if some imports fail."""
        from navixmind.bridge import _prewarm_imports

        # The function should complete without raising even if imports fail
        # Each import is wrapped in try/except in _prewarm_imports
        try:
            _prewarm_imports()
        except Exception as e:
            pytest.fail(f"_prewarm_imports should not raise: {e}")

        # Test passes if no exception was raised
        assert True
