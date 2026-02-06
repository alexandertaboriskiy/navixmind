"""
Media Tools - Video/audio download and processing
"""

import os
from urllib.parse import urlparse

from ..bridge import ToolError, get_bridge
from ..utils.security import is_blocked_domain


def download_media(
    url: str,
    format: str = "video"
) -> dict:
    """
    Download media from supported platforms.

    Args:
        url: URL of the media
        format: "video" or "audio"

    Returns:
        Dict with download result
    """
    import yt_dlp

    # Check for blocked domains (YouTube)
    if is_blocked_domain(url):
        raise ToolError(
            "YouTube downloads are not supported due to platform policies. "
            "Try TikTok, Instagram, or other supported platforms."
        )

    bridge = get_bridge()
    bridge.log("Extracting media info...")

    try:
        # Configure yt-dlp
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Extract info first
            info = ydl.extract_info(url, download=False)

            # Check if it redirected to YouTube
            extractor = info.get('extractor', '').lower()
            if 'youtube' in extractor:
                raise ToolError(
                    "This link redirects to YouTube, which is not supported."
                )

            final_url = info.get('webpage_url', url)
            if is_blocked_domain(final_url):
                raise ToolError(
                    "This link redirects to a blocked platform."
                )

            # Get best format
            title = info.get('title', 'download')
            duration = info.get('duration', 0)

            bridge.log(f"Found: {title} ({duration}s)")

            # Request Flutter to perform the actual download
            # (yt-dlp extraction + native download for reliability)
            formats = info.get('formats', [])

            if format == "audio":
                # Find best audio format
                audio_formats = [f for f in formats if f.get('acodec') != 'none' and f.get('vcodec') == 'none']
                if not audio_formats:
                    audio_formats = [f for f in formats if f.get('acodec') != 'none']
                best_format = audio_formats[-1] if audio_formats else formats[-1]
            else:
                # Find best video format
                video_formats = [f for f in formats if f.get('vcodec') != 'none']
                best_format = video_formats[-1] if video_formats else formats[-1]

            download_url = best_format.get('url')
            ext = best_format.get('ext', 'mp4')

            if not download_url:
                raise ToolError("Could not extract download URL")

            return {
                "title": title,
                "duration": duration,
                "download_url": download_url,
                "format": format,
                "extension": ext,
                "extractor": extractor,
            }

    except yt_dlp.DownloadError as e:
        raise ToolError(f"Failed to extract media: {str(e)}")
    except Exception as e:
        raise ToolError(f"Media download failed: {str(e)}")
