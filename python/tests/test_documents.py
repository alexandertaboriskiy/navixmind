"""
Comprehensive tests for the NavixMind documents module.

Tests cover:
- read_pdf: all pages, page ranges, single pages, invalid pages, truncation
- create_pdf: with/without title, special character escaping
- convert_document: docx to txt/pdf/html, txt to pdf/html, unsupported formats
- Error handling for all functions
"""

import sys
import pytest
from unittest.mock import Mock, patch, MagicMock, mock_open

# Mock the external modules that documents.py depends on before importing
sys.modules['pypdf'] = Mock()
sys.modules['reportlab'] = Mock()
sys.modules['reportlab.lib'] = Mock()
sys.modules['reportlab.lib.pagesizes'] = Mock()
sys.modules['reportlab.lib.styles'] = Mock()
sys.modules['reportlab.lib.units'] = Mock()
sys.modules['reportlab.platypus'] = Mock()
sys.modules['docx'] = Mock()

# Import the module under test directly
from navixmind.tools import documents
from navixmind.bridge import ToolError


class TestReadPdf:
    """Tests for the read_pdf function."""

    def test_read_all_pages(self):
        """Test reading all pages from a PDF."""
        # Setup mock
        mock_page1 = Mock()
        mock_page1.extract_text.return_value = "Content of page 1"
        mock_page2 = Mock()
        mock_page2.extract_text.return_value = "Content of page 2"
        mock_page3 = Mock()
        mock_page3.extract_text.return_value = "Content of page 3"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page1, mock_page2, mock_page3]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.object(documents, 'validate_pdf_for_processing'), \
             patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            # Re-import to pick up the mock
            import importlib
            importlib.reload(documents)
            # Re-patch validate after reload
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="all")

        assert result["path"] == "/path/to/test.pdf"
        assert result["total_pages"] == 3
        assert result["pages_extracted"] == 3
        assert "Content of page 1" in result["text"]
        assert "Content of page 2" in result["text"]
        assert "Content of page 3" in result["text"]
        assert "--- Page 1 ---" in result["text"]
        assert "--- Page 2 ---" in result["text"]
        assert "--- Page 3 ---" in result["text"]

    def test_read_page_range(self):
        """Test reading a specific page range from a PDF."""
        pages = [Mock() for _ in range(10)]
        for i, page in enumerate(pages):
            page.extract_text.return_value = f"Content page {i + 1}"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = pages
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="3-7")

        assert result["total_pages"] == 10
        assert result["pages_extracted"] == 5
        assert "Content page 3" in result["text"]
        assert "Content page 4" in result["text"]
        assert "Content page 5" in result["text"]
        assert "Content page 6" in result["text"]
        assert "Content page 7" in result["text"]
        assert "Content page 1" not in result["text"]
        assert "Content page 2" not in result["text"]
        assert "Content page 8" not in result["text"]

    def test_read_page_range_exceeds_total(self):
        """Test page range that exceeds total pages is handled correctly."""
        pages = [Mock() for _ in range(3)]
        for i, page in enumerate(pages):
            page.extract_text.return_value = f"Content {i + 1}"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = pages
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                # Requesting pages 2-10 when only 3 pages exist
                result = documents.read_pdf("/path/to/test.pdf", pages="2-10")

        # Should only extract pages 2 and 3
        assert result["total_pages"] == 3
        assert result["pages_extracted"] == 2

    def test_read_single_page(self):
        """Test reading a single specific page from a PDF."""
        pages = [Mock() for _ in range(5)]
        for i, page in enumerate(pages):
            page.extract_text.return_value = f"Page {i + 1} text"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = pages
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="3")

        assert result["total_pages"] == 5
        assert result["pages_extracted"] == 1
        assert "Page 3 text" in result["text"]
        assert "--- Page 3 ---" in result["text"]
        assert "Page 1 text" not in result["text"]
        assert "Page 2 text" not in result["text"]

    def test_read_first_page(self):
        """Test reading the first page."""
        mock_page = Mock()
        mock_page.extract_text.return_value = "First page content"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page, Mock(), Mock()]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="1")

        assert result["pages_extracted"] == 1
        assert "First page content" in result["text"]

    def test_read_invalid_page_number(self):
        """Test reading a page that doesn't exist raises ToolError."""
        mock_reader_instance = Mock()
        mock_reader_instance.pages = [Mock(), Mock()]  # 2 pages
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_pdf("/path/to/test.pdf", pages="5")

        assert "doesn't exist" in str(exc_info.value)
        assert "5" in str(exc_info.value)
        assert "2 pages" in str(exc_info.value)

    def test_read_page_zero_accesses_last_page(self):
        """Test reading page 0 accesses the last page (Python negative indexing).

        Note: The current implementation allows page 0 which results in
        index -1, accessing the last page via Python's negative indexing.
        This is not explicitly guarded against in the code.
        """
        mock_page = Mock()
        mock_page.extract_text.return_value = "Last page content"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page]  # 1 page
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                # Page 0 becomes index -1, which accesses last page
                result = documents.read_pdf("/path/to/test.pdf", pages="0")

        # Due to Python's negative indexing, this accesses the last page
        assert result["pages_extracted"] == 1
        assert "Last page content" in result["text"]

    def test_text_truncation_at_100000_chars(self):
        """Test that text is truncated at 100000 characters."""
        # Create content that exceeds 100000 chars
        long_content = "x" * 60000
        mock_page1 = Mock()
        mock_page1.extract_text.return_value = long_content
        mock_page2 = Mock()
        mock_page2.extract_text.return_value = long_content

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page1, mock_page2]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="all")

        # Text should be truncated and have truncation message
        assert len(result["text"]) > 100000
        assert result["text"].endswith("[Content truncated...]")

    def test_text_exactly_100000_not_truncated(self):
        """Test that text exactly at 100000 chars is not truncated."""
        # Create content that is exactly at the limit
        mock_page = Mock()
        mock_page.extract_text.return_value = "x" * 99980  # Leave room for page header

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="all")

        assert "[Content truncated...]" not in result["text"]

    def test_empty_page_text_skipped(self):
        """Test that pages with no text are handled properly."""
        mock_page1 = Mock()
        mock_page1.extract_text.return_value = "Page 1 content"
        mock_page2 = Mock()
        mock_page2.extract_text.return_value = ""  # Empty page
        mock_page3 = Mock()
        mock_page3.extract_text.return_value = None  # None returned
        mock_page4 = Mock()
        mock_page4.extract_text.return_value = "Page 4 content"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page1, mock_page2, mock_page3, mock_page4]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf", pages="all")

        assert result["total_pages"] == 4
        assert result["pages_extracted"] == 4
        assert "Page 1 content" in result["text"]
        assert "Page 4 content" in result["text"]

    def test_validation_called(self):
        """Test that PDF validation is called."""
        mock_page = Mock()
        mock_page.extract_text.return_value = "Content"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing') as mock_validate:
                documents.read_pdf("/path/to/test.pdf")
                mock_validate.assert_called_once_with("/path/to/test.pdf")

    def test_reader_exception_raises_tool_error(self):
        """Test that PdfReader exceptions are wrapped in ToolError."""
        mock_reader_class = Mock(side_effect=Exception("Corrupted PDF file"))
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_pdf("/path/to/corrupted.pdf")

        assert "Failed to read PDF" in str(exc_info.value)
        assert "Corrupted PDF file" in str(exc_info.value)

    def test_default_pages_parameter(self):
        """Test that default pages parameter is 'all'."""
        pages = [Mock() for _ in range(3)]
        for i, page in enumerate(pages):
            page.extract_text.return_value = f"Page {i + 1}"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = pages
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                result = documents.read_pdf("/path/to/test.pdf")  # No pages parameter

        assert result["pages_extracted"] == 3  # All pages extracted


