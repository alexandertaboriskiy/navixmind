"""
Tools - Native tool implementations for the agent

This module provides tool definitions and execution logic.
"""

from typing import Any, Dict

from .web import web_fetch, headless_browser
from .documents import (
    read_pdf, create_pdf, convert_document, create_zip, read_file, write_file,
    read_docx, modify_docx, read_pptx, modify_pptx, read_xlsx, modify_xlsx,
)
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
        "name": "read_docx",
        "description": "Extract text, tables, and metadata from a DOCX file.",
        "input_schema": {
            "type": "object",
            "properties": {
                "docx_path": {"type": "string", "description": "Path to the DOCX file"},
                "extract": {
                    "type": "string",
                    "enum": ["text", "tables", "all"],
                    "default": "all",
                    "description": "What to extract"
                }
            },
            "required": ["docx_path"]
        }
    },
    {
        "name": "modify_docx",
        "description": "Modify an existing DOCX file. Can replace text, add paragraphs, update table cells, and save back.",
        "input_schema": {
            "type": "object",
            "properties": {
                "input_path": {"type": "string", "description": "Path to the source DOCX"},
                "output_path": {"type": "string", "description": "Where to save the modified DOCX"},
                "operations": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "action": {"type": "string", "enum": ["replace_text", "add_paragraph", "update_table_cell"]},
                            "params": {"type": "object"}
                        }
                    },
                    "description": "replace_text: {old, new}. add_paragraph: {text, style?}. update_table_cell: {table, row, col, text}."
                }
            },
            "required": ["input_path", "output_path", "operations"]
        }
    },
    {
        "name": "read_pptx",
        "description": "Extract text, slide content, speaker notes, and metadata from a PPTX file.",
        "input_schema": {
            "type": "object",
            "properties": {
                "pptx_path": {"type": "string", "description": "Path to the PPTX file"},
                "extract": {
                    "type": "string",
                    "enum": ["text", "slides", "notes", "all"],
                    "default": "all",
                    "description": "What to extract"
                }
            },
            "required": ["pptx_path"]
        }
    },
    {
        "name": "modify_pptx",
        "description": "Modify an existing PPTX file. Can replace text across slides, add slides, update shape text, set speaker notes, and save back.",
        "input_schema": {
            "type": "object",
            "properties": {
                "input_path": {"type": "string", "description": "Path to the source PPTX"},
                "output_path": {"type": "string", "description": "Where to save the modified PPTX"},
                "operations": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "action": {"type": "string", "enum": ["replace_text", "add_slide", "update_slide_text", "set_notes"]},
                            "params": {"type": "object"}
                        }
                    },
                    "description": "replace_text: {old, new}. add_slide: {layout_index?, title?, content?}. update_slide_text: {slide, shape_name, text}. set_notes: {slide, text}."
                }
            },
            "required": ["input_path", "output_path", "operations"]
        }
    },
    {
        "name": "read_xlsx",
        "description": "Extract cell data, sheet names, and formulas from an XLSX file.",
        "input_schema": {
            "type": "object",
            "properties": {
                "xlsx_path": {"type": "string", "description": "Path to the XLSX file"},
                "sheet": {"type": "string", "description": "Sheet name or index. Omit for all sheets."},
                "range": {"type": "string", "description": "Cell range, e.g., 'A1:D10'. Omit for all data."},
                "extract": {
                    "type": "string",
                    "enum": ["values", "formulas", "all"],
                    "default": "values",
                    "description": "What to extract"
                }
            },
            "required": ["xlsx_path"]
        }
    },
    {
        "name": "modify_xlsx",
        "description": "Modify an existing XLSX file. Can update cells, set formulas, add rows/sheets, delete sheets, and save back.",
        "input_schema": {
            "type": "object",
            "properties": {
                "input_path": {"type": "string", "description": "Path to the source XLSX"},
                "output_path": {"type": "string", "description": "Where to save the modified XLSX"},
                "operations": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "action": {"type": "string", "enum": ["set_cell", "set_formula", "add_row", "add_sheet", "delete_sheet"]},
                            "params": {"type": "object"}
                        }
                    },
                    "description": "set_cell: {sheet?, cell, value}. set_formula: {sheet?, cell, formula}. add_row: {sheet?, values: []}. add_sheet: {name}. delete_sheet: {name}."
                }
            },
            "required": ["input_path", "output_path", "operations"]
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
        "name": "read_file",
        "description": "Read text content from a file.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Path to the file to read"}
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "write_file",
        "description": "Write text content to a file. The created file will be available for download/sharing.",
        "input_schema": {
            "type": "object",
            "properties": {
                "output_path": {"type": "string", "description": "Filename or path for the output file"},
                "content": {"type": "string", "description": "Text content to write to the file"}
            },
            "required": ["output_path", "content"]
        }
    },
    {
        "name": "python_execute",
        "description": """Execute Python code in a secure sandbox. Use this for:
- Data processing and analysis (pandas DataFrames, CSV, groupby, etc.)
- Mathematical calculations and algorithms
- Statistical analysis (numpy, statistics)
- Charts and plots (matplotlib — figures are auto-saved as PNG and returned)
- Text manipulation and parsing
- JSON/CSV data processing
- Any computation that requires custom logic

Available modules: math, numpy, pandas, matplotlib, json, re, datetime, collections, itertools, statistics, csv, base64, hashlib.
FORBIDDEN: subprocess, os, sys, shutil, socket, http, urllib, pathlib, glob, signal, ctypes, requests, multiprocessing, threading.
To run FFmpeg/FFprobe, use the ffmpeg_process tool instead. To access files, use dedicated tools (read_pdf, ocr_image, etc.).

For plots, use matplotlib — figures are auto-saved as PNG files and returned. An OUTPUT_DIR variable is available for saving files explicitly (e.g., df.to_csv(OUTPUT_DIR + '/data.csv')).

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
        "read_docx": read_docx,
        "modify_docx": modify_docx,
        "read_pptx": read_pptx,
        "modify_pptx": modify_pptx,
        "read_xlsx": read_xlsx,
        "modify_xlsx": modify_xlsx,
        "create_zip": create_zip,
        "download_media": download_media,
        "google_calendar": google_calendar,
        "gmail": gmail,
        "ffmpeg_process": _ffmpeg_process,
        "ocr_image": _ocr_image,
        "smart_crop": _smart_crop,
        "python_execute": python_execute,
        "file_info": _file_info,
        "read_file": read_file,
        "write_file": write_file,
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

    # Pass output_dir to python_execute for file writing and plot auto-save
    if tool_name == "python_execute" and output_dir:
        args["output_dir"] = output_dir

    # Pass timeout for native tools
    if tool_name in ["ocr_image", "ffmpeg_process", "smart_crop"]:
        args["_timeout_ms"] = context.get("tool_timeout_ms", 30000)

    # Strip internal keys that Claude may echo back from context
    args.pop('_timeout_ms', None) if tool_name not in ["ocr_image", "ffmpeg_process", "smart_crop"] else None

    return tool_func(**args)


def _resolve_file_paths(args: Dict[str, Any], file_map: Dict[str, str]) -> None:
    """Resolve basename references to full file paths using the attached files map."""
    import os
    path_keys = ['image_path', 'input_path', 'pdf_path', 'file_path', 'path', 'docx_path', 'pptx_path', 'xlsx_path']
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
