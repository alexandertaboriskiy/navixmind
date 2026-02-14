"""
Comprehensive tests for the NavixMind tools module.

Tests cover:
- Tool schema definitions
- Tool execution routing
- Web tools (fetch, headless browser)
- Document tools (PDF, conversion)
- Media tools (download)
- Google API tools
- Error handling
"""

import json
import pytest
from unittest.mock import Mock, patch, MagicMock


class TestToolsSchema:
    """Tests for tool schema definitions."""

    def test_all_tools_have_schema(self):
        """Test all tools have proper schema."""
        from navixmind.tools import TOOLS_SCHEMA

        required_tools = [
            "web_fetch", "headless_browser", "read_pdf", "create_pdf",
            "convert_document", "download_media", "ffmpeg_process",
            "ocr_image", "google_calendar", "gmail", "smart_crop"
        ]

        tool_names = [t["name"] for t in TOOLS_SCHEMA]
        for tool in required_tools:
            assert tool in tool_names, f"Missing schema for {tool}"

    def test_schema_format(self):
        """Test each schema has required fields."""
        from navixmind.tools import TOOLS_SCHEMA

        for schema in TOOLS_SCHEMA:
            assert "name" in schema
            assert "description" in schema
            assert "input_schema" in schema
            assert schema["input_schema"]["type"] == "object"
            assert "properties" in schema["input_schema"]

    def test_schema_required_fields(self):
        """Test schemas define required fields."""
        from navixmind.tools import TOOLS_SCHEMA

        for schema in TOOLS_SCHEMA:
            if "required" in schema["input_schema"]:
                required = schema["input_schema"]["required"]
                properties = schema["input_schema"]["properties"]
                for field in required:
                    assert field in properties, \
                        f"Required field {field} not in properties for {schema['name']}"


class TestExecuteTool:
    """Tests for the execute_tool function."""

    def test_execute_unknown_tool(self):
        """Test executing unknown tool raises error."""
        from navixmind.tools import execute_tool
        from navixmind.bridge import ToolError

        with pytest.raises(ToolError) as exc_info:
            execute_tool("nonexistent_tool", {}, {})

        assert "Unknown tool" in str(exc_info.value)

    def test_execute_web_fetch(self):
        """Test executing web_fetch tool with mocked requests."""
        from navixmind.tools import execute_tool

        mock_response = Mock()
        mock_response.content = b"<html><body>Test content</body></html>"
        mock_response.status_code = 200
        mock_response.raise_for_status = Mock()

        with patch('requests.get', return_value=mock_response):
            result = execute_tool("web_fetch", {"url": "https://example.com"}, {})

        assert "text" in result
        assert result["url"] == "https://example.com"

    def test_execute_google_tools_get_context(self):
        """Test Google tools receive context."""
        from navixmind.tools import execute_tool, ToolError

        # Test that the tool correctly passes context by checking error when no token
        # The important thing is that context gets passed through
        with pytest.raises(ToolError) as exc_info:
            execute_tool(
                "google_calendar",
                {"action": "list"},
                {}  # No auth token
            )

        # Should fail with auth error, proving context is checked
        assert "not connected" in str(exc_info.value).lower()


