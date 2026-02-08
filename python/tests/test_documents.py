"""
Comprehensive tests for the NavixMind documents module.

Tests cover:
- read_pdf: all pages, page ranges, single pages, invalid pages, truncation
- create_pdf: with/without title, special character escaping
- convert_document: docx to txt/pdf/html, txt to pdf/html, unsupported formats
- read_docx, modify_docx: DOCX read/write
- read_pptx, modify_pptx: PPTX read/write
- read_xlsx, modify_xlsx: XLSX read/write
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
sys.modules['pptx'] = Mock()
sys.modules['pptx.util'] = Mock()
sys.modules['openpyxl'] = Mock()

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


class TestReadFile:
    """Tests for the read_file function."""

    def test_read_normal_text_file(self):
        """Test reading a normal text file."""
        content = "Hello, world!\nThis is a test file."

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=len(content.encode('utf-8'))), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/test.txt")

        assert result["path"] == "/path/to/test.txt"
        assert result["content"] == content
        assert result["size_bytes"] == len(content.encode('utf-8'))

    def test_read_utf8_special_chars(self):
        """Test reading a file with UTF-8 special characters."""
        content = "Héllo wörld! 日本語テスト 🎉"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=42), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/unicode.txt")

        assert result["content"] == content

    def test_read_truncation_at_100k(self):
        """Test that content is truncated at 100000 characters."""
        content = "x" * 150000

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=150000), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/large.txt")

        assert len(result["content"]) == 100000 + len("\n\n[Content truncated...]")
        assert result["content"].endswith("[Content truncated...]")
        assert result["content"][:100000] == "x" * 100000

    def test_read_exactly_100k_not_truncated(self):
        """Test that content exactly at 100000 chars is not truncated."""
        content = "x" * 100000

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=100000), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/exact.txt")

        assert "[Content truncated...]" not in result["content"]
        assert len(result["content"]) == 100000

    def test_read_file_not_found(self):
        """Test reading a non-existent file raises ToolError."""
        with patch.object(documents, 'validate_file_for_processing',
                          side_effect=ToolError("File not found: /path/to/missing.txt")):

            with pytest.raises(ToolError) as exc_info:
                documents.read_file("/path/to/missing.txt")

        assert "File not found" in str(exc_info.value)

    def test_read_empty_file(self):
        """Test reading an empty file returns empty content."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=0), \
             patch('builtins.open', mock_open(read_data="")):

            result = documents.read_file("/path/to/empty.txt")

        assert result["content"] == ""
        assert result["size_bytes"] == 0

    def test_read_binary_file_graceful(self):
        """Test reading a binary file uses errors='replace' for graceful handling."""
        # Simulate binary content that gets replaced
        replaced_content = "some\ufffddata\ufffdhere"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=100), \
             patch('builtins.open', mock_open(read_data=replaced_content)):

            result = documents.read_file("/path/to/binary.bin")

        assert result["content"] == replaced_content

    def test_read_file_validation_called(self):
        """Test that file validation is called."""
        with patch.object(documents, 'validate_file_for_processing') as mock_validate, \
             patch('os.path.getsize', return_value=10), \
             patch('builtins.open', mock_open(read_data="test")):

            documents.read_file("/path/to/test.txt")
            mock_validate.assert_called_once_with("/path/to/test.txt")

    def test_read_file_io_error(self):
        """Test that IOError is wrapped in ToolError."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=10), \
             patch('builtins.open', side_effect=IOError("Permission denied")):

            with pytest.raises(ToolError) as exc_info:
                documents.read_file("/path/to/protected.txt")

        assert "Failed to read file" in str(exc_info.value)
        assert "Permission denied" in str(exc_info.value)

    def test_read_file_multiline(self):
        """Test reading a multi-line file preserves line breaks."""
        content = "Line 1\nLine 2\nLine 3\n"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=len(content)), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/multiline.txt")

        assert result["content"] == content
        assert result["content"].count("\n") == 3


class TestWriteFile:
    """Tests for the write_file function."""

    def test_write_text_file(self):
        """Test writing a normal text file."""
        content = "Hello, world!"

        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()) as mock_file, \
             patch('os.path.getsize', return_value=len(content.encode('utf-8'))):

            result = documents.write_file("/path/to/output.txt", content)

        assert result["output_path"] == "/path/to/output.txt"
        assert result["success"] is True
        assert result["size_bytes"] == len(content.encode('utf-8'))
        mock_file.assert_called_with("/path/to/output.txt", 'w', encoding='utf-8')

    def test_write_file_content_written(self):
        """Test that content is actually written to the file."""
        content = "Test content\nwith newlines"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            documents.write_file("/path/to/output.txt", content)

        assert "".join(written) == content

    def test_write_file_output_path_in_result(self):
        """Test that output_path key is in result dict (triggers UI chip)."""
        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=5):

            result = documents.write_file("/path/to/file.csv", "a,b,c")

        assert "output_path" in result
        assert result["output_path"] == "/path/to/file.csv"

    def test_write_file_too_large(self):
        """Test that content exceeding 1M chars is rejected."""
        large_content = "x" * 1_000_001

        with pytest.raises(ToolError) as exc_info:
            documents.write_file("/path/to/huge.txt", large_content)

        assert "Content too large" in str(exc_info.value)
        assert "1000001" in str(exc_info.value)

    def test_write_file_exactly_at_limit(self):
        """Test that content exactly at 1M chars is accepted."""
        content = "x" * 1_000_000

        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=1_000_000):

            result = documents.write_file("/path/to/max.txt", content)

        assert result["success"] is True

    def test_write_file_creates_directory(self):
        """Test that parent directories are created."""
        with patch('os.makedirs') as mock_makedirs, \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=5):

            documents.write_file("/path/to/new/dir/file.txt", "hello")

        mock_makedirs.assert_called_with("/path/to/new/dir", exist_ok=True)

    def test_write_file_no_dir_component(self):
        """Test writing a file with no directory component."""
        with patch('os.makedirs') as mock_makedirs, \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=5):

            documents.write_file("output.txt", "hello")

        # os.makedirs should NOT be called when dirname is empty
        mock_makedirs.assert_not_called()

    def test_write_file_unicode_content(self):
        """Test writing unicode content."""
        content = "日本語テスト\nЗдравствуйте\n🎉🚀"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=50):

            result = documents.write_file("/path/to/unicode.txt", content)

        assert result["success"] is True
        assert "".join(written) == content

    def test_write_file_io_error(self):
        """Test that IOError is wrapped in ToolError."""
        with patch('os.makedirs'), \
             patch('builtins.open', side_effect=IOError("Disk full")):

            with pytest.raises(ToolError) as exc_info:
                documents.write_file("/path/to/output.txt", "content")

        assert "Failed to write file" in str(exc_info.value)
        assert "Disk full" in str(exc_info.value)

    def test_write_file_empty_content(self):
        """Test writing empty content."""
        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=0):

            result = documents.write_file("/path/to/empty.txt", "")

        assert result["success"] is True
        assert result["size_bytes"] == 0

    def test_write_file_csv_content(self):
        """Test writing CSV content (common use case)."""
        content = "name,age,city\nAlice,30,NYC\nBob,25,SF"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            result = documents.write_file("/path/to/data.csv", content)

        assert result["success"] is True
        assert "".join(written) == content


# ---------------------------------------------------------------------------
# DOCX read/write tests
# ---------------------------------------------------------------------------

class TestReadDocx:
    """Tests for the read_docx function."""

    def _setup_docx_mock(self, paragraphs_text, tables=None):
        """Set up docx Document mock."""
        mock_doc = Mock()
        mock_paras = []
        for text in paragraphs_text:
            para = Mock()
            para.text = text
            mock_paras.append(para)
        mock_doc.paragraphs = mock_paras
        mock_doc.tables = tables or []
        mock_doc_class = Mock(return_value=mock_doc)
        return Mock(Document=mock_doc_class)

    def test_read_docx_all(self):
        """Test reading all content from a DOCX."""
        mock_docx = self._setup_docx_mock(["First paragraph", "Second paragraph"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx")

        assert result["path"] == "/path/to/test.docx"
        assert "First paragraph" in result["text"]
        assert "Second paragraph" in result["text"]
        assert result["paragraph_count"] == 2
        assert result["table_count"] == 0

    def test_read_docx_text_only(self):
        """Test extracting text only from DOCX."""
        mock_docx = self._setup_docx_mock(["Hello", "World"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="text")

        assert "text" in result
        assert "tables" not in result

    def test_read_docx_tables_only(self):
        """Test extracting tables only from DOCX."""
        mock_cell1 = Mock()
        mock_cell1.text = "A1"
        mock_cell2 = Mock()
        mock_cell2.text = "B1"
        mock_row = Mock()
        mock_row.cells = [mock_cell1, mock_cell2]
        mock_table = Mock()
        mock_table.rows = [mock_row]

        mock_docx = self._setup_docx_mock(["Text"], tables=[mock_table])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="tables")

        assert "tables" in result
        assert result["table_count"] == 1
        assert result["tables"][0][0] == ["A1", "B1"]
        assert "text" not in result

    def test_read_docx_empty_paragraphs_filtered(self):
        """Test that empty paragraphs are filtered from text."""
        mock_docx = self._setup_docx_mock(["Content", "", "   ", "More content"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="text")

        assert "Content" in result["text"]
        assert "More content" in result["text"]

    def test_read_docx_validation_called(self):
        """Test that file validation is called."""
        mock_docx = self._setup_docx_mock(["Text"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.read_docx("/path/to/test.docx")
                mock_validate.assert_called_once_with("/path/to/test.docx", 'document')

    def test_read_docx_exception_raises_tool_error(self):
        """Test that exceptions are wrapped in ToolError."""
        mock_docx = Mock(Document=Mock(side_effect=Exception("Corrupted file")))

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_docx("/path/to/bad.docx")

        assert "Failed to read DOCX" in str(exc_info.value)


class TestModifyDocx:
    """Tests for the modify_docx function."""

    def _setup_docx_mock(self):
        mock_doc = Mock()
        mock_run = Mock()
        mock_run.text = "Hello World"
        mock_para = Mock()
        mock_para.text = "Hello World"
        mock_para.runs = [mock_run]
        mock_doc.paragraphs = [mock_para]
        mock_doc.tables = []
        mock_doc_class = Mock(return_value=mock_doc)
        return Mock(Document=mock_doc_class), mock_doc

    def test_replace_text(self):
        """Test replacing text in a DOCX."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/path/to/input.docx",
                    "/path/to/output.docx",
                    [{"action": "replace_text", "params": {"old": "Hello", "new": "Hi"}}]
                )

        assert result["success"] is True
        assert result["operations_applied"] == 1
        mock_doc.save.assert_called_once_with("/path/to/output.docx")

    def test_add_paragraph(self):
        """Test adding a paragraph to a DOCX."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/path/to/input.docx",
                    "/path/to/output.docx",
                    [{"action": "add_paragraph", "params": {"text": "New paragraph"}}]
                )

        assert result["success"] is True
        mock_doc.add_paragraph.assert_called_once_with("New paragraph", style=None)

    def test_modify_docx_exception(self):
        """Test that exceptions are wrapped in ToolError."""
        mock_docx = Mock(Document=Mock(side_effect=Exception("Cannot open")))

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_docx("/in.docx", "/out.docx", [])

        assert "Failed to modify DOCX" in str(exc_info.value)


# ---------------------------------------------------------------------------
# PPTX read/write tests
# ---------------------------------------------------------------------------

class TestReadPptx:
    """Tests for the read_pptx function."""

    def _make_shape(self, text="", has_text_frame=True, has_table=False, name="Shape"):
        shape = Mock()
        shape.name = name
        shape.has_text_frame = has_text_frame
        shape.has_table = has_table
        if has_text_frame:
            para = Mock()
            para.text = text
            shape.text_frame = Mock()
            shape.text_frame.paragraphs = [para]
        return shape

    def _make_slide(self, texts=None, notes=""):
        slide = Mock()
        shapes = []
        for t in (texts or []):
            shapes.append(self._make_shape(text=t))
        slide.shapes = shapes
        slide.has_notes_slide = bool(notes)
        if notes:
            slide.notes_slide = Mock()
            slide.notes_slide.notes_text_frame = Mock()
            slide.notes_slide.notes_text_frame.text = notes
        return slide

    def test_read_pptx_all(self):
        """Test reading all content from a PPTX."""
        mock_prs = Mock()
        mock_prs.slides = [
            self._make_slide(texts=["Title", "Body text"], notes="Speaker note"),
            self._make_slide(texts=["Slide 2 title"]),
        ]

        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx")

        assert result["slide_count"] == 2
        assert "Title" in result["text"]
        assert "Body text" in result["text"]
        assert "Slide 2 title" in result["text"]
        assert len(result["slides"]) == 2
        assert result["notes"][0]["notes"] == "Speaker note"

    def test_read_pptx_text_only(self):
        """Test extracting text only."""
        mock_prs = Mock()
        mock_prs.slides = [self._make_slide(texts=["Hello"])]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="text")

        assert "text" in result
        assert "slides" not in result
        assert "notes" not in result

    def test_read_pptx_exception(self):
        """Test exception handling."""
        mock_pptx = Mock(Presentation=Mock(side_effect=Exception("Bad file")))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_pptx("/path/to/bad.pptx")

        assert "Failed to read PPTX" in str(exc_info.value)


class TestModifyPptx:
    """Tests for the modify_pptx function."""

    def test_replace_text(self):
        """Test replacing text across slides."""
        mock_run = Mock()
        mock_run.text = "Old Text"
        mock_para = Mock()
        mock_para.runs = [mock_run]
        mock_shape = Mock()
        mock_shape.has_text_frame = True
        mock_shape.text_frame = Mock()
        mock_shape.text_frame.paragraphs = [mock_para]
        mock_slide = Mock()
        mock_slide.shapes = [mock_shape]
        mock_prs = Mock()
        mock_prs.slides = [mock_slide]

        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "replace_text", "params": {"old": "Old", "new": "New"}}]
                )

        assert result["success"] is True
        assert result["operations_applied"] == 1
        mock_prs.save.assert_called_once_with("/out.pptx")

    def test_add_slide(self):
        """Test adding a slide."""
        mock_layout = Mock()
        mock_ph = Mock()
        mock_ph.placeholder_format = Mock()
        mock_ph.placeholder_format.idx = 0
        mock_new_slide = Mock()
        mock_new_slide.placeholders = [mock_ph]

        mock_prs = Mock()
        mock_prs.slides = Mock()
        mock_prs.slides.__iter__ = Mock(return_value=iter([]))
        mock_prs.slide_layouts = [Mock(), mock_layout]
        mock_prs.slides.add_slide = Mock(return_value=mock_new_slide)

        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "add_slide", "params": {"title": "New Slide"}}]
                )

        assert result["success"] is True
        assert result["operations_applied"] == 1

    def test_modify_pptx_exception(self):
        """Test exception handling."""
        mock_pptx = Mock(Presentation=Mock(side_effect=Exception("Cannot open")))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_pptx("/in.pptx", "/out.pptx", [])

        assert "Failed to modify PPTX" in str(exc_info.value)


# ---------------------------------------------------------------------------
# XLSX read/write tests
# ---------------------------------------------------------------------------

class TestReadXlsx:
    """Tests for the read_xlsx function."""

    def _make_cell(self, value, data_type='n'):
        cell = Mock()
        cell.value = value
        cell.data_type = data_type
        return cell

    def _make_worksheet(self, rows_data, name="Sheet1", dimensions="A1:B2"):
        ws = Mock()
        ws.dimensions = dimensions
        rows = []
        for row_data in rows_data:
            rows.append([self._make_cell(v) for v in row_data])
        ws.iter_rows = Mock(return_value=iter(rows))
        ws.__getitem__ = Mock(return_value=iter(rows))
        return ws

    def test_read_xlsx_basic(self):
        """Test reading basic XLSX data."""
        ws = self._make_worksheet([["A1", "B1"], ["A2", "B2"]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx")

        assert result["sheet_count"] == 1
        assert result["sheet_names"] == ["Sheet1"]
        assert "Sheet1" in result["sheets"]

    def test_read_xlsx_specific_sheet(self):
        """Test reading a specific sheet by name."""
        ws = self._make_worksheet([["Data"]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1", "Sheet2"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx", sheet="Sheet2")

        assert "Sheet2" in result["sheets"]
        assert len(result["sheets"]) == 1

    def test_read_xlsx_sheet_not_found(self):
        """Test error when sheet not found."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_xlsx("/path/to/test.xlsx", sheet="Missing")

        assert "not found" in str(exc_info.value)

    def test_read_xlsx_exception(self):
        """Test exception handling."""
        mock_openpyxl = Mock(load_workbook=Mock(side_effect=Exception("Bad file")))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_xlsx("/path/to/bad.xlsx")

        assert "Failed to read XLSX" in str(exc_info.value)


