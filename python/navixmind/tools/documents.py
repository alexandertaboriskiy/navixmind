"""
Document Tools - PDF, document processing, and ZIP archive creation
"""

import os
import zipfile
from io import BytesIO
from typing import Optional

from ..bridge import ToolError
from ..utils.file_limits import validate_file_for_processing, validate_pdf_for_processing


def read_pdf(pdf_path: str, pages: str = "all") -> dict:
    """
    Extract text from a PDF file.

    Args:
        pdf_path: Path to the PDF file
        pages: Page range ("all", "1-5", "3", etc.)

    Returns:
        Dict with extracted text
    """
    from pypdf import PdfReader

    # Validate file
    validate_pdf_for_processing(pdf_path)

    try:
        reader = PdfReader(pdf_path)
        total_pages = len(reader.pages)

        # Parse page range
        if pages == "all":
            page_indices = range(total_pages)
        elif "-" in pages:
            start, end = pages.split("-")
            start = int(start) - 1
            end = min(int(end), total_pages)
            page_indices = range(start, end)
        else:
            page_num = int(pages) - 1
            if page_num >= total_pages:
                raise ToolError(f"Page {pages} doesn't exist. PDF has {total_pages} pages.")
            page_indices = [page_num]

        # Extract text
        text_parts = []
        for i in page_indices:
            page = reader.pages[i]
            text = page.extract_text()
            if text:
                text_parts.append(f"--- Page {i + 1} ---\n{text}")

        full_text = "\n\n".join(text_parts)

        # Truncate if too long
        if len(full_text) > 100000:
            full_text = full_text[:100000] + "\n\n[Content truncated...]"

        return {
            "path": pdf_path,
            "total_pages": total_pages,
            "pages_extracted": len(page_indices),
            "text": full_text
        }

    except Exception as e:
        raise ToolError(f"Failed to read PDF: {str(e)}")


def create_pdf(
    output_path: str,
    content: Optional[str] = None,
    title: Optional[str] = None,
    image_paths: Optional[list] = None,
) -> dict:
    """
    Create a PDF from text and/or images.

    Args:
        output_path: Where to save the PDF
        content: Optional text content for the PDF
        title: Optional document title
        image_paths: Optional list of image file paths to embed

    Returns:
        Dict with output path and page count
    """
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image

    if not content and not image_paths:
        raise ToolError("create_pdf requires at least 'content' or 'image_paths'")

    try:
        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        # Create document
        page_width, page_height = letter
        margin = 72
        doc = SimpleDocTemplate(
            output_path,
            pagesize=letter,
            rightMargin=margin,
            leftMargin=margin,
            topMargin=margin,
            bottomMargin=margin,
        )

        usable_width = page_width - 2 * margin
        usable_height = page_height - 2 * margin

        # Get styles
        styles = getSampleStyleSheet()

        # Build content
        story = []

        # Add title if provided
        if title:
            title_style = ParagraphStyle(
                'Title',
                parent=styles['Heading1'],
                fontSize=18,
                spaceAfter=30,
            )
            story.append(Paragraph(title, title_style))
            story.append(Spacer(1, 0.25 * inch))

        # Add text content paragraphs
        if content:
            body_style = styles['Normal']
            for paragraph in content.split('\n\n'):
                if paragraph.strip():
                    # Escape special characters
                    safe_text = paragraph.replace('&', '&amp;')
                    safe_text = safe_text.replace('<', '&lt;')
                    safe_text = safe_text.replace('>', '&gt;')
                    story.append(Paragraph(safe_text, body_style))
                    story.append(Spacer(1, 0.1 * inch))

        # Embed images
        if image_paths:
            for img_path in image_paths:
                if not os.path.isfile(img_path):
                    raise ToolError(f"Image file not found: {img_path}")

                # Get image dimensions and scale to fit page
                from PIL import Image as PILImage
                with PILImage.open(img_path) as pil_img:
                    img_w, img_h = pil_img.size

                # Scale to fit within usable area while maintaining aspect ratio
                scale = min(usable_width / img_w, usable_height / img_h, 1.0)
                display_w = img_w * scale
                display_h = img_h * scale

                story.append(Image(img_path, width=display_w, height=display_h))
                story.append(Spacer(1, 0.2 * inch))

        # Build PDF
        doc.build(story)

        return {
            "output_path": output_path,
            "success": True,
        }

    except ToolError:
        raise
    except Exception as e:
        raise ToolError(f"Failed to create PDF: {str(e)}")


