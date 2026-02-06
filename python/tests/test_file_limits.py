"""Tests for file size validation"""

import os
import tempfile
import pytest
from unittest.mock import patch, Mock
from navixmind.utils.file_limits import (
    validate_file_for_processing,
    validate_pdf_for_processing,
    validate_image_for_processing,
    get_limit_for_type,
    FileTooLargeError,
    FILE_SIZE_LIMITS,
    PROCESSING_LIMITS,
    format_size
)


class TestFileSizeLimits:
    def test_small_file_passes(self):
        # Create a small temp file
        with tempfile.NamedTemporaryFile(suffix='.txt', delete=False) as f:
            f.write(b'Small content')
            temp_path = f.name

        try:
            # Should not raise
            validate_file_for_processing(temp_path, 'document')
        finally:
            os.unlink(temp_path)

    def test_missing_file_raises(self):
        with pytest.raises(FileNotFoundError):
            validate_file_for_processing('/nonexistent/file.pdf', 'pdf')

    def test_type_detection(self):
        # Test that file type is auto-detected from extension
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            validate_file_for_processing(temp_path)  # Should detect as PDF
        finally:
            os.unlink(temp_path)

    def test_limits_defined(self):
        assert 'pdf' in FILE_SIZE_LIMITS
        assert 'image' in FILE_SIZE_LIMITS
        assert 'video' in FILE_SIZE_LIMITS
        assert 'audio' in FILE_SIZE_LIMITS
        assert 'default' in FILE_SIZE_LIMITS


class TestFormatSize:
    def test_bytes(self):
        assert format_size(500) == '500 B'

    def test_kilobytes(self):
        assert format_size(1500) == '1.5 KB'

    def test_megabytes(self):
        assert format_size(1500000) == '1.4 MB'
        assert format_size(50 * 1024 * 1024) == '50.0 MB'


class TestGetLimitForType:
    """Tests for get_limit_for_type function."""

    def test_get_pdf_limit(self):
        """Test getting PDF size limit."""
        limit = get_limit_for_type('pdf')
        assert limit == FILE_SIZE_LIMITS['pdf']

    def test_get_image_limit(self):
        """Test getting image size limit."""
        limit = get_limit_for_type('image')
        assert limit == FILE_SIZE_LIMITS['image']

    def test_get_unknown_type_returns_default(self):
        """Test unknown type returns default limit."""
        limit = get_limit_for_type('unknown_type')
        assert limit == FILE_SIZE_LIMITS['default']


class TestValidatePdfForProcessing:
    """Tests for validate_pdf_for_processing function."""

    def test_small_pdf_passes(self):
        """Test that a small PDF with few pages passes validation."""
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            mock_reader = Mock()
            mock_reader.pages = [Mock()] * 5  # 5 pages

            with patch('navixmind.utils.file_limits.validate_file_for_processing'), \
                 patch('pypdf.PdfReader', return_value=mock_reader):
                validate_pdf_for_processing(temp_path)
        finally:
            os.unlink(temp_path)

    def test_pdf_too_many_pages_raises(self):
        """Test that PDF with too many pages raises error."""
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            mock_reader = Mock()
            mock_reader.pages = [Mock()] * (PROCESSING_LIMITS['pdf_pages'] + 1)

            with patch('navixmind.utils.file_limits.validate_file_for_processing'), \
                 patch('pypdf.PdfReader', return_value=mock_reader):
                with pytest.raises(FileTooLargeError) as exc_info:
                    validate_pdf_for_processing(temp_path)
                assert 'too many pages' in str(exc_info.value)
        finally:
            os.unlink(temp_path)

    def test_pypdf_not_available_skips_check(self):
        """Test that missing pypdf doesn't crash."""
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            with patch('navixmind.utils.file_limits.validate_file_for_processing'), \
                 patch.dict('sys.modules', {'pypdf': None}):
                # Should not raise even if pypdf is missing
                validate_pdf_for_processing(temp_path)
        finally:
            os.unlink(temp_path)


class TestValidateImageForProcessing:
    """Tests for validate_image_for_processing function."""

    def test_small_image_passes(self):
        """Test that a small image passes validation."""
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            mock_img = Mock()
            mock_img.width = 1000
            mock_img.height = 1000
            mock_img.__enter__ = Mock(return_value=mock_img)
            mock_img.__exit__ = Mock(return_value=False)

            with patch('navixmind.utils.file_limits.validate_file_for_processing'), \
                 patch('PIL.Image.open', return_value=mock_img):
                validate_image_for_processing(temp_path)
        finally:
            os.unlink(temp_path)

    def test_large_image_raises(self):
        """Test that image with too many pixels raises error."""
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            mock_img = Mock()
            # Make image larger than limit
            mock_img.width = 10000
            mock_img.height = 10000  # 100M pixels > 25M limit
            mock_img.__enter__ = Mock(return_value=mock_img)
            mock_img.__exit__ = Mock(return_value=False)

            with patch('navixmind.utils.file_limits.validate_file_for_processing'), \
                 patch('PIL.Image.open', return_value=mock_img):
                with pytest.raises(FileTooLargeError) as exc_info:
                    validate_image_for_processing(temp_path)
                assert 'resolution too high' in str(exc_info.value)
        finally:
            os.unlink(temp_path)

    def test_pillow_not_available_skips_check(self):
        """Test that missing Pillow doesn't crash."""
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
            f.write(b'x' * 100)
            temp_path = f.name

        try:
            with patch('navixmind.utils.file_limits.validate_file_for_processing'), \
                 patch.dict('sys.modules', {'PIL': None, 'PIL.Image': None}):
                # Should not raise even if Pillow is missing
                validate_image_for_processing(temp_path)
        finally:
            os.unlink(temp_path)