class TestModifyXlsx:
    """Tests for the modify_xlsx function."""

    def test_set_cell(self):
        """Test setting a cell value."""
        mock_ws = MagicMock()
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=mock_ws)
        mock_wb.__contains__ = Mock(side_effect=lambda x: x == "Sheet1")

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "set_cell", "params": {"sheet": "Sheet1", "cell": "A1", "value": 42}}]
                )

        assert result["success"] is True
        assert result["operations_applied"] == 1
        mock_wb.save.assert_called_once_with("/out.xlsx")

    def test_add_row(self):
        """Test adding a row."""
        mock_ws = Mock()
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=mock_ws)
        mock_wb.__contains__ = Mock(side_effect=lambda x: x == "Sheet1")

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "add_row", "params": {"values": [1, 2, 3]}}]
                )

        assert result["success"] is True
        mock_ws.append.assert_called_once_with([1, 2, 3])

    def test_add_sheet(self):
        """Test adding a new sheet."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "add_sheet", "params": {"name": "NewSheet"}}]
                )

        assert result["success"] is True
        mock_wb.create_sheet.assert_called_once_with(title="NewSheet")

    def test_delete_sheet(self):
        """Test deleting a sheet."""
        mock_wb = MagicMock()
        mock_wb.sheetnames = ["Sheet1", "Sheet2"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "delete_sheet", "params": {"name": "Sheet2"}}]
                )

        assert result["success"] is True
        assert result["operations_applied"] == 1

    def test_sheet_not_found_error(self):
        """Test error when setting cell on non-existent sheet."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__contains__ = Mock(return_value=False)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx(
                        "/in.xlsx", "/out.xlsx",
                        [{"action": "set_cell", "params": {"sheet": "Missing", "cell": "A1", "value": 1}}]
                    )

        assert "not found" in str(exc_info.value)

    def test_modify_xlsx_exception(self):
        """Test exception handling."""
        mock_openpyxl = Mock(load_workbook=Mock(side_effect=Exception("Cannot open")))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])

        assert "Failed to modify XLSX" in str(exc_info.value)


# ===========================================================================
# Comprehensive corner-case tests for Office document tools
# ===========================================================================