class TestTimeoutStripping:
    """Tests for _timeout_ms handling in execute_tool."""

    def test_timeout_not_passed_to_create_zip(self):
        """Test that _timeout_ms is stripped from non-native tools like create_zip."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod.create_zip
        mock_zip = Mock(return_value={"output_path": "/out.zip", "success": True, "file_count": 1, "size_bytes": 100})
        tools_mod.create_zip = mock_zip
        try:
            execute_tool(
                "create_zip",
                {"output_path": "/out.zip", "file_paths": ["/a.txt"], "compression": "deflated", "_timeout_ms": 30000},
                {}
            )
            mock_zip.assert_called_once()
            call_kwargs = mock_zip.call_args[1]
            assert "_timeout_ms" not in call_kwargs
        finally:
            tools_mod.create_zip = original

    def test_timeout_not_passed_to_create_pdf(self):
        """Test that _timeout_ms is stripped from create_pdf."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod.create_pdf
        mock_pdf = Mock(return_value={"output_path": "/out.pdf", "success": True})
        tools_mod.create_pdf = mock_pdf
        try:
            execute_tool(
                "create_pdf",
                {"output_path": "/out.pdf", "content": "hello", "_timeout_ms": 30000},
                {}
            )
            call_kwargs = mock_pdf.call_args[1]
            assert "_timeout_ms" not in call_kwargs
        finally:
            tools_mod.create_pdf = original

    def test_timeout_kept_for_native_tools(self):
        """Test that _timeout_ms IS kept for native tools (ffmpeg, ocr, smart_crop)."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod._ffmpeg_process
        mock_ffmpeg = Mock(return_value={"success": True, "output_path": "/out.mp4"})
        tools_mod._ffmpeg_process = mock_ffmpeg
        try:
            execute_tool(
                "ffmpeg_process",
                {"input_path": "/in.mp4", "operation": "trim", "output_path": "/out.mp4"},
                {"tool_timeout_ms": 60000}
            )
            call_kwargs = mock_ffmpeg.call_args[1]
            assert "_timeout_ms" in call_kwargs
            assert call_kwargs["_timeout_ms"] == 60000
        finally:
            tools_mod._ffmpeg_process = original

    def test_timeout_not_passed_to_web_fetch(self):
        """Test that _timeout_ms is stripped from web_fetch."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod.web_fetch
        mock_fetch = Mock(return_value={"url": "https://example.com", "text": "hi"})
        tools_mod.web_fetch = mock_fetch
        try:
            execute_tool(
                "web_fetch",
                {"url": "https://example.com", "_timeout_ms": 30000},
                {}
            )
            call_kwargs = mock_fetch.call_args[1]
            assert "_timeout_ms" not in call_kwargs
        finally:
            tools_mod.web_fetch = original


class TestFilePathResolution:
    """Tests for file path resolution in execute_tool."""

    def test_array_paths_resolved_by_basename(self):
        """Test that file_paths array items are resolved via basename lookup."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        file_map = {
            "segment_01.mp3": "/storage/emulated/0/output/segment_01.mp3",
            "segment_02.mp3": "/storage/emulated/0/output/segment_02.mp3",
        }

        original = tools_mod.create_zip
        mock_zip = Mock(return_value={"output_path": "/out.zip", "success": True, "file_count": 2, "size_bytes": 200})
        tools_mod.create_zip = mock_zip
        try:
            execute_tool(
                "create_zip",
                {"output_path": "/out.zip", "file_paths": ["segment_01.mp3", "segment_02.mp3"]},
                {"_file_map": file_map}
            )
            call_kwargs = mock_zip.call_args[1]
            assert call_kwargs["file_paths"] == [
                "/storage/emulated/0/output/segment_01.mp3",
                "/storage/emulated/0/output/segment_02.mp3",
            ]
        finally:
            tools_mod.create_zip = original

    def test_array_paths_resolved_by_full_path_basename(self):
        """Test that full paths in file_paths are resolved via basename extraction."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        file_map = {
            "segment_01.mp3": "/storage/emulated/0/output/segment_01.mp3",
        }

        original = tools_mod.create_zip
        mock_zip = Mock(return_value={"output_path": "/out.zip", "success": True, "file_count": 1, "size_bytes": 100})
        tools_mod.create_zip = mock_zip
        try:
            execute_tool(
                "create_zip",
                {"output_path": "/out.zip", "file_paths": ["/wrong/path/segment_01.mp3"]},
                {"_file_map": file_map}
            )
            call_kwargs = mock_zip.call_args[1]
            assert call_kwargs["file_paths"] == ["/storage/emulated/0/output/segment_01.mp3"]
        finally:
            tools_mod.create_zip = original

    def test_array_paths_passthrough_when_not_in_map(self):
        """Test that paths not in file_map are passed through unchanged."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod.create_zip
        mock_zip = Mock(return_value={"output_path": "/out.zip", "success": True, "file_count": 1, "size_bytes": 100})
        tools_mod.create_zip = mock_zip
        try:
            execute_tool(
                "create_zip",
                {"output_path": "/out.zip", "file_paths": ["/existing/path/file.mp3"]},
                {"_file_map": {}}
            )
            call_kwargs = mock_zip.call_args[1]
            assert call_kwargs["file_paths"] == ["/existing/path/file.mp3"]
        finally:
            tools_mod.create_zip = original


class TestWebFetch:
    """Tests for the web_fetch tool."""

    def test_fetch_text_mode(self):
        """Test fetching page in text mode."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head><title>Test</title></head>
                    <body><main><p>Hello World</p></main></body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        assert "Hello World" in result["text"]
        assert result["title"] == "Test"

    def test_fetch_html_mode(self):
        """Test fetching page in HTML mode."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            result = web_fetch("https://example.com", extract_mode="html")

        assert "html" in result
        assert "<body>" in result["html"]

    def test_fetch_links_mode(self):
        """Test fetching page in links mode."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html><body>
                    <a href="https://link1.com">Link 1</a>
                    <a href="https://link2.com">Link 2</a>
                </body></html>
            """

            result = web_fetch("https://example.com", extract_mode="links")

        assert len(result["links"]) == 2

    def test_fetch_adds_https(self):
        """Test URL without scheme gets https added."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("example.com")

        call_url = mock_get.call_args[0][0]
        assert call_url.startswith("https://")

    def test_fetch_timeout(self):
        """Test fetch handles timeout."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError
        import requests

        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.Timeout()

            with pytest.raises(ToolError) as exc_info:
                web_fetch("https://example.com")

            assert "timed out" in str(exc_info.value).lower()

    def test_fetch_request_error(self):
        """Test fetch handles request errors."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError
        import requests

        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.RequestException("Connection failed")

            with pytest.raises(ToolError):
                web_fetch("https://example.com")

    def test_fetch_truncates_long_content(self):
        """Test long content is truncated."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            # Create very long content
            long_text = "x" * 100000
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = f"<html><body>{long_text}</body></html>".encode()

            result = web_fetch("https://example.com")

        assert len(result["text"]) <= 50050  # 50000 + truncation message


class TestHeadlessBrowser:
    """Tests for the headless_browser tool."""

    def test_headless_browser_delegates_to_native(self):
        """Test headless browser calls native tool."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "text": "JS rendered content"
            }

            result = headless_browser(
                "https://spa-app.com",
                wait_seconds=5,
                extract_selector=".content"
            )

        mock_bridge.return_value.call_native.assert_called_once()
        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args[0][0] == "headless_browser"
        assert call_args[0][1]["url"] == "https://spa-app.com"
        assert call_args[0][1]["wait_seconds"] == 5


