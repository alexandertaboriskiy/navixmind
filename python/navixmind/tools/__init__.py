"""
Tools - Native tool implementations for the agent

This module provides tool definitions and execution logic.
"""

from typing import Any, Dict

from .web import web_fetch, headless_browser
from .documents import read_pdf, create_pdf, convert_document, create_zip
from .media import download_media
from .google_api import google_calendar, gmail
from .code_executor import python_execute

from ..bridge import ToolError


# Tool schema for Claude
TOOLS_SCHEMA = [
    {
        "name": "web_fetch",
        "description": "Fetch a webpage and extract its text content.",
        "input_schema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL to fetch"},
                "extract_mode": {
                    "type": "string",
                    "enum": ["text", "html", "links"],
                    "description": "What to extract from the page"
                }
            },
            "required": ["url"]
        }
    },
    {
        "name": "headless_browser",
        "description": "Load a JavaScript-heavy page in a headless browser and extract content.",
        "input_schema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL to load"},
                "wait_seconds": {
                    "type": "integer",
                    "default": 5,
                    "description": "Seconds to wait for JS to render"
                },
                "extract_selector": {
                    "type": "string",
                    "description": "CSS selector to extract, or empty for full page"
                }
            },
            "required": ["url"]
        }
    },
    {
        "name": "read_pdf",
        "description": "Extract text content from a PDF file.",
        "input_schema": {
            "type": "object",
            "properties": {
                "pdf_path": {"type": "string", "description": "Path to PDF file"},
                "pages": {
                    "type": "string",
                    "description": "Page range, e.g., '1-5' or 'all'"
                }
            },
            "required": ["pdf_path"]
        }
    },
    {
        "name": "create_pdf",
        "description": "Create a PDF document from text and/or images. Can embed images (JPG, PNG) directly into the PDF.",
        "input_schema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "Text content for the PDF (optional if images provided)"},
                "title": {"type": "string", "description": "Document title"},
                "output_path": {"type": "string", "description": "Where to save the PDF"},
                "image_paths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of image file paths to embed in the PDF"
                }
            },
            "required": ["output_path"]
        }
    },
    {
        "name": "convert_document",
        "description": "Convert documents between formats (DOCX to PDF, etc.)",
        "input_schema": {
            "type": "object",
            "properties": {
                "input_path": {"type": "string", "description": "Path to input file"},
                "output_format": {
                    "type": "string",
                    "enum": ["pdf", "html", "txt"],
                    "description": "Target format"
                }
            },
            "required": ["input_path", "output_format"]
        }
    },
    {
        "name": "create_zip",
        "description": "Create a ZIP archive from one or more files. Supports deflated (compressed) and stored (no compression) modes.",
        "input_schema": {
            "type": "object",
            "properties": {
                "output_path": {"type": "string", "description": "Where to save the ZIP file"},
                "file_paths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of file paths to include in the archive"
                },
                "compression": {
                    "type": "string",
                    "enum": ["deflated", "stored"],
                    "default": "deflated",
                    "description": "Compression method: 'deflated' (smaller) or 'stored' (no compression, faster)"
                }
            },
            "required": ["output_path", "file_paths"]
        }
    },
    {
        "name": "download_media",
        "description": "Download video/audio from supported platforms (TikTok, Instagram, etc.). NOT YouTube.",
        "input_schema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL of the media"},
                "format": {
                    "type": "string",
                    "enum": ["video", "audio"],
                    "description": "Whether to download video or audio only"
                }
            },
            "required": ["url"]
        }
    },
    {
        "name": "ffmpeg_process",
        "description": "Process video/audio with FFmpeg. Operations: trim, crop, resize, filter (brightness/contrast/etc), custom (raw FFmpeg args for complex ops), extract_audio, extract_frame, convert.",
        "input_schema": {
            "type": "object",
            "properties": {
                "input_path": {"type": "string", "description": "Path to input file"},
                "output_path": {"type": "string", "description": "Path for output file"},
                "operation": {
                    "type": "string",
                    "enum": ["trim", "crop", "resize", "filter", "custom", "extract_audio", "extract_frame", "convert"],
                    "description": "Operation to perform"
                },
                "params": {
                    "type": "object",
                    "description": "Operation params. trim: {start, end} or {start, duration}. crop: {width, height, x, y}. resize: {width, height}. filter: {vf} for video filters (e.g. 'eq=brightness=0.3'), {af} for audio filters. custom: {args} raw FFmpeg arguments between -i input and output (for complex multi-filter chains, e.g. \"-vf select='not(mod(floor(t)\\,2))',setpts=N/FRAME_RATE/TB -af aselect='not(mod(floor(t)\\,2))',asetpts=N/SR/TB -c:v libx264 -crf 23 -c:a aac\"). extract_audio: {format, bitrate}. extract_frame: {timestamp}. convert: {codec, quality (int 0-51)}."
                }
            },
            "required": ["input_path", "output_path", "operation"]
        }
    },
    {
        "name": "ocr_image",
        "description": "Extract text from an image using OCR.",
        "input_schema": {
            "type": "object",
            "properties": {
                "image_path": {"type": "string", "description": "Path to image file"}
            },
            "required": ["image_path"]
        }
    },
    {
        "name": "smart_crop",
        "description": "Smart crop video/image to focus on faces. ONLY use for simple face-centered cropping. For TikTok/Reels adaptation with effects, transitions, or custom crop positions, use ffmpeg_process instead.",
        "input_schema": {
            "type": "object",
            "properties": {
                "input_path": {"type": "string", "description": "Path to input video or image"},
                "output_path": {"type": "string", "description": "Path for output file"},
                "aspect_ratio": {
                    "type": "string",
                    "default": "9:16",
                    "description": "Target aspect ratio (e.g., '9:16' for vertical, '16:9' for horizontal)"
                }
            },
            "required": ["input_path", "output_path"]
        }
    },
    {
        "name": "google_calendar",
        "description": "Query or create Google Calendar events. Requires user authorization.",
        "input_schema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "create", "delete"],
                    "description": "Action to perform"
                },
                "date_range": {
                    "type": "string",
                    "description": "For list: 'today', 'this_week', or ISO date range"
                },
                "event": {
                    "type": "object",
                    "description": "For create: {title, start, end, description}"
                }
            },
            "required": ["action"]
        }
    },
    {
        "name": "gmail",
        "description": "Read Gmail messages (read-only). Requires user authorization.",
        "input_schema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "read"],
                    "description": "Action to perform"
                },
                "query": {
                    "type": "string",
                    "description": "For list: Gmail search query"
                },
                "message_id": {
                    "type": "string",
                    "description": "For read: message ID"
                }
            },
            "required": ["action"]
        }
    },
    {
        "name": "file_info",
        "description": "Get file metadata (size, name, extension). Use this instead of trying os.path in python_execute.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Path to the file"}
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "python_execute",
        "description": """Execute Python code in a secure sandbox. Use this for:
- Data processing and analysis
- Mathematical calculations and algorithms
- Text manipulation and parsing
- JSON/CSV data processing
- Any computation that requires custom logic

Available modules: math, numpy, json, re, datetime, collections, itertools, statistics, csv, base64, hashlib.
FORBIDDEN: subprocess, os, sys, shutil, socket, http, urllib, pathlib, glob, signal, ctypes, requests, multiprocessing, threading.
To run FFmpeg/FFprobe, use the ffmpeg_process tool instead. To access files, use dedicated tools (read_pdf, ocr_image, etc.).

The code runs with a 30-second timeout. Print statements and the last expression's value are captured and returned.""",
        "input_schema": {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Python code to execute. Can be multi-line. Use print() for output."
                },
                "file_paths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Optional list of file paths the code is allowed to read (must be files provided by user)"
                }
            },
            "required": ["code"]
        }
    }
]