class TestReadDocxCornerCases:
    """Corner-case tests for the read_docx function."""

    def _setup_docx_mock(self, paragraphs_text, tables=None):
        mock_doc = Mock()
        mock_paras = [Mock(text=t) for t in paragraphs_text]
        mock_doc.paragraphs = mock_paras
        mock_doc.tables = tables or []
        return Mock(Document=Mock(return_value=mock_doc))

    def test_empty_document_no_paragraphs(self):
        """DOCX with zero paragraphs."""
        mock_docx = self._setup_docx_mock([])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/empty.docx")

        assert result["text"] == ""
        assert result["paragraph_count"] == 0
        assert result["table_count"] == 0

    def test_all_whitespace_paragraphs(self):
        """DOCX with only whitespace paragraphs produces empty text."""
        mock_docx = self._setup_docx_mock(["  ", "\t", "\n", "   \n  "])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/whitespace.docx", extract="text")

        assert result["text"] == ""
        assert result["paragraph_count"] == 4

    def test_text_truncation_at_limit(self):
        """Text exceeding PROCESSING_LIMITS['text_chars'] is truncated."""
        long_text = "A" * 500
        mock_docx = self._setup_docx_mock([long_text])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'), \
                 patch.dict(documents.PROCESSING_LIMITS, {'text_chars': 100}):
                result = documents.read_docx("/path/to/long.docx", extract="text")

        assert len(result["text"]) < 500
        assert "[Content truncated...]" in result["text"]

    def test_multiple_tables(self):
        """DOCX with multiple tables."""
        def make_table(rows_data):
            table = Mock()
            rows = []
            for row_cells in rows_data:
                row = Mock()
                row.cells = [Mock(text=c) for c in row_cells]
                rows.append(row)
            table.rows = rows
            return table

        t1 = make_table([["A", "B"], ["C", "D"]])
        t2 = make_table([["X", "Y", "Z"]])

        mock_docx = self._setup_docx_mock(["Text"], tables=[t1, t2])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/multi_table.docx", extract="tables")

        assert result["table_count"] == 2
        assert result["tables"][0] == [["A", "B"], ["C", "D"]]
        assert result["tables"][1] == [["X", "Y", "Z"]]

    def test_unicode_content(self):
        """DOCX with unicode characters."""
        mock_docx = self._setup_docx_mock(["日本語テスト", "Ñoño español", " Emoji 🎉"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/unicode.docx", extract="text")

        assert "日本語テスト" in result["text"]
        assert "Ñoño" in result["text"]
        assert "🎉" in result["text"]

    def test_validation_error_propagates(self):
        """ToolError from validation is not wrapped."""
        mock_docx = self._setup_docx_mock(["Text"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing',
                              side_effect=ToolError("File too large (600MB)")):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_docx("/path/to/huge.docx")

        assert "File too large" in str(exc_info.value)
        assert "Failed to read DOCX" not in str(exc_info.value)

    def test_empty_table_rows(self):
        """Table with zero rows."""
        table = Mock()
        table.rows = []
        mock_docx = self._setup_docx_mock(["Text"], tables=[table])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/empty_table.docx", extract="tables")

        assert result["table_count"] == 1
        assert result["tables"][0] == []


class TestModifyDocxCornerCases:
    """Corner-case tests for the modify_docx function."""

    def _setup_docx_mock(self, paragraphs=None, tables=None):
        mock_doc = Mock()
        if paragraphs is None:
            paragraphs = [{"text": "Hello World", "runs": [{"text": "Hello World"}]}]
        paras = []
        for p_data in paragraphs:
            para = Mock()
            para.text = p_data["text"]
            runs = []
            for r_data in p_data.get("runs", []):
                run = Mock()
                run.text = r_data["text"]
                runs.append(run)
            para.runs = runs
            paras.append(para)
        mock_doc.paragraphs = paras
        mock_doc.tables = tables or []
        return Mock(Document=Mock(return_value=mock_doc)), mock_doc

    def test_empty_operations_list(self):
        """Empty operations list still saves the file."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx("/in.docx", "/out.docx", [])

        assert result["success"] is True
        assert result["operations_applied"] == 0
        mock_doc.save.assert_called_once()

    def test_replace_text_no_match(self):
        """Replace text that doesn't exist still counts as applied."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "replace_text", "params": {"old": "NONEXISTENT", "new": "X"}}]
                )

        assert result["success"] is True
        assert result["operations_applied"] == 1

    def test_multiple_operations_sequential(self):
        """Multiple operations applied in order."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [
                        {"action": "replace_text", "params": {"old": "Hello", "new": "Hi"}},
                        {"action": "add_paragraph", "params": {"text": "New text"}},
                        {"action": "add_paragraph", "params": {"text": "More text", "style": "Heading1"}},
                    ]
                )

        assert result["operations_applied"] == 3

    def test_add_paragraph_with_style(self):
        """Add paragraph with explicit style."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "add_paragraph", "params": {"text": "Title", "style": "Heading1"}}]
                )

        mock_doc.add_paragraph.assert_called_once_with("Title", style="Heading1")

    def test_update_table_cell_valid(self):
        """Update a cell in a valid table."""
        mock_cell = Mock()
        mock_row = Mock()
        mock_row.cells = [mock_cell, Mock()]
        mock_table = Mock()
        mock_table.rows = [mock_row, Mock()]

        mock_docx, mock_doc = self._setup_docx_mock(tables=[mock_table])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "update_table_cell", "params": {"table": 0, "row": 0, "col": 0, "text": "Updated"}}]
                )

        assert result["operations_applied"] == 1
        assert mock_cell.text == "Updated"

    def test_update_table_cell_out_of_bounds_table_index(self):
        """Table index beyond available tables — not applied."""
        mock_docx, mock_doc = self._setup_docx_mock(tables=[])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "update_table_cell", "params": {"table": 5, "row": 0, "col": 0, "text": "X"}}]
                )

        assert result["operations_applied"] == 0

    def test_update_table_cell_out_of_bounds_row(self):
        """Row index beyond available rows — not applied."""
        mock_table = Mock()
        mock_table.rows = [Mock()]
        mock_table.rows[0].cells = [Mock()]

        mock_docx, mock_doc = self._setup_docx_mock(tables=[mock_table])

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "update_table_cell", "params": {"table": 0, "row": 99, "col": 0, "text": "X"}}]
                )

        assert result["operations_applied"] == 0

    def test_unknown_action_ignored(self):
        """Unknown action names are silently skipped."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "delete_everything", "params": {}}]
                )

        assert result["operations_applied"] == 0
        assert result["success"] is True

    def test_output_dir_created(self):
        """Output directory is created if it doesn't exist."""
        mock_docx, _ = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs') as mock_makedirs:
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.modify_docx("/in.docx", "/some/deep/dir/out.docx", [])

        mock_makedirs.assert_called_once_with("/some/deep/dir", exist_ok=True)

    def test_output_at_root_no_makedirs(self):
        """Output path with no directory component doesn't call makedirs."""
        mock_docx, _ = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs') as mock_makedirs:
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.modify_docx("/in.docx", "out.docx", [])

        mock_makedirs.assert_not_called()

    def test_validation_error_not_wrapped(self):
        """ToolError from validation is not double-wrapped."""
        mock_docx, _ = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing',
                              side_effect=ToolError("Too large")):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_docx("/in.docx", "/out.docx", [])

        assert "Too large" in str(exc_info.value)
        assert "Failed to modify DOCX" not in str(exc_info.value)

    def test_replace_text_across_multiple_runs(self):
        """Replace text that spans multiple paragraphs."""
        paragraphs = [
            {"text": "Hello World", "runs": [{"text": "Hello World"}]},
            {"text": "Hello Again", "runs": [{"text": "Hello Again"}]},
        ]
        mock_docx, mock_doc = self._setup_docx_mock(paragraphs=paragraphs)

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "replace_text", "params": {"old": "Hello", "new": "Hi"}}]
                )

        # Both runs should be modified
        assert mock_doc.paragraphs[0].runs[0].text == "Hi World"
        assert mock_doc.paragraphs[1].runs[0].text == "Hi Again"

    def test_missing_params_defaults(self):
        """Operations with missing params key use empty dict."""
        mock_docx, mock_doc = self._setup_docx_mock()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "add_paragraph"}]
                )

        assert result["success"] is True
        mock_doc.add_paragraph.assert_called_once_with("", style=None)


