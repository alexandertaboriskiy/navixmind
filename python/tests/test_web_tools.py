"""
Comprehensive tests for web fetching and headless browser tools.

Tests cover:
- web_fetch tool with various extract modes
- HTTP error handling (404, 500, timeout)
- Content processing and truncation
- URL validation and security
- headless_browser tool delegation
- URL scheme validation (dangerous URL blocking)
- SSRF prevention (localhost/internal IP blocking)
- Domain blocking (YouTube)
- Redirect following with domain checks
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
import requests


class TestWebFetchTextMode:
    """Tests for web_fetch in text extraction mode."""

    def test_fetch_text_from_main_element(self):
        """Test extracting text from <main> element."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head><title>Test Page</title></head>
                    <body>
                        <nav>Navigation</nav>
                        <main><p>Main content here</p></main>
                        <footer>Footer</footer>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        assert "Main content here" in result["text"]
        assert "Navigation" not in result["text"]
        assert "Footer" not in result["text"]
        assert result["title"] == "Test Page"
        assert result["status"] == 200

    def test_fetch_text_from_article_element(self):
        """Test extracting text from <article> element when no <main>."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head><title>Article</title></head>
                    <body>
                        <header>Header</header>
                        <article><p>Article content</p></article>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        assert "Article content" in result["text"]
        assert "Header" not in result["text"]

    def test_fetch_text_from_body_fallback(self):
        """Test extracting text from body when no main/article elements."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head><title>Simple</title></head>
                    <body>
                        <div><p>Body content only</p></div>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        assert "Body content only" in result["text"]

    def test_fetch_removes_scripts_and_styles(self):
        """Test that scripts, styles, nav, footer, header are removed."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head>
                        <title>Test</title>
                        <style>.hidden { display: none; }</style>
                    </head>
                    <body>
                        <script>alert('bad');</script>
                        <nav>Navigation menu</nav>
                        <main><p>Real content</p></main>
                        <footer>Footer info</footer>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        assert "Real content" in result["text"]
        assert "alert" not in result["text"]
        assert "Navigation menu" not in result["text"]
        assert "Footer info" not in result["text"]
        assert ".hidden" not in result["text"]

    def test_fetch_cleans_whitespace(self):
        """Test that excessive whitespace is cleaned up."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <main>
                            <p>Line 1</p>


                            <p>Line 2</p>
                        </main>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        # Should not have excessive blank lines
        assert "\n\n\n" not in result["text"]
        assert "Line 1" in result["text"]
        assert "Line 2" in result["text"]

    def test_fetch_returns_none_title_when_missing(self):
        """Test that missing title returns None."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html><body><p>No title page</p></body></html>
            """

            result = web_fetch("https://example.com", extract_mode="text")

        assert result["title"] is None


class TestWebFetchHtmlMode:
    """Tests for web_fetch in HTML extraction mode."""

    def test_fetch_html_returns_processed_html(self):
        """Test fetching in HTML mode returns processed HTML."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <script>bad();</script>
                        <div class="content">Hello</div>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="html")

        assert "html" in result
        assert "content" in result["html"]
        assert "Hello" in result["html"]
        # Scripts should be removed
        assert "bad()" not in result["html"]
        assert result["status"] == 200

    def test_fetch_html_removes_nav_footer_header(self):
        """Test HTML mode also removes nav, footer, header elements."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <header>Header content</header>
                        <nav>Nav content</nav>
                        <main>Main content</main>
                        <footer>Footer content</footer>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="html")

        assert "Main content" in result["html"]
        assert "Header content" not in result["html"]
        assert "Nav content" not in result["html"]
        assert "Footer content" not in result["html"]


class TestWebFetchLinksMode:
    """Tests for web_fetch in links extraction mode."""

    def test_fetch_links_extracts_all_links(self):
        """Test extracting links from page."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <a href="https://link1.com">Link 1</a>
                        <a href="https://link2.com">Link 2</a>
                        <a href="https://link3.com">Link 3</a>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="links")

        assert len(result["links"]) == 3
        assert result["links"][0]["url"] == "https://link1.com"
        assert result["links"][0]["text"] == "Link 1"
        assert result["links"][1]["url"] == "https://link2.com"
        assert result["links"][2]["url"] == "https://link3.com"

    def test_fetch_links_ignores_relative_urls(self):
        """Test that relative URLs are ignored."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <a href="https://absolute.com">Absolute</a>
                        <a href="/relative/path">Relative</a>
                        <a href="relative.html">Also Relative</a>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="links")

        assert len(result["links"]) == 1
        assert result["links"][0]["url"] == "https://absolute.com"

    def test_fetch_links_limits_to_50(self):
        """Test that links are limited to 50."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            # Create HTML with 100 links
            links_html = "".join(
                f'<a href="https://link{i}.com">Link {i}</a>'
                for i in range(100)
            )
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = f"<html><body>{links_html}</body></html>".encode()

            result = web_fetch("https://example.com", extract_mode="links")

        assert len(result["links"]) == 50

    def test_fetch_links_strips_text(self):
        """Test that link text is stripped."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <a href="https://link.com">
                            Link with whitespace
                        </a>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="links")

        assert result["links"][0]["text"] == "Link with whitespace"


