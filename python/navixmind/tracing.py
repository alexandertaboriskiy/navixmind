"""
Tracing module - Mentiora platform integration for observability.

Captures LLM calls and tool executions as trace events, sends them
to the Mentiora dashboard in a background thread. Gracefully no-ops
when the requests library is unavailable or no API key is configured.

Uses the Mentiora REST API directly (no SDK dependency) to avoid
native-extension issues on Chaquopy/Android.
"""

import json
import os
import struct
import threading
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from .crash_logger import CrashLogger

# Maximum characters for input/output fields before truncation
MAX_FIELD_LENGTH = 8000

# Maximum spans per trace (matches max_iterations default)
MAX_SPANS = 100

# Mentiora platform endpoint
MENTIORA_BASE_URL = "https://platform.mentiora.ai"
MENTIORA_TIMEOUT = 10  # seconds per request

# Check if requests is available (it's a Chaquopy pip dep)
try:
    import requests as _requests
    _HTTP_AVAILABLE = True
except ImportError:
    _HTTP_AVAILABLE = False
    CrashLogger.log_info("requests library not available - tracing disabled")


def _uuid7() -> str:
    """Generate a UUID v7 (time-ordered) as a string.

    UUID v7 format: unix_ts_ms (48 bits) | ver=7 (4 bits) | rand_a (12 bits)
                    | var=10 (2 bits) | rand_b (62 bits)
    """
    timestamp_ms = int(time.time() * 1000)
    rand_bytes = os.urandom(10)

    # Build 16 bytes
    ts_bytes = struct.pack(">Q", timestamp_ms)[-6:]  # 48-bit big-endian
    rand_a = rand_bytes[:2]
    rand_b = rand_bytes[2:]

    raw = bytearray(ts_bytes + rand_a + rand_b)

    # Set version (bits 48-51 = 0111)
    raw[6] = (raw[6] & 0x0F) | 0x70
    # Set variant (bits 64-65 = 10)
    raw[8] = (raw[8] & 0x3F) | 0x80

    hex_str = raw.hex()
    return f"{hex_str[:8]}-{hex_str[8:12]}-{hex_str[12:16]}-{hex_str[16:20]}-{hex_str[20:]}"


def _to_record(value: Any, key: str = "data") -> Dict[str, Any]:
    """Ensure a value is a dict/record for the Mentiora API.

    The API requires input/output to be JSON objects, not strings.
    Dicts pass through; lists/strings are wrapped with a descriptive key.
    """
    if value is None:
        return {}
    if isinstance(value, dict):
        # Truncate large string values inside
        result = {}
        for k, v in value.items():
            if isinstance(v, str) and len(v) > MAX_FIELD_LENGTH:
                result[k] = _truncate(v)
            else:
                result[k] = v
        return result
    if isinstance(value, (list, tuple)):
        return {key: value}
    s = str(value)
    if len(s) > MAX_FIELD_LENGTH:
        s = _truncate(s)
    return {key: s}


def _build_llm_input(messages: Any) -> Dict[str, Any]:
    """Build LLM input record matching Mentiora SDK format.

    Expected: {"messages": [...], "prompt": "last user message"}
    """
    if messages is None:
        return {}
    if isinstance(messages, dict):
        return messages
    if isinstance(messages, (list, tuple)):
        # Extract last user message as prompt
        prompt = ""
        for msg in reversed(messages):
            if isinstance(msg, dict) and msg.get("role") == "user":
                content = msg.get("content", "")
                if isinstance(content, str):
                    prompt = content
                elif isinstance(content, list):
                    # Claude content blocks
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "text":
                            prompt = block.get("text", "")
                            break
                break
        return {"messages": messages, "prompt": prompt}
    return {"prompt": str(messages)}


def _build_llm_output(response: Any) -> Dict[str, Any]:
    """Build LLM output record matching Mentiora SDK format.

    Expected: {"content": "assistant response text", "choices": [...]}
    """
    if response is None:
        return {}
    if isinstance(response, dict):
        return response
    if isinstance(response, (list, tuple)):
        # Claude content blocks — extract text
        content = ""
        for block in response:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "")
                content += text
        return {"content": content, "choices": response}
    return {"content": str(response)}