class TestReadPptxCornerCases:
    """Corner-case tests for the read_pptx function."""

    def _make_shape(self, text="", has_text_frame=True, has_table=False, name="Shape"):
        shape = Mock()
        shape.name = name
        shape.has_text_frame = has_text_frame
        shape.has_table = has_table
        if has_text_frame:
            para = Mock()
            para.text = text
            shape.text_frame = Mock()
            shape.text_frame.paragraphs = [para]
        if has_table:
            shape.table = Mock()
        return shape

    def _make_slide(self, texts=None, notes="", shapes_raw=None):
        slide = Mock()
        if shapes_raw is not None:
            slide.shapes = shapes_raw
        else:
            shapes = []
            for t in (texts or []):
                shapes.append(self._make_shape(text=t))
            slide.shapes = shapes
        slide.has_notes_slide = bool(notes)
        if notes:
            slide.notes_slide = Mock()
            slide.notes_slide.notes_text_frame = Mock()
            slide.notes_slide.notes_text_frame.text = notes
        return slide

    def test_empty_presentation(self):
        """PPTX with zero slides."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/empty.pptx")

        assert result["slide_count"] == 0
        assert result["slides"] == []
        assert result["notes"] == []

    def test_too_many_slides_raises(self):
        """Presentation exceeding pptx_slides limit raises ToolError."""
        mock_prs = Mock()
        mock_prs.slides = [Mock() for _ in range(600)]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'), \
                 patch.dict(documents.PROCESSING_LIMITS, {'pptx_slides': 500}):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_pptx("/path/to/huge.pptx")

        assert "too many slides" in str(exc_info.value).lower()

    def test_slide_with_no_text_shapes(self):
        """Slide with shapes that have no text frames (images, etc.)."""
        image_shape = self._make_shape(has_text_frame=False, name="Picture1")
        slide = self._make_slide(shapes_raw=[image_shape])

        mock_prs = Mock()
        mock_prs.slides = [slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/images.pptx")

        assert result["slides"][0]["text"] == ""
        assert result["slides"][0]["shapes"] == []

    def test_slide_with_empty_text_frame(self):
        """Shape with text frame but only whitespace."""
        empty_shape = self._make_shape(text="   ", name="EmptyBox")
        slide = self._make_slide(shapes_raw=[empty_shape])

        mock_prs = Mock()
        mock_prs.slides = [slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/empty_text.pptx")

        # Whitespace-only text should be filtered
        assert result["slides"][0]["shapes"] == []

    def test_slide_with_table_shape(self):
        """Slide with a table shape extracts table data."""
        table_shape = self._make_shape(has_text_frame=False, has_table=True, name="Table1")
        mock_cell1 = Mock(text="R1C1")
        mock_cell2 = Mock(text="R1C2")
        mock_row = Mock()
        mock_row.cells = [mock_cell1, mock_cell2]
        table_shape.table.rows = [mock_row]

        slide = self._make_slide(shapes_raw=[table_shape])
        mock_prs = Mock()
        mock_prs.slides = [slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/table.pptx")

        table_shapes = [s for s in result["slides"][0]["shapes"] if "table" in s]
        assert len(table_shapes) == 1
        assert table_shapes[0]["table"] == [["R1C1", "R1C2"]]

    def test_notes_only_extract(self):
        """Extract only notes."""
        mock_prs = Mock()
        mock_prs.slides = [
            self._make_slide(texts=["Title"], notes="Note 1"),
            self._make_slide(texts=["Title2"]),
            self._make_slide(texts=["Title3"], notes="Note 3"),
        ]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/notes.pptx", extract="notes")

        assert "notes" in result
        assert "slides" not in result
        assert "text" not in result
        # Only slides with notes should appear
        assert len(result["notes"]) == 2
        assert result["notes"][0]["slide"] == 1
        assert result["notes"][1]["slide"] == 3

    def test_slides_only_extract(self):
        """Extract only slides data (no text or notes in result)."""
        mock_prs = Mock()
        mock_prs.slides = [self._make_slide(texts=["Slide text"])]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="slides")

        assert "slides" in result
        assert "text" not in result
        assert "notes" not in result

    def test_text_truncation(self):
        """Text exceeding limit is truncated."""
        long_text = "X" * 500
        mock_prs = Mock()
        mock_prs.slides = [self._make_slide(texts=[long_text])]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'), \
                 patch.dict(documents.PROCESSING_LIMITS, {'text_chars': 100}):
                result = documents.read_pptx("/path/to/long.pptx", extract="text")

        assert "[Content truncated...]" in result["text"]

    def test_validation_error_propagates(self):
        """ToolError from validation is not wrapped."""
        mock_pptx = Mock(Presentation=Mock(return_value=Mock()))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing',
                              side_effect=ToolError("Too large")):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_pptx("/path/to/huge.pptx")

        assert "Too large" in str(exc_info.value)
        assert "Failed to read PPTX" not in str(exc_info.value)

    def test_slide_without_notes_slide(self):
        """Slide where has_notes_slide is False."""
        slide = self._make_slide(texts=["Content"])
        slide.has_notes_slide = False

        mock_prs = Mock()
        mock_prs.slides = [slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/no_notes.pptx")

        assert result["slides"][0]["notes"] == ""
        assert result["notes"] == []


class TestModifyPptxCornerCases:
    """Corner-case tests for the modify_pptx function."""

    def _make_prs(self, slides_data=None, num_layouts=2):
        mock_prs = Mock()
        slides = []
        for sd in (slides_data or []):
            slide = Mock()
            shapes = []
            for shape_info in sd.get("shapes", []):
                shape = Mock()
                shape.name = shape_info.get("name", "Shape")
                shape.has_text_frame = shape_info.get("has_text_frame", True)
                if shape.has_text_frame:
                    runs = []
                    for r in shape_info.get("runs", [shape_info.get("text", "")]):
                        run = Mock()
                        run.text = r
                        runs.append(run)
                    para = Mock()
                    para.runs = runs
                    para.text = "".join(r.text for r in runs)
                    shape.text_frame = Mock()
                    shape.text_frame.paragraphs = [para]
                shapes.append(shape)
            slide.shapes = shapes
            slides.append(slide)

        mock_prs.slides = slides
        mock_prs.slide_layouts = [Mock() for _ in range(num_layouts)]
        return mock_prs

    def test_empty_operations(self):
        """Empty operations still saves."""
        mock_prs = self._make_prs([{"shapes": [{"text": "Hi"}]}])
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx("/in.pptx", "/out.pptx", [])

        assert result["success"] is True
        assert result["operations_applied"] == 0
        mock_prs.save.assert_called_once()

    def test_replace_text_across_multiple_slides(self):
        """Replace text finds matches across all slides."""
        mock_prs = self._make_prs([
            {"shapes": [{"text": "Old title", "runs": ["Old title"]}]},
            {"shapes": [{"text": "Another Old line", "runs": ["Another Old line"]}]},
        ])
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "replace_text", "params": {"old": "Old", "new": "New"}}]
                )

        assert result["operations_applied"] == 1
        # Both slides' runs should be modified
        assert mock_prs.slides[0].shapes[0].text_frame.paragraphs[0].runs[0].text == "New title"
        assert mock_prs.slides[1].shapes[0].text_frame.paragraphs[0].runs[0].text == "Another New line"

    def test_update_slide_text_out_of_range(self):
        """update_slide_text with slide index beyond range — not applied."""
        mock_prs = self._make_prs([{"shapes": [{"name": "Title", "text": "Hi"}]}])
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "update_slide_text", "params": {"slide": 99, "shape_name": "Title", "text": "New"}}]
                )

        assert result["operations_applied"] == 0

    def test_update_slide_text_shape_not_found(self):
        """update_slide_text with wrong shape name — not applied."""
        mock_prs = self._make_prs([{"shapes": [{"name": "Title1", "text": "Hi"}]}])
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "update_slide_text", "params": {"slide": 1, "shape_name": "WrongName", "text": "New"}}]
                )

        assert result["operations_applied"] == 0

    def test_set_notes_on_slide(self):
        """Set speaker notes on a valid slide."""
        slide = Mock()
        slide.shapes = []
        notes_slide = Mock()
        notes_slide.notes_text_frame = Mock()
        slide.notes_slide = notes_slide

        mock_prs = Mock()
        mock_prs.slides = [slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "set_notes", "params": {"slide": 1, "text": "My speaker notes"}}]
                )

        assert result["operations_applied"] == 1
        assert notes_slide.notes_text_frame.text == "My speaker notes"

    def test_set_notes_slide_out_of_range(self):
        """set_notes with out-of-range slide — not applied."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "set_notes", "params": {"slide": 5, "text": "Notes"}}]
                )

        assert result["operations_applied"] == 0

    def test_add_slide_layout_index_clamped(self):
        """Layout index beyond available layouts is clamped."""
        mock_prs = Mock()
        mock_prs.slides = Mock()
        mock_prs.slides.__iter__ = Mock(return_value=iter([]))
        mock_prs.slide_layouts = [Mock(), Mock()]  # Only 2 layouts

        mock_new_slide = Mock()
        mock_new_slide.placeholders = []
        mock_prs.slides.add_slide = Mock(return_value=mock_new_slide)

        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "add_slide", "params": {"layout_index": 999}}]
                )

        assert result["operations_applied"] == 1
        # Should use last layout (index 1) since 999 > 1
        mock_prs.slides.add_slide.assert_called_once_with(mock_prs.slide_layouts[1])

    def test_unknown_action_ignored(self):
        """Unknown action names are silently skipped."""
        mock_prs = self._make_prs([])
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "unknown_action", "params": {}}]
                )

        assert result["operations_applied"] == 0
        assert result["success"] is True

    def test_validation_error_not_wrapped(self):
        """ToolError from validation propagates directly."""
        mock_pptx = Mock(Presentation=Mock())

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing',
                              side_effect=ToolError("Too large")):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_pptx("/in.pptx", "/out.pptx", [])

        assert "Too large" in str(exc_info.value)
        assert "Failed to modify PPTX" not in str(exc_info.value)