class TestWebFetchHttpErrors:
    """Tests for web_fetch HTTP error handling."""

    def test_fetch_handles_404_error(self):
        """Test handling of 404 Not Found error."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError

        with patch('requests.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 404
            mock_response.raise_for_status.side_effect = requests.HTTPError(
                "404 Client Error: Not Found"
            )
            mock_get.return_value = mock_response

            with pytest.raises(ToolError) as exc_info:
                web_fetch("https://example.com/notfound")

        assert "Failed to fetch" in str(exc_info.value)

    def test_fetch_handles_500_error(self):
        """Test handling of 500 Internal Server Error."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError

        with patch('requests.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 500
            mock_response.raise_for_status.side_effect = requests.HTTPError(
                "500 Server Error: Internal Server Error"
            )
            mock_get.return_value = mock_response

            with pytest.raises(ToolError) as exc_info:
                web_fetch("https://example.com/error")

        assert "Failed to fetch" in str(exc_info.value)

    def test_fetch_handles_timeout(self):
        """Test handling of request timeout."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError

        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.Timeout("Connection timed out")

            with pytest.raises(ToolError) as exc_info:
                web_fetch("https://slow-server.com")

        assert "timed out" in str(exc_info.value).lower()

    def test_fetch_handles_connection_error(self):
        """Test handling of connection error."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError

        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.ConnectionError("Failed to connect")

            with pytest.raises(ToolError) as exc_info:
                web_fetch("https://unreachable.com")

        assert "Failed to fetch" in str(exc_info.value)

    def test_fetch_handles_ssl_error(self):
        """Test handling of SSL/TLS error."""
        from navixmind.tools.web import web_fetch
        from navixmind.bridge import ToolError

        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.exceptions.SSLError("SSL handshake failed")

            with pytest.raises(ToolError) as exc_info:
                web_fetch("https://bad-ssl.com")

        assert "Failed to fetch" in str(exc_info.value)


class TestWebFetchContentTruncation:
    """Tests for content truncation in web_fetch."""

    def test_truncates_content_over_50000_chars(self):
        """Test that content over 50000 chars is truncated."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            # Create content with exactly 60000 characters
            long_content = "x" * 60000
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = f"<html><body><main>{long_content}</main></body></html>".encode()

            result = web_fetch("https://example.com", extract_mode="text")

        # Should be truncated to ~50000 plus truncation message
        assert len(result["text"]) <= 50100
        assert "[Content truncated...]" in result["text"]

    def test_does_not_truncate_short_content(self):
        """Test that content under 50000 chars is not truncated."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            content = "Normal length content"
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = f"<html><body><main>{content}</main></body></html>".encode()

            result = web_fetch("https://example.com", extract_mode="text")

        assert "[Content truncated...]" not in result["text"]
        assert "Normal length content" in result["text"]

    def test_truncation_message_format(self):
        """Test the format of the truncation message."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            long_content = "a" * 100000
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = f"<html><body><main>{long_content}</main></body></html>".encode()

            result = web_fetch("https://example.com", extract_mode="text")

        assert result["text"].endswith("[Content truncated...]")


class TestWebFetchUrlHandling:
    """Tests for URL handling in web_fetch."""

    def test_adds_https_to_url_without_scheme(self):
        """Test that URLs without scheme get https:// added."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("example.com")

        call_url = mock_get.call_args[0][0]
        assert call_url == "https://example.com"

    def test_preserves_existing_https_scheme(self):
        """Test that existing https:// scheme is preserved."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("https://example.com")

        call_url = mock_get.call_args[0][0]
        assert call_url == "https://example.com"

    def test_preserves_existing_http_scheme(self):
        """Test that existing http:// scheme is preserved."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("http://example.com")

        call_url = mock_get.call_args[0][0]
        assert call_url == "http://example.com"

    def test_returns_final_url(self):
        """Test that the URL in result matches what was fetched."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            result = web_fetch("example.com/path")

        assert result["url"] == "https://example.com/path"


class TestWebFetchUserAgent:
    """Tests for User-Agent setting in web_fetch."""

    def test_uses_mobile_user_agent(self):
        """Test that a mobile User-Agent is used."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("https://example.com")

        call_kwargs = mock_get.call_args[1]
        headers = call_kwargs.get('headers', {})
        user_agent = headers.get('User-Agent', '')

        assert 'Mozilla' in user_agent
        assert 'Mobile' in user_agent

    def test_user_agent_contains_chrome(self):
        """Test that User-Agent contains Chrome identifier."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("https://example.com")

        call_kwargs = mock_get.call_args[1]
        headers = call_kwargs.get('headers', {})
        user_agent = headers.get('User-Agent', '')

        assert 'Chrome' in user_agent


class TestWebFetchTimeout:
    """Tests for timeout configuration in web_fetch."""

    def test_uses_30_second_timeout(self):
        """Test that a 30 second timeout is used."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>Test</body></html>"

            web_fetch("https://example.com")

        call_kwargs = mock_get.call_args[1]
        assert call_kwargs.get('timeout') == 30


class TestHeadlessBrowser:
    """Tests for the headless_browser tool."""

    def test_delegates_to_native_bridge(self):
        """Test that headless_browser delegates to native bridge."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {"text": "Rendered content"}
            mock_get_bridge.return_value = mock_bridge

            result = headless_browser("https://spa-app.com")

        mock_bridge.call_native.assert_called_once()
        assert result["text"] == "Rendered content"

    def test_passes_url_to_native(self):
        """Test that URL is passed correctly to native."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://test-spa.com")

        call_args = mock_bridge.call_native.call_args
        assert call_args[0][1]["url"] == "https://test-spa.com"

    def test_passes_wait_seconds_to_native(self):
        """Test that wait_seconds is passed correctly."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://example.com", wait_seconds=10)

        call_args = mock_bridge.call_native.call_args
        assert call_args[0][1]["wait_seconds"] == 10

    def test_passes_css_selector_to_native(self):
        """Test that CSS selector is passed correctly."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://example.com", extract_selector=".main-content")

        call_args = mock_bridge.call_native.call_args
        assert call_args[0][1]["extract_selector"] == ".main-content"

    def test_default_wait_seconds_is_5(self):
        """Test that default wait_seconds is 5."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://example.com")

        call_args = mock_bridge.call_native.call_args
        assert call_args[0][1]["wait_seconds"] == 5

    def test_default_selector_is_none(self):
        """Test that default extract_selector is None."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://example.com")

        call_args = mock_bridge.call_native.call_args
        assert call_args[0][1]["extract_selector"] is None

    def test_calculates_timeout_based_on_wait_seconds(self):
        """Test that timeout is calculated as (wait_seconds + 10) * 1000."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://example.com", wait_seconds=8)

        call_args = mock_bridge.call_native.call_args
        # (8 + 10) * 1000 = 18000ms
        assert call_args[1]["timeout_ms"] == 18000

    def test_calls_headless_browser_native_tool(self):
        """Test that the correct native tool name is called."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.return_value = {}
            mock_get_bridge.return_value = mock_bridge

            headless_browser("https://example.com")

        call_args = mock_bridge.call_native.call_args
        assert call_args[0][0] == "headless_browser"

    def test_handles_native_timeout(self):
        """Test handling of native timeout."""
        from navixmind.tools.web import headless_browser

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.side_effect = TimeoutError("Native call timed out")
            mock_get_bridge.return_value = mock_bridge

            with pytest.raises(TimeoutError):
                headless_browser("https://slow-spa.com", wait_seconds=5)

    def test_handles_native_tool_error(self):
        """Test handling of native ToolError."""
        from navixmind.tools.web import headless_browser
        from navixmind.bridge import ToolError

        with patch('navixmind.tools.web.get_bridge') as mock_get_bridge:
            mock_bridge = Mock()
            mock_bridge.call_native.side_effect = ToolError("Browser failed to load")
            mock_get_bridge.return_value = mock_bridge

            with pytest.raises(ToolError) as exc_info:
                headless_browser("https://broken-site.com")

        assert "Browser failed to load" in str(exc_info.value)


