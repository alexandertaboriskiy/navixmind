"""
Agent - ReAct loop implementation with Claude integration

This module implements the main agent logic, handling user queries,
tool execution, and response generation using a proper ReAct pattern.
"""

import json
import os
from typing import Any, Dict, List, Optional, Tuple

import requests

from .bridge import get_bridge, ToolError
from .session import get_session, apply_delta
from .crash_logger import CrashLogger
from .tools import execute_tool, TOOLS_SCHEMA


# Constants (defaults, overridden by settings via context)
DEFAULT_MAX_ITERATIONS = 50
DEFAULT_MAX_TOOL_CALLS = 50
DEFAULT_MAX_TOKENS = 16384
MAX_CONTEXT_TOKENS = 150000
DEFAULT_MODEL = "claude-opus-4-20250514"
SONNET_MODEL = "claude-sonnet-4-20250514"
FALLBACK_MODEL = "claude-haiku-4-5-20251001"

# Cost threshold for switching to cheaper model (percentage of daily limit)
COST_THRESHOLD_FOR_HAIKU = 80

# Simple query patterns that can use Haiku
SIMPLE_QUERY_PATTERNS = [
    "what time",
    "what day",
    "what date",
    "convert",
    "format",
    "translate to",
    "is this",
    "yes or no",
    "true or false",
    "classify",
    "categorize",
    "extract",
    "list the",
    "count the",
    "how many",
    "summarize briefly",
]

# Complex query patterns that need Sonnet
COMPLEX_QUERY_PATTERNS = [
    "analyze",
    "explain in detail",
    "compare and contrast",
    "write code",
    "debug",
    "implement",
    "design",
    "create a plan",
    "step by step",
    "research",
    "investigate",
]

# Global API key storage (set via Flutter)
_api_key: Optional[str] = None

# Global Google access token (set via Flutter or per-query context)
_access_token: Optional[str] = None


def set_api_key(key: str) -> None:
    """Set the Claude API key globally."""
    global _api_key
    _api_key = key
    CrashLogger.log_info("API key set")


def get_api_key() -> Optional[str]:
    """Get the Claude API key (from global or environment)."""
    return _api_key or os.environ.get('CLAUDE_API_KEY')


def set_access_token(token: str) -> None:
    """Set the Google access token globally."""
    global _access_token
    _access_token = token
    CrashLogger.log_info("Google access token set")