class TestCreatePdf:
    """Tests for the create_pdf function."""

    @pytest.fixture(autouse=True)
    def mock_makedirs(self):
        """Mock os.makedirs to avoid filesystem errors with fake paths."""
        with patch('os.makedirs'):
            yield

    def _setup_reportlab_mocks(self):
        """Set up comprehensive reportlab mocks."""
        mock_doc = Mock()
        mock_doc_class = Mock(return_value=mock_doc)
        mock_styles = {'Normal': Mock(), 'Heading1': Mock()}
        mock_get_styles = Mock(return_value=mock_styles)
        mock_paragraph = Mock()
        mock_spacer = Mock()
        mock_paragraph_style = Mock()

        mock_reportlab = Mock()
        mock_reportlab_lib = Mock()
        mock_reportlab_lib_pagesizes = Mock()
        mock_reportlab_lib_pagesizes.letter = (612, 792)
        mock_reportlab_lib_styles = Mock()
        mock_reportlab_lib_styles.getSampleStyleSheet = mock_get_styles
        mock_reportlab_lib_styles.ParagraphStyle = mock_paragraph_style
        mock_reportlab_lib_units = Mock()
        mock_reportlab_lib_units.inch = 72
        mock_reportlab_platypus = Mock()
        mock_reportlab_platypus.SimpleDocTemplate = mock_doc_class
        mock_reportlab_platypus.Paragraph = mock_paragraph
        mock_reportlab_platypus.Spacer = mock_spacer

        return {
            'reportlab': mock_reportlab,
            'reportlab.lib': mock_reportlab_lib,
            'reportlab.lib.pagesizes': mock_reportlab_lib_pagesizes,
            'reportlab.lib.styles': mock_reportlab_lib_styles,
            'reportlab.lib.units': mock_reportlab_lib_units,
            'reportlab.platypus': mock_reportlab_platypus,
        }, mock_doc, mock_paragraph, mock_paragraph_style, mock_doc_class

    def test_create_pdf_basic(self):
        """Test basic PDF creation."""
        mocks, mock_doc, _, _, _ = self._setup_reportlab_mocks()

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            result = documents.create_pdf(
                content="Hello World",
                output_path="/path/to/output.pdf"
            )

        assert result["success"] is True
        assert result["output_path"] == "/path/to/output.pdf"
        mock_doc.build.assert_called_once()

    def test_create_pdf_with_title(self):
        """Test PDF creation with a title."""
        mocks, mock_doc, mock_paragraph, mock_para_style, _ = self._setup_reportlab_mocks()

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            result = documents.create_pdf(
                content="Document content here.",
                output_path="/path/to/output.pdf",
                title="My Document Title"
            )

        assert result["success"] is True
        # Verify ParagraphStyle was called (for title)
        mock_para_style.assert_called()

    def test_create_pdf_without_title(self):
        """Test PDF creation without a title."""
        mocks, mock_doc, _, mock_para_style, _ = self._setup_reportlab_mocks()

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            result = documents.create_pdf(
                content="Content only",
                output_path="/path/to/output.pdf",
                title=None
            )

        assert result["success"] is True
        mock_doc.build.assert_called_once()

    def test_create_pdf_escapes_ampersand(self):
        """Test that & is escaped to &amp;"""
        mocks, _, mock_paragraph, _, _ = self._setup_reportlab_mocks()
        paragraph_calls = []
        mock_paragraph.side_effect = lambda text, style: paragraph_calls.append(text)

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(
                content="Tom & Jerry",
                output_path="/path/to/output.pdf"
            )

        # Check that Paragraph was called with escaped content
        assert any('&amp;' in str(call) for call in paragraph_calls)

    def test_create_pdf_escapes_less_than(self):
        """Test that < is escaped to &lt;"""
        mocks, _, mock_paragraph, _, _ = self._setup_reportlab_mocks()
        paragraph_calls = []
        mock_paragraph.side_effect = lambda text, style: paragraph_calls.append(text)

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(
                content="x < y",
                output_path="/path/to/output.pdf"
            )

        assert any('&lt;' in str(call) for call in paragraph_calls)

    def test_create_pdf_escapes_greater_than(self):
        """Test that > is escaped to &gt;"""
        mocks, _, mock_paragraph, _, _ = self._setup_reportlab_mocks()
        paragraph_calls = []
        mock_paragraph.side_effect = lambda text, style: paragraph_calls.append(text)

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(
                content="x > y",
                output_path="/path/to/output.pdf"
            )

        assert any('&gt;' in str(call) for call in paragraph_calls)

    def test_create_pdf_escapes_all_special_chars(self):
        """Test that all special characters are escaped correctly."""
        mocks, _, mock_paragraph, _, _ = self._setup_reportlab_mocks()
        paragraph_calls = []
        mock_paragraph.side_effect = lambda text, style: paragraph_calls.append(text)

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(
                content="<html>&nbsp;</html>",
                output_path="/path/to/output.pdf"
            )

        # All special chars should be escaped
        escaped_calls = [c for c in paragraph_calls if isinstance(c, str)]
        assert any('&lt;' in c and '&gt;' in c and '&amp;' in c for c in escaped_calls)

    def test_create_pdf_multiple_paragraphs(self):
        """Test PDF creation with multiple paragraphs."""
        mocks, _, mock_paragraph, _, _ = self._setup_reportlab_mocks()
        paragraph_calls = []
        mock_paragraph.side_effect = lambda text, style: paragraph_calls.append(text)

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(
                content="First paragraph.\n\nSecond paragraph.\n\nThird paragraph.",
                output_path="/path/to/output.pdf"
            )

        # Should have 3 paragraph calls (one for each content paragraph)
        assert len(paragraph_calls) >= 3

    def test_create_pdf_empty_paragraphs_skipped(self):
        """Test that empty paragraphs are skipped."""
        mocks, _, mock_paragraph, _, _ = self._setup_reportlab_mocks()
        paragraph_calls = []
        mock_paragraph.side_effect = lambda text, style: paragraph_calls.append(text)

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(
                content="First\n\n\n\nSecond",  # Extra blank paragraphs
                output_path="/path/to/output.pdf"
            )

        # Only 2 non-empty paragraphs should be created
        non_empty_calls = [c for c in paragraph_calls if c and c.strip()]
        assert len(non_empty_calls) == 2

    def test_create_pdf_document_margins(self):
        """Test that PDF is created with correct margins."""
        mocks, _, _, _, mock_doc_class = self._setup_reportlab_mocks()

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            documents.create_pdf(content="Test", output_path="/path/to/output.pdf")

        # Verify margins are set to 72 (1 inch)
        call_kwargs = mock_doc_class.call_args[1]
        assert call_kwargs['rightMargin'] == 72
        assert call_kwargs['leftMargin'] == 72
        assert call_kwargs['topMargin'] == 72
        assert call_kwargs['bottomMargin'] == 72

    def test_create_pdf_exception_raises_tool_error(self):
        """Test that exceptions are wrapped in ToolError."""
        mocks, _, _, _, mock_doc_class = self._setup_reportlab_mocks()
        mock_doc_class.side_effect = Exception("Disk full")

        with patch.dict('sys.modules', mocks):
            import importlib
            importlib.reload(documents)

            with pytest.raises(ToolError) as exc_info:
                documents.create_pdf(content="Test", output_path="/path/to/output.pdf")

        assert "Failed to create PDF" in str(exc_info.value)
        assert "Disk full" in str(exc_info.value)