def execute_tool(
    tool_name: str,
    args: Dict[str, Any],
    context: Dict[str, Any]
) -> Any:
    """
    Execute a tool by name.

    Args:
        tool_name: Name of the tool to execute
        args: Tool arguments
        context: Execution context (tokens, etc.)

    Returns:
        Tool result

    Raises:
        ToolError: If tool execution fails
    """
    tool_map = {
        "web_fetch": web_fetch,
        "headless_browser": headless_browser,
        "read_pdf": read_pdf,
        "create_pdf": create_pdf,
        "convert_document": convert_document,
        "create_zip": create_zip,
        "download_media": download_media,
        "google_calendar": google_calendar,
        "gmail": gmail,
        "ffmpeg_process": _ffmpeg_process,
        "ocr_image": _ocr_image,
        "smart_crop": _smart_crop,
        "python_execute": python_execute,
        "file_info": _file_info,
    }

    if tool_name not in tool_map:
        raise ToolError(f"Unknown tool: {tool_name}")

    tool_func = tool_map[tool_name]

    # Resolve file paths: if a tool arg is a basename that matches an attached file,
    # replace it with the full path so native tools can find the file
    file_map = context.get('_file_map', {})
    if file_map:
        _resolve_file_paths(args, file_map)

    # Resolve relative output paths to writable directory
    output_dir = context.get('output_dir')
    if output_dir:
        _resolve_output_paths(args, output_dir)

    # Add context to args for tools that need it
    if tool_name in ["google_calendar", "gmail"]:
        args["_context"] = context

    # Pass timeout for native tools
    if tool_name in ["ocr_image", "ffmpeg_process", "smart_crop"]:
        args["_timeout_ms"] = context.get("tool_timeout_ms", 30000)

    # Strip internal keys that Claude may echo back from context
    args.pop('_timeout_ms', None) if tool_name not in ["ocr_image", "ffmpeg_process", "smart_crop"] else None

    return tool_func(**args)


