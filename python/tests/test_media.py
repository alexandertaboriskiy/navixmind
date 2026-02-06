"""
Comprehensive tests for the NavixMind media tools module.

Tests cover:
- YouTube domain blocking (youtube.com, youtu.be, www.youtube.com)
- YouTube subdomain blocking
- YouTube extractor detection in info
- YouTube redirect in final_url blocked
- Valid non-YouTube URL extraction
- Audio format selection (acodec != none, vcodec == none)
- Video format selection (vcodec != none)
- No download_url raises ToolError
- yt_dlp.DownloadError handling
- General exception handling
- Empty formats list handling
- Bridge.log called during extraction
- Title and duration extracted correctly
"""

import pytest
from unittest.mock import Mock, patch, MagicMock

from navixmind.bridge import ToolError
from navixmind.tools.media import download_media


class TestYouTubeBlocking:
    """Tests for YouTube URL blocking."""

    def test_youtube_com_blocked(self):
        """Test that youtube.com URLs are blocked."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=True):
            with pytest.raises(ToolError) as exc_info:
                download_media("https://youtube.com/watch?v=abc123")

            assert "YouTube downloads are not supported" in str(exc_info.value)
            assert "platform policies" in str(exc_info.value)

    def test_www_youtube_com_blocked(self):
        """Test that www.youtube.com URLs are blocked."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=True):
            with pytest.raises(ToolError) as exc_info:
                download_media("https://www.youtube.com/watch?v=abc123")

            assert "YouTube downloads are not supported" in str(exc_info.value)

    def test_youtu_be_blocked(self):
        """Test that youtu.be URLs are blocked."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=True):
            with pytest.raises(ToolError) as exc_info:
                download_media("https://youtu.be/abc123")

            assert "YouTube downloads are not supported" in str(exc_info.value)

    def test_youtube_subdomains_blocked(self):
        """Test that YouTube subdomains are blocked."""
        youtube_urls = [
            "https://m.youtube.com/watch?v=abc123",
            "https://music.youtube.com/watch?v=abc123",
            "https://gaming.youtube.com/watch?v=abc123",
            "https://studio.youtube.com/video/abc123",
            "https://kids.youtube.com/watch?v=abc123",
        ]

        for url in youtube_urls:
            with patch('navixmind.tools.media.is_blocked_domain', return_value=True):
                with pytest.raises(ToolError) as exc_info:
                    download_media(url)

                assert "YouTube downloads are not supported" in str(exc_info.value)

    def test_suggestion_for_alternative_platforms(self):
        """Test that error message suggests alternative platforms."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=True):
            with pytest.raises(ToolError) as exc_info:
                download_media("https://youtube.com/watch?v=abc123")

            error_message = str(exc_info.value)
            assert "TikTok" in error_message or "Instagram" in error_message