class TestConvertDocument:
    """Tests for the convert_document function."""

    def _setup_docx_mock(self, paragraphs_text):
        """Set up docx mock with given paragraph texts."""
        mock_doc = Mock()
        mock_paras = []
        for text in paragraphs_text:
            para = Mock()
            para.text = text
            mock_paras.append(para)
        mock_doc.paragraphs = mock_paras
        mock_doc_class = Mock(return_value=mock_doc)
        return Mock(Document=mock_doc_class)

    def test_convert_docx_to_txt(self):
        """Test converting DOCX to TXT."""
        mock_docx = self._setup_docx_mock(["First paragraph", "Second paragraph"])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_open()) as mock_file:
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.convert_document("/path/to/doc.docx", "txt")

        assert result["success"] is True
        assert result["output_path"] == "/path/to/doc.txt"
        # Verify file was written
        mock_file.assert_called_with("/path/to/doc.txt", 'w', encoding='utf-8')

    def test_convert_docx_to_pdf(self):
        """Test converting DOCX to PDF."""
        mock_docx = self._setup_docx_mock(["Document content"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'), \
                 patch.object(documents, 'create_pdf') as mock_create_pdf:
                mock_create_pdf.return_value = {"output_path": "/path/to/doc.pdf", "success": True}
                result = documents.convert_document("/path/to/doc.docx", "pdf")

        assert result["success"] is True
        mock_create_pdf.assert_called_once()

    def test_convert_docx_to_html(self):
        """Test converting DOCX to HTML."""
        mock_docx = self._setup_docx_mock(["Paragraph one", "Paragraph two"])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_open()) as mock_file:
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.convert_document("/path/to/doc.docx", "html")

        assert result["success"] is True
        assert result["output_path"] == "/path/to/doc.html"

    def test_convert_doc_to_txt(self):
        """Test converting DOC to TXT (same as DOCX)."""
        mock_docx = self._setup_docx_mock(["Content"])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_open()) as mock_file:
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.convert_document("/path/to/doc.doc", "txt")

        assert result["success"] is True
        assert result["output_path"] == "/path/to/doc.txt"

    def test_convert_txt_to_pdf(self):
        """Test converting TXT to PDF."""
        with patch('builtins.open', mock_open(read_data="Text content here")), \
             patch.object(documents, 'validate_file_for_processing'), \
             patch.object(documents, 'create_pdf') as mock_create_pdf:

            mock_create_pdf.return_value = {"output_path": "/path/to/doc.pdf", "success": True}
            result = documents.convert_document("/path/to/doc.txt", "pdf")

        assert result["success"] is True
        mock_create_pdf.assert_called_once_with("Text content here", "/path/to/doc.pdf")

    def test_convert_txt_to_html(self):
        """Test converting TXT to HTML."""
        with patch('builtins.open', mock_open(read_data="Para 1\n\nPara 2")) as mock_file, \
             patch.object(documents, 'validate_file_for_processing'):

            result = documents.convert_document("/path/to/doc.txt", "html")

        assert result["success"] is True
        assert result["output_path"] == "/path/to/doc.html"

    def test_convert_unsupported_input_format(self):
        """Test converting unsupported input format raises ToolError."""
        with patch.object(documents, 'validate_file_for_processing'):
            with pytest.raises(ToolError) as exc_info:
                documents.convert_document("/path/to/file.xyz", "pdf")

        assert "Unsupported input format" in str(exc_info.value)
        assert ".xyz" in str(exc_info.value)

    def test_convert_unsupported_output_format_docx(self):
        """Test converting DOCX to unsupported output format."""
        mock_docx = self._setup_docx_mock(["Content"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.convert_document("/path/to/doc.docx", "odt")

        assert "Unsupported output format" in str(exc_info.value)
        assert "odt" in str(exc_info.value)

    def test_convert_unsupported_output_format_txt(self):
        """Test converting TXT to unsupported output format."""
        with patch('builtins.open', mock_open(read_data="Content")), \
             patch.object(documents, 'validate_file_for_processing'):

            with pytest.raises(ToolError) as exc_info:
                documents.convert_document("/path/to/file.txt", "docx")

        assert "Unsupported output format" in str(exc_info.value)
        assert "docx" in str(exc_info.value)

    def test_convert_validation_called(self):
        """Test that file validation is called."""
        mock_docx = self._setup_docx_mock(["Content"])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_open()):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.convert_document("/path/to/doc.docx", "txt")
                mock_validate.assert_called_once_with("/path/to/doc.docx", 'document')

    def test_convert_output_path_generated(self):
        """Test that output path is correctly generated from input path."""
        mock_docx = self._setup_docx_mock(["Content"])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_open()):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.convert_document("/path/to/my_document.docx", "txt")

        assert result["output_path"] == "/path/to/my_document.txt"

    def test_convert_uppercase_extension(self):
        """Test conversion with uppercase extension."""
        mock_docx = self._setup_docx_mock(["Content"])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_open()):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.convert_document("/path/to/doc.DOCX", "txt")

        assert result["success"] is True

    def test_convert_docx_html_contains_paragraphs(self):
        """Test HTML output contains paragraph tags."""
        mock_docx = self._setup_docx_mock(["First paragraph", "Second paragraph"])
        written_content = []

        def capture_write(content):
            written_content.append(content)

        mock_file = mock_open()
        mock_file.return_value.write = capture_write

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_file):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.convert_document("/path/to/doc.docx", "html")

        # Verify HTML structure
        html_content = ''.join(written_content)
        assert '<!DOCTYPE html>' in html_content
        assert '<html>' in html_content
        assert '<p>' in html_content
        assert '</body>' in html_content

    def test_convert_txt_to_html_multiple_paragraphs(self):
        """Test TXT to HTML with multiple paragraphs."""
        written_content = []

        def capture_write(content):
            written_content.append(content)

        # Create mock that returns different content for read vs write
        m = mock_open(read_data="Para 1\n\nPara 2\n\nPara 3")
        m.return_value.write = capture_write

        with patch('builtins.open', m), \
             patch.object(documents, 'validate_file_for_processing'):
            documents.convert_document("/path/to/doc.txt", "html")

        html_content = ''.join(written_content)
        assert html_content.count('<p>') == 3

    def test_convert_docx_empty_paragraphs_filtered(self):
        """Test that empty paragraphs are filtered in HTML output."""
        # Include empty and whitespace-only paragraphs
        mock_docx = self._setup_docx_mock(["Content", "", "   ", "More content"])
        written_content = []

        def capture_write(content):
            written_content.append(content)

        mock_file = mock_open()
        mock_file.return_value.write = capture_write

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_file):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.convert_document("/path/to/doc.docx", "html")

        html_content = ''.join(written_content)
        # Only non-empty paragraphs should be included
        assert html_content.count('<p>') == 2

    def test_convert_docx_extracts_text(self):
        """Test DOCX to TXT extracts paragraph text correctly."""
        mock_docx = self._setup_docx_mock(["First", "Second"])
        written_content = []

        def capture_write(content):
            written_content.append(content)

        mock_file = mock_open()
        mock_file.return_value.write = capture_write

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('builtins.open', mock_file):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.convert_document("/path/to/doc.docx", "txt")

        text_content = ''.join(written_content)
        assert "First" in text_content
        assert "Second" in text_content
        # Paragraphs should be joined with double newlines
        assert "First\n\nSecond" in text_content

    def test_convert_exception_wrapped_in_tool_error(self):
        """Test that exceptions are wrapped in ToolError."""
        mock_docx = Mock(Document=Mock(side_effect=Exception("Cannot read file")))

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.convert_document("/path/to/doc.docx", "txt")

        assert "Conversion failed" in str(exc_info.value)
        assert "Cannot read file" in str(exc_info.value)


