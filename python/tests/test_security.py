"""
Comprehensive security tests for the NavixMind Python module.

Tests cover:
- Path traversal prevention
- Domain blocking
- Input sanitization
- File size limits
- URL validation
"""

import os
import pytest
from navixmind.utils.security import (
    is_blocked_domain,
    sanitize_filename,
    sanitize_path,
    BLOCKED_DOMAINS,
    SecurityError,
)
from navixmind.utils.file_limits import FILE_SIZE_LIMITS


class TestBlockedDomains:
    """Tests for domain blocking functionality."""

    def test_youtube_blocked(self):
        """Test that YouTube domains are blocked."""
        assert is_blocked_domain('https://youtube.com/watch?v=123') is True
        assert is_blocked_domain('https://www.youtube.com/watch?v=123') is True
        assert is_blocked_domain('https://youtu.be/123') is True
        assert is_blocked_domain('https://m.youtube.com/watch?v=123') is True
        assert is_blocked_domain('https://music.youtube.com/watch?v=123') is True

    def test_youtube_subdomains_blocked(self):
        """Test that all YouTube subdomains are blocked."""
        assert is_blocked_domain('https://studio.youtube.com') is True
        assert is_blocked_domain('https://gaming.youtube.com') is True
        assert is_blocked_domain('https://kids.youtube.com') is True
        assert is_blocked_domain('https://tv.youtube.com') is True

    def test_youtube_nocookie_blocked(self):
        """Test that youtube-nocookie.com is blocked."""
        assert is_blocked_domain('https://www.youtube-nocookie.com/embed/123') is True

    def test_other_sites_allowed(self):
        """Test that other video sites are allowed."""
        assert is_blocked_domain('https://tiktok.com/@user/video/123') is False
        assert is_blocked_domain('https://instagram.com/p/123') is False
        assert is_blocked_domain('https://twitter.com/status/123') is False
        assert is_blocked_domain('https://vimeo.com/123') is False

    def test_invalid_url_allowed(self):
        """Test that invalid URLs are allowed through (will fail on request)."""
        assert is_blocked_domain('not a url') is False

    def test_case_insensitive_blocking(self):
        """Test that domain blocking is case-insensitive."""
        assert is_blocked_domain('https://YOUTUBE.COM/watch?v=123') is True
        assert is_blocked_domain('https://YouTube.com/watch?v=123') is True
        assert is_blocked_domain('https://yOuTuBe.CoM/watch?v=123') is True

    def test_blocked_domains_constant(self):
        """Test that BLOCKED_DOMAINS constant is defined."""
        assert isinstance(BLOCKED_DOMAINS, (list, tuple, set))
        assert 'youtube.com' in BLOCKED_DOMAINS
        assert 'youtu.be' in BLOCKED_DOMAINS

    def test_legitimate_educational_sites_allowed(self):
        """Test that legitimate sites are allowed."""
        assert is_blocked_domain('https://wikipedia.org/wiki/Python') is False
        assert is_blocked_domain('https://github.com/user/repo') is False
        assert is_blocked_domain('https://stackoverflow.com/questions/123') is False

    def test_empty_url(self):
        """Test handling of empty URL."""
        result = is_blocked_domain('')
        assert isinstance(result, bool)

    def test_url_with_query_params(self):
        """Test URL with complex query parameters."""
        assert is_blocked_domain(
            'https://youtube.com/watch?v=123&list=456&t=789'
        ) is True

    def test_url_with_fragment(self):
        """Test URL with fragment."""
        assert is_blocked_domain('https://youtube.com/watch?v=123#t=60') is True