class TestMediaTools:
    """Tests for media download tools."""

    def test_download_blocks_youtube(self):
        """Test YouTube URLs are blocked."""
        from navixmind.tools.media import download_media
        from navixmind.bridge import ToolError

        with pytest.raises(ToolError) as exc_info:
            download_media("https://www.youtube.com/watch?v=abc123")

        assert "youtube" in str(exc_info.value).lower()
        assert "not supported" in str(exc_info.value).lower()

    def test_download_blocks_youtu_be(self):
        """Test youtu.be URLs are blocked."""
        from navixmind.tools.media import download_media
        from navixmind.bridge import ToolError

        with pytest.raises(ToolError) as exc_info:
            download_media("https://youtu.be/abc123")

        assert "youtube" in str(exc_info.value).lower()

    def test_download_video_format(self):
        """Test downloading in video format."""
        from navixmind.tools.media import download_media

        with patch('yt_dlp.YoutubeDL') as mock_ydl:
            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "title": "Test Video",
                "duration": 120,
                "extractor": "instagram",
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test", format="video")

        assert result["title"] == "Test Video"
        assert result["format"] == "video"

    def test_download_audio_format(self):
        """Test downloading in audio format."""
        from navixmind.tools.media import download_media

        with patch('yt_dlp.YoutubeDL') as mock_ydl:
            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "title": "Test Audio",
                "duration": 180,
                "extractor": "soundcloud",
                "webpage_url": "https://soundcloud.com/test",
                "formats": [
                    {"vcodec": "none", "acodec": "mp3", "url": "https://cdn.com/audio.mp3", "ext": "mp3"}
                ]
            }

            result = download_media("https://soundcloud.com/test", format="audio")

        assert result["format"] == "audio"

    def test_download_blocks_redirect_to_youtube(self):
        """Test URLs that redirect to YouTube are blocked."""
        from navixmind.tools.media import download_media
        from navixmind.bridge import ToolError

        with patch('yt_dlp.YoutubeDL') as mock_ydl:
            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "youtube",
                "title": "Video"
            }

            with pytest.raises(ToolError) as exc_info:
                download_media("https://shortened.url/xyz")

            assert "youtube" in str(exc_info.value).lower()