# System prompt
SYSTEM_PROMPT = """You are NavixMind, an AI assistant running on an Android device. You have access to
various tools through the NavixMind OS environment.

AVAILABLE TOOLS:
- **python_execute** — Run Python code in a secure sandbox (math, numpy, pandas, matplotlib, json, re, datetime, collections, itertools, functools, statistics, csv, base64, hashlib). Use print() for output. FORBIDDEN: subprocess, os, sys, shutil, socket, http, urllib, pathlib, glob, signal, ctypes, multiprocessing, threading.
- **web_fetch** — Fetch a webpage and extract text, HTML, or links
- **headless_browser** — Load JavaScript-heavy pages in a headless browser
- **read_pdf** — Extract text from PDF files (supports page ranges)
- **create_pdf** — Create PDF from text and/or images
- **create_zip** — Create ZIP archives from one or more files (supports deflated/stored compression)
- **convert_document** — Convert between DOCX, PDF, HTML, and TXT
- **read_docx** — Extract text, tables, and metadata from DOCX files
- **modify_docx** — Modify existing DOCX files (replace text, add paragraphs, update table cells)
- **read_pptx** — Extract text, slide content, speaker notes from PPTX files
- **modify_pptx** — Modify existing PPTX files (replace text, add slides, update shapes, set notes)
- **read_xlsx** — Extract cell data, sheet names, and formulas from XLSX files
- **modify_xlsx** — Modify existing XLSX files (set cells, formulas, add rows/sheets, delete sheets)
- **ffmpeg_process** — Process video/audio: trim, crop, resize, filter, extract audio/frame, convert. Returns media_duration_seconds (actual media length) and processing_time_ms (execution time) — do NOT confuse them. NEVER use % patterns (like %03d) in output filenames — the tool expects a single output file. To split media into segments, use multiple trim calls with start/duration.
- **smart_crop** — Smart crop video/image to focus on faces (for simple face-centered cropping only)
- **ocr_image** — Extract text from images using OCR
- **download_media** — Download video/audio from supported platforms (NOT YouTube)
- **google_calendar** — Query or create Google Calendar events (list, create, delete)
- **gmail** — Read Gmail messages (list, read). Read-only access — sending is not available.
- **file_info** — Get file metadata (size, name, extension)
- **read_file** — Read text content from a file (any text-based format)
- **write_file** — Write text content to a file (saved to device, available for download/sharing)

GOOGLE SERVICES (google_calendar, gmail):
- These tools require the user to connect their Google account in Settings first.
- If a Google tool returns "Google account not connected", tell the user: "Please connect your Google account in Settings to use this feature."
- Do NOT retry Google tools after a "not connected" error — it won't help until the user connects.

FILE HANDLING:
- Users attach files to their messages. Use file basenames (e.g., "photo.jpg") when calling tools — paths are resolved automatically.
- Output files (create_pdf, create_zip, ffmpeg_process, write_file, etc.) are saved to the device. Use descriptive filenames.
- **ALWAYS include the output file path in your response** when you create or modify a file. The user needs the path to share/download the result. Example: "Here's your compressed video: `/path/to/output.mp4`"
- To check file properties, use the file_info tool. Do NOT import os in python_execute.

FFMPEG PATTERNS (use these exact patterns — do NOT improvise):
- **Keep every Nth second**: operation="filter", vf="select='not(mod(floor(t),N))',setpts=N/FRAME_RATE/TB", af="aselect='not(mod(floor(t),N))',asetpts=N/SR/TB" (e.g. N=2 keeps seconds 0,2,4...)
- **Remove every Nth second**: operation="filter", vf="select='mod(floor(t),N)',setpts=N/FRAME_RATE/TB", af="aselect='mod(floor(t),N)',asetpts=N/SR/TB"
- **Keep time range**: operation="trim" with start/end or start/duration — simpler and more reliable than select
- **Black & white**: operation="filter", vf="hue=s=0" (do NOT use format=gray — it breaks Android playback)
- **Speed up/slow down**: operation="filter", vf="setpts=0.5*PTS" (2x speed), af="atempo=2.0"
- **A/V sync rule**: ALWAYS provide matching af when using vf with select/aselect. Use setpts=N/FRAME_RATE/TB for video and asetpts=N/SR/TB for audio.
- **NEVER use mod(n,...) for time-based editing** — n is frame number (varies with FPS), use t (time in seconds) instead.
- Prefer operation="trim" for simple cuts over complex select expressions.
- **NEVER use operation="custom"** for video filtering. Use operation="filter" with vf/af — it handles A/V sync, codec selection, and Android compatibility automatically. operation="custom" is ONLY for rare edge cases that no other operation supports.
- Commas inside filter expressions are escaped automatically — write them normally.
- When combining effects (e.g. select + black & white), chain them in a single vf string: vf="select='...',setpts=...,hue=s=0"

PYTHON EXECUTION:
- Use python_execute for calculations, data processing, algorithms, text manipulation.
- Use pandas for tabular data analysis (DataFrames, groupby, describe, CSV read/write).
- Use matplotlib for charts/graphs. Plots are auto-saved as PNG and returned to the user.
- An OUTPUT_DIR variable is available in python_execute for saving output files (CSV, plots, etc.).
- Do NOT use python_execute to call ffmpeg/ffprobe — use the ffmpeg_process tool instead.
- Do NOT access files via os/pathlib — use dedicated tools (read_file, read_pdf, ocr_image, file_info, etc.).
- python_execute cannot access the network — use web_fetch for that.
- python_execute can only read files explicitly listed in its file_paths parameter.

PROBLEM-SOLVING — NEVER GIVE UP ON FIRST ATTEMPT:
- If a tool cannot do something in one call, BREAK IT DOWN into multiple steps. Never say "I can't" without trying an alternative.
- For complex file operations (e.g., "improve all slide titles", "reformat every table", "update all headings"):
  1. FIRST read the file to understand its structure (read_pptx, read_docx, read_xlsx, read_pdf).
  2. THEN iterate: process each element (slide, paragraph, row, page) one at a time using modify tools or python_execute.
  3. Each iteration can use YOUR intelligence to generate improved content (new titles, better descriptions, reformatted text).
- If a dedicated tool (modify_pptx, modify_docx, modify_xlsx) is too limited for a complex operation, use python_execute with the file's library directly (python-pptx, python-docx, openpyxl) — the file_paths parameter gives you read access, and you can write output to OUTPUT_DIR.
- If one approach fails, TRY ANOTHER. Exhaust all options before telling the user something is impossible.
- This applies to ALL tasks, not just documents: web fetching, media processing, data analysis — always adapt and retry.

ERROR HANDLING:
- If a tool fails, try an alternative approach FIRST. Only explain the error if all approaches fail.
- If python_execute fails due to a forbidden module, use the correct dedicated tool.
- If a file is not found, ask the user to re-attach it.

STYLE:
- Be concise; this is a mobile interface.
- Use markdown for formatting when helpful.
- For code or data, use monospace formatting.

CRITICAL RULE:
- Each user message is a NEW request. You MUST call the appropriate tools to fulfill it.
- NEVER assume previous results satisfy the current request. If the user asks to process, convert, or create a file, you MUST call the tool — do NOT just describe the result or say "done".
- The conversation history shows what happened before. Your job is to execute the NEW request NOW using tools.
"""