class TestReadXlsxCornerCases:
    """Corner-case tests for the read_xlsx function."""

    def _make_cell(self, value, data_type='n'):
        cell = Mock()
        cell.value = value
        cell.data_type = data_type
        return cell

    def _make_worksheet(self, rows_data, dimensions="A1:B2"):
        ws = Mock()
        ws.dimensions = dimensions
        rows = [[self._make_cell(v) for v in row] for row in rows_data]
        ws.iter_rows = Mock(return_value=iter(rows))
        ws.__getitem__ = Mock(return_value=iter(rows))
        return ws

    def test_empty_worksheet(self):
        """Sheet with no rows."""
        ws = self._make_worksheet([], dimensions="A1:A1")
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/empty.xlsx")

        assert result["sheets"]["Sheet1"]["row_count"] == 0
        assert result["sheets"]["Sheet1"]["rows"] == []

    def test_multiple_sheets(self):
        """Workbook with multiple sheets — all read by default."""
        ws1 = self._make_worksheet([["A"]])
        ws2 = self._make_worksheet([["B"]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Data", "Summary"]
        mock_wb.__getitem__ = Mock(side_effect=lambda name: ws1 if name == "Data" else ws2)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/multi.xlsx")

        assert result["sheet_count"] == 2
        assert "Data" in result["sheets"]
        assert "Summary" in result["sheets"]

    def test_sheet_by_numeric_index(self):
        """Select sheet by numeric index string."""
        ws = self._make_worksheet([["Data"]])
        mock_wb = Mock()
        mock_wb.sheetnames = ["First", "Second", "Third"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx", sheet="1")

        assert "Second" in result["sheets"]
        assert len(result["sheets"]) == 1

    def test_sheet_index_out_of_range(self):
        """Numeric sheet index beyond available sheets raises ToolError."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_xlsx("/path/to/test.xlsx", sheet="99")

        assert "out of range" in str(exc_info.value)

    def test_row_truncation_at_limit(self):
        """Rows exceeding xlsx_rows limit are truncated."""
        rows = [[f"val_{i}"] for i in range(10)]
        ws = self._make_worksheet(rows)
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'), \
                 patch.dict(documents.PROCESSING_LIMITS, {'xlsx_rows': 5}):
                result = documents.read_xlsx("/path/to/big.xlsx")

        sheet_data = result["sheets"]["Sheet1"]
        # Should have 5 data rows + 1 truncation marker
        assert sheet_data["row_count"] == 5
        assert "[Truncated" in str(sheet_data["rows"][-1])

    def test_cell_range_selection(self):
        """Reading with a specific cell range."""
        ws = Mock()
        ws.dimensions = "A1:D10"
        cell1 = self._make_cell("X")
        cell2 = self._make_cell("Y")
        ws.__getitem__ = Mock(return_value=[[cell1, cell2]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx", range="A1:B1")

        # Should use ws[range] instead of iter_rows
        ws.__getitem__.assert_called_with("A1:B1")

    def test_formula_cells(self):
        """Formula extraction mode."""
        formula_cell = self._make_cell("=SUM(A1:A10)", data_type='f')
        value_cell = self._make_cell(42)
        ws = Mock()
        ws.dimensions = "A1:B1"
        ws.iter_rows = Mock(return_value=iter([[formula_cell, value_cell]]))

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/formulas.xlsx", extract="formulas")

        assert result["sheets"]["Sheet1"]["rows"][0][0] == "=SUM(A1:A10)"

    def test_none_cell_values(self):
        """Cells with None values (empty cells)."""
        ws = self._make_worksheet([[None, "Data", None]])
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/sparse.xlsx")

        assert result["sheets"]["Sheet1"]["rows"][0] == [None, "Data", None]

    def test_validation_error_propagates(self):
        """ToolError from validation is not wrapped."""
        mock_openpyxl = Mock()

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing',
                              side_effect=ToolError("Too large")):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_xlsx("/path/to/huge.xlsx")

        assert "Too large" in str(exc_info.value)
        assert "Failed to read XLSX" not in str(exc_info.value)

    def test_workbook_closed_after_read(self):
        """Workbook is closed after reading."""
        ws = self._make_worksheet([["Data"]])
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.read_xlsx("/path/to/test.xlsx")

        mock_wb.close.assert_called_once()


class TestModifyXlsxCornerCases:
    """Corner-case tests for the modify_xlsx function."""

    def _make_wb(self, sheets=None):
        mock_wb = MagicMock()
        sheets = sheets or ["Sheet1"]
        mock_wb.sheetnames = sheets
        ws_dict = {name: MagicMock() for name in sheets}
        mock_wb.__getitem__ = Mock(side_effect=lambda name: ws_dict[name])
        mock_wb.__contains__ = Mock(side_effect=lambda name: name in sheets)
        return mock_wb, ws_dict

    def test_empty_operations(self):
        """Empty operations still saves and closes."""
        mock_wb, _ = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])

        assert result["success"] is True
        assert result["operations_applied"] == 0
        mock_wb.save.assert_called_once()
        mock_wb.close.assert_called_once()

    def test_set_formula(self):
        """Set a formula in a cell."""
        mock_wb, ws_dict = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "set_formula", "params": {"cell": "B2", "formula": "=SUM(A1:A10)"}}]
                )

        assert result["operations_applied"] == 1
        ws_dict["Sheet1"].__setitem__.assert_called_with("B2", "=SUM(A1:A10)")

    def test_default_sheet_when_not_specified(self):
        """When sheet is not in params, use first sheet."""
        mock_wb, ws_dict = self._make_wb(["Alpha", "Beta"])
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "set_cell", "params": {"cell": "A1", "value": "test"}}]
                )

        assert result["operations_applied"] == 1
        ws_dict["Alpha"].__setitem__.assert_called_with("A1", "test")

    def test_multiple_operations_mixed(self):
        """Multiple different operations in sequence."""
        mock_wb, ws_dict = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [
                        {"action": "set_cell", "params": {"cell": "A1", "value": "Name"}},
                        {"action": "set_cell", "params": {"cell": "B1", "value": "Age"}},
                        {"action": "add_row", "params": {"values": ["Alice", 30]}},
                        {"action": "add_row", "params": {"values": ["Bob", 25]}},
                        {"action": "set_formula", "params": {"cell": "C1", "formula": "=COUNT(B:B)"}},
                    ]
                )

        assert result["operations_applied"] == 5

    def test_delete_nonexistent_sheet_not_counted(self):
        """Deleting a sheet that doesn't exist is not counted."""
        mock_wb, _ = self._make_wb(["Sheet1"])
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "delete_sheet", "params": {"name": "NonExistent"}}]
                )

        assert result["operations_applied"] == 0

    def test_add_row_empty_values(self):
        """Add row with empty values list."""
        mock_wb, ws_dict = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "add_row", "params": {"values": []}}]
                )

        assert result["operations_applied"] == 1
        ws_dict["Sheet1"].append.assert_called_once_with([])

    def test_add_row_no_values_key(self):
        """Add row with missing values key defaults to empty list."""
        mock_wb, ws_dict = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "add_row", "params": {}}]
                )

        assert result["operations_applied"] == 1
        ws_dict["Sheet1"].append.assert_called_once_with([])

    def test_set_cell_various_types(self):
        """Set cells with various value types (int, float, string, None, bool)."""
        mock_wb, ws_dict = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [
                        {"action": "set_cell", "params": {"cell": "A1", "value": 42}},
                        {"action": "set_cell", "params": {"cell": "A2", "value": 3.14}},
                        {"action": "set_cell", "params": {"cell": "A3", "value": "text"}},
                        {"action": "set_cell", "params": {"cell": "A4", "value": None}},
                        {"action": "set_cell", "params": {"cell": "A5", "value": True}},
                    ]
                )

        assert result["operations_applied"] == 5

    def test_unknown_action_ignored(self):
        """Unknown action is silently ignored."""
        mock_wb, _ = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "pivot_table", "params": {}}]
                )

        assert result["operations_applied"] == 0
        assert result["success"] is True

    def test_set_formula_sheet_not_found(self):
        """set_formula on non-existent sheet raises ToolError."""
        mock_wb, _ = self._make_wb(["Sheet1"])
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx(
                        "/in.xlsx", "/out.xlsx",
                        [{"action": "set_formula", "params": {"sheet": "Missing", "cell": "A1", "formula": "=1"}}]
                    )

        assert "not found" in str(exc_info.value)

    def test_add_row_sheet_not_found(self):
        """add_row on non-existent sheet raises ToolError."""
        mock_wb, _ = self._make_wb(["Sheet1"])
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx(
                        "/in.xlsx", "/out.xlsx",
                        [{"action": "add_row", "params": {"sheet": "Missing", "values": [1]}}]
                    )

        assert "not found" in str(exc_info.value)

    def test_output_dir_created(self):
        """Output directory is created."""
        mock_wb, _ = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs') as mock_makedirs:
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.modify_xlsx("/in.xlsx", "/deep/nested/out.xlsx", [])

        mock_makedirs.assert_called_once_with("/deep/nested", exist_ok=True)

    def test_validation_error_not_wrapped(self):
        """ToolError from validation propagates directly."""
        mock_openpyxl = Mock()

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing',
                              side_effect=ToolError("Too large")):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])

        assert "Too large" in str(exc_info.value)
        assert "Failed to modify XLSX" not in str(exc_info.value)

    def test_add_sheet_default_name(self):
        """Add sheet with no name uses default."""
        mock_wb, _ = self._make_wb()
        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "add_sheet", "params": {}}]
                )

        assert result["operations_applied"] == 1
        mock_wb.create_sheet.assert_called_once_with(title="Sheet")


# ===========================================================================
# Extended corner-case tests for read_file
# ===========================================================================

class TestReadFileCornerCases:
    """Extended corner-case tests for the read_file function."""

    def test_read_whitespace_only_file(self):
        """Test reading a file that contains only whitespace."""
        content = "   \t\n  \n\n   "

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=len(content)), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/whitespace.txt")

        assert result["content"] == content
        assert result["size_bytes"] == len(content)

    def test_read_newlines_only_file(self):
        """Test reading a file that contains only newlines."""
        content = "\n\n\n\n\n"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=5), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/newlines.txt")

        assert result["content"] == content
        assert result["content"].count("\n") == 5

    def test_read_truncation_boundary_100001(self):
        """Test truncation at exactly 100001 chars (one over limit)."""
        content = "x" * 100001

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=100001), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/boundary.txt")

        assert result["content"].endswith("[Content truncated...]")
        assert result["content"][:100000] == "x" * 100000

    def test_read_mixed_line_endings(self):
        """Test reading file with mixed line endings (\r\n, \r, \n)."""
        content = "line1\r\nline2\rline3\nline4"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=len(content)), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/mixed_eol.txt")

        # Content should be preserved as-is (open in text mode may normalize)
        assert "line1" in result["content"]
        assert "line4" in result["content"]

    def test_read_very_long_single_line(self):
        """Test reading a file with one very long line and no newlines."""
        content = "a" * 50000

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=50000), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/longline.txt")

        assert len(result["content"]) == 50000
        assert "\n" not in result["content"]

    def test_read_file_getsize_raises_oserror(self):
        """Test that OSError from os.path.getsize is wrapped in ToolError."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', side_effect=OSError("No such file")):

            with pytest.raises(ToolError) as exc_info:
                documents.read_file("/path/to/gone.txt")

        assert "Failed to read file" in str(exc_info.value)

    def test_read_file_validation_toolerror_reraises(self):
        """Test that ToolError from validation is re-raised, not wrapped."""
        with patch.object(documents, 'validate_file_for_processing',
                          side_effect=ToolError("File too large: 500MB")):

            with pytest.raises(ToolError) as exc_info:
                documents.read_file("/path/to/huge.bin")

        # Should be the original error, not "Failed to read file: ..."
        assert "File too large: 500MB" == str(exc_info.value)

    def test_read_file_result_keys(self):
        """Test that result dict contains exactly the expected keys."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=4), \
             patch('builtins.open', mock_open(read_data="test")):

            result = documents.read_file("/path/to/test.txt")

        assert set(result.keys()) == {"path", "content", "size_bytes"}

    def test_read_file_size_reflects_original_not_truncated(self):
        """Test that size_bytes reflects the original file size, not truncated content."""
        content = "x" * 200000

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=200000), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/big.txt")

        # size_bytes should be the actual file size on disk
        assert result["size_bytes"] == 200000
        # content should be truncated
        assert result["content"].endswith("[Content truncated...]")

    def test_read_file_unicode_replacement_chars(self):
        """Test that invalid bytes are replaced with U+FFFD."""
        # This simulates what errors='replace' produces
        content = "hello\ufffdworld\ufffd"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=12), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/broken_encoding.txt")

        assert "\ufffd" in result["content"]

    def test_read_file_open_uses_replace_error_mode(self):
        """Test that open is called with errors='replace'."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=4), \
             patch('builtins.open', mock_open(read_data="test")) as m:

            documents.read_file("/path/to/file.txt")

        m.assert_called_once_with("/path/to/file.txt", 'r', encoding='utf-8', errors='replace')

    def test_read_file_tab_characters_preserved(self):
        """Test that tab characters are preserved."""
        content = "col1\tcol2\tcol3\nval1\tval2\tval3"

        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=len(content)), \
             patch('builtins.open', mock_open(read_data=content)):

            result = documents.read_file("/path/to/tsv.txt")

        assert "\t" in result["content"]
        assert result["content"].count("\t") == 4

    def test_read_file_single_character(self):
        """Test reading a file with a single character."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=1), \
             patch('builtins.open', mock_open(read_data="X")):

            result = documents.read_file("/path/to/single.txt")

        assert result["content"] == "X"
        assert result["size_bytes"] == 1

    def test_read_file_permission_error(self):
        """Test PermissionError is wrapped in ToolError."""
        with patch.object(documents, 'validate_file_for_processing'), \
             patch('os.path.getsize', return_value=100), \
             patch('builtins.open', side_effect=PermissionError("Access denied")):

            with pytest.raises(ToolError) as exc_info:
                documents.read_file("/root/secret.txt")

        assert "Failed to read file" in str(exc_info.value)
        assert "Access denied" in str(exc_info.value)