def _truncate(value: Any, max_len: int = MAX_FIELD_LENGTH) -> str:
    """Truncate a value to max_len characters for safe transmission."""
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        try:
            s = json.dumps(value)
        except (TypeError, ValueError):
            s = str(value)
    else:
        s = str(value)
    if len(s) > max_len:
        return s[:max_len - 20] + "\n...[truncated]..."
    return s


def _iso_now() -> str:
    """Return current UTC time as ISO 8601 string with Z suffix."""
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class _MentioraHttpClient:
    """Lightweight HTTP client for the Mentiora tracing API.

    Uses requests.Session for connection reuse. All errors propagate
    to the caller (caught by QueryTrace._send).
    """

    def __init__(self, api_key: str):
        self._session = _requests.Session()
        self._session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "navixmind/1.0",
        })

    def send_trace(self, event_data: Dict[str, Any]) -> None:
        """POST a single TraceEvent to the Mentiora API."""
        url = f"{MENTIORA_BASE_URL}/api/v1/traces"
        resp = self._session.post(url, json=event_data, timeout=MENTIORA_TIMEOUT)
        if not resp.ok:
            CrashLogger.log_info(f"Mentiora API {resp.status_code}: {resp.text[:500]}")
        resp.raise_for_status()

    def close(self) -> None:
        try:
            self._session.close()
        except Exception:
            pass


class TracingManager:
    """Singleton that manages the Mentiora HTTP client and creates query traces.

    Thread-safe. All errors are caught and logged, never propagated.
    """

    _instance: Optional["TracingManager"] = None
    _lock = threading.Lock()

    def __init__(self):
        self._api_key: Optional[str] = None
        self._client: Optional[_MentioraHttpClient] = None

    @classmethod
    def instance(cls) -> "TracingManager":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    @property
    def enabled(self) -> bool:
        """Whether tracing is active (requests available + key set)."""
        return _HTTP_AVAILABLE and self._api_key is not None and len(self._api_key) > 0

    def set_api_key(self, key: str) -> None:
        """Set the Mentiora API key. Creates or recreates the client."""
        old_client = self._client
        self._api_key = key if key else None
        self._client = None  # Reset client so it's recreated lazily
        if old_client is not None:
            old_client.close()
        if self._api_key:
            CrashLogger.log_info("Mentiora tracing key set")
        else:
            CrashLogger.log_info("Mentiora tracing key cleared")

    def _get_client(self) -> Optional[_MentioraHttpClient]:
        """Lazily create and return the HTTP client."""
        if not self.enabled:
            return None
        if self._client is None:
            try:
                self._client = _MentioraHttpClient(api_key=self._api_key)
            except Exception as e:
                CrashLogger.log_error("mentiora_client_init", e)
                self._client = None
        return self._client

    def start_trace(self, conversation_id: Optional[str] = None) -> "QueryTrace":
        """Create a new QueryTrace for a process_query() call.

        Returns a _NullQueryTrace if tracing is disabled.
        """
        if not self.enabled:
            return _NullQueryTrace()
        try:
            return QueryTrace(
                manager=self,
                conversation_id=conversation_id,
            )
        except Exception as e:
            CrashLogger.log_error("start_trace", e)
            return _NullQueryTrace()