# User-friendly error messages
ERROR_MESSAGES = {
    "network_offline": "No internet connection. Check your network and try again.",
    "api_rate_limit": "Too many requests. Please wait {seconds} seconds.",
    "api_quota_exceeded": "Daily API limit reached. Resets at midnight.",
    "auth_expired": "Session expired. Tap to sign in again.",
    "storage_full": "Device storage full ({used}/{total}). Free up space to continue.",
    "ffmpeg_invalid_input": "Cannot process this video format. Try a different file.",
    "llm_overloaded": "AI service is busy. Retrying automatically...",
    "tool_timeout": "Operation timed out after {seconds}s. The file may be too large.",
    "python_crash": "Internal error occurred. The app will recover automatically.",
    "file_too_large": "File is too large ({size}MB). Maximum allowed: {max}MB.",
}


class ClaudeClient:
    """Client for Claude API with retry logic."""

    def __init__(self, api_key: str, model: str = DEFAULT_MODEL):
        self.api_key = api_key
        self.model = model
        self.base_url = "https://api.anthropic.com/v1/messages"

    def create_message(
        self,
        messages: List[Dict[str, Any]],
        system: str = SYSTEM_PROMPT,
        tools: Optional[List[dict]] = None,
        max_tokens: int = 4096,
        retry_count: int = 3
    ) -> dict:
        """
        Create a message with Claude, with retry logic for transient errors.

        Args:
            messages: Conversation messages
            system: System prompt
            tools: Tool definitions
            max_tokens: Maximum tokens in response
            retry_count: Number of retries for transient errors

        Returns:
            API response dict

        Raises:
            APIError: On non-recoverable API errors
        """
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }

        body = {
            "model": self.model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": messages,
        }

        if tools:
            body["tools"] = tools

        last_error = None
        for attempt in range(retry_count):
            try:
                response = requests.post(
                    self.base_url,
                    headers=headers,
                    json=body,
                    timeout=120
                )

                if response.status_code == 200:
                    return response.json()

                error_body = response.json()
                error_message = error_body.get('error', {}).get('message', 'Unknown API error')

                # Handle rate limiting with retry
                if response.status_code == 429:
                    retry_after = int(response.headers.get('retry-after', 5))
                    if attempt < retry_count - 1:
                        import time
                        time.sleep(retry_after)
                        continue
                    raise APIError(f"Rate limited: {error_message}", 429)

                # Handle server errors with retry
                if response.status_code in (500, 502, 503):
                    if attempt < retry_count - 1:
                        import time
                        time.sleep(2 ** attempt)  # Exponential backoff
                        continue
                    raise APIError(f"Server error: {error_message}", response.status_code)

                # Non-recoverable errors
                raise APIError(error_message, response.status_code)

            except requests.Timeout:
                last_error = APIError("Request timed out", 408)
                if attempt < retry_count - 1:
                    continue
                raise last_error

            except requests.RequestException as e:
                last_error = APIError(f"Network error: {str(e)}", 0)
                if attempt < retry_count - 1:
                    import time
                    time.sleep(1)
                    continue
                raise last_error

        raise last_error or APIError("Unknown error", 0)