# ===========================================================================
# Extended corner-case tests for write_file
# ===========================================================================

class TestWriteFileCornerCases:
    """Extended corner-case tests for the write_file function."""

    def test_write_file_makedirs_failure(self):
        """Test that makedirs failure is wrapped in ToolError."""
        with patch('os.makedirs', side_effect=OSError("Permission denied")):

            with pytest.raises(ToolError) as exc_info:
                documents.write_file("/root/protected/file.txt", "content")

        assert "Failed to write file" in str(exc_info.value)

    def test_write_file_permission_error(self):
        """Test PermissionError on file open is wrapped in ToolError."""
        with patch('os.makedirs'), \
             patch('builtins.open', side_effect=PermissionError("Read-only filesystem")):

            with pytest.raises(ToolError) as exc_info:
                documents.write_file("/path/to/readonly.txt", "content")

        assert "Failed to write file" in str(exc_info.value)
        assert "Read-only filesystem" in str(exc_info.value)

    def test_write_file_preserves_newlines(self):
        """Test that various newline characters are preserved."""
        content = "line1\nline2\nline3\n"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            documents.write_file("/path/to/out.txt", content)

        assert "".join(written) == content
        assert "".join(written).count("\n") == 3

    def test_write_file_preserves_tabs(self):
        """Test that tab characters are preserved."""
        content = "col1\tcol2\tcol3"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            documents.write_file("/path/to/out.tsv", content)

        assert "\t" in "".join(written)

    def test_write_file_content_one_over_limit(self):
        """Test content at exactly 1_000_001 chars is rejected."""
        content = "x" * 1_000_001

        with pytest.raises(ToolError) as exc_info:
            documents.write_file("/path/to/file.txt", content)

        assert "Content too large" in str(exc_info.value)

    def test_write_file_content_two_over_limit(self):
        """Test content well over limit includes size info in error."""
        content = "x" * 2_000_000

        with pytest.raises(ToolError) as exc_info:
            documents.write_file("/path/to/file.txt", content)

        assert "2000000" in str(exc_info.value)
        assert "1000000" in str(exc_info.value)

    def test_write_file_getsize_error_after_write(self):
        """Test OSError from os.path.getsize after successful write."""
        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', side_effect=OSError("Stat failed")):

            with pytest.raises(ToolError) as exc_info:
                documents.write_file("/path/to/out.txt", "content")

        assert "Failed to write file" in str(exc_info.value)

    def test_write_file_result_keys(self):
        """Test that result dict contains exactly the expected keys."""
        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=5):

            result = documents.write_file("/path/to/file.txt", "hello")

        assert set(result.keys()) == {"output_path", "success", "size_bytes"}

    def test_write_file_special_chars_in_filename(self):
        """Test writing to a path with special characters in filename."""
        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()) as m, \
             patch('os.path.getsize', return_value=5):

            result = documents.write_file("/path/to/my file (1).txt", "hello")

        assert result["output_path"] == "/path/to/my file (1).txt"
        m.assert_called_with("/path/to/my file (1).txt", 'w', encoding='utf-8')

    def test_write_file_json_content(self):
        """Test writing JSON content (common use case)."""
        content = '{"key": "value", "items": [1, 2, 3]}'
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            result = documents.write_file("/path/to/data.json", content)

        assert result["success"] is True
        assert "".join(written) == content

    def test_write_file_html_content(self):
        """Test writing HTML content."""
        content = "<html><body><h1>Hello</h1></body></html>"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            result = documents.write_file("/path/to/page.html", content)

        assert result["success"] is True
        assert "".join(written) == content

    def test_write_file_large_content_just_under_limit(self):
        """Test writing content at 999_999 chars (just under 1M limit)."""
        content = "a" * 999_999

        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()), \
             patch('os.path.getsize', return_value=999_999):

            result = documents.write_file("/path/to/big.txt", content)

        assert result["success"] is True

    def test_write_file_open_uses_utf8_encoding(self):
        """Test that open is called with encoding='utf-8'."""
        with patch('os.makedirs'), \
             patch('builtins.open', mock_open()) as m, \
             patch('os.path.getsize', return_value=5):

            documents.write_file("/path/to/out.txt", "hello")

        m.assert_called_with("/path/to/out.txt", 'w', encoding='utf-8')

    def test_write_file_multiline_markdown(self):
        """Test writing multi-line markdown content."""
        content = "# Title\n\n## Section 1\n\nParagraph text.\n\n- Item 1\n- Item 2\n"
        written = []

        m = mock_open()
        m.return_value.write = lambda data: written.append(data)

        with patch('os.makedirs'), \
             patch('builtins.open', m), \
             patch('os.path.getsize', return_value=len(content)):

            result = documents.write_file("/path/to/doc.md", content)

        assert result["success"] is True
        assert "".join(written) == content

    def test_write_file_size_check_before_io(self):
        """Test that content size is checked before any I/O operation."""
        large_content = "x" * 1_000_001

        # If size check happens first, open should never be called
        with patch('os.makedirs') as mock_mkdirs, \
             patch('builtins.open', mock_open()) as mock_file:

            with pytest.raises(ToolError):
                documents.write_file("/path/to/file.txt", large_content)

        # Neither makedirs nor open should have been called
        mock_mkdirs.assert_not_called()
        mock_file.assert_not_called()


# ===========================================================================
# Extended corner-case tests for read_docx
# ===========================================================================