class TestDocumentTools:
    """Tests for document processing tools."""

    def test_read_pdf_all_pages(self):
        """Test reading all pages from PDF."""
        from navixmind.tools.documents import read_pdf

        with patch('navixmind.tools.documents.validate_pdf_for_processing'), \
             patch('pypdf.PdfReader') as mock_reader:

            mock_page1 = Mock()
            mock_page1.extract_text.return_value = "Page 1 content"
            mock_page2 = Mock()
            mock_page2.extract_text.return_value = "Page 2 content"

            mock_reader.return_value.pages = [mock_page1, mock_page2]

            result = read_pdf("/path/to/test.pdf", pages="all")

        assert result["total_pages"] == 2
        assert result["pages_extracted"] == 2
        assert "Page 1 content" in result["text"]
        assert "Page 2 content" in result["text"]

    def test_read_pdf_page_range(self):
        """Test reading specific page range from PDF."""
        from navixmind.tools.documents import read_pdf

        with patch('navixmind.tools.documents.validate_pdf_for_processing'), \
             patch('pypdf.PdfReader') as mock_reader:

            pages = [Mock() for _ in range(5)]
            for i, page in enumerate(pages):
                page.extract_text.return_value = f"Page {i+1}"

            mock_reader.return_value.pages = pages

            result = read_pdf("/path/to/test.pdf", pages="2-4")

        assert result["pages_extracted"] == 3
        assert "Page 2" in result["text"]
        assert "Page 4" in result["text"]
        assert "Page 1" not in result["text"]

    def test_read_pdf_single_page(self):
        """Test reading single page from PDF."""
        from navixmind.tools.documents import read_pdf

        with patch('navixmind.tools.documents.validate_pdf_for_processing'), \
             patch('pypdf.PdfReader') as mock_reader:

            pages = [Mock() for _ in range(3)]
            for i, page in enumerate(pages):
                page.extract_text.return_value = f"Page {i+1}"

            mock_reader.return_value.pages = pages

            result = read_pdf("/path/to/test.pdf", pages="2")

        assert result["pages_extracted"] == 1
        assert "Page 2" in result["text"]

    def test_read_pdf_invalid_page(self):
        """Test reading invalid page number."""
        from navixmind.tools.documents import read_pdf
        from navixmind.bridge import ToolError

        with patch('navixmind.tools.documents.validate_pdf_for_processing'), \
             patch('pypdf.PdfReader') as mock_reader:

            mock_reader.return_value.pages = [Mock()]

            with pytest.raises(ToolError) as exc_info:
                read_pdf("/path/to/test.pdf", pages="5")

            assert "doesn't exist" in str(exc_info.value)

    def test_create_pdf(self):
        """Test creating PDF from text."""
        from navixmind.tools.documents import create_pdf

        # Mock styles as a dict-like object
        mock_styles = {
            'Heading1': Mock(),
            'Normal': Mock()
        }

        # Patch at the source modules since imports are inside the function
        with patch('reportlab.platypus.SimpleDocTemplate') as mock_doc, \
             patch('reportlab.lib.pagesizes.letter', (612, 792)), \
             patch('reportlab.lib.styles.getSampleStyleSheet', return_value=mock_styles), \
             patch('reportlab.lib.styles.ParagraphStyle'), \
             patch('reportlab.platypus.Paragraph'), \
             patch('reportlab.platypus.Spacer'), \
             patch('reportlab.lib.units.inch', 72), \
             patch('os.makedirs'):  # avoid read-only filesystem error

            mock_instance = Mock()
            mock_doc.return_value = mock_instance

            result = create_pdf(
                content="Hello World\n\nSecond paragraph",
                output_path="/path/to/output.pdf",
                title="Test Document"
            )

        mock_instance.build.assert_called_once()
        assert result["success"] is True
        assert result["output_path"] == "/path/to/output.pdf"

    def test_convert_docx_to_txt(self):
        """Test converting DOCX to TXT."""
        from navixmind.tools.documents import convert_document

        with patch('navixmind.tools.documents.validate_file_for_processing'), \
             patch('docx.Document') as mock_doc, \
             patch('builtins.open', create=True) as mock_open:

            mock_para1 = Mock()
            mock_para1.text = "Paragraph 1"
            mock_para2 = Mock()
            mock_para2.text = "Paragraph 2"
            mock_doc.return_value.paragraphs = [mock_para1, mock_para2]

            result = convert_document("/path/to/doc.docx", "txt")

        assert result["success"] is True
        assert result["output_path"].endswith(".txt")

    def test_convert_unsupported_format(self):
        """Test converting unsupported format."""
        from navixmind.tools.documents import convert_document
        from navixmind.bridge import ToolError

        with patch('navixmind.tools.documents.validate_file_for_processing'):
            with pytest.raises(ToolError) as exc_info:
                convert_document("/path/to/file.xyz", "pdf")

            assert "Unsupported" in str(exc_info.value)