class APIError(Exception):
    """Error from Claude API."""

    def __init__(self, message: str, status_code: int):
        super().__init__(message)
        self.status_code = status_code


def handle_request(request_json: str) -> str:
    """
    Main entry point for handling requests from Flutter.

    Args:
        request_json: JSON-RPC request string

    Returns:
        JSON-RPC response string
    """
    try:
        request = json.loads(request_json)
        method = request.get('method')
        params = request.get('params', {})
        request_id = request.get('id')

        if method == 'process_query':
            result = process_query(
                user_query=params.get('user_query', ''),
                files=params.get('files', []),
                context=params.get('context', {})
            )
            return json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "result": result
            })

        elif method == 'apply_delta':
            apply_delta(params)
            return json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {"success": True}
            })

        elif method == 'set_api_key':
            set_api_key(params.get('api_key', ''))
            return json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {"success": True}
            })

        elif method == 'set_access_token':
            set_access_token(params.get('access_token', ''))
            return json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {"success": True}
            })

        elif method == 'self_improve':
            result = self_improve(
                conversation=params.get('conversation', []),
                current_prompt=params.get('current_prompt', ''),
                api_key=params.get('api_key', ''),
            )
            return json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "result": result
            })

        else:
            return json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            })

    except json.JSONDecodeError as e:
        CrashLogger.log_error("handle_request", e)
        return json.dumps({
            "jsonrpc": "2.0",
            "id": None,
            "error": {
                "code": -32700,
                "message": f"Parse error: {str(e)}"
            }
        })
    except Exception as e:
        CrashLogger.log_error("handle_request", e)
        return json.dumps({
            "jsonrpc": "2.0",
            "id": None,
            "error": {
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            }
        })


