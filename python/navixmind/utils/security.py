"""
Security utilities - Path sanitization and domain blocking
"""

import os
from urllib.parse import urlparse


# Blocked domains (YouTube and variants)
BLOCKED_DOMAINS = [
    'youtube.com',
    'www.youtube.com',
    'youtu.be',
    'm.youtube.com',
    'youtube-nocookie.com',
    'music.youtube.com',
    'gaming.youtube.com',
]

# Allowed path roots for file access
ALLOWED_PATH_ROOTS = [
    '/data/data/ai.navixmind/',
    '/storage/emulated/',
    '/sdcard/',
]


class SecurityError(Exception):
    """Security violation error."""
    pass


def sanitize_path(path: str) -> str:
    """
    Sanitize a file path to prevent directory traversal.

    Args:
        path: Path to sanitize

    Returns:
        Resolved absolute path

    Raises:
        SecurityError: If path is outside allowed directories
    """
    # Resolve any ../ tricks
    resolved = os.path.realpath(path)

    # Check debug mode
    debug_mode = os.environ.get('NAVIXMIND_DEBUG', 'false').lower() == 'true'
    if debug_mode:
        # In debug mode, allow more paths for development
        return resolved

    # Verify it's in allowed directories
    if not any(resolved.startswith(root) for root in ALLOWED_PATH_ROOTS):
        raise SecurityError(f"Path not allowed: {path}")

    return resolved


def is_blocked_domain(url: str) -> bool:
    """
    Check if a URL is from a blocked domain.

    Args:
        url: URL to check

    Returns:
        True if domain is blocked
    """
    # Check debug mode - allow all in debug
    debug_mode = os.environ.get('NAVIXMIND_DEBUG', 'false').lower() == 'true'
    if debug_mode:
        return False

    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()

        # Remove www. prefix for comparison
        if domain.startswith('www.'):
            domain = domain[4:]

        # Check exact match and subdomain match
        for blocked in BLOCKED_DOMAINS:
            blocked_clean = blocked.replace('www.', '')
            if domain == blocked_clean or domain.endswith('.' + blocked_clean):
                return True

        return False

    except Exception:
        # If we can't parse the URL, allow it through
        # (will likely fail on the actual request anyway)
        return False


def sanitize_filename(filename: str) -> str:
    """
    Sanitize a filename to remove potentially dangerous characters.

    Args:
        filename: Filename to sanitize

    Returns:
        Sanitized filename
    """
    # Remove path separators
    filename = filename.replace('/', '_').replace('\\', '_')

    # Remove other dangerous characters
    dangerous = ['..', '\x00', '\n', '\r']
    for char in dangerous:
        filename = filename.replace(char, '_')

    # Limit length
    if len(filename) > 255:
        name, ext = os.path.splitext(filename)
        filename = name[:255 - len(ext)] + ext

    return filename