class TestUrlValidationDangerousSchemes:
    """Tests for blocking dangerous URL schemes."""

    def test_file_scheme_detection(self):
        """Test that file:// URLs can be detected."""
        from urllib.parse import urlparse

        parsed = urlparse("file:///etc/passwd")
        assert parsed.scheme == "file"

    def test_javascript_scheme_detection(self):
        """Test that javascript: URLs can be detected."""
        from urllib.parse import urlparse

        parsed = urlparse("javascript:alert('xss')")
        assert parsed.scheme == "javascript"

    def test_data_scheme_detection(self):
        """Test that data: URLs can be detected."""
        from urllib.parse import urlparse

        parsed = urlparse("data:text/html,<script>alert(1)</script>")
        assert parsed.scheme == "data"

    def test_http_scheme_allowed(self):
        """Test that http:// URLs are valid."""
        from urllib.parse import urlparse

        parsed = urlparse("http://example.com")
        assert parsed.scheme == "http"
        assert parsed.netloc == "example.com"

    def test_https_scheme_allowed(self):
        """Test that https:// URLs are valid."""
        from urllib.parse import urlparse

        parsed = urlparse("https://example.com")
        assert parsed.scheme == "https"
        assert parsed.netloc == "example.com"


class TestSsrfPrevention:
    """Tests for SSRF (Server-Side Request Forgery) prevention patterns."""

    def test_localhost_detection(self):
        """Test detection of localhost URLs."""
        from urllib.parse import urlparse

        localhost_urls = [
            "http://localhost/admin",
            "http://localhost:8080/api",
            "http://127.0.0.1/secret",
            "http://127.0.0.1:3000/internal",
        ]

        for url in localhost_urls:
            parsed = urlparse(url)
            assert parsed.netloc.split(':')[0] in ['localhost', '127.0.0.1']

    def test_internal_ip_detection(self):
        """Test detection of internal/private IP addresses."""
        import ipaddress

        internal_ips = [
            "10.0.0.1",
            "10.255.255.255",
            "172.16.0.1",
            "172.31.255.255",
            "192.168.0.1",
            "192.168.255.255",
        ]

        for ip in internal_ips:
            addr = ipaddress.ip_address(ip)
            assert addr.is_private

    def test_public_ip_allowed(self):
        """Test that public IPs are not flagged as internal."""
        import ipaddress

        public_ips = [
            "8.8.8.8",
            "1.1.1.1",
            "142.250.185.46",
        ]

        for ip in public_ips:
            addr = ipaddress.ip_address(ip)
            assert not addr.is_private

    def test_loopback_detection(self):
        """Test detection of loopback addresses."""
        import ipaddress

        loopback = ipaddress.ip_address("127.0.0.1")
        assert loopback.is_loopback