def process_query(
    user_query: str,
    files: List[str] = None,
    context: Dict[str, Any] = None
) -> dict:
    """
    Process a user query through the ReAct agent loop.

    This implements the full ReAct pattern:
    1. Send query to Claude with tools available
    2. If Claude uses a tool, execute it and send result back
    3. Repeat until Claude responds with end_turn or max iterations reached

    Args:
        user_query: The user's query text
        files: List of file paths attached to the query
        context: Additional context (tokens, device info, etc.)

    Returns:
        Result dict with 'content' key containing the response
    """
    bridge = get_bridge()
    session = get_session()
    context = context or {}

    # Get API key (from global storage or environment)
    api_key = get_api_key()

    if not api_key:
        return {
            "content": "API key not configured. Please enter your Claude API key to get started.",
            "error": True
        }

    # Inject stored Google access token as fallback if not in per-query context
    if _access_token and 'google_access_token' not in context:
        context['google_access_token'] = _access_token

    # Add attachment info to context for model selection
    if files:
        context['has_attachments'] = True

    # Use custom system prompt from context, or fall back to default
    system_prompt = context.get('system_prompt', SYSTEM_PROMPT)

    # Select appropriate model based on query and context
    selected_model, model_reason = _select_model(user_query, context)
    bridge.log(model_reason, level="info")
    if system_prompt != SYSTEM_PROMPT:
        bridge.log("Using custom system prompt", level="info")

    # Create Claude client with selected model
    client = ClaudeClient(api_key, model=selected_model)

    # Build initial messages from session context
    messages = session.get_context_for_llm(MAX_CONTEXT_TOKENS)
    bridge.log(f"Context: {len(messages)} previous messages, {len(session.messages)} in session", level="info")

    # Add current user message with any attachments
    user_content = user_query
    # Persist file map across queries so subsequent queries can reference earlier uploads
    if not hasattr(session, '_file_map'):
        session._file_map = {}
    if files:
        file_list = ", ".join(os.path.basename(f) for f in files)
        user_content += f"\n\n[Attached files: {file_list}]"
        # Merge new uploads into persistent file map
        for f in files:
            session._file_map[os.path.basename(f)] = f
    # Always provide the full file map to tools
    context['_file_map'] = dict(session._file_map)

    messages.append({"role": "user", "content": user_content})

    # Add to session for context tracking (use enriched content so file names persist)
    session.add_message("user", user_content)

    # ReAct loop — limits configurable from Settings
    max_iterations = context.get('max_iterations', DEFAULT_MAX_ITERATIONS)
    max_tool_calls = context.get('max_tool_calls', DEFAULT_MAX_TOOL_CALLS)
    max_tokens = context.get('max_tokens', DEFAULT_MAX_TOKENS)
    iteration = 0
    tool_call_count = 0
    final_response = None
    created_files = []  # Track output files for session context

    while iteration < max_iterations:
        iteration += 1
        bridge.log(f"Thinking... (step {iteration}/{max_iterations})", progress=iteration / max_iterations * 0.5)

        try:
            bridge.log("Calling Claude API...", level="info")
            response = client.create_message(
                messages=messages,
                system=system_prompt,
                tools=TOOLS_SCHEMA,
                max_tokens=max_tokens,
            )
            bridge.log("Got response from Claude", level="info")
        except APIError as e:
            bridge.log(f"API error: {e}", level="error")
            error_msg = _get_user_friendly_error(e)
            session.add_message("assistant", error_msg)
            return {"content": error_msg, "error": True}
        except Exception as e:
            CrashLogger.log_error("process_query", e)
            bridge.log(f"Exception: {str(e)}", level="error")
            error_msg = f"An unexpected error occurred: {e}"
            session.add_message("assistant", error_msg)
            return {
                "content": error_msg,
                "error": True
            }

        # Get stop reason and content
        stop_reason = response.get('stop_reason')
        content_blocks = response.get('content', [])

        # Log stop reason for visibility
        bridge.log(f"Stop reason: {stop_reason}", level="info")

        # Track usage for cost management
        usage = response.get('usage', {})
        if usage:
            input_tokens = usage.get('input_tokens', 0)
            output_tokens = usage.get('output_tokens', 0)
            bridge.log(f"Tokens: {input_tokens} in, {output_tokens} out", level="info")
            _record_usage(
                model=client.model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                context=context
            )

        # Log any text content (Claude's thinking before tool use)
        thinking_text = _extract_text_content(content_blocks)
        if thinking_text and stop_reason == 'tool_use':
            # Show a preview of Claude's thinking
            preview = thinking_text[:100] + "..." if len(thinking_text) > 100 else thinking_text
            bridge.log(f"Thinking: {preview}", level="info")

        # Case 1: Agent finished (end_turn)
        if stop_reason == 'end_turn':
            final_response = _extract_text_content(content_blocks)
            bridge.log("Preparing response...", progress=0.95)
            # Store response in session. File paths are tracked in session._file_map
            # so follow-up queries can reference them. Do NOT append file list to the
            # assistant text — it confuses the model into thinking work is already done.
            session.add_message("assistant", final_response)
            bridge.log("Done!", progress=1.0)
            result = {"content": final_response}
            if created_files:
                result["created_files"] = created_files
            return result

        # Case 2: Agent wants to use tools
        if stop_reason == 'tool_use':
            # Process all tool calls in this response
            tool_results = []

            # Count tools in this response
            tools_in_response = sum(1 for b in content_blocks if b.get('type') == 'tool_use')
            bridge.log(f"Executing {tools_in_response} tool(s)...", level="info")

            for block in content_blocks:
                if block.get('type') == 'tool_use':
                    tool_name = block.get('name')
                    tool_input = block.get('input', {})
                    tool_id = block.get('id')

                    tool_call_count += 1
                    if tool_call_count > max_tool_calls:
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": tool_id,
                            "is_error": True,
                            "content": "Maximum tool calls reached for this query."
                        })
                        continue

                    # Log tool name and input summary
                    input_summary = _summarize_tool_input(tool_name, tool_input)
                    bridge.log(f"Tool: {tool_name} - {input_summary}", progress=0.5 + (iteration / max_iterations * 0.3))

                    try:
                        # Log code for python_execute before running
                        if tool_name == 'python_execute':
                            code = tool_input.get('code', '')
                            if code:
                                bridge.log(f"Code:\n```python\n{code}\n```", level="info")

                        result = execute_tool(tool_name, tool_input, context)
                        # Truncate large results
                        result_str = json.dumps(result) if isinstance(result, dict) else str(result)

                        # Log created files as clickable links and add to file map
                        if isinstance(result, dict):
                            if result.get('output_path'):
                                output_path = result['output_path']
                                bridge.log(f"File: {output_path}", level="info")
                                created_files.append(output_path)
                                session._file_map[os.path.basename(output_path)] = output_path
                            # Also track multi-file results (e.g. FFmpeg split)
                            if result.get('output_paths'):
                                for p in result['output_paths']:
                                    bridge.log(f"File: {p}", level="info")
                                    created_files.append(p)
                                    session._file_map[os.path.basename(p)] = p

                        # Log result summary
                        result_summary = _summarize_tool_result(tool_name, result_str)
                        bridge.log(f"Result: {result_summary}", level="info")

                        if len(result_str) > 10000:
                            result_str = result_str[:5000] + "\n\n[Output truncated...]\n\n" + result_str[-2000:]

                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": tool_id,
                            "content": result_str
                        })
                    except ToolError as e:
                        bridge.log(f"Tool error: {e}", level="warn")
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": tool_id,
                            "is_error": True,
                            "content": str(e)
                        })
                    except Exception as e:
                        CrashLogger.log_error(f"tool_{tool_name}", e)
                        bridge.log(f"Tool exception: {str(e)}", level="error")
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": tool_id,
                            "is_error": True,
                            "content": f"Tool error: {str(e)}"
                        })

            # Add assistant message (with tool_use blocks) and tool results to conversation
            messages.append({"role": "assistant", "content": content_blocks})
            messages.append({"role": "user", "content": tool_results})

            # Continue the loop to get next response
            continue

        # Case 3: Max tokens reached — continue the loop so Claude can finish
        if stop_reason == 'max_tokens':
            bridge.log("Response hit token limit, continuing...", level="info")
            # Add partial assistant content to conversation and ask to continue
            messages.append({"role": "assistant", "content": content_blocks})
            messages.append({"role": "user", "content": "Continue from where you left off."})
            continue

        # Case 4: Unexpected stop reason
        bridge.log(f"Unexpected stop reason: {stop_reason}", level="warn")
        partial = _extract_text_content(content_blocks)
        if partial:
            session.add_message("assistant", partial)
            return {"content": partial}
        break

    # Reached max iterations
    summary = _summarize_progress(messages, tool_call_count)
    max_iter_msg = f"I've reached my step limit after {iteration} iterations and {tool_call_count} tool calls. {summary}"
    session.add_message("assistant", max_iter_msg)
    return {"content": max_iter_msg}


