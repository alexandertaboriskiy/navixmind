"""
Bridge - Thread-safe communication with Flutter

This module handles bidirectional communication between Python and Flutter
using a JSON-RPC 2.0 style protocol with thread-safe message queuing.
"""

import json
import threading
from queue import Queue
from typing import Any, Callable, Dict, Optional
from uuid import uuid4

from .crash_logger import CrashLogger


class ToolError(Exception):
    """Error from native tool execution."""

    def __init__(self, message: str, code: int = -32000):
        super().__init__(message)
        self.code = code


class NavixMindBridge:
    """
    Thread-safe bridge for Flutter communication.
    Uses Queue + Event pattern to avoid GIL deadlocks.
    """

    _instance: Optional['NavixMindBridge'] = None
    _lock = threading.Lock()

    def __init__(self):
        self._pending: Dict[str, threading.Event] = {}
        self._results: Dict[str, dict] = {}
        self._response_queue: Queue = Queue()
        self._outgoing_queue: Queue = Queue()  # Queue for messages to Flutter
        self._internal_lock = threading.Lock()
        self._send_callback: Optional[Callable[[str], None]] = None
        self._status = "initializing"

        # Start response listener thread
        self._listener_thread = threading.Thread(
            target=self._response_listener,
            daemon=True
        )
        self._listener_thread.start()

    @classmethod
    def get_instance(cls) -> 'NavixMindBridge':
        """Get singleton instance."""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = NavixMindBridge()
        return cls._instance

    def _response_listener(self) -> None:
        """Background thread that receives responses from Flutter."""
        CrashLogger.log_info("Response listener thread started")
        while True:
            try:
                response = self._response_queue.get()
                if response is None:
                    CrashLogger.log_info("Response listener received shutdown signal")
                    break  # Shutdown signal

                msg_id = response.get('id')
                CrashLogger.log_info(f"Response listener got response with id: {msg_id}")
                if msg_id and msg_id in self._pending:
                    CrashLogger.log_info(f"Found pending request for {msg_id}, setting event")
                    with self._internal_lock:
                        self._results[msg_id] = response
                        self._pending[msg_id].set()  # Unblock waiting call
                    CrashLogger.log_info(f"Event set for {msg_id}")
                else:
                    CrashLogger.log_info(f"No pending request for {msg_id}, pending: {list(self._pending.keys())}")
            except Exception as e:
                CrashLogger.log_error("response_listener", e)

    def set_send_callback(self, callback: Callable[[str], None]) -> None:
        """Set the callback function for sending messages to Flutter."""
        self._send_callback = callback

    def _send(self, message: dict) -> None:
        """Queue a message to be sent to Flutter."""
        try:
            self._outgoing_queue.put_nowait(json.dumps(message))
        except Exception as e:
            CrashLogger.log_error("send", e)

    def get_pending_message(self) -> Optional[str]:
        """Get next pending message for Flutter (called by Kotlin)."""
        try:
            return self._outgoing_queue.get_nowait()
        except:
            return None

    def has_pending_messages(self) -> bool:
        """Check if there are pending messages."""
        return not self._outgoing_queue.empty()

    def call_native(
        self,
        tool: str,
        args: dict,
        timeout_ms: int = 30000
    ) -> dict:
        """
        NON-BLOCKING call to native tool.
        Uses Event.wait() which releases GIL, preventing deadlock.

        Args:
            tool: Name of the native tool to call
            args: Arguments for the tool
            timeout_ms: Timeout in milliseconds

        Returns:
            Result dictionary from the tool

        Raises:
            TimeoutError: If the call times out
            ToolError: If the tool returns an error
        """
        msg_id = str(uuid4())
        event = threading.Event()

        with self._internal_lock:
            self._pending[msg_id] = event

        # Send request (this goes to Flutter via Chaquopy channel)
        CrashLogger.log_info(f"call_native: sending request for {tool} with id {msg_id}")
        self._send({
            "jsonrpc": "2.0",
            "id": msg_id,
            "method": "native_tool",
            "params": {
                "tool": tool,
                "args": args,
                "timeout_ms": timeout_ms
            }
        })
        CrashLogger.log_info(f"call_native: request sent, waiting for response (timeout={timeout_ms}ms)")

        # Wait with timeout - Event.wait() releases GIL!
        if not event.wait(timeout=timeout_ms / 1000):
            CrashLogger.log_info(f"call_native: TIMEOUT for {tool} ({msg_id}), pending: {list(self._pending.keys())}")
            with self._internal_lock:
                del self._pending[msg_id]
            raise TimeoutError(f"Native call {tool} timed out after {timeout_ms}ms")

        CrashLogger.log_info(f"call_native: got response for {tool} ({msg_id})")

        # Retrieve result
        with self._internal_lock:
            result = self._results.pop(msg_id)
            del self._pending[msg_id]

        if 'error' in result:
            raise ToolError(
                result['error']['message'],
                result['error'].get('code', -32000)
            )

        return result.get('result', {})

    def receive_response(self, response_json: str) -> None:
        """
        Called by Chaquopy when Flutter sends a response.

        Args:
            response_json: JSON string of the response
        """
        try:
            CrashLogger.log_info(f"receive_response called with: {response_json[:200]}...")
            response = json.loads(response_json)
            msg_id = response.get('id')
            CrashLogger.log_info(f"Parsed response with id: {msg_id}, pending ids: {list(self._pending.keys())}")
            self._response_queue.put(response)
            CrashLogger.log_info("Response added to queue")
        except json.JSONDecodeError as e:
            CrashLogger.log_error("receive_response", e)

    def log(
        self,
        message: str,
        level: str = "info",
        progress: Optional[float] = None
    ) -> None:
        """
        Non-blocking log emission to Flutter.

        Args:
            message: Log message
            level: Log level (info, warn, error)
            progress: Optional progress value 0.0-1.0
        """
        params = {"level": level, "message": message}
        if progress is not None:
            params["progress"] = progress

        self._send({
            "jsonrpc": "2.0",
            "method": "log",
            "params": params
        })

    def get_status(self) -> str:
        """Get current bridge status."""
        return self._status

    def set_status(self, status: str) -> None:
        """Set bridge status."""
        self._status = status

    def shutdown(self) -> None:
        """Shutdown the bridge."""
        self._response_queue.put(None)  # Signal listener to stop