class TestFileLimits:
    """Tests for file size limit validation."""

    def test_validate_file_size(self):
        """Test file size validation."""
        from navixmind.utils.file_limits import validate_file_for_processing, FileTooLargeError
        import os

        with patch('os.path.exists') as mock_exists, \
             patch('os.path.getsize') as mock_size:

            mock_exists.return_value = True
            mock_size.return_value = 600 * 1024 * 1024  # 600MB (exceeds 500MB limit)

            with pytest.raises(FileTooLargeError):
                validate_file_for_processing("/path/to/large.pdf", "pdf")

    def test_validate_file_not_found(self):
        """Test validation of non-existent file."""
        from navixmind.utils.file_limits import validate_file_for_processing

        with patch('os.path.exists') as mock_exists:
            mock_exists.return_value = False

            with pytest.raises(FileNotFoundError):
                validate_file_for_processing("/path/to/missing.pdf")

    def test_validate_auto_detect_type(self):
        """Test automatic file type detection."""
        from navixmind.utils.file_limits import validate_file_for_processing

        with patch('os.path.exists') as mock_exists, \
             patch('os.path.getsize') as mock_size:

            mock_exists.return_value = True
            mock_size.return_value = 1024  # Small file

            # Should not raise - detects type from extension
            validate_file_for_processing("/path/to/file.jpg")
            validate_file_for_processing("/path/to/file.mp4")
            validate_file_for_processing("/path/to/file.pdf")


class TestSecurityTools:
    """Tests for security-related functionality."""

    def test_is_blocked_domain_youtube(self):
        """Test YouTube domain is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://www.youtube.com/watch?v=abc") is True
        assert is_blocked_domain("https://youtube.com/watch?v=abc") is True
        assert is_blocked_domain("https://youtu.be/abc") is True
        assert is_blocked_domain("https://m.youtube.com/watch?v=abc") is True

    def test_is_blocked_domain_allowed(self):
        """Test allowed domains are not blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://instagram.com/p/abc") is False
        assert is_blocked_domain("https://tiktok.com/@user/video/123") is False
        assert is_blocked_domain("https://example.com") is False