class TestConvertDocxHelper:
    """Tests for the _convert_docx helper function."""

    def test_convert_docx_pdf_uses_create_pdf(self):
        """Test _convert_docx uses create_pdf for PDF output."""
        mock_doc = Mock()
        mock_para = Mock()
        mock_para.text = "Test content"
        mock_doc.paragraphs = [mock_para]
        mock_doc_class = Mock(return_value=mock_doc)
        mock_docx = Mock(Document=mock_doc_class)

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'create_pdf') as mock_create_pdf:
                mock_create_pdf.return_value = {"output_path": "/path/to/out.pdf", "success": True}
                result = documents._convert_docx("/path/to/in.docx", "pdf", "/path/to/out.pdf")

        mock_create_pdf.assert_called_once_with("Test content", "/path/to/out.pdf")
        assert result["success"] is True


class TestConvertTxtHelper:
    """Tests for the _convert_txt helper function."""

    def test_convert_txt_pdf_uses_create_pdf(self):
        """Test _convert_txt uses create_pdf for PDF output."""
        with patch('builtins.open', mock_open(read_data="File content")), \
             patch.object(documents, 'create_pdf') as mock_create_pdf:

            mock_create_pdf.return_value = {"output_path": "/path/to/out.pdf", "success": True}
            result = documents._convert_txt("/path/to/in.txt", "pdf", "/path/to/out.pdf")

        mock_create_pdf.assert_called_once_with("File content", "/path/to/out.pdf")

    def test_convert_txt_html_creates_proper_structure(self):
        """Test _convert_txt creates proper HTML structure."""
        written_content = []

        def capture_write(content):
            written_content.append(content)

        m = mock_open(read_data="Line 1\n\nLine 2")
        m.return_value.write = capture_write

        with patch('builtins.open', m):
            result = documents._convert_txt("/path/to/in.txt", "html", "/path/to/out.html")

        html_content = ''.join(written_content)
        assert '<!DOCTYPE html>' in html_content
        assert '<meta charset="utf-8">' in html_content
        assert '<title>Converted Document</title>' in html_content


