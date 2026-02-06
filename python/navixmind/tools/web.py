"""
Web Tools - Fetch and parse web content
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse

from ..bridge import ToolError, get_bridge


def web_fetch(
    url: str,
    extract_mode: str = "text"
) -> dict:
    """
    Fetch a webpage and extract content.

    Args:
        url: URL to fetch
        extract_mode: "text", "html", or "links"

    Returns:
        Dict with extracted content
    """
    # Validate URL
    parsed = urlparse(url)
    if not parsed.scheme:
        url = "https://" + url

    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 "
                          "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
        }

        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()

        soup = BeautifulSoup(response.content, 'lxml')

        # Remove script and style elements
        for element in soup(['script', 'style', 'nav', 'footer', 'header']):
            element.decompose()

        if extract_mode == "html":
            return {
                "url": url,
                "html": str(soup),
                "status": response.status_code
            }

        elif extract_mode == "links":
            links = []
            for a in soup.find_all('a', href=True):
                href = a['href']
                text = a.get_text(strip=True)
                if href.startswith('http'):
                    links.append({"url": href, "text": text})
            return {
                "url": url,
                "links": links[:50],  # Limit to 50 links
                "status": response.status_code
            }

        else:  # text mode
            # Get main content
            main_content = soup.find('main') or soup.find('article') or soup.body

            if main_content:
                text = main_content.get_text(separator='\n', strip=True)
            else:
                text = soup.get_text(separator='\n', strip=True)

            # Clean up excessive whitespace
            lines = [line.strip() for line in text.split('\n') if line.strip()]
            text = '\n'.join(lines)

            # Truncate if too long
            if len(text) > 50000:
                text = text[:50000] + "\n\n[Content truncated...]"

            return {
                "url": url,
                "title": soup.title.string if soup.title else None,
                "text": text,
                "status": response.status_code
            }

    except requests.Timeout:
        raise ToolError(f"Request to {url} timed out")
    except requests.RequestException as e:
        raise ToolError(f"Failed to fetch {url}: {str(e)}")


def headless_browser(
    url: str,
    wait_seconds: int = 5,
    extract_selector: str = None
) -> dict:
    """
    Load a page in headless browser (for JS-heavy sites).

    This delegates to Flutter's WebView implementation.

    Args:
        url: URL to load
        wait_seconds: Time to wait for JS
        extract_selector: CSS selector to extract

    Returns:
        Dict with extracted content
    """
    bridge = get_bridge()

    result = bridge.call_native(
        "headless_browser",
        {
            "url": url,
            "wait_seconds": wait_seconds,
            "extract_selector": extract_selector
        },
        timeout_ms=(wait_seconds + 10) * 1000
    )

    return result