class TestYouTubeExtractorDetection:
    """Tests for YouTube extractor detection in yt_dlp info."""

    def test_youtube_extractor_in_info_blocked(self):
        """Test that YouTube extractor in info raises ToolError."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "youtube",
                "title": "Some Video",
            }

            with pytest.raises(ToolError) as exc_info:
                download_media("https://short.link/xyz")

            assert "redirects to YouTube" in str(exc_info.value)
            assert "not supported" in str(exc_info.value)

    def test_youtube_extractor_case_insensitive(self):
        """Test that YouTube extractor detection is case insensitive."""
        test_extractors = ["YouTube", "YOUTUBE", "youTube", "youtube:playlist"]

        for extractor in test_extractors:
            with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
                 patch('navixmind.tools.media.get_bridge') as mock_bridge, \
                 patch('yt_dlp.YoutubeDL') as mock_ydl:

                mock_bridge.return_value.log = Mock()

                mock_instance = MagicMock()
                mock_ydl.return_value.__enter__.return_value = mock_instance
                mock_instance.extract_info.return_value = {
                    "extractor": extractor,
                    "title": "Some Video",
                }

                with pytest.raises(ToolError) as exc_info:
                    download_media("https://short.link/xyz")

                assert "youtube" in str(exc_info.value).lower()


class TestYouTubeRedirectBlocking:
    """Tests for blocking URLs that redirect to YouTube."""

    def test_final_url_redirect_to_youtube_blocked(self):
        """Test that final_url redirecting to YouTube is blocked."""
        with patch('navixmind.tools.media.is_blocked_domain') as mock_blocked, \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            # First call (initial URL): not blocked
            # Second call (final_url): blocked
            mock_blocked.side_effect = [False, True]
            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "generic",
                "title": "Some Video",
                "webpage_url": "https://youtube.com/watch?v=abc123",
            }

            with pytest.raises(ToolError) as exc_info:
                download_media("https://redirect-service.com/xyz")

            assert "redirects to a blocked platform" in str(exc_info.value)

    def test_final_url_uses_original_if_not_in_info(self):
        """Test that original URL is used if webpage_url not in info."""
        with patch('navixmind.tools.media.is_blocked_domain') as mock_blocked, \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_blocked.return_value = False
            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/abc123")

            # Should have called is_blocked_domain twice - once for initial URL, once for final
            assert mock_blocked.call_count == 2


class TestValidNonYouTubeURL:
    """Tests for valid non-YouTube URL extraction."""

    def test_valid_instagram_url_extracts_info(self):
        """Test that valid Instagram URL extracts info successfully."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Instagram Video",
                "duration": 120,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["title"] == "Instagram Video"
            assert result["duration"] == 120
            assert result["format"] == "video"
            assert result["extension"] == "mp4"
            assert result["extractor"] == "instagram"

    def test_valid_tiktok_url_extracts_info(self):
        """Test that valid TikTok URL extracts info successfully."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "tiktok",
                "title": "TikTok Video",
                "duration": 30,
                "webpage_url": "https://tiktok.com/@user/video/123",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://tiktok.com/@user/video/123")

            assert result["title"] == "TikTok Video"
            assert result["extractor"] == "tiktok"

    def test_vimeo_url_extracts_info(self):
        """Test that Vimeo URL extracts info successfully."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "vimeo",
                "title": "Vimeo Video",
                "duration": 300,
                "webpage_url": "https://vimeo.com/123456",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://vimeo-cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://vimeo.com/123456")

            assert result["title"] == "Vimeo Video"
            assert result["extractor"] == "vimeo"


class TestAudioFormatSelection:
    """Tests for audio format selection."""

    def test_audio_format_selects_audio_only_codec(self):
        """Test that audio format selects format with acodec != none and vcodec == none."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "soundcloud",
                "title": "Audio Track",
                "duration": 180,
                "webpage_url": "https://soundcloud.com/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"},
                    {"vcodec": "none", "acodec": "mp3", "url": "https://cdn.com/audio.mp3", "ext": "mp3"},
                    {"vcodec": "none", "acodec": "opus", "url": "https://cdn.com/audio.opus", "ext": "opus"},
                ]
            }

            result = download_media("https://soundcloud.com/test", format="audio")

            assert result["format"] == "audio"
            # Should select the last audio-only format (opus)
            assert result["download_url"] == "https://cdn.com/audio.opus"
            assert result["extension"] == "opus"

    def test_audio_format_falls_back_to_any_audio_codec(self):
        """Test that audio format falls back to any format with acodec != none."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "generic",
                "title": "Combined Media",
                "duration": 120,
                "webpage_url": "https://example.com/media",
                "formats": [
                    # No audio-only formats, only combined audio+video
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/combined.mp4", "ext": "mp4"},
                    {"vcodec": "h265", "acodec": "opus", "url": "https://cdn.com/combined2.webm", "ext": "webm"},
                ]
            }

            result = download_media("https://example.com/media", format="audio")

            assert result["format"] == "audio"
            # Should fall back to the last format with acodec != none
            assert result["download_url"] == "https://cdn.com/combined2.webm"

    def test_audio_format_falls_back_to_last_format(self):
        """Test that audio format falls back to last format if no audio codec."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "generic",
                "title": "Video Only",
                "duration": 60,
                "webpage_url": "https://example.com/media",
                "formats": [
                    {"vcodec": "h264", "acodec": "none", "url": "https://cdn.com/video1.mp4", "ext": "mp4"},
                    {"vcodec": "h265", "acodec": "none", "url": "https://cdn.com/video2.mp4", "ext": "mp4"},
                ]
            }

            result = download_media("https://example.com/media", format="audio")

            # Should fall back to the last format in the list
            assert result["download_url"] == "https://cdn.com/video2.mp4"


class TestVideoFormatSelection:
    """Tests for video format selection."""

    def test_video_format_selects_video_codec(self):
        """Test that video format selects format with vcodec != none."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Video Post",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "none", "acodec": "mp3", "url": "https://cdn.com/audio.mp3", "ext": "mp3"},
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/sd.mp4", "ext": "mp4"},
                    {"vcodec": "h265", "acodec": "aac", "url": "https://cdn.com/hd.mp4", "ext": "mp4"},
                ]
            }

            result = download_media("https://instagram.com/p/test", format="video")

            assert result["format"] == "video"
            # Should select the last video format (h265)
            assert result["download_url"] == "https://cdn.com/hd.mp4"

    def test_video_format_falls_back_to_last_format(self):
        """Test that video format falls back to last format if no video codec."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "generic",
                "title": "Audio Only",
                "duration": 180,
                "webpage_url": "https://example.com/media",
                "formats": [
                    {"vcodec": "none", "acodec": "mp3", "url": "https://cdn.com/audio1.mp3", "ext": "mp3"},
                    {"vcodec": "none", "acodec": "opus", "url": "https://cdn.com/audio2.opus", "ext": "opus"},
                ]
            }

            result = download_media("https://example.com/media", format="video")

            # Should fall back to the last format in the list
            assert result["download_url"] == "https://cdn.com/audio2.opus"

    def test_video_default_format(self):
        """Test that video is the default format."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            # Call without format parameter
            result = download_media("https://instagram.com/p/test")

            assert result["format"] == "video"