def convert_document(
    input_path: str,
    output_format: str
) -> dict:
    """
    Convert document to another format.

    Args:
        input_path: Path to input document
        output_format: Target format (pdf, html, txt)

    Returns:
        Dict with output path
    """
    validate_file_for_processing(input_path, 'document')

    ext = os.path.splitext(input_path)[1].lower()
    base_name = os.path.splitext(input_path)[0]
    output_path = f"{base_name}.{output_format}"

    try:
        if ext in ['.docx', '.doc']:
            return _convert_docx(input_path, output_format, output_path)
        elif ext == '.txt':
            return _convert_txt(input_path, output_format, output_path)
        else:
            raise ToolError(f"Unsupported input format: {ext}")

    except Exception as e:
        raise ToolError(f"Conversion failed: {str(e)}")


def _convert_docx(input_path: str, output_format: str, output_path: str) -> dict:
    """Convert DOCX to target format."""
    from docx import Document

    doc = Document(input_path)

    # Extract text
    full_text = []
    for para in doc.paragraphs:
        full_text.append(para.text)

    text = '\n\n'.join(full_text)

    if output_format == 'txt':
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(text)
        return {"output_path": output_path, "success": True}

    elif output_format == 'pdf':
        return create_pdf(text, output_path)

    elif output_format == 'html':
        html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Converted Document</title></head>
<body>
{''.join(f'<p>{p}</p>' for p in full_text if p.strip())}
</body>
</html>"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html)
        return {"output_path": output_path, "success": True}

    else:
        raise ToolError(f"Unsupported output format: {output_format}")


def _convert_txt(input_path: str, output_format: str, output_path: str) -> dict:
    """Convert TXT to target format."""
    with open(input_path, 'r', encoding='utf-8') as f:
        text = f.read()

    if output_format == 'pdf':
        return create_pdf(text, output_path)

    elif output_format == 'html':
        paragraphs = text.split('\n\n')
        html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Converted Document</title></head>
<body>
{''.join(f'<p>{p}</p>' for p in paragraphs if p.strip())}
</body>
</html>"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html)
        return {"output_path": output_path, "success": True}

    else:
        raise ToolError(f"Unsupported output format: {output_format}")


def create_zip(
    output_path: str,
    file_paths: list,
    compression: str = "deflated",
) -> dict:
    """
    Create a ZIP archive from a list of files.

    Uses Python's built-in zipfile module (PSF License 2.0 — fully free/open).

    Args:
        output_path: Where to save the ZIP file
        file_paths: List of file paths to include in the archive
        compression: Compression method — "deflated" (smaller, default) or "stored" (no compression, faster)

    Returns:
        Dict with output path, file count, and total size
    """
    if not file_paths:
        raise ToolError("create_zip requires at least one file path")

    compression_map = {
        "deflated": zipfile.ZIP_DEFLATED,
        "stored": zipfile.ZIP_STORED,
    }
    if compression not in compression_map:
        raise ToolError(
            f"Unsupported compression: {compression}. Use 'deflated' or 'stored'."
        )

    try:
        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        # Verify all files exist before creating the archive
        for fpath in file_paths:
            if not os.path.isfile(fpath):
                raise ToolError(f"File not found: {fpath}")

        # Track basenames to handle duplicates
        seen_names = {}
        zip_compression = compression_map[compression]

        with zipfile.ZipFile(output_path, 'w', compression=zip_compression) as zf:
            for fpath in file_paths:
                basename = os.path.basename(fpath)

                # Handle duplicate basenames by appending a counter
                if basename in seen_names:
                    seen_names[basename] += 1
                    name, ext = os.path.splitext(basename)
                    arcname = f"{name}_{seen_names[basename]}{ext}"
                else:
                    seen_names[basename] = 0
                    arcname = basename

                zf.write(fpath, arcname)

        # Get final archive size
        archive_size = os.path.getsize(output_path)

        return {
            "output_path": output_path,
            "success": True,
            "file_count": len(file_paths),
            "size_bytes": archive_size,
            "size_mb": round(archive_size / (1024 * 1024), 2),
            "compression": compression,
        }

    except ToolError:
        raise
    except Exception as e:
        raise ToolError(f"Failed to create ZIP: {str(e)}")