def _resolve_file_paths(args: Dict[str, Any], file_map: Dict[str, str]) -> None:
    """Resolve basename references to full file paths using the attached files map."""
    import os
    path_keys = ['image_path', 'input_path', 'pdf_path', 'file_path', 'path']
    for key in path_keys:
        if key in args:
            value = args[key]
            if isinstance(value, str):
                # Direct match (value is already a basename in the map)
                if value in file_map:
                    args[key] = file_map[value]
                # Try matching basename of a full path Claude may have guessed
                elif os.path.basename(value) in file_map:
                    args[key] = file_map[os.path.basename(value)]

    # Also resolve arrays of paths (e.g. image_paths for create_pdf, file_paths for create_zip)
    array_path_keys = ['image_paths', 'file_paths']
    for key in array_path_keys:
        if key in args and isinstance(args[key], list):
            resolved = []
            for p in args[key]:
                if isinstance(p, str):
                    if p in file_map:
                        resolved.append(file_map[p])
                    elif os.path.basename(p) in file_map:
                        resolved.append(file_map[os.path.basename(p)])
                    else:
                        resolved.append(p)
                else:
                    resolved.append(p)
            args[key] = resolved


def _resolve_output_paths(args: Dict[str, Any], output_dir: str) -> None:
    """Resolve relative output paths to a writable directory."""
    import os
    os.makedirs(output_dir, exist_ok=True)
    output_keys = ['output_path']
    for key in output_keys:
        if key in args:
            value = args[key]
            if isinstance(value, str) and not os.path.isabs(value):
                args[key] = os.path.join(output_dir, value)


def _file_info(file_path: str, **kwargs) -> dict:
    """Get file metadata (size, name, extension)."""
    import os
    if not os.path.exists(file_path):
        raise ToolError(f"File not found: {file_path}")
    size_bytes = os.path.getsize(file_path)
    return {
        "name": os.path.basename(file_path),
        "path": file_path,
        "size_bytes": size_bytes,
        "size_mb": round(size_bytes / (1024 * 1024), 2),
        "extension": os.path.splitext(file_path)[1].lstrip('.'),
    }


def _ffmpeg_process(**kwargs) -> dict:
    """FFmpeg processing - delegates to native Flutter tool."""
    from ..bridge import get_bridge
    bridge = get_bridge()

    timeout_ms = kwargs.pop('_timeout_ms', 30000)
    # FFmpeg gets 10x the base timeout (video processing is slow)
    return bridge.call_native("ffmpeg", kwargs, timeout_ms=timeout_ms * 10)


def _ocr_image(**kwargs) -> dict:
    """OCR - delegates to native ML Kit tool."""
    from ..bridge import get_bridge
    bridge = get_bridge()

    timeout_ms = kwargs.pop('_timeout_ms', 30000)
    return bridge.call_native("ocr", kwargs, timeout_ms=timeout_ms)


def _smart_crop(**kwargs) -> dict:
    """Smart crop with face detection - delegates to native tool."""
    from ..bridge import get_bridge
    bridge = get_bridge()

    timeout_ms = kwargs.pop('_timeout_ms', 30000)
    # Smart crop gets 10x the base timeout (video processing is slow)
    return bridge.call_native("smart_crop", kwargs, timeout_ms=timeout_ms * 10)