class QueryTrace:
    """Collects LLM and tool spans for one process_query() call.

    Call add_llm_span() / add_tool_span() during the ReAct loop,
    then finish() at each return point. finish() sends all spans
    to Mentiora in a background thread as individual TraceEvent POSTs.
    """

    def __init__(self, manager: TracingManager, conversation_id: Optional[str] = None):
        self._manager = manager
        self._conversation_id = conversation_id
        self._spans: List[Dict[str, Any]] = []
        self._start_time = time.time()
        self._finished = False
        self._lock = threading.Lock()
        self._trace_id = _uuid7()
        self._thread_id = _uuid7()  # Always a valid UUID v7 for Mentiora API

    @property
    def trace_id(self) -> str:
        return self._trace_id

    def add_llm_span(
        self,
        model: str,
        messages: Any,
        response: Any,
        input_tokens: int = 0,
        output_tokens: int = 0,
        duration_ms: int = 0,
        error: Optional[str] = None,
    ) -> None:
        """Record an LLM API call span."""
        try:
            with self._lock:
                if self._finished or len(self._spans) >= MAX_SPANS:
                    return
                span = {
                    "span_type": "llm",
                    "span_id": _uuid7(),
                    "name": "llm.call",
                    "model": model,
                    "provider": "anthropic",
                    "input": messages,
                    "output": response,
                    "input_tokens": input_tokens,
                    "output_tokens": output_tokens,
                    "duration_ms": duration_ms,
                    "start_time": _iso_now(),
                }
                if error:
                    span["error"] = _truncate(error, 2000)
                self._spans.append(span)
        except Exception as e:
            CrashLogger.log_error("add_llm_span", e)

    def add_tool_span(
        self,
        tool_name: str,
        tool_input: Any,
        tool_output: Any,
        duration_ms: int = 0,
        error: Optional[str] = None,
    ) -> None:
        """Record a tool execution span."""
        try:
            with self._lock:
                if self._finished or len(self._spans) >= MAX_SPANS:
                    return
                span = {
                    "span_type": "tool",
                    "span_id": _uuid7(),
                    "name": f"tool.{tool_name}",
                    "tool_name": tool_name,
                    "input": tool_input,
                    "output": tool_output,
                    "duration_ms": duration_ms,
                    "start_time": _iso_now(),
                }
                if error:
                    span["error"] = _truncate(error, 2000)
                self._spans.append(span)
        except Exception as e:
            CrashLogger.log_error("add_tool_span", e)

    def finish(self, final_response: Optional[str] = None, error: Optional[str] = None) -> None:
        """Send all collected spans to Mentiora in a background thread.

        Each span is sent as an individual TraceEvent POST.
        Safe to call multiple times - only the first call sends.
        """
        with self._lock:
            if self._finished:
                return
            self._finished = True
            spans_copy = list(self._spans)

        total_duration_ms = int((time.time() - self._start_time) * 1000)

        def _send():
            try:
                client = self._manager._get_client()
                if client is None:
                    return

                for span in spans_copy:
                    try:
                        event = self._span_to_event(span)
                        client.send_trace(event)
                    except Exception as e:
                        CrashLogger.log_error("mentiora_send_span", e)

            except Exception as e:
                CrashLogger.log_error("mentiora_send_trace", e)

        try:
            thread = threading.Thread(target=_send, daemon=True)
            thread.start()
        except Exception as e:
            CrashLogger.log_error("mentiora_start_thread", e)

    def _span_to_event(self, span: Dict[str, Any]) -> Dict[str, Any]:
        """Convert an internal span dict to a Mentiora TraceEvent payload."""
        span_type = span["span_type"]

        # Build input/output as proper records matching SDK format
        if span_type == "llm":
            input_record = _build_llm_input(span.get("input"))
            output_record = _build_llm_output(span.get("output"))
        else:
            input_record = _to_record(span.get("input"), "params")
            output_record = _to_record(span.get("output"), "result")

        event = {
            "trace_id": self._trace_id,
            "span_id": span["span_id"],
            "thread_id": self._thread_id,
            "name": span["name"],
            "type": span_type,
            "input": input_record,
            "output": output_record,
            "start_time": span.get("start_time", _iso_now()),
            "duration_ms": span.get("duration_ms", 0),
            "tags": ["navixmind"],
        }

        if span.get("error"):
            event["error"] = {
                "message": _truncate(span["error"], 2000),
                "type": "AgentError",
            }

        if span_type == "llm":
            event["model"] = span.get("model", "unknown")
            event["provider"] = span.get("provider", "anthropic")
            event["usage"] = {
                "prompt_tokens": span.get("input_tokens", 0),
                "completion_tokens": span.get("output_tokens", 0),
            }

        if span_type == "tool":
            event["metadata"] = {"tool_name": span.get("tool_name", "")}

        return event


class _NullQueryTrace:
    """No-op trace for when tracing is disabled."""

    @property
    def trace_id(self) -> str:
        return ""

    def add_llm_span(self, **kwargs) -> None:
        pass

    def add_tool_span(self, **kwargs) -> None:
        pass

    def finish(self, **kwargs) -> None:
        pass