def _extract_text_content(content_blocks: List[dict]) -> str:
    """Extract all text content from response blocks."""
    text_parts = []
    for block in content_blocks:
        if block.get('type') == 'text':
            text_parts.append(block.get('text', ''))
    return '\n'.join(text_parts)


def _summarize_progress(messages: List[dict], tool_call_count: int) -> str:
    """Summarize what the agent has accomplished."""
    tool_names = set()

    for msg in messages:
        content = msg.get('content', [])
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get('type') == 'tool_use':
                    tool_names.add(block.get('name', 'unknown'))

    if tool_names:
        return f"I used these tools: {', '.join(sorted(tool_names))}. Here's what I found so far..."
    return "I was analyzing your request but couldn't complete it."


def _get_user_friendly_error(error: APIError) -> str:
    """Convert API error to user-friendly message."""
    if error.status_code == 429:
        return ERROR_MESSAGES["api_rate_limit"].format(seconds=60)
    if error.status_code == 401:
        return "Invalid API key. Please check your configuration in Settings."
    if error.status_code in (500, 502, 503):
        return ERROR_MESSAGES["llm_overloaded"]
    if error.status_code == 408:
        return ERROR_MESSAGES["tool_timeout"].format(seconds=120)
    return f"Sorry, I encountered an error: {error}"


def _record_usage(model: str, input_tokens: int, output_tokens: int, context: dict) -> None:
    """Record API usage for cost tracking."""
    try:
        bridge = get_bridge()
        bridge._send({
            "jsonrpc": "2.0",
            "method": "record_usage",
            "params": {
                "model": model,
                "input_tokens": input_tokens,
                "output_tokens": output_tokens
            }
        })
    except Exception as e:
        CrashLogger.log_error("record_usage", e)