class TestNativeToolDelegation:
    """Tests for tools that delegate to native (Flutter) implementation."""

    def test_ffmpeg_process_delegates(self):
        """Test FFmpeg tool delegates to native."""
        from navixmind.tools import execute_tool

        with patch('navixmind.bridge.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "success": True,
                "output_path": "/path/to/output.mp4"
            }

            result = execute_tool("ffmpeg_process", {
                "input_path": "/path/to/input.mp4",
                "output_path": "/path/to/output.mp4",
                "operation": "crop"
            }, {})

        mock_bridge.return_value.call_native.assert_called_once()
        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args is not None
        assert call_args[0][0] == "ffmpeg"

    def test_ocr_image_delegates(self):
        """Test OCR tool delegates to native."""
        from navixmind.tools import execute_tool

        with patch('navixmind.bridge.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "success": True,
                "text": "Extracted text"
            }

            result = execute_tool("ocr_image", {
                "image_path": "/path/to/image.jpg"
            }, {})

        mock_bridge.return_value.call_native.assert_called_once()
        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args is not None
        assert call_args[0][0] == "ocr"

    def test_smart_crop_delegates(self):
        """Test smart crop tool delegates to native."""
        from navixmind.tools import execute_tool

        with patch('navixmind.bridge.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "success": True,
                "output_path": "/path/to/output.mp4"
            }

            result = execute_tool("smart_crop", {
                "input_path": "/path/to/video.mp4",
                "output_path": "/path/to/output.mp4",
                "aspect_ratio": "9:16"
            }, {})

        mock_bridge.return_value.call_native.assert_called_once()
        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args is not None
        assert call_args[0][0] == "smart_crop"

    def test_image_compose_delegates(self):
        """Test image_compose tool delegates to native."""
        from navixmind.tools import execute_tool

        with patch('navixmind.bridge.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "success": True,
                "output_path": "/path/to/combined.jpg",
                "width": 800,
                "height": 400,
                "output_size_bytes": 125000,
                "operation": "concat_horizontal",
            }

            result = execute_tool("image_compose", {
                "input_paths": ["/path/to/img1.jpg", "/path/to/img2.jpg"],
                "output_path": "/path/to/combined.jpg",
                "operation": "concat_horizontal",
            }, {})

        mock_bridge.return_value.call_native.assert_called_once()
        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args is not None
        assert call_args[0][0] == "image_compose"
        assert call_args[0][1]["operation"] == "concat_horizontal"

    def test_image_compose_adjust_delegates(self):
        """Test image_compose adjust operation delegates to native."""
        from navixmind.tools import execute_tool

        with patch('navixmind.bridge.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "success": True,
                "output_path": "/path/to/bright.jpg",
                "width": 1920,
                "height": 1080,
                "output_size_bytes": 250000,
                "operation": "adjust",
            }

            result = execute_tool("image_compose", {
                "input_paths": ["/path/to/photo.jpg"],
                "output_path": "/path/to/bright.jpg",
                "operation": "adjust",
                "params": {"brightness": 1.3, "contrast": 1.1},
            }, {})

        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args[0][1]["operation"] == "adjust"
        assert call_args[0][1]["params"]["brightness"] == 1.3

    def test_image_compose_gets_timeout(self):
        """Test image_compose receives timeout from context."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod._image_compose
        mock_compose = Mock(return_value={"success": True, "output_path": "/out.jpg"})
        tools_mod._image_compose = mock_compose
        try:
            execute_tool(
                "image_compose",
                {"input_paths": ["/a.jpg"], "output_path": "/out.jpg", "operation": "grayscale"},
                {"tool_timeout_ms": 60000}
            )
            call_kwargs = mock_compose.call_args[1]
            assert "_timeout_ms" in call_kwargs
            assert call_kwargs["_timeout_ms"] == 60000
        finally:
            tools_mod._image_compose = original

    def test_list_files_delegates(self):
        """Test list_files tool delegates to native."""
        from navixmind.tools import execute_tool

        with patch('navixmind.bridge.get_bridge') as mock_bridge:
            mock_bridge.return_value.call_native.return_value = {
                "success": True,
                "directory": "/storage/emulated/0/Pictures/Screenshots",
                "files": [
                    {
                        "name": "shot1.png",
                        "path": "/storage/emulated/0/Pictures/Screenshots/shot1.png",
                        "size_bytes": 125000,
                        "modified": "2024-01-15T10:30:00.000",
                    },
                ],
                "file_count": 1,
            }

            result = execute_tool("list_files", {
                "directory": "screenshots",
            }, {})

        mock_bridge.return_value.call_native.assert_called_once()
        call_args = mock_bridge.return_value.call_native.call_args
        assert call_args is not None
        assert call_args[0][0] == "list_files"
        assert call_args[0][1]["directory"] == "screenshots"

    def test_list_files_gets_timeout(self):
        """Test list_files receives timeout from context."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod._list_files
        mock_list = Mock(return_value={"success": True, "files": [], "file_count": 0})
        tools_mod._list_files = mock_list
        try:
            execute_tool(
                "list_files",
                {"directory": "downloads"},
                {"tool_timeout_ms": 15000}
            )
            call_kwargs = mock_list.call_args[1]
            assert "_timeout_ms" in call_kwargs
            assert call_kwargs["_timeout_ms"] == 15000
        finally:
            tools_mod._list_files = original


