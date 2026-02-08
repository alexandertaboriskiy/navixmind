"""
File size validation - Prevents OOM on Android's limited heap
"""

import os


class FileTooLargeError(Exception):
    """Error when file exceeds size limits."""
    pass


# File size limits in bytes — generous because all processing is local
# (Python/FFmpeg on device), files are never sent raw to LLM cloud APIs.
FILE_SIZE_LIMITS = {
    'pdf': 500 * 1024 * 1024,       # 500MB
    'image': 500 * 1024 * 1024,     # 500MB
    'video': 500 * 1024 * 1024,     # 500MB
    'audio': 500 * 1024 * 1024,     # 500MB
    'document': 500 * 1024 * 1024,  # 500MB
    'default': 500 * 1024 * 1024,   # 500MB
}

# Memory-safe processing limits
PROCESSING_LIMITS = {
    'pdf_pages': 200,              # Max pages to process at once
    'image_pixels': 25_000_000,    # ~5000x5000 max resolution
    'text_chars': 1_000_000,       # 1M chars max text processing
    'xlsx_rows': 100_000,          # Max rows to process per sheet
    'pptx_slides': 500,            # Max slides to process
}


def validate_file_for_processing(path: str, file_type: str = None) -> None:
    """
    Validate file before processing. Raises FileTooLargeError if exceeded.
    MUST be called before any file processing in Python.

    Args:
        path: Path to the file
        file_type: Type of file (pdf, image, video, etc.)

    Raises:
        FileTooLargeError: If file exceeds size limit
        FileNotFoundError: If file doesn't exist
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")

    size = os.path.getsize(path)

    # Auto-detect type from extension if not provided
    if file_type is None:
        ext = os.path.splitext(path)[1].lower()
        type_map = {
            '.pdf': 'pdf',
            '.jpg': 'image', '.jpeg': 'image', '.png': 'image',
            '.gif': 'image', '.webp': 'image', '.heic': 'image',
            '.mp4': 'video', '.mov': 'video', '.avi': 'video',
            '.mkv': 'video', '.webm': 'video',
            '.mp3': 'audio', '.wav': 'audio', '.m4a': 'audio',
            '.aac': 'audio', '.ogg': 'audio', '.flac': 'audio',
            '.doc': 'document', '.docx': 'document',
            '.pptx': 'document', '.ppt': 'document',
            '.xlsx': 'document', '.xls': 'document', '.xlsm': 'document',
            '.odt': 'document', '.rtf': 'document',
        }
        file_type = type_map.get(ext, 'default')

    limit = FILE_SIZE_LIMITS.get(file_type, FILE_SIZE_LIMITS['default'])

    if size > limit:
        raise FileTooLargeError(
            f"File is too large ({size / 1024 / 1024:.1f}MB). "
            f"Maximum for {file_type}: {limit / 1024 / 1024:.0f}MB"
        )


def validate_pdf_for_processing(path: str) -> None:
    """
    Check PDF page count before processing.

    Args:
        path: Path to PDF file

    Raises:
        FileTooLargeError: If PDF has too many pages
    """
    validate_file_for_processing(path, 'pdf')

    try:
        from pypdf import PdfReader
        reader = PdfReader(path)
        page_count = len(reader.pages)

        if page_count > PROCESSING_LIMITS['pdf_pages']:
            raise FileTooLargeError(
                f"PDF has too many pages ({page_count}). "
                f"Maximum: {PROCESSING_LIMITS['pdf_pages']} pages"
            )
    except ImportError:
        # pypdf not available, skip page count check
        pass


def validate_image_for_processing(path: str) -> None:
    """
    Check image resolution before loading into memory.

    Args:
        path: Path to image file

    Raises:
        FileTooLargeError: If image resolution is too high
    """
    validate_file_for_processing(path, 'image')

    try:
        from PIL import Image
        with Image.open(path) as img:
            pixels = img.width * img.height
            if pixels > PROCESSING_LIMITS['image_pixels']:
                max_dim = int(PROCESSING_LIMITS['image_pixels'] ** 0.5)
                raise FileTooLargeError(
                    f"Image resolution too high ({img.width}x{img.height}). "
                    f"Maximum: ~{max_dim}x{max_dim}"
                )
    except ImportError:
        # Pillow not available, skip resolution check
        pass


def get_limit_for_type(file_type: str) -> int:
    """Get the size limit for a file type."""
    return FILE_SIZE_LIMITS.get(file_type, FILE_SIZE_LIMITS['default'])


def format_size(bytes: int) -> str:
    """Format bytes as human-readable string."""
    if bytes < 1024:
        return f"{bytes} B"
    if bytes < 1024 * 1024:
        return f"{bytes / 1024:.1f} KB"
    return f"{bytes / (1024 * 1024):.1f} MB"