def _select_model(query: str, context: Dict[str, Any]) -> Tuple[str, str]:
    """
    Select the appropriate model based on query complexity and cost budget.

    Returns:
        Tuple of (model_name, reason)

    Selection criteria:
    1. If cost budget is >= 80% used -> use Haiku to conserve budget
    2. If query is simple (classification, format conversion, etc.) -> use Haiku
    3. If query is complex (analysis, coding, research) -> use Sonnet
    4. Default -> use Sonnet for best quality
    """
    query_lower = query.lower().strip()

    # Check 1: Cost budget threshold
    cost_percent_used = context.get('cost_percent_used', 0) or 0
    if cost_percent_used >= COST_THRESHOLD_FOR_HAIKU:
        return FALLBACK_MODEL, f"Using faster model (budget at {cost_percent_used:.1f}%)"

    # Check 2: Explicit model request in context
    requested_model = context.get('preferred_model')
    if requested_model == 'haiku':
        return FALLBACK_MODEL, "Using faster model (user preference)"
    if requested_model == 'sonnet':
        return SONNET_MODEL, "Using Sonnet model (user preference)"
    if requested_model == 'opus':
        return DEFAULT_MODEL, "Using Opus model (user preference)"

    # Check 3: Complex query patterns -> always use Sonnet
    for pattern in COMPLEX_QUERY_PATTERNS:
        if pattern in query_lower:
            return DEFAULT_MODEL, "Using advanced model for complex task"

    # Check 4: Simple query patterns -> can use Haiku
    for pattern in SIMPLE_QUERY_PATTERNS:
        if pattern in query_lower:
            return FALLBACK_MODEL, "Using faster model for simple task"

    # Check 5: Very short queries are often simple
    word_count = len(query.split())
    if word_count <= 5 and '?' in query:
        return FALLBACK_MODEL, "Using faster model for quick question"

    # Check 6: Queries with attachments typically need more analysis
    if context.get('has_attachments', False):
        return DEFAULT_MODEL, "Using advanced model for file analysis"

    # Default: Use Sonnet for best quality
    return DEFAULT_MODEL, "Using advanced model"


def _summarize_tool_input(tool_name: str, tool_input: dict) -> str:
    """Create a short summary of tool input for logging."""
    try:
        if tool_name == 'python_execute':
            code = tool_input.get('code', '')
            lines = code.strip().split('\n')
            if len(lines) > 1:
                return f"{len(lines)} lines of code"
            elif code:
                return code[:50] + "..." if len(code) > 50 else code
            return "empty code"

        if tool_name == 'web_fetch':
            url = tool_input.get('url', '')
            return url[:60] + "..." if len(url) > 60 else url

        if tool_name in ('read_file', 'ocr_image'):
            path = tool_input.get('image_path', tool_input.get('path', tool_input.get('file_path', '')))
            import os
            return os.path.basename(path) if path else "unknown file"

        if tool_name == 'create_pdf':
            title = tool_input.get('title', 'untitled')
            images = tool_input.get('image_paths', [])
            if images:
                return f"Creating '{title}' with {len(images)} image(s)"
            return f"Creating '{title}'"

        if tool_name == 'ffmpeg_process':
            op = tool_input.get('operation', '?')
            params = tool_input.get('params', {})
            params_str = json.dumps(params) if params else ''
            if len(params_str) > 100:
                params_str = params_str[:100] + '...'
            return f"{op}: {params_str}" if params_str else op

        # Generic fallback
        keys = list(tool_input.keys())
        if keys:
            return f"params: {', '.join(keys[:3])}"
        return "no params"
    except Exception:
        return "..."


def _summarize_tool_result(tool_name: str, result_str: str) -> str:
    """Create a short summary of tool result for logging."""
    try:
        length = len(result_str)
        if length > 500:
            return f"got {length} chars"
        elif length > 100:
            return result_str[:80] + "..."
        else:
            return result_str[:100]
    except Exception:
        return "..."