class TestImageComposeSchema:
    """Tests for image_compose tool schema."""

    def test_schema_exists(self):
        """Test image_compose schema is defined."""
        from navixmind.tools import TOOLS_SCHEMA
        tool_names = [t["name"] for t in TOOLS_SCHEMA]
        assert "image_compose" in tool_names

    def test_schema_has_required_fields(self):
        """Test image_compose schema has proper structure."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "image_compose")

        assert "description" in schema
        assert "input_schema" in schema
        assert "properties" in schema["input_schema"]

        props = schema["input_schema"]["properties"]
        assert "input_paths" in props
        assert "output_path" in props
        assert "operation" in props
        assert "params" in props

    def test_schema_operations_include_adjust(self):
        """Test image_compose operations include adjust for brightness/contrast."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "image_compose")
        ops = schema["input_schema"]["properties"]["operation"]["enum"]

        assert "adjust" in ops
        assert "concat_horizontal" in ops
        assert "concat_vertical" in ops
        assert "overlay" in ops
        assert "resize" in ops
        assert "crop" in ops
        assert "grayscale" in ops
        assert "blur" in ops

    def test_schema_required(self):
        """Test required fields are specified."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "image_compose")
        required = schema["input_schema"]["required"]

        assert "input_paths" in required
        assert "output_path" in required
        assert "operation" in required

    def test_schema_description_mentions_PIL_warning(self):
        """Test description warns against PIL usage."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "image_compose")
        desc = schema["description"]

        assert "PIL" in desc or "Pillow" in desc

    def test_schema_description_warns_against_ffmpeg(self):
        """Test description warns against using ffmpeg for images."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "image_compose")
        desc = schema["description"]

        assert "ffmpeg" in desc.lower()

    def test_offline_schema_exists(self):
        """Test image_compose is in offline schema."""
        from navixmind.tools import OFFLINE_TOOLS_SCHEMA
        tool_names = [t["name"] for t in OFFLINE_TOOLS_SCHEMA]
        assert "image_compose" in tool_names

    def test_offline_schema_operations_match(self):
        """Test offline schema has same operations."""
        from navixmind.tools import OFFLINE_TOOLS_SCHEMA
        schema = next(t for t in OFFLINE_TOOLS_SCHEMA if t["name"] == "image_compose")
        ops = schema["input_schema"]["properties"]["operation"]["enum"]

        assert "adjust" in ops
        assert "grayscale" in ops
        assert "blur" in ops


class TestListFilesSchema:
    """Tests for list_files tool schema."""

    def test_schema_exists(self):
        """Test list_files schema is defined."""
        from navixmind.tools import TOOLS_SCHEMA
        tool_names = [t["name"] for t in TOOLS_SCHEMA]
        assert "list_files" in tool_names

    def test_schema_has_required_fields(self):
        """Test list_files schema has proper structure."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "list_files")

        props = schema["input_schema"]["properties"]
        assert "directory" in props

    def test_schema_directory_enum(self):
        """Test list_files directory options are constrained."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "list_files")
        dirs = schema["input_schema"]["properties"]["directory"]["enum"]

        assert "output" in dirs
        assert "screenshots" in dirs
        assert "camera" in dirs
        assert "downloads" in dirs
        assert len(dirs) == 4  # No extra unsafe directories

    def test_schema_required(self):
        """Test required fields."""
        from navixmind.tools import TOOLS_SCHEMA
        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "list_files")
        assert "directory" in schema["input_schema"]["required"]

    def test_offline_schema_exists(self):
        """Test list_files is in offline schema."""
        from navixmind.tools import OFFLINE_TOOLS_SCHEMA
        tool_names = [t["name"] for t in OFFLINE_TOOLS_SCHEMA]
        assert "list_files" in tool_names


class TestInputPathsResolution:
    """Tests for input_paths array resolution in file path handling."""

    def test_input_paths_resolved_by_basename(self):
        """Test input_paths array items are resolved via basename lookup."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        file_map = {
            "img1.jpg": "/data/user/0/ai.navixmind/files/navixmind_shared/img1.jpg",
            "img2.jpg": "/data/user/0/ai.navixmind/files/navixmind_shared/img2.jpg",
        }

        original = tools_mod._image_compose
        mock_compose = Mock(return_value={"success": True, "output_path": "/out.jpg"})
        tools_mod._image_compose = mock_compose
        try:
            execute_tool(
                "image_compose",
                {
                    "input_paths": ["img1.jpg", "img2.jpg"],
                    "output_path": "combined.jpg",
                    "operation": "concat_horizontal",
                },
                {"_file_map": file_map, "output_dir": "/tmp/out"}
            )
            call_kwargs = mock_compose.call_args[1]
            assert call_kwargs["input_paths"] == [
                "/data/user/0/ai.navixmind/files/navixmind_shared/img1.jpg",
                "/data/user/0/ai.navixmind/files/navixmind_shared/img2.jpg",
            ]
        finally:
            tools_mod._image_compose = original

    def test_input_paths_resolved_by_full_path_basename(self):
        """Test full paths in input_paths are resolved via basename extraction."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        file_map = {
            "photo.jpg": "/data/user/0/ai.navixmind/files/navixmind_shared/photo.jpg",
        }

        original = tools_mod._image_compose
        mock_compose = Mock(return_value={"success": True, "output_path": "/out.jpg"})
        tools_mod._image_compose = mock_compose
        try:
            execute_tool(
                "image_compose",
                {
                    "input_paths": ["/wrong/path/photo.jpg"],
                    "output_path": "result.jpg",
                    "operation": "resize",
                    "params": {"width": 800},
                },
                {"_file_map": file_map, "output_dir": "/tmp/out"}
            )
            call_kwargs = mock_compose.call_args[1]
            assert call_kwargs["input_paths"] == [
                "/data/user/0/ai.navixmind/files/navixmind_shared/photo.jpg",
            ]
        finally:
            tools_mod._image_compose = original

    def test_input_paths_passthrough_when_not_in_map(self):
        """Test paths not in file_map are passed through unchanged."""
        from navixmind.tools import execute_tool
        import navixmind.tools as tools_mod

        original = tools_mod._image_compose
        mock_compose = Mock(return_value={"success": True, "output_path": "/out.jpg"})
        tools_mod._image_compose = mock_compose
        try:
            execute_tool(
                "image_compose",
                {
                    "input_paths": ["/real/path/photo.jpg"],
                    "output_path": "result.jpg",
                    "operation": "grayscale",
                },
                {"_file_map": {}, "output_dir": "/tmp/out"}
            )
            call_kwargs = mock_compose.call_args[1]
            assert call_kwargs["input_paths"] == ["/real/path/photo.jpg"]
        finally:
            tools_mod._image_compose = original


class TestToolMapCompleteness:
    """Tests to verify all schemas have corresponding dispatch functions."""

    def test_all_schema_tools_are_dispatchable(self):
        """Test every tool in TOOLS_SCHEMA is registered in the tool_map."""
        from navixmind.tools import TOOLS_SCHEMA, execute_tool
        from navixmind.bridge import ToolError

        tool_names = [t["name"] for t in TOOLS_SCHEMA]

        # Tools that block: python_execute waits for input,
        # native tools call bridge.call_native() which blocks waiting for Flutter
        skip = {
            "python_execute",
            "ffmpeg_process", "ocr_image", "smart_crop",
            "image_compose", "list_files",
            "headless_browser",
            "google_calendar", "gmail",
        }

        for name in tool_names:
            if name in skip:
                continue
            try:
                execute_tool(name, {}, {})
            except ToolError as e:
                assert "Unknown tool" not in str(e), f"Tool {name} is not registered in tool_map"
            except Exception:
                pass  # Missing params is fine — we just verify dispatch

        # For skipped tools, verify they exist in schema (dispatch tested
        # individually in TestNativeToolDelegation with mocked bridges)
        schema_names = {t["name"] for t in TOOLS_SCHEMA}
        for name in skip:
            assert name in schema_names, f"Skipped tool {name} not found in TOOLS_SCHEMA"

    def test_image_compose_in_tool_map(self):
        """Test image_compose is registered in execute_tool dispatch."""
        from navixmind.tools import execute_tool
        from navixmind.bridge import ToolError

        try:
            execute_tool("image_compose", {}, {})
        except ToolError as e:
            assert "Unknown tool" not in str(e)
        except Exception:
            pass  # Missing params is fine

    def test_list_files_in_tool_map(self):
        """Test list_files is registered in execute_tool dispatch."""
        from navixmind.tools import execute_tool
        from navixmind.bridge import ToolError

        try:
            execute_tool("list_files", {}, {})
        except ToolError as e:
            assert "Unknown tool" not in str(e)
        except Exception:
            pass