class TestIntegration:
    """Integration tests combining multiple document operations."""

    def test_read_and_convert_workflow(self):
        """Test a typical read PDF then convert workflow."""
        # Read PDF
        mock_page = Mock()
        mock_page.extract_text.return_value = "Extracted content from PDF"

        mock_reader_instance = Mock()
        mock_reader_instance.pages = [mock_page]
        mock_reader_class = Mock(return_value=mock_reader_instance)
        mock_pypdf = Mock(PdfReader=mock_reader_class)

        with patch.dict('sys.modules', {'pypdf': mock_pypdf}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_pdf_for_processing'):
                read_result = documents.read_pdf("/path/to/input.pdf")

        assert "Extracted content from PDF" in read_result["text"]

        # Create new PDF - mock reportlab
        mocks = {
            'reportlab': Mock(),
            'reportlab.lib': Mock(),
            'reportlab.lib.pagesizes': Mock(letter=(612, 792)),
            'reportlab.lib.styles': Mock(getSampleStyleSheet=Mock(return_value={'Normal': Mock(), 'Heading1': Mock()}), ParagraphStyle=Mock()),
            'reportlab.lib.units': Mock(inch=72),
            'reportlab.platypus': Mock(SimpleDocTemplate=Mock(return_value=Mock()), Paragraph=Mock(), Spacer=Mock()),
        }

        with patch.dict('sys.modules', mocks), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)

            create_result = documents.create_pdf(
                content=read_result["text"],
                output_path="/path/to/output.pdf"
            )

        assert create_result["success"] is True

    def test_convert_preserves_content(self):
        """Test that conversion preserves text content."""
        original_content = "This is the original document content."

        with patch('builtins.open', mock_open(read_data=original_content)), \
             patch.object(documents, 'validate_file_for_processing'), \
             patch.object(documents, 'create_pdf') as mock_create_pdf:

            mock_create_pdf.return_value = {"output_path": "/path/to/out.pdf", "success": True}
            documents.convert_document("/path/to/doc.txt", "pdf")

        # Verify create_pdf received the original content
        call_args = mock_create_pdf.call_args[0]
        assert call_args[0] == original_content
