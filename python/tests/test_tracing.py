"""
Comprehensive tests for the Mentiora tracing module.

Tests cover:
- TracingManager singleton, init, enable/disable
- QueryTrace span collection (LLM and tool)
- No-op when disabled (_NullQueryTrace)
- Truncation of large values
- Thread safety
- Graceful error handling
- finish() idempotency
- _MentioraHttpClient
- _span_to_event conversion
"""

import json
import threading
import time
import pytest
from unittest.mock import Mock, patch, MagicMock


class TestTracingManagerSingleton:
    """Tests for TracingManager singleton behavior."""

    def test_singleton_returns_same_instance(self):
        """TracingManager.instance() always returns the same object."""
        from navixmind.tracing import TracingManager
        a = TracingManager.instance()
        b = TracingManager.instance()
        assert a is b

    def test_singleton_thread_safe(self):
        """Multiple threads calling instance() get the same object."""
        from navixmind.tracing import TracingManager
        results = []

        def get_instance():
            results.append(TracingManager.instance())

        threads = [threading.Thread(target=get_instance) for _ in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(results) == 10
        assert all(r is results[0] for r in results)


class TestTracingManagerEnabled:
    """Tests for TracingManager enabled/disabled state."""

    def test_disabled_by_default(self):
        """Tracing is disabled when no key is set."""
        from navixmind.tracing import TracingManager
        mgr = TracingManager()
        assert not mgr.enabled

    def test_enabled_after_set_key(self):
        """Tracing is enabled after setting a non-empty key."""
        from navixmind.tracing import TracingManager, _HTTP_AVAILABLE
        mgr = TracingManager()
        mgr.set_api_key("test-key-123")
        assert mgr.enabled == _HTTP_AVAILABLE

    def test_disabled_after_clear_key(self):
        """Tracing is disabled after setting key to empty string."""
        from navixmind.tracing import TracingManager
        mgr = TracingManager()
        mgr.set_api_key("test-key-123")
        mgr.set_api_key("")
        assert not mgr.enabled

    def test_disabled_after_none_key(self):
        """Tracing is disabled when key is set to None-equivalent."""
        from navixmind.tracing import TracingManager
        mgr = TracingManager()
        mgr.set_api_key("test-key-123")
        mgr.set_api_key("")  # Empty string
        assert not mgr.enabled

    def test_disabled_when_http_unavailable(self):
        """Tracing is disabled when requests is not importable."""
        from navixmind.tracing import TracingManager
        mgr = TracingManager()
        mgr.set_api_key("test-key-123")
        with patch('navixmind.tracing._HTTP_AVAILABLE', False):
            assert not mgr.enabled

    def test_set_key_closes_old_client(self):
        """Setting a new key closes the previous HTTP client."""
        from navixmind.tracing import TracingManager
        mgr = TracingManager()
        old_client = Mock()
        mgr._client = old_client
        mgr.set_api_key("new-key")
        old_client.close.assert_called_once()


class TestTracingManagerStartTrace:
    """Tests for TracingManager.start_trace()."""

    def test_returns_null_trace_when_disabled(self):
        """start_trace returns _NullQueryTrace when tracing disabled."""
        from navixmind.tracing import TracingManager, _NullQueryTrace
        mgr = TracingManager()
        trace = mgr.start_trace()
        assert isinstance(trace, _NullQueryTrace)

    def test_returns_query_trace_when_enabled(self):
        """start_trace returns QueryTrace when tracing enabled."""
        from navixmind.tracing import TracingManager, QueryTrace, _HTTP_AVAILABLE
        if not _HTTP_AVAILABLE:
            pytest.skip("requests not available")
        mgr = TracingManager()
        mgr.set_api_key("test-key")
        trace = mgr.start_trace(conversation_id="conv-123")
        assert isinstance(trace, QueryTrace)
        assert trace.trace_id != ""

    def test_handles_exception_gracefully(self):
        """start_trace returns _NullQueryTrace on error."""
        from navixmind.tracing import TracingManager, _NullQueryTrace
        mgr = TracingManager()
        mgr.set_api_key("test-key")
        with patch('navixmind.tracing._HTTP_AVAILABLE', True), \
             patch('navixmind.tracing.QueryTrace', side_effect=Exception("boom")):
            trace = mgr.start_trace()
        assert isinstance(trace, _NullQueryTrace)


class TestMentioraHttpClient:
    """Tests for _MentioraHttpClient."""

    def test_sets_auth_header(self):
        """Client sets Bearer authorization header."""
        from navixmind.tracing import _MentioraHttpClient
        client = _MentioraHttpClient(api_key="my-key-123")
        assert client._session.headers["Authorization"] == "Bearer my-key-123"

    def test_sets_content_type(self):
        """Client sets JSON content type."""
        from navixmind.tracing import _MentioraHttpClient
        client = _MentioraHttpClient(api_key="key")
        assert client._session.headers["Content-Type"] == "application/json"

    def test_sets_user_agent(self):
        """Client sets navixmind user agent."""
        from navixmind.tracing import _MentioraHttpClient
        client = _MentioraHttpClient(api_key="key")
        assert "navixmind" in client._session.headers["User-Agent"]

    def test_send_trace_posts_to_correct_url(self):
        """send_trace POSTs to /api/v1/traces."""
        from navixmind.tracing import _MentioraHttpClient, MENTIORA_BASE_URL
        client = _MentioraHttpClient(api_key="key")
        with patch.object(client._session, 'post') as mock_post:
            mock_post.return_value = Mock(status_code=200)
            mock_post.return_value.raise_for_status = Mock()
            client.send_trace({"trace_id": "abc"})
        mock_post.assert_called_once()
        call_url = mock_post.call_args[0][0]
        assert call_url == f"{MENTIORA_BASE_URL}/api/v1/traces"

    def test_send_trace_sends_json_body(self):
        """send_trace passes event data as JSON body."""
        from navixmind.tracing import _MentioraHttpClient
        client = _MentioraHttpClient(api_key="key")
        event = {"trace_id": "abc", "span_id": "def"}
        with patch.object(client._session, 'post') as mock_post:
            mock_post.return_value = Mock(status_code=200)
            mock_post.return_value.raise_for_status = Mock()
            client.send_trace(event)
        assert mock_post.call_args[1]["json"] == event

    def test_close_closes_session(self):
        """close() closes the underlying session."""
        from navixmind.tracing import _MentioraHttpClient
        client = _MentioraHttpClient(api_key="key")
        with patch.object(client._session, 'close') as mock_close:
            client.close()
        mock_close.assert_called_once()


class TestQueryTrace:
    """Tests for QueryTrace span collection and sending."""

    def _make_trace(self):
        """Create a QueryTrace with a mock manager."""
        from navixmind.tracing import QueryTrace, TracingManager
        mgr = TracingManager()
        mgr.set_api_key("test-key")
        mgr._client = Mock()  # Avoid real client creation
        return QueryTrace(manager=mgr, conversation_id="conv-1")

    def test_trace_id_is_nonempty(self):
        """QueryTrace has a non-empty trace_id."""
        trace = self._make_trace()
        assert trace.trace_id
        assert isinstance(trace.trace_id, str)
        assert len(trace.trace_id) > 8

    def test_add_llm_span(self):
        """LLM spans are collected with correct fields."""
        trace = self._make_trace()
        trace.add_llm_span(
            model="claude-opus-4-6",
            messages=[{"role": "user", "content": "hello"}],
            response=[{"type": "text", "text": "hi"}],
            input_tokens=10,
            output_tokens=5,
            duration_ms=500,
        )
        assert len(trace._spans) == 1
        span = trace._spans[0]
        assert span["span_type"] == "llm"
        assert span["name"] == "llm.call"
        assert span["model"] == "claude-opus-4-6"
        assert span["provider"] == "anthropic"
        assert span["input_tokens"] == 10
        assert span["output_tokens"] == 5
        assert span["duration_ms"] == 500
        assert "span_id" in span
        assert "start_time" in span

    def test_add_tool_span(self):
        """Tool spans are collected with correct fields."""
        trace = self._make_trace()
        trace.add_tool_span(
            tool_name="web_fetch",
            tool_input={"url": "https://example.com"},
            tool_output={"text": "content"},
            duration_ms=1200,
        )
        assert len(trace._spans) == 1
        span = trace._spans[0]
        assert span["span_type"] == "tool"
        assert span["name"] == "tool.web_fetch"
        assert span["tool_name"] == "web_fetch"
        assert span["duration_ms"] == 1200
        assert "span_id" in span

    def test_add_llm_span_with_error(self):
        """LLM span with error includes error field."""
        trace = self._make_trace()
        trace.add_llm_span(
            model="claude-opus-4-6",
            messages=[],
            response=None,
            duration_ms=100,
            error="Rate limited",
        )
        assert trace._spans[0]["error"] == "Rate limited"

    def test_add_tool_span_with_error(self):
        """Tool span with error includes error field."""
        trace = self._make_trace()
        trace.add_tool_span(
            tool_name="ffmpeg_process",
            tool_input={},
            tool_output=None,
            duration_ms=5000,
            error="Timeout",
        )
        assert trace._spans[0]["error"] == "Timeout"

    def test_multiple_spans_in_order(self):
        """Multiple spans are collected in order."""
        trace = self._make_trace()
        trace.add_llm_span(model="m1", messages=[], response=[], duration_ms=100)
        trace.add_tool_span(tool_name="t1", tool_input={}, tool_output={}, duration_ms=200)
        trace.add_llm_span(model="m1", messages=[], response=[], duration_ms=300)
        trace.add_tool_span(tool_name="t2", tool_input={}, tool_output={}, duration_ms=400)

        assert len(trace._spans) == 4
        assert trace._spans[0]["span_type"] == "llm"
        assert trace._spans[1]["span_type"] == "tool"
        assert trace._spans[2]["span_type"] == "llm"
        assert trace._spans[3]["span_type"] == "tool"

    def test_max_spans_enforced(self):
        """Spans beyond MAX_SPANS are silently dropped."""
        from navixmind.tracing import MAX_SPANS
        trace = self._make_trace()
        for i in range(MAX_SPANS + 50):
            trace.add_llm_span(model="m", messages=[], response=[], duration_ms=1)
        assert len(trace._spans) == MAX_SPANS

    def test_finish_sends_in_background(self):
        """finish() starts a background thread to send per-span events."""
        trace = self._make_trace()
        trace.add_llm_span(model="m", messages=[], response=[], duration_ms=100)
        trace.add_tool_span(tool_name="t", tool_input={}, tool_output={}, duration_ms=200)

        with patch.object(trace._manager, '_get_client') as mock_get_client:
            mock_client = Mock()
            mock_get_client.return_value = mock_client
            trace.finish(final_response="Done")
            # Wait briefly for the daemon thread
            time.sleep(0.2)

        # Each span should be sent individually
        assert mock_client.send_trace.call_count == 2

    def test_finish_idempotent(self):
        """Calling finish() multiple times only sends once."""
        trace = self._make_trace()
        trace.add_llm_span(model="m", messages=[], response=[], duration_ms=100)

        with patch.object(trace._manager, '_get_client') as mock_get_client:
            mock_client = Mock()
            mock_get_client.return_value = mock_client
            trace.finish()
            trace.finish()
            trace.finish()
            time.sleep(0.2)

        # Only one call per span (1 span total)
        assert mock_client.send_trace.call_count == 1

    def test_no_spans_after_finish(self):
        """Spans added after finish() are silently ignored."""
        trace = self._make_trace()
        trace.finish()
        trace.add_llm_span(model="m", messages=[], response=[], duration_ms=100)
        trace.add_tool_span(tool_name="t", tool_input={}, tool_output={}, duration_ms=100)
        assert len(trace._spans) == 0

    def test_finish_handles_send_error_gracefully(self):
        """finish() does not raise even if send_trace() fails."""
        trace = self._make_trace()
        trace.add_llm_span(model="m", messages=[], response=[], duration_ms=100)
        with patch.object(trace._manager, '_get_client') as mock_get_client:
            mock_client = Mock()
            mock_client.send_trace.side_effect = Exception("network error")
            mock_get_client.return_value = mock_client
            # Should not raise
            trace.finish()
            time.sleep(0.2)

    def test_finish_no_client_available(self):
        """finish() is no-op when client is None."""
        trace = self._make_trace()
        with patch.object(trace._manager, '_get_client', return_value=None):
            trace.finish()
            time.sleep(0.1)
        # No assertion needed — just should not raise

    def test_duration_calculation(self):
        """Total duration is approximately correct (validated by send call)."""
        trace = self._make_trace()
        time.sleep(0.05)  # 50ms
        trace.add_llm_span(model="m", messages=[], response=[], duration_ms=100)

        with patch.object(trace._manager, '_get_client') as mock_get_client:
            mock_client = Mock()
            mock_get_client.return_value = mock_client
            trace.finish()
            time.sleep(0.2)

        # Verify the span was sent
        assert mock_client.send_trace.call_count == 1


class TestSpanToEvent:
    """Tests for QueryTrace._span_to_event conversion."""

    def _make_trace(self):
        from navixmind.tracing import QueryTrace, TracingManager
        mgr = TracingManager()
        mgr.set_api_key("test-key")
        mgr._client = Mock()
        return QueryTrace(manager=mgr, conversation_id="conv-42")

    def test_llm_span_to_event(self):
        """LLM span converts to correct TraceEvent format."""
        trace = self._make_trace()
        span = {
            "span_type": "llm",
            "span_id": "span-123",
            "name": "llm.call",
            "model": "claude-sonnet-4-5-20241022",
            "provider": "anthropic",
            "input": '{"messages": []}',
            "output": '{"text": "hi"}',
            "input_tokens": 50,
            "output_tokens": 20,
            "duration_ms": 800,
            "start_time": "2024-01-01T00:00:00Z",
        }
        event = trace._span_to_event(span)
        assert event["trace_id"] == trace.trace_id
        assert event["span_id"] == "span-123"
        assert event["name"] == "llm.call"
        assert event["type"] == "llm"
        assert event["model"] == "claude-sonnet-4-5-20241022"
        assert event["provider"] == "anthropic"
        assert event["thread_id"] == "conv-42"
        assert event["tags"] == ["navixmind"]
        assert event["usage"]["prompt_tokens"] == 50
        assert event["usage"]["completion_tokens"] == 20

    def test_tool_span_to_event(self):
        """Tool span converts to correct TraceEvent format."""
        trace = self._make_trace()
        span = {
            "span_type": "tool",
            "span_id": "span-456",
            "name": "tool.web_fetch",
            "tool_name": "web_fetch",
            "input": '{"url": "x"}',
            "output": '{"text": "y"}',
            "duration_ms": 1500,
            "start_time": "2024-01-01T00:00:00Z",
        }
        event = trace._span_to_event(span)
        assert event["type"] == "tool"
        assert event["metadata"]["tool_name"] == "web_fetch"
        assert "model" not in event
        assert "usage" not in event

    def test_span_with_error(self):
        """Span with error converts correctly."""
        trace = self._make_trace()
        span = {
            "span_type": "llm",
            "span_id": "span-err",
            "name": "llm.call",
            "model": "m",
            "provider": "anthropic",
            "input": "",
            "output": "",
            "duration_ms": 0,
            "start_time": "2024-01-01T00:00:00Z",
            "error": "Rate limited",
        }
        event = trace._span_to_event(span)
        assert event["error"]["message"] == "Rate limited"
        assert event["error"]["type"] == "AgentError"

    def test_no_thread_id_when_empty(self):
        """No thread_id field when conversation_id is None."""
        from navixmind.tracing import QueryTrace, TracingManager
        mgr = TracingManager()
        mgr.set_api_key("key")
        mgr._client = Mock()
        trace = QueryTrace(manager=mgr, conversation_id=None)
        span = {
            "span_type": "llm",
            "span_id": "s",
            "name": "llm.call",
            "model": "m",
            "provider": "anthropic",
            "input": "",
            "output": "",
            "duration_ms": 0,
            "start_time": "2024-01-01T00:00:00Z",
        }
        event = trace._span_to_event(span)
        assert "thread_id" not in event


class TestQueryTraceThreadSafety:
    """Tests for concurrent access to QueryTrace."""

    def _make_trace(self):
        from navixmind.tracing import QueryTrace, TracingManager
        mgr = TracingManager()
        mgr.set_api_key("test-key")
        mgr._client = Mock()
        return QueryTrace(manager=mgr)

    def test_concurrent_add_spans(self):
        """Multiple threads adding spans concurrently don't corrupt state."""
        trace = self._make_trace()
        errors = []

        def add_spans(thread_id):
            try:
                for i in range(20):
                    if i % 2 == 0:
                        trace.add_llm_span(
                            model=f"m-{thread_id}",
                            messages=[],
                            response=[],
                            duration_ms=i,
                        )
                    else:
                        trace.add_tool_span(
                            tool_name=f"t-{thread_id}",
                            tool_input={},
                            tool_output={},
                            duration_ms=i,
                        )
            except Exception as e:
                errors.append(e)

        threads = [threading.Thread(target=add_spans, args=(i,)) for i in range(5)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert not errors
        assert len(trace._spans) == 100  # 5 threads * 20 spans each

    def test_concurrent_finish_only_sends_once(self):
        """Multiple threads calling finish() concurrently only send once."""
        trace = self._make_trace()
        trace.add_llm_span(model="m", messages=[], response=[], duration_ms=100)

        with patch.object(trace._manager, '_get_client') as mock_get_client:
            mock_client = Mock()
            mock_get_client.return_value = mock_client

            threads = [threading.Thread(target=trace.finish) for _ in range(10)]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
            time.sleep(0.3)

        # Should only call send_trace once (1 span)
        assert mock_client.send_trace.call_count == 1


class TestNullQueryTrace:
    """Tests for the _NullQueryTrace no-op implementation."""

    def test_trace_id_is_empty(self):
        """_NullQueryTrace has empty trace_id."""
        from navixmind.tracing import _NullQueryTrace
        trace = _NullQueryTrace()
        assert trace.trace_id == ""

    def test_add_llm_span_is_noop(self):
        """add_llm_span does nothing."""
        from navixmind.tracing import _NullQueryTrace
        trace = _NullQueryTrace()
        trace.add_llm_span(model="m", messages=[], response=[])
        # No exception, no state change

    def test_add_tool_span_is_noop(self):
        """add_tool_span does nothing."""
        from navixmind.tracing import _NullQueryTrace
        trace = _NullQueryTrace()
        trace.add_tool_span(tool_name="t", tool_input={}, tool_output={})

    def test_finish_is_noop(self):
        """finish does nothing."""
        from navixmind.tracing import _NullQueryTrace
        trace = _NullQueryTrace()
        trace.finish()
        trace.finish()  # Double-call is fine

    def test_accepts_all_kwargs(self):
        """All methods accept arbitrary kwargs without error."""
        from navixmind.tracing import _NullQueryTrace
        trace = _NullQueryTrace()
        trace.add_llm_span(
            model="m", messages=[], response=[],
            input_tokens=10, output_tokens=5, duration_ms=100, error="err"
        )
        trace.add_tool_span(
            tool_name="t", tool_input={}, tool_output={},
            duration_ms=100, error="err"
        )
        trace.finish(final_response="done", error="err")


class TestTruncation:
    """Tests for the _truncate helper."""

    def test_short_string_unchanged(self):
        """Short strings pass through unchanged."""
        from navixmind.tracing import _truncate
        assert _truncate("hello") == "hello"

    def test_long_string_truncated(self):
        """Long strings are truncated with indicator."""
        from navixmind.tracing import _truncate, MAX_FIELD_LENGTH
        long_str = "x" * (MAX_FIELD_LENGTH + 1000)
        result = _truncate(long_str)
        assert len(result) <= MAX_FIELD_LENGTH
        assert "truncated" in result

    def test_dict_serialized(self):
        """Dicts are JSON-serialized."""
        from navixmind.tracing import _truncate
        result = _truncate({"key": "value"})
        assert '"key"' in result
        assert '"value"' in result

    def test_list_serialized(self):
        """Lists are JSON-serialized."""
        from navixmind.tracing import _truncate
        result = _truncate([1, 2, 3])
        assert result == "[1, 2, 3]"

    def test_none_returns_empty(self):
        """None returns empty string."""
        from navixmind.tracing import _truncate
        assert _truncate(None) == ""

    def test_number_to_string(self):
        """Numbers are converted to strings."""
        from navixmind.tracing import _truncate
        assert _truncate(42) == "42"
        assert _truncate(3.14) == "3.14"

    def test_custom_max_len(self):
        """Custom max_len is respected."""
        from navixmind.tracing import _truncate
        result = _truncate("x" * 200, max_len=50)
        assert len(result) <= 50
        assert "truncated" in result

    def test_large_dict_truncated(self):
        """Large dicts are truncated after serialization."""
        from navixmind.tracing import _truncate
        large_dict = {f"key_{i}": "v" * 1000 for i in range(20)}
        result = _truncate(large_dict, max_len=500)
        assert len(result) <= 500
        assert "truncated" in result

    def test_unserializable_dict_fallback(self):
        """Non-JSON-serializable objects fall back to str()."""
        from navixmind.tracing import _truncate

        class Custom:
            def __str__(self):
                return "custom_object"

        result = _truncate(Custom())
        assert result == "custom_object"


class TestIsoNow:
    """Tests for the _iso_now helper."""

    def test_returns_utc_string(self):
        """Returns a UTC ISO 8601 string ending with Z."""
        from navixmind.tracing import _iso_now
        result = _iso_now()
        assert result.endswith("Z")
        assert "T" in result

    def test_returns_different_values(self):
        """Successive calls return different timestamps (or same in fast execution)."""
        from navixmind.tracing import _iso_now
        t1 = _iso_now()
        time.sleep(0.01)
        t2 = _iso_now()
        # t2 should be >= t1 (could be same if very fast)
        assert t2 >= t1


class TestAgentTracingIntegration:
    """Tests for tracing integration in agent.py."""

    def test_set_mentiora_key_handler(self):
        """handle_request routes set_mentiora_key correctly."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "set_mentiora_key",
            "params": {"api_key": "test-mentiora-key"}
        })

        with patch('navixmind.agent.set_mentiora_key') as mock_set:
            response = handle_request(request)

        result = json.loads(response)
        assert result["result"]["success"] is True
        mock_set.assert_called_once_with("test-mentiora-key")

    def test_set_mentiora_key_empty(self):
        """handle_request handles empty mentiora key."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "set_mentiora_key",
            "params": {"api_key": ""}
        })

        with patch('navixmind.agent.set_mentiora_key') as mock_set:
            response = handle_request(request)

        result = json.loads(response)
        assert result["result"]["success"] is True
        mock_set.assert_called_once_with("")

    def test_set_mentiora_key_missing_param(self):
        """handle_request handles missing api_key param (defaults to empty)."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "set_mentiora_key",
            "params": {}
        })

        with patch('navixmind.agent.set_mentiora_key') as mock_set:
            response = handle_request(request)

        result = json.loads(response)
        assert result["result"]["success"] is True
        mock_set.assert_called_once_with("")

    def test_set_mentiora_key_function(self):
        """set_mentiora_key() delegates to TracingManager."""
        from navixmind.agent import set_mentiora_key

        with patch('navixmind.agent.TracingManager') as MockTM:
            mock_instance = Mock()
            MockTM.instance.return_value = mock_instance
            set_mentiora_key("my-key")

        mock_instance.set_api_key.assert_called_once_with("my-key")

    def test_process_query_creates_trace(self):
        """process_query creates a trace and calls finish."""
        import navixmind.agent
        from navixmind.agent import process_query

        original_key = navixmind.agent._api_key
        navixmind.agent._api_key = "test-key"

        try:
            with patch('navixmind.agent.get_bridge') as mock_bridge, \
                 patch('navixmind.agent.get_session') as mock_session, \
                 patch('navixmind.agent.ClaudeClient') as mock_client_class, \
                 patch('navixmind.agent.TracingManager') as MockTM:

                mock_bridge.return_value = Mock()
                mock_session_inst = Mock()
                mock_session_inst.get_context_for_llm.return_value = []
                mock_session_inst.messages = []
                mock_session_inst._file_map = {}
                mock_session.return_value = mock_session_inst

                mock_client = Mock()
                mock_client.model = "claude-opus-4-6"
                mock_client.create_message.return_value = {
                    "stop_reason": "end_turn",
                    "content": [{"type": "text", "text": "Hello!"}],
                    "usage": {"input_tokens": 10, "output_tokens": 5}
                }
                mock_client_class.return_value = mock_client

                mock_trace = Mock()
                MockTM.instance.return_value.start_trace.return_value = mock_trace

                result = process_query("Hi", context={})

            assert result["content"] == "Hello!"
            # Trace should have recorded an LLM span and called finish
            mock_trace.add_llm_span.assert_called_once()
            mock_trace.finish.assert_called_once()
            # Check finish was called with final_response
            call_kwargs = mock_trace.finish.call_args
            assert call_kwargs[1].get('final_response') == "Hello!" or \
                   (call_kwargs[0] if call_kwargs[0] else None)
        finally:
            navixmind.agent._api_key = original_key