class TestReadDocxCornerCases:
    """Extended corner-case tests for the read_docx function."""

    def _setup_docx_mock(self, paragraphs_text, tables=None):
        mock_doc = Mock()
        mock_paras = [Mock(text=t) for t in paragraphs_text]
        mock_doc.paragraphs = mock_paras
        mock_doc.tables = tables or []
        return Mock(Document=Mock(return_value=mock_doc))

    def test_read_docx_multiple_tables(self):
        """Test reading DOCX with multiple tables."""
        mock_cell_a = Mock(text="A1")
        mock_cell_b = Mock(text="B1")
        mock_row1 = Mock(cells=[mock_cell_a, mock_cell_b])
        mock_table1 = Mock(rows=[mock_row1])

        mock_cell_c = Mock(text="C1")
        mock_row2 = Mock(cells=[mock_cell_c])
        mock_table2 = Mock(rows=[mock_row2])

        mock_docx = self._setup_docx_mock(["Text"], tables=[mock_table1, mock_table2])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="tables")

        assert result["table_count"] == 2
        assert result["tables"][0][0] == ["A1", "B1"]
        assert result["tables"][1][0] == ["C1"]

    def test_read_docx_table_multiple_rows(self):
        """Test reading DOCX table with multiple rows and columns."""
        rows = []
        for i in range(3):
            cells = [Mock(text=f"R{i}C{j}") for j in range(4)]
            rows.append(Mock(cells=cells))
        mock_table = Mock(rows=rows)

        mock_docx = self._setup_docx_mock([], tables=[mock_table])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="tables")

        assert len(result["tables"][0]) == 3
        assert len(result["tables"][0][0]) == 4
        assert result["tables"][0][1][2] == "R1C2"

    def test_read_docx_empty_table(self):
        """Test reading DOCX with empty table (no rows)."""
        mock_table = Mock(rows=[])
        mock_docx = self._setup_docx_mock(["Text"], tables=[mock_table])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="all")

        assert result["table_count"] == 1
        assert result["tables"][0] == []

    def test_read_docx_zero_paragraphs(self):
        """Test reading DOCX with no paragraphs."""
        mock_docx = self._setup_docx_mock([])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/empty.docx", extract="text")

        assert result["text"] == ""
        assert result["paragraph_count"] == 0

    def test_read_docx_all_paragraphs_empty(self):
        """Test reading DOCX where all paragraphs are empty."""
        mock_docx = self._setup_docx_mock(["", "   ", "\t", "\n"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="text")

        assert result["text"] == ""
        assert result["paragraph_count"] == 4  # Counts all, not just non-empty

    def test_read_docx_paragraph_count_includes_empty(self):
        """Test that paragraph_count includes empty paragraphs."""
        mock_docx = self._setup_docx_mock(["A", "", "B", "", "C"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="text")

        assert result["paragraph_count"] == 5
        assert "A" in result["text"]
        assert "B" in result["text"]
        assert "C" in result["text"]

    def test_read_docx_text_with_special_chars(self):
        """Test reading DOCX with special characters in text."""
        mock_docx = self._setup_docx_mock(["Héllo & Wörld", "<tag>", "日本語"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="text")

        assert "Héllo & Wörld" in result["text"]
        assert "<tag>" in result["text"]
        assert "日本語" in result["text"]

    def test_read_docx_extract_all_has_both_keys(self):
        """Test that extract='all' includes both text and tables keys."""
        mock_docx = self._setup_docx_mock(["Text"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="all")

        assert "text" in result
        assert "tables" in result
        assert "paragraph_count" in result
        assert "table_count" in result

    def test_read_docx_tables_no_tables_present(self):
        """Test extract='tables' when no tables exist."""
        mock_docx = self._setup_docx_mock(["Paragraph only"])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/test.docx", extract="tables")

        assert result["table_count"] == 0
        assert result["tables"] == []
        assert "text" not in result

    def test_read_docx_text_truncation(self):
        """Test that very long DOCX text is truncated at PROCESSING_LIMITS."""
        long_text = "x" * 500_000
        mock_docx = self._setup_docx_mock([long_text, long_text, long_text])

        with patch.dict('sys.modules', {'docx': mock_docx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_docx("/path/to/huge.docx", extract="text")

        assert result["text"].endswith("[Content truncated...]")


# ===========================================================================
# Extended corner-case tests for modify_docx
# ===========================================================================

class TestModifyDocxCornerCases:
    """Extended corner-case tests for the modify_docx function."""

    def _setup_docx_with_table(self):
        mock_doc = Mock()
        mock_run = Mock(text="Hello")
        mock_para = Mock(text="Hello", runs=[mock_run])
        mock_doc.paragraphs = [mock_para]

        mock_cell = Mock()
        mock_cell.text = "original"
        mock_row = Mock(cells=[mock_cell, Mock()])
        mock_row.cells = [mock_cell, Mock()]
        mock_table = Mock(rows=[mock_row])
        mock_doc.tables = [mock_table]

        return Mock(Document=Mock(return_value=mock_doc)), mock_doc, mock_cell

    def test_update_table_cell(self):
        """Test updating a specific table cell."""
        mock_docx, mock_doc, mock_cell = self._setup_docx_with_table()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "update_table_cell", "params": {"table": 0, "row": 0, "col": 0, "text": "new"}}]
                )

        assert result["operations_applied"] == 1
        assert mock_cell.text == "new"

    def test_update_table_cell_out_of_bounds_table(self):
        """Test update_table_cell with table index out of bounds."""
        mock_docx, mock_doc, _ = self._setup_docx_with_table()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "update_table_cell", "params": {"table": 99, "row": 0, "col": 0, "text": "x"}}]
                )

        # Should silently skip if index out of bounds
        assert result["operations_applied"] == 0

    def test_update_table_cell_out_of_bounds_row(self):
        """Test update_table_cell with row index out of bounds."""
        mock_docx, mock_doc, _ = self._setup_docx_with_table()

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "update_table_cell", "params": {"table": 0, "row": 99, "col": 0, "text": "x"}}]
                )

        assert result["operations_applied"] == 0

    def test_replace_text_not_found(self):
        """Test replace_text when old text doesn't exist in any paragraph."""
        mock_docx = Mock(Document=Mock(return_value=Mock(
            paragraphs=[Mock(text="Hello World", runs=[Mock(text="Hello World")])],
            tables=[]
        )))

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "replace_text", "params": {"old": "NONEXISTENT", "new": "X"}}]
                )

        # replace_text always counts as applied even if no match found
        # (it iterates paragraphs, and the "applied" counter is outside the match check)
        assert result["success"] is True

    def test_multiple_operations(self):
        """Test applying multiple operations in one call."""
        mock_doc = Mock()
        mock_run = Mock(text="old text")
        mock_para = Mock(text="old text", runs=[mock_run])
        mock_doc.paragraphs = [mock_para]
        mock_doc.tables = []
        mock_docx = Mock(Document=Mock(return_value=mock_doc))

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [
                        {"action": "replace_text", "params": {"old": "old", "new": "new"}},
                        {"action": "add_paragraph", "params": {"text": "Added"}},
                        {"action": "add_paragraph", "params": {"text": "Also added", "style": "Heading1"}},
                    ]
                )

        assert result["operations_applied"] == 3

    def test_empty_operations_list(self):
        """Test modify_docx with empty operations list."""
        mock_doc = Mock(paragraphs=[], tables=[])
        mock_docx = Mock(Document=Mock(return_value=mock_doc))

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx("/in.docx", "/out.docx", [])

        assert result["success"] is True
        assert result["operations_applied"] == 0
        mock_doc.save.assert_called_once()

    def test_add_paragraph_with_style(self):
        """Test adding a paragraph with a specific style."""
        mock_doc = Mock(paragraphs=[], tables=[])
        mock_docx = Mock(Document=Mock(return_value=mock_doc))

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx(
                    "/in.docx", "/out.docx",
                    [{"action": "add_paragraph", "params": {"text": "Heading", "style": "Heading1"}}]
                )

        mock_doc.add_paragraph.assert_called_once_with("Heading", style="Heading1")

    def test_modify_docx_output_path_in_result(self):
        """Test that output_path key is in result."""
        mock_doc = Mock(paragraphs=[], tables=[])
        mock_docx = Mock(Document=Mock(return_value=mock_doc))

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_docx("/in.docx", "/out.docx", [])

        assert result["output_path"] == "/out.docx"

    def test_modify_docx_validation_called(self):
        """Test that validation is called on input path."""
        mock_doc = Mock(paragraphs=[], tables=[])
        mock_docx = Mock(Document=Mock(return_value=mock_doc))

        with patch.dict('sys.modules', {'docx': mock_docx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.modify_docx("/in.docx", "/out.docx", [])
                mock_validate.assert_called_once_with("/in.docx", 'document')


# ===========================================================================
# Extended corner-case tests for read_pptx
# ===========================================================================

class TestReadPptxCornerCases:
    """Extended corner-case tests for the read_pptx function."""

    def _make_shape(self, text="", has_text_frame=True, has_table=False, name="Shape"):
        shape = Mock()
        shape.name = name
        shape.has_text_frame = has_text_frame
        shape.has_table = has_table
        if has_text_frame:
            para = Mock(text=text)
            shape.text_frame = Mock(paragraphs=[para])
        return shape

    def _make_slide(self, texts=None, notes="", table_rows=None):
        slide = Mock()
        shapes = []
        for t in (texts or []):
            shapes.append(self._make_shape(text=t))
        if table_rows is not None:
            tbl_shape = self._make_shape(has_text_frame=False, has_table=True, name="Table")
            rows = []
            for row_data in table_rows:
                rows.append(Mock(cells=[Mock(text=c) for c in row_data]))
            tbl_shape.table = Mock(rows=rows)
            shapes.append(tbl_shape)
        slide.shapes = shapes
        slide.has_notes_slide = bool(notes)
        if notes:
            slide.notes_slide = Mock()
            slide.notes_slide.notes_text_frame = Mock(text=notes)
        return slide

    def test_read_pptx_slides_only(self):
        """Test extracting slides data only."""
        mock_prs = Mock()
        mock_prs.slides = [self._make_slide(texts=["Slide 1"])]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="slides")

        assert "slides" in result
        assert "text" not in result
        assert "notes" not in result

    def test_read_pptx_notes_only(self):
        """Test extracting notes only."""
        mock_prs = Mock()
        mock_prs.slides = [
            self._make_slide(texts=["S1"], notes="Note 1"),
            self._make_slide(texts=["S2"]),  # No notes
            self._make_slide(texts=["S3"], notes="Note 3"),
        ]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="notes")

        assert "notes" in result
        assert "text" not in result
        assert "slides" not in result
        # Only slides with notes should be included
        assert len(result["notes"]) == 2
        assert result["notes"][0]["notes"] == "Note 1"
        assert result["notes"][1]["notes"] == "Note 3"

    def test_read_pptx_slide_with_table(self):
        """Test reading slide with a table shape."""
        mock_prs = Mock()
        mock_prs.slides = [self._make_slide(texts=["Title"], table_rows=[["A", "B"], ["C", "D"]])]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="slides")

        # Should have table data in shapes
        slide_shapes = result["slides"][0]["shapes"]
        table_shapes = [s for s in slide_shapes if "table" in s]
        assert len(table_shapes) == 1
        assert table_shapes[0]["table"] == [["A", "B"], ["C", "D"]]

    def test_read_pptx_empty_presentation(self):
        """Test reading a presentation with zero slides."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/empty.pptx")

        assert result["slide_count"] == 0
        assert result["slides"] == []
        assert result["notes"] == []

    def test_read_pptx_too_many_slides(self):
        """Test that exceeding slide limit raises ToolError."""
        mock_prs = Mock()
        mock_prs.slides = [Mock() for _ in range(501)]  # Over 500 limit
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_pptx("/path/to/huge.pptx")

        assert "too many slides" in str(exc_info.value)

    def test_read_pptx_validation_called(self):
        """Test that validation is called."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.read_pptx("/path/to/test.pptx")
                mock_validate.assert_called_once_with("/path/to/test.pptx", 'document')

    def test_read_pptx_slide_with_no_text_shapes(self):
        """Test slide containing only non-text shapes."""
        shape = Mock()
        shape.has_text_frame = False
        shape.has_table = False
        slide = Mock()
        slide.shapes = [shape]
        slide.has_notes_slide = False

        mock_prs = Mock()
        mock_prs.slides = [slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="all")

        assert result["slides"][0]["text"] == ""
        assert result["slides"][0]["shapes"] == []

    def test_read_pptx_slide_empty_text_shape_filtered(self):
        """Test that shapes with empty text are filtered out."""
        mock_prs = Mock()
        mock_prs.slides = [self._make_slide(texts=["", "   ", "Actual text"])]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_pptx("/path/to/test.pptx", extract="slides")

        # Only non-empty text shapes should be in shapes list
        text_shapes = [s for s in result["slides"][0]["shapes"] if "text" in s]
        assert len(text_shapes) == 1
        assert text_shapes[0]["text"] == "Actual text"


# ===========================================================================
# Extended corner-case tests for modify_pptx
# ===========================================================================