def self_improve(
    conversation: List[Dict[str, str]],
    current_prompt: str,
    api_key: str,
) -> dict:
    """
    Analyze a conversation and generate an improved system prompt.

    Uses extended thinking to deeply analyze what went well and what could
    be improved, then produces a refined system prompt.

    Args:
        conversation: List of {role, content} dicts from the chat
        current_prompt: The current system prompt text
        api_key: Claude API key

    Returns:
        Dict with 'improved_prompt' on success, or 'error'/'message' on failure
    """
    bridge = get_bridge()

    if not api_key:
        return {"error": True, "message": "API key not configured"}

    if not conversation:
        return {"error": True, "message": "No conversation to analyze"}

    bridge.log("Analyzing conversation for self-improvement...", level="info")

    # Format conversation as readable text
    conv_text = ""
    for msg in conversation:
        role = msg.get("role", "unknown").capitalize()
        content = msg.get("content", "")
        conv_text += f"[{role}]: {content}\n\n"

    # Build tool names list for context
    tool_names = [t["name"] for t in TOOLS_SCHEMA]
    tool_list_str = ", ".join(tool_names)

    # Build the meta-prompt
    meta_prompt = f"""You are analyzing a conversation between a user and an AI assistant called NavixMind.
Your task is to improve the system prompt that guides the assistant's behavior.

CURRENT SYSTEM PROMPT:
---
{current_prompt}
---

AVAILABLE TOOLS (the assistant has these tools via the API — the system prompt should reference them by name):
{tool_list_str}

CONVERSATION:
---
{conv_text}
---

Analyze the conversation carefully:
1. What did the assistant do well?
2. Where did the assistant fail, get confused, or could have been better?
3. What specific tools did the assistant misuse, fail to use, or use incorrectly?
4. What patterns, preferences, or needs does the user have?
5. What instructions could help the assistant handle similar situations better next time?

Now write an IMPROVED system prompt that:
- Keeps all working parts of the current prompt (especially the AVAILABLE TOOLS section)
- Adds specific instructions to fix the exact failures you observed in the conversation
- References tools BY NAME (e.g. "use google_calendar for calendar queries", not just "access calendar")
- Adds error-handling guidance for any errors that occurred (e.g. "if Google not connected, tell user to connect in Settings")
- Incorporates user preferences and patterns you noticed
- Stays concise — this runs on a mobile device
- Does NOT remove any tool names or capability descriptions from the current prompt

Output ONLY the improved system prompt text, nothing else. No preamble, no explanation."""

    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    body = {
        "model": DEFAULT_MODEL,
        "max_tokens": 16000,
        "thinking": {
            "type": "enabled",
            "budget_tokens": 10000,
        },
        "temperature": 1,
        "messages": [
            {"role": "user", "content": meta_prompt},
        ],
    }

    try:
        bridge.log("Calling Claude with extended thinking...", level="info")
        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers=headers,
            json=body,
            timeout=180,
        )

        if response.status_code != 200:
            error_body = response.json()
            error_msg = error_body.get("error", {}).get("message", "Unknown API error")
            bridge.log(f"Self-improve API error: {error_msg}", level="error")
            return {"error": True, "message": f"API error: {error_msg}"}

        result = response.json()

        # Record usage
        usage = result.get("usage", {})
        if usage:
            _record_usage(
                model=DEFAULT_MODEL,
                input_tokens=usage.get("input_tokens", 0),
                output_tokens=usage.get("output_tokens", 0),
                context={},
            )

        # Extract only text blocks (skip thinking blocks)
        content_blocks = result.get("content", [])
        text_parts = []
        for block in content_blocks:
            if block.get("type") == "text":
                text_parts.append(block.get("text", ""))

        improved_prompt = "\n".join(text_parts).strip()

        if not improved_prompt:
            bridge.log("Self-improve returned empty response", level="warn")
            return {"error": True, "message": "No improved prompt generated"}

        bridge.log("System prompt improved successfully", level="info")
        return {"improved_prompt": improved_prompt}

    except requests.Timeout:
        bridge.log("Self-improve timed out", level="error")
        return {"error": True, "message": "Request timed out (180s). Try with a shorter conversation."}
    except requests.RequestException as e:
        bridge.log(f"Self-improve network error: {e}", level="error")
        return {"error": True, "message": f"Network error: {str(e)}"}
    except Exception as e:
        CrashLogger.log_error("self_improve", e)
        bridge.log(f"Self-improve exception: {e}", level="error")
        return {"error": True, "message": f"Unexpected error: {str(e)}"}