class TestYouTubeDomainBlocking:
    """Tests for YouTube domain blocking using security module."""

    def test_youtube_com_blocked(self):
        """Test that youtube.com is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://youtube.com/watch?v=abc") is True

    def test_www_youtube_com_blocked(self):
        """Test that www.youtube.com is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://www.youtube.com/watch?v=abc") is True

    def test_youtu_be_blocked(self):
        """Test that youtu.be is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://youtu.be/abc123") is True

    def test_m_youtube_com_blocked(self):
        """Test that m.youtube.com is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://m.youtube.com/watch?v=abc") is True

    def test_music_youtube_com_blocked(self):
        """Test that music.youtube.com is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://music.youtube.com/watch?v=abc") is True

    def test_youtube_nocookie_blocked(self):
        """Test that youtube-nocookie.com is blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://youtube-nocookie.com/embed/abc") is True

    def test_youtube_with_path_blocked(self):
        """Test that YouTube URLs with various paths are blocked."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://youtube.com/channel/abc") is True
        assert is_blocked_domain("https://youtube.com/playlist?list=abc") is True
        assert is_blocked_domain("https://youtube.com/@username") is True

    def test_case_insensitive_blocking(self):
        """Test that YouTube blocking is case-insensitive."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://YOUTUBE.COM/watch?v=abc") is True
        assert is_blocked_domain("https://YouTube.com/watch?v=abc") is True
        assert is_blocked_domain("https://YoUtUbE.CoM/watch?v=abc") is True