class TestModifyPptxCornerCases:
    """Extended corner-case tests for the modify_pptx function."""

    def test_update_slide_text(self):
        """Test updating text of a specific shape on a slide."""
        mock_shape = Mock()
        mock_shape.name = "Title 1"
        mock_shape.has_text_frame = True
        mock_para = Mock()
        mock_shape.text_frame = Mock(paragraphs=[mock_para])

        mock_slide = Mock()
        mock_slide.shapes = [mock_shape]

        mock_prs = Mock()
        mock_prs.slides = [mock_slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "update_slide_text", "params": {"slide": 1, "shape_name": "Title 1", "text": "New Title"}}]
                )

        assert result["operations_applied"] == 1
        assert mock_para.text == "New Title"

    def test_update_slide_text_invalid_slide_number(self):
        """Test update_slide_text with invalid slide number."""
        mock_prs = Mock()
        mock_prs.slides = [Mock()]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "update_slide_text", "params": {"slide": 99, "shape_name": "X", "text": "Y"}}]
                )

        assert result["operations_applied"] == 0

    def test_set_notes(self):
        """Test setting speaker notes on a slide."""
        mock_notes_slide = Mock()
        mock_notes_slide.notes_text_frame = Mock()
        mock_slide = Mock()
        mock_slide.notes_slide = mock_notes_slide

        mock_prs = Mock()
        mock_prs.slides = [mock_slide]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "set_notes", "params": {"slide": 1, "text": "My notes"}}]
                )

        assert result["operations_applied"] == 1
        assert mock_notes_slide.notes_text_frame.text == "My notes"

    def test_set_notes_invalid_slide(self):
        """Test set_notes with slide number out of range."""
        mock_prs = Mock()
        mock_prs.slides = [Mock()]
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [{"action": "set_notes", "params": {"slide": 50, "text": "Notes"}}]
                )

        assert result["operations_applied"] == 0

    def test_modify_pptx_empty_operations(self):
        """Test modify with empty operations list."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx("/in.pptx", "/out.pptx", [])

        assert result["success"] is True
        assert result["operations_applied"] == 0
        mock_prs.save.assert_called_once()

    def test_modify_pptx_multiple_operations(self):
        """Test applying multiple operations in one call."""
        mock_notes = Mock()
        mock_notes.notes_text_frame = Mock()
        mock_slide = Mock()
        mock_slide.shapes = []
        mock_slide.notes_slide = mock_notes

        mock_prs = Mock()
        mock_slides = MagicMock()
        mock_slides.__iter__ = Mock(return_value=iter([mock_slide]))
        mock_slides.__len__ = Mock(return_value=1)
        mock_slides.__getitem__ = Mock(return_value=mock_slide)
        new_slide = Mock(placeholders=[])
        mock_slides.add_slide = Mock(return_value=new_slide)
        mock_prs.slides = mock_slides
        mock_prs.slide_layouts = [Mock(), Mock()]

        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx(
                    "/in.pptx", "/out.pptx",
                    [
                        {"action": "set_notes", "params": {"slide": 1, "text": "Note"}},
                        {"action": "add_slide", "params": {"title": "New"}},
                    ]
                )

        assert result["operations_applied"] == 2

    def test_modify_pptx_output_path_in_result(self):
        """Test that output_path key is in result."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_pptx("/in.pptx", "/out.pptx", [])

        assert result["output_path"] == "/out.pptx"

    def test_modify_pptx_validation_called(self):
        """Test that validation is called on input path."""
        mock_prs = Mock()
        mock_prs.slides = []
        mock_pptx = Mock(Presentation=Mock(return_value=mock_prs))

        with patch.dict('sys.modules', {'pptx': mock_pptx}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.modify_pptx("/in.pptx", "/out.pptx", [])
                mock_validate.assert_called_once_with("/in.pptx", 'document')


# ===========================================================================
# Extended corner-case tests for read_xlsx
# ===========================================================================

class TestReadXlsxCornerCases:
    """Extended corner-case tests for the read_xlsx function."""

    def _make_cell(self, value, data_type='n'):
        cell = Mock()
        cell.value = value
        cell.data_type = data_type
        return cell

    def _make_worksheet(self, rows_data, dimensions="A1:B2"):
        ws = Mock()
        ws.dimensions = dimensions
        rows = [[self._make_cell(v) for v in row] for row in rows_data]
        ws.iter_rows = Mock(return_value=iter(rows))
        ws.__getitem__ = Mock(return_value=iter(rows))
        return ws

    def test_read_xlsx_by_sheet_index(self):
        """Test reading a specific sheet by numeric index."""
        ws = self._make_worksheet([["Data"]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1", "Sheet2", "Sheet3"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx", sheet="1")

        assert "Sheet2" in result["sheets"]

    def test_read_xlsx_by_sheet_index_out_of_range(self):
        """Test error when sheet index is out of range."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.read_xlsx("/path/to/test.xlsx", sheet="5")

        assert "out of range" in str(exc_info.value)

    def test_read_xlsx_multiple_sheets(self):
        """Test reading all sheets from a multi-sheet workbook."""
        ws1 = self._make_worksheet([["A"]])
        ws2 = self._make_worksheet([["B"]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1", "Sheet2"]

        def getitem(name):
            return ws1 if name == "Sheet1" else ws2
        mock_wb.__getitem__ = Mock(side_effect=getitem)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx")

        assert "Sheet1" in result["sheets"]
        assert "Sheet2" in result["sheets"]
        assert result["sheet_count"] == 2

    def test_read_xlsx_with_cell_range(self):
        """Test reading with a specific cell range."""
        ws = self._make_worksheet([["A1", "B1"], ["A2", "B2"]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx", range="A1:B2")

        # ws.__getitem__ should have been called for the range
        ws.__getitem__.assert_called_with("A1:B2")

    def test_read_xlsx_empty_worksheet(self):
        """Test reading an empty worksheet."""
        ws = self._make_worksheet([])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/empty.xlsx")

        assert result["sheets"]["Sheet1"]["row_count"] == 0
        assert result["sheets"]["Sheet1"]["rows"] == []

    def test_read_xlsx_row_truncation(self):
        """Test that rows are truncated at max_rows limit."""
        # Create worksheet with many rows
        rows_data = [[f"val_{i}"] for i in range(200)]
        ws = Mock()
        ws.dimensions = "A1:A200"
        rows = [[self._make_cell(f"val_{i}")] for i in range(200)]
        ws.iter_rows = Mock(return_value=iter(rows))

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        # Set a low max_rows for testing
        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'), \
                 patch.object(documents, 'PROCESSING_LIMITS', {'text_chars': 1_000_000, 'xlsx_rows': 50, 'pptx_slides': 500}):
                result = documents.read_xlsx("/path/to/big.xlsx")

        # Should have truncated + the truncation message row
        assert result["sheets"]["Sheet1"]["row_count"] == 50
        last_row = result["sheets"]["Sheet1"]["rows"][-1]
        assert "Truncated" in str(last_row)

    def test_read_xlsx_validation_called(self):
        """Test that validation is called on input path."""
        ws = self._make_worksheet([["A"]])
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.read_xlsx("/path/to/test.xlsx")
                mock_validate.assert_called_once_with("/path/to/test.xlsx", 'document')

    def test_read_xlsx_workbook_closed(self):
        """Test that workbook is closed after reading."""
        ws = self._make_worksheet([["A"]])
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.read_xlsx("/path/to/test.xlsx")

        mock_wb.close.assert_called_once()

    def test_read_xlsx_none_cell_values(self):
        """Test handling of None cell values (empty cells)."""
        ws = self._make_worksheet([[None, "B1"], ["A2", None]])

        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=ws)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.read_xlsx("/path/to/test.xlsx")

        rows = result["sheets"]["Sheet1"]["rows"]
        assert rows[0][0] is None
        assert rows[0][1] == "B1"
        assert rows[1][0] == "A2"
        assert rows[1][1] is None


# ===========================================================================
# Extended corner-case tests for modify_xlsx
# ===========================================================================

class TestModifyXlsxCornerCases:
    """Extended corner-case tests for the modify_xlsx function."""

    def test_set_formula(self):
        """Test setting a formula in a cell."""
        mock_ws = MagicMock()
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=mock_ws)
        mock_wb.__contains__ = Mock(side_effect=lambda x: x == "Sheet1")

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "set_formula", "params": {"sheet": "Sheet1", "cell": "C1", "formula": "=A1+B1"}}]
                )

        assert result["operations_applied"] == 1
        mock_ws.__setitem__.assert_called_with("C1", "=A1+B1")

    def test_set_cell_defaults_to_first_sheet(self):
        """Test that set_cell defaults to first sheet when sheet param omitted."""
        mock_ws = MagicMock()
        mock_wb = Mock()
        mock_wb.sheetnames = ["MySheet"]
        mock_wb.__getitem__ = Mock(return_value=mock_ws)
        mock_wb.__contains__ = Mock(side_effect=lambda x: x == "MySheet")

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "set_cell", "params": {"cell": "A1", "value": "hello"}}]
                )

        assert result["operations_applied"] == 1
        mock_wb.__getitem__.assert_called_with("MySheet")

    def test_delete_sheet_nonexistent(self):
        """Test deleting a non-existent sheet silently does nothing."""
        mock_wb = MagicMock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [{"action": "delete_sheet", "params": {"name": "NonExistent"}}]
                )

        # Should not error, just 0 applied
        assert result["success"] is True
        assert result["operations_applied"] == 0

    def test_modify_xlsx_multiple_operations(self):
        """Test applying multiple mixed operations."""
        mock_ws = MagicMock()
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__getitem__ = Mock(return_value=mock_ws)
        mock_wb.__contains__ = Mock(side_effect=lambda x: x == "Sheet1")

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx(
                    "/in.xlsx", "/out.xlsx",
                    [
                        {"action": "set_cell", "params": {"cell": "A1", "value": 42}},
                        {"action": "set_formula", "params": {"cell": "B1", "formula": "=A1*2"}},
                        {"action": "add_row", "params": {"values": [1, 2, 3]}},
                        {"action": "add_sheet", "params": {"name": "New"}},
                    ]
                )

        assert result["operations_applied"] == 4

    def test_modify_xlsx_empty_operations(self):
        """Test modify with empty operations list."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])

        assert result["success"] is True
        assert result["operations_applied"] == 0
        mock_wb.save.assert_called_once()
        mock_wb.close.assert_called_once()

    def test_modify_xlsx_output_path_in_result(self):
        """Test that output_path key is in result."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                result = documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])

        assert result["output_path"] == "/out.xlsx"

    def test_modify_xlsx_validation_called(self):
        """Test that validation is called on input path."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing') as mock_validate:
                documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])
                mock_validate.assert_called_once_with("/in.xlsx", 'document')

    def test_modify_xlsx_workbook_closed_after_save(self):
        """Test that workbook is closed after saving."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                documents.modify_xlsx("/in.xlsx", "/out.xlsx", [])

        mock_wb.save.assert_called_once()
        mock_wb.close.assert_called_once()

    def test_set_formula_sheet_not_found(self):
        """Test set_formula raises ToolError when sheet not found."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__contains__ = Mock(return_value=False)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx(
                        "/in.xlsx", "/out.xlsx",
                        [{"action": "set_formula", "params": {"sheet": "Missing", "cell": "A1", "formula": "=1"}}]
                    )

        assert "not found" in str(exc_info.value)

    def test_add_row_sheet_not_found(self):
        """Test add_row raises ToolError when sheet not found."""
        mock_wb = Mock()
        mock_wb.sheetnames = ["Sheet1"]
        mock_wb.__contains__ = Mock(return_value=False)

        mock_openpyxl = Mock(load_workbook=Mock(return_value=mock_wb))

        with patch.dict('sys.modules', {'openpyxl': mock_openpyxl}), \
             patch('os.makedirs'):
            import importlib
            importlib.reload(documents)
            with patch.object(documents, 'validate_file_for_processing'):
                with pytest.raises(ToolError) as exc_info:
                    documents.modify_xlsx(
                        "/in.xlsx", "/out.xlsx",
                        [{"action": "add_row", "params": {"sheet": "Missing", "values": [1]}}]
                    )