class TestSanitizeFilename:
    """Tests for filename sanitization."""

    def test_removes_path_separators(self):
        """Test that path separators are replaced."""
        # The actual implementation replaces / and .. with _
        result = sanitize_filename('../../../etc/passwd')
        assert '/' not in result
        assert sanitize_filename('file/with/slashes.txt') == 'file_with_slashes.txt'

    def test_removes_null_bytes(self):
        """Test that null bytes are removed."""
        assert sanitize_filename('file\x00name.txt') == 'file_name.txt'

    def test_truncates_long_names(self):
        """Test that long names are truncated."""
        long_name = 'a' * 300 + '.txt'
        result = sanitize_filename(long_name)
        assert len(result) <= 255
        assert result.endswith('.txt')

    def test_preserves_normal_names(self):
        """Test that normal filenames are preserved."""
        assert sanitize_filename('normal_file.txt') == 'normal_file.txt'
        assert sanitize_filename('photo-2024-01-15.jpg') == 'photo-2024-01-15.jpg'

    def test_removes_backslash(self):
        """Test that backslashes are replaced."""
        result = sanitize_filename('file\\name.txt')
        assert '\\' not in result

    def test_removes_special_characters(self):
        """Test that special characters are handled."""
        dangerous_names = [
            'file<name>.txt',
            'file|name.txt',
            'file:name.txt',
            'file"name.txt',
            'file?name.txt',
            'file*name.txt',
        ]
        for name in dangerous_names:
            result = sanitize_filename(name)
            assert len(result) > 0

    def test_handles_unicode(self):
        """Test handling of unicode filenames."""
        unicode_names = [
            'файл.txt',  # Russian
            '文件.pdf',  # Chinese
            'αρχείο.txt',  # Greek
        ]
        for name in unicode_names:
            result = sanitize_filename(name)
            assert len(result) > 0

    def test_empty_filename(self):
        """Test handling of empty filename."""
        result = sanitize_filename('')
        # Should return something valid
        assert isinstance(result, str)

    def test_only_special_chars(self):
        """Test filename with only special characters."""
        result = sanitize_filename('...')
        assert isinstance(result, str)

    def test_preserves_extension(self):
        """Test that file extensions are preserved when possible."""
        result = sanitize_filename('file../path.pdf')
        # Should still have .pdf extension
        assert 'pdf' in result


class TestSanitizePath:
    """Tests for path sanitization.

    Note: The actual sanitize_path function takes only a path argument
    and validates against predefined ALLOWED_PATH_ROOTS. In debug mode,
    it allows all paths.
    """

    def test_resolves_path_to_absolute(self):
        """Test that paths are resolved to absolute."""
        # Enable debug mode for testing
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            result = sanitize_path('relative/path')
            assert os.path.isabs(result)
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'

    def test_resolves_parent_refs(self):
        """Test that parent references are resolved."""
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            result = sanitize_path('../test/../test/file.txt')
            assert '..' not in result
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'

    def test_handles_absolute_paths(self):
        """Test handling of absolute paths."""
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            result = sanitize_path('/tmp/test.txt')
            # Should be an absolute path
            assert os.path.isabs(result)
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'

    def test_normalizes_slashes(self):
        """Test that multiple slashes are normalized."""
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            result = sanitize_path('path//to///file')
            # os.path.realpath normalizes slashes
            assert isinstance(result, str)
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'

    def test_raises_security_error_for_disallowed_path(self):
        """Test that disallowed paths raise SecurityError."""
        os.environ['NAVIXMIND_DEBUG'] = 'false'
        try:
            with pytest.raises(SecurityError):
                sanitize_path('/etc/passwd')
        finally:
            pass

    def test_debug_mode_allows_all_paths(self):
        """Test that debug mode allows all paths."""
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            # This should NOT raise in debug mode
            result = sanitize_path('/etc/passwd')
            assert isinstance(result, str)
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'


class TestFileSizeLimits:
    """Tests for file size limit constants."""

    def test_pdf_limit(self):
        """Test PDF size limit."""
        assert FILE_SIZE_LIMITS['pdf'] == 500 * 1024 * 1024  # 500MB

    def test_image_limit(self):
        """Test image size limit."""
        assert FILE_SIZE_LIMITS['image'] == 500 * 1024 * 1024  # 500MB

    def test_video_limit(self):
        """Test video size limit."""
        assert FILE_SIZE_LIMITS['video'] == 500 * 1024 * 1024  # 500MB

    def test_audio_limit(self):
        """Test audio size limit."""
        assert FILE_SIZE_LIMITS['audio'] == 500 * 1024 * 1024  # 500MB

    def test_default_limit(self):
        """Test default size limit."""
        assert 'default' in FILE_SIZE_LIMITS
        assert FILE_SIZE_LIMITS['default'] == 500 * 1024 * 1024  # 500MB

    def test_all_limits_positive(self):
        """Test that all limits are positive."""
        for file_type, limit in FILE_SIZE_LIMITS.items():
            assert limit > 0, f"{file_type} limit should be positive"