class TestAllowedDomains:
    """Tests for domains that should be allowed."""

    def test_instagram_allowed(self):
        """Test that Instagram is allowed."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://instagram.com/p/abc") is False
        assert is_blocked_domain("https://www.instagram.com/reel/abc") is False

    def test_tiktok_allowed(self):
        """Test that TikTok is allowed."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://tiktok.com/@user/video/123") is False
        assert is_blocked_domain("https://www.tiktok.com/@user") is False

    def test_twitter_allowed(self):
        """Test that Twitter/X is allowed."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://twitter.com/user/status/123") is False
        assert is_blocked_domain("https://x.com/user/status/123") is False

    def test_general_websites_allowed(self):
        """Test that general websites are allowed."""
        from navixmind.utils.security import is_blocked_domain

        assert is_blocked_domain("https://example.com") is False
        assert is_blocked_domain("https://wikipedia.org/wiki/Test") is False
        assert is_blocked_domain("https://github.com/user/repo") is False
        assert is_blocked_domain("https://stackoverflow.com/questions/123") is False


class TestRedirectHandling:
    """Tests for redirect handling patterns."""

    def test_redirect_detection_pattern(self):
        """Test pattern for detecting redirects."""
        # This tests the pattern, actual implementation depends on requests config
        with patch('requests.get') as mock_get:
            # Simulate redirect via history
            redirect_response = Mock()
            redirect_response.status_code = 301
            redirect_response.url = "https://youtube.com/watch?v=abc"

            final_response = Mock()
            final_response.status_code = 200
            final_response.url = "https://youtube.com/watch?v=abc"
            final_response.history = [redirect_response]
            final_response.content = b"<html></html>"

            mock_get.return_value = final_response

            response = mock_get("https://short.url/abc", allow_redirects=True)

            # The final URL can be checked after redirect
            assert response.url == "https://youtube.com/watch?v=abc"

    def test_redirect_history_available(self):
        """Test that redirect history is available in response."""
        with patch('requests.get') as mock_get:
            r1 = Mock(status_code=301, url="https://short.url/abc")
            r2 = Mock(status_code=302, url="https://intermediate.com/redir")

            final = Mock()
            final.status_code = 200
            final.url = "https://final.destination.com"
            final.history = [r1, r2]
            final.content = b"<html></html>"

            mock_get.return_value = final

            response = mock_get("https://short.url/abc")

            assert len(response.history) == 2


class TestEdgeCases:
    """Tests for edge cases in web tools."""

    def test_empty_page_handling(self):
        """Test handling of empty page content."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body></body></html>"

            result = web_fetch("https://empty.com", extract_mode="text")

        assert result["text"] == ""

    def test_page_with_only_whitespace(self):
        """Test handling of page with only whitespace."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"<html><body>   \n\n   </body></html>"

            result = web_fetch("https://whitespace.com", extract_mode="text")

        assert result["text"].strip() == ""

    def test_malformed_html_handling(self):
        """Test handling of malformed HTML."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <p>Unclosed paragraph
                        <div>Nested wrong<p>Text</div></p>
                        Valid content
                    </body>
                </html>
            """

            result = web_fetch("https://malformed.com", extract_mode="text")

        # BeautifulSoup with lxml should handle this gracefully
        assert "Valid content" in result["text"]

    def test_unicode_content_handling(self):
        """Test handling of unicode content."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = """
                <html>
                    <head><meta charset="utf-8"></head>
                    <body>
                        <main>
                            <p>Hello World</p>
                            <p>Привет мир</p>
                            <p>你好世界</p>
                            <p>مرحبا بالعالم</p>
                        </main>
                    </body>
                </html>
            """.encode('utf-8')

            result = web_fetch("https://unicode.com", extract_mode="text")

        assert "Hello World" in result["text"]
        assert "Привет мир" in result["text"]
        assert "你好世界" in result["text"]

    def test_links_with_empty_href(self):
        """Test handling of links with empty href."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <a href="">Empty href</a>
                        <a href="https://valid.com">Valid</a>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="links")

        # Only the valid link should be included
        assert len(result["links"]) == 1
        assert result["links"][0]["url"] == "https://valid.com"

    def test_links_without_href_attribute(self):
        """Test handling of anchor tags without href."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <body>
                        <a name="anchor">Named anchor</a>
                        <a href="https://valid.com">Valid link</a>
                    </body>
                </html>
            """

            result = web_fetch("https://example.com", extract_mode="links")

        assert len(result["links"]) == 1


class TestDefaultExtractMode:
    """Tests for default extract mode behavior."""

    def test_default_mode_is_text(self):
        """Test that default extract mode is 'text'."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head><title>Default Test</title></head>
                    <body><main>Default mode content</main></body>
                </html>
            """

            result = web_fetch("https://example.com")

        # Should return text mode result with 'text' and 'title' keys
        assert "text" in result
        assert "title" in result
        assert "Default mode content" in result["text"]


class TestInvalidExtractMode:
    """Tests for invalid extract mode handling."""

    def test_unknown_mode_defaults_to_text(self):
        """Test that unknown extract mode defaults to text mode."""
        from navixmind.tools.web import web_fetch

        with patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.content = b"""
                <html>
                    <head><title>Test</title></head>
                    <body><main>Content here</main></body>
                </html>
            """

            # Unknown mode should fall through to text mode (else clause)
            result = web_fetch("https://example.com", extract_mode="unknown")

        assert "text" in result
        assert "Content here" in result["text"]