class TestNoDownloadURL:
    """Tests for missing download URL handling."""

    def test_no_download_url_raises_tool_error(self):
        """Test that missing download_url raises ToolError."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": None, "ext": "mp4"}
                ]
            }

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "Could not extract download URL" in str(exc_info.value)

    def test_no_url_key_in_format_raises_tool_error(self):
        """Test that format without url key raises ToolError."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "ext": "mp4"}  # No 'url' key
                ]
            }

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "Could not extract download URL" in str(exc_info.value)


class TestYtDlpDownloadError:
    """Tests for yt_dlp.DownloadError handling."""

    def test_download_error_raises_tool_error(self):
        """Test that yt_dlp.DownloadError is caught and raises ToolError."""
        import yt_dlp

        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.side_effect = yt_dlp.DownloadError("Video unavailable")

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "Failed to extract media" in str(exc_info.value)
            assert "Video unavailable" in str(exc_info.value)

    def test_download_error_with_specific_message(self):
        """Test that DownloadError message is preserved."""
        import yt_dlp

        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.side_effect = yt_dlp.DownloadError(
                "This video is private and cannot be downloaded"
            )

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "private" in str(exc_info.value).lower()


class TestGeneralExceptionHandling:
    """Tests for general exception handling."""

    def test_general_exception_raises_tool_error(self):
        """Test that general exceptions are caught and raise ToolError."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.side_effect = RuntimeError("Unexpected error")

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "Media download failed" in str(exc_info.value)
            assert "Unexpected error" in str(exc_info.value)

    def test_connection_error_handling(self):
        """Test that connection errors are handled."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.side_effect = ConnectionError("Network unreachable")

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "Media download failed" in str(exc_info.value)

    def test_timeout_error_handling(self):
        """Test that timeout errors are handled."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.side_effect = TimeoutError("Request timed out")

            with pytest.raises(ToolError) as exc_info:
                download_media("https://instagram.com/p/test")

            assert "Media download failed" in str(exc_info.value)


class TestEmptyFormatsListHandling:
    """Tests for empty formats list handling."""

    def test_empty_formats_list_raises_error(self):
        """Test that empty formats list causes an error."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": []  # Empty formats list
            }

            with pytest.raises((ToolError, IndexError)):
                download_media("https://instagram.com/p/test")

    def test_missing_formats_key_raises_error(self):
        """Test that missing formats key causes an error."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                # No 'formats' key
            }

            with pytest.raises((ToolError, TypeError, IndexError)):
                download_media("https://instagram.com/p/test")


class TestBridgeLogCalls:
    """Tests for Bridge.log calls during extraction."""

    def test_log_called_for_extracting_info(self):
        """Test that bridge.log is called when extracting info."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_get_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge = Mock()
            mock_get_bridge.return_value = mock_bridge

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            download_media("https://instagram.com/p/test")

            # Check that log was called with extracting message
            log_calls = mock_bridge.log.call_args_list
            assert any("Extracting media info" in str(call) for call in log_calls)

    def test_log_called_with_title_and_duration(self):
        """Test that bridge.log is called with title and duration after extraction."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_get_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge = Mock()
            mock_get_bridge.return_value = mock_bridge

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Amazing Video Title",
                "duration": 120,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            download_media("https://instagram.com/p/test")

            # Check that log was called with Found message including title and duration
            log_calls = mock_bridge.log.call_args_list
            found_call = [call for call in log_calls if "Found" in str(call)]
            assert len(found_call) > 0
            assert "Amazing Video Title" in str(found_call[0])
            assert "120" in str(found_call[0])


class TestTitleAndDurationExtraction:
    """Tests for title and duration extraction."""

    def test_title_extracted_correctly(self):
        """Test that title is extracted correctly."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "My Special Video Title",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["title"] == "My Special Video Title"

    def test_duration_extracted_correctly(self):
        """Test that duration is extracted correctly."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 3600,  # 1 hour
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["duration"] == 3600

    def test_missing_title_uses_default(self):
        """Test that missing title uses default value."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                # No 'title' key
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["title"] == "download"  # Default value

    def test_missing_duration_uses_default(self):
        """Test that missing duration uses default value."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                # No 'duration' key
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["duration"] == 0  # Default value


class TestExtensionExtraction:
    """Tests for file extension extraction."""

    def test_extension_extracted_correctly(self):
        """Test that extension is extracted from format."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.webm", "ext": "webm"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["extension"] == "webm"

    def test_missing_extension_uses_default(self):
        """Test that missing extension uses default mp4."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video"}
                    # No 'ext' key
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert result["extension"] == "mp4"  # Default value


class TestYtDlpOptions:
    """Tests for yt_dlp configuration options."""

    def test_ydl_configured_with_quiet_mode(self):
        """Test that yt_dlp is configured with quiet mode."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            download_media("https://instagram.com/p/test")

            # Check that YoutubeDL was called with quiet options
            call_kwargs = mock_ydl.call_args[0][0]
            assert call_kwargs.get('quiet') is True
            assert call_kwargs.get('no_warnings') is True

    def test_ydl_extract_info_called_without_download(self):
        """Test that extract_info is called with download=False."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            download_media("https://instagram.com/p/test")

            # Check that extract_info was called with download=False
            mock_instance.extract_info.assert_called_once()
            call_kwargs = mock_instance.extract_info.call_args[1]
            assert call_kwargs.get('download') is False


class TestReturnValueStructure:
    """Tests for the return value structure."""

    def test_return_value_has_all_required_keys(self):
        """Test that return value has all required keys."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert "title" in result
            assert "duration" in result
            assert "download_url" in result
            assert "format" in result
            assert "extension" in result
            assert "extractor" in result

    def test_return_value_types(self):
        """Test that return value has correct types."""
        with patch('navixmind.tools.media.is_blocked_domain', return_value=False), \
             patch('navixmind.tools.media.get_bridge') as mock_bridge, \
             patch('yt_dlp.YoutubeDL') as mock_ydl:

            mock_bridge.return_value.log = Mock()

            mock_instance = MagicMock()
            mock_ydl.return_value.__enter__.return_value = mock_instance
            mock_instance.extract_info.return_value = {
                "extractor": "instagram",
                "title": "Test Video",
                "duration": 60,
                "webpage_url": "https://instagram.com/p/test",
                "formats": [
                    {"vcodec": "h264", "acodec": "aac", "url": "https://cdn.com/video.mp4", "ext": "mp4"}
                ]
            }

            result = download_media("https://instagram.com/p/test")

            assert isinstance(result, dict)
            assert isinstance(result["title"], str)
            assert isinstance(result["duration"], (int, float))
            assert isinstance(result["download_url"], str)
            assert isinstance(result["format"], str)
            assert isinstance(result["extension"], str)
            assert isinstance(result["extractor"], str)