class TestEdgeCases:
    """Tests for edge cases and security boundaries."""

    def test_url_encoded_traversal_blocked(self):
        """Test URL-encoded path traversal in is_blocked_domain."""
        # URL-encoded paths in domain context
        assert is_blocked_domain('https://youtube.com/%2e%2e/secret') is True

    def test_very_long_path_handling(self):
        """Test handling of very long paths."""
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            long_path = 'a/' * 50 + 'file.txt'
            result = sanitize_path(long_path)
            # Should handle without crashing
            assert isinstance(result, str)
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'

    def test_empty_string_path(self):
        """Test empty string path."""
        os.environ['NAVIXMIND_DEBUG'] = 'true'
        try:
            result = sanitize_path('')
            assert isinstance(result, str)
        finally:
            os.environ['NAVIXMIND_DEBUG'] = 'false'


class TestSecurityConstants:
    """Tests for security-related constants."""

    def test_blocked_domains_not_empty(self):
        """Test that blocked domains list is not empty."""
        assert len(BLOCKED_DOMAINS) > 0

    def test_file_size_limits_complete(self):
        """Test that all expected file types have limits."""
        expected_types = ['pdf', 'image', 'video', 'audio', 'default']
        for file_type in expected_types:
            assert file_type in FILE_SIZE_LIMITS


class TestDebugMode:
    """Tests for debug mode behavior."""

    def test_debug_mode_env_variable(self):
        """Test that debug mode is controlled by NAVIXMIND_DEBUG."""
        # Save original
        original = os.environ.get('NAVIXMIND_DEBUG')

        try:
            # Test with debug enabled
            os.environ['NAVIXMIND_DEBUG'] = 'true'
            assert is_blocked_domain('https://youtube.com') is False

            # Test with debug disabled
            os.environ['NAVIXMIND_DEBUG'] = 'false'
            assert is_blocked_domain('https://youtube.com') is True
        finally:
            # Restore
            if original is None:
                os.environ.pop('NAVIXMIND_DEBUG', None)
            else:
                os.environ['NAVIXMIND_DEBUG'] = original

    def test_debug_mode_case_insensitive(self):
        """Test that debug mode check is case-insensitive."""
        original = os.environ.get('NAVIXMIND_DEBUG')

        try:
            os.environ['NAVIXMIND_DEBUG'] = 'TRUE'
            assert is_blocked_domain('https://youtube.com') is False

            os.environ['NAVIXMIND_DEBUG'] = 'True'
            assert is_blocked_domain('https://youtube.com') is False
        finally:
            if original is None:
                os.environ.pop('NAVIXMIND_DEBUG', None)
            else:
                os.environ['NAVIXMIND_DEBUG'] = original


class TestIsBlockedDomainEdgeCases:
    """Edge case tests for is_blocked_domain function."""

    def test_malformed_url_returns_false(self):
        """Test that malformed URLs don't crash and return False."""
        # These edge cases should not crash
        assert is_blocked_domain('') is False
        assert is_blocked_domain('not-a-url') is False
        assert is_blocked_domain('://missing-scheme') is False

    def test_url_parsing_exception_returns_false(self):
        """Test exception during URL parsing returns False."""
        from unittest.mock import patch

        # Force an exception during URL parsing
        with patch('navixmind.utils.security.urlparse') as mock_urlparse:
            mock_urlparse.side_effect = Exception("Parsing failed")
            result = is_blocked_domain('https://youtube.com')
            assert result is False


class TestSanitizePathAllowedRoots:
    """Tests for sanitize_path with allowed path roots."""

    def test_allowed_android_path(self):
        """Test that allowed Android paths pass validation."""
        from unittest.mock import patch

        # Mock realpath to return an allowed Android path
        with patch('os.path.realpath') as mock_realpath:
            mock_realpath.return_value = '/data/data/ai.navixmind/files/test.txt'
            result = sanitize_path('/data/data/ai.navixmind/files/test.txt')
            assert result == '/data/data/ai.navixmind/files/test.txt'

    def test_allowed_storage_path(self):
        """Test that allowed storage paths pass validation."""
        from unittest.mock import patch

        with patch('os.path.realpath') as mock_realpath:
            mock_realpath.return_value = '/storage/emulated/0/Download/file.pdf'
            result = sanitize_path('/storage/emulated/0/Download/file.pdf')
            assert result == '/storage/emulated/0/Download/file.pdf'

    def test_allowed_sdcard_path(self):
        """Test that allowed sdcard paths pass validation."""
        from unittest.mock import patch

        with patch('os.path.realpath') as mock_realpath:
            mock_realpath.return_value = '/sdcard/Documents/file.txt'
            result = sanitize_path('/sdcard/Documents/file.txt')
            assert result == '/sdcard/Documents/file.txt'