# Global bridge instance
_bridge: Optional[NavixMindBridge] = None


def initialize() -> None:
    """Initialize the bridge."""
    global _bridge
    _bridge = NavixMindBridge.get_instance()
    _bridge.set_status("ready")
    CrashLogger.log_info("Bridge initialized")

    # Start pre-warming heavy imports in background
    _start_prewarm()


def _start_prewarm() -> None:
    """Start background thread to pre-warm heavy imports."""
    prewarm_thread = threading.Thread(
        target=_prewarm_imports,
        daemon=True,
        name="prewarm-imports"
    )
    prewarm_thread.start()


def _prewarm_imports() -> None:
    """
    Import heavy modules in background thread.

    This runs after basic initialization so first queries can be handled
    while heavy imports load. When user actually needs document/media
    processing, the modules are already loaded.
    """
    try:
        # PDF processing
        import pypdf  # noqa: F401
        CrashLogger.log_info("Pre-warmed: pypdf")
    except ImportError:
        pass

    try:
        # PDF generation
        import reportlab  # noqa: F401
        CrashLogger.log_info("Pre-warmed: reportlab")
    except ImportError:
        pass

    try:
        # Image processing
        from PIL import Image  # noqa: F401
        CrashLogger.log_info("Pre-warmed: Pillow")
    except ImportError:
        pass

    try:
        # Numerical operations
        import numpy  # noqa: F401
        CrashLogger.log_info("Pre-warmed: numpy")
    except ImportError:
        pass

    try:
        # Web requests
        import httpx  # noqa: F401
        CrashLogger.log_info("Pre-warmed: httpx")
    except ImportError:
        pass

    CrashLogger.log_info("Pre-warming complete")


def receive_response(response_json: str) -> None:
    """Receive a response from Flutter."""
    if _bridge:
        _bridge.receive_response(response_json)


def get_status() -> str:
    """Get bridge status."""
    if _bridge:
        return _bridge.get_status()
    return "uninitialized"


def get_bridge() -> NavixMindBridge:
    """Get the bridge instance."""
    global _bridge
    if _bridge is None:
        _bridge = NavixMindBridge.get_instance()
    return _bridge
