"""Tests for the self_improve function in agent.py"""

import json
import unittest
from unittest.mock import patch, MagicMock

from navixmind.agent import self_improve, handle_request


class TestSelfImprove(unittest.TestCase):
    """Tests for self_improve()"""

    def setUp(self):
        """Set up mocks for bridge."""
        self.bridge_patcher = patch("navixmind.agent.get_bridge")
        self.mock_get_bridge = self.bridge_patcher.start()
        self.mock_bridge = MagicMock()
        self.mock_get_bridge.return_value = self.mock_bridge

    def tearDown(self):
        self.bridge_patcher.stop()

    def test_no_api_key_returns_error(self):
        """Should return error when API key is empty."""
        result = self_improve(
            conversation=[{"role": "user", "content": "hi"}],
            current_prompt="test prompt",
            api_key="",
        )

        self.assertTrue(result["error"])
        self.assertIn("API key", result["message"])

    def test_empty_conversation_returns_error(self):
        """Should return error when conversation is empty."""
        result = self_improve(
            conversation=[],
            current_prompt="test prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("No conversation", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_successful_improvement(self, mock_post):
        """Should return improved prompt on success."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [
                {"type": "thinking", "thinking": "Let me analyze..."},
                {"type": "text", "text": "You are an improved assistant."},
            ],
            "usage": {
                "input_tokens": 100,
                "output_tokens": 50,
            },
        }
        mock_post.return_value = mock_response

        result = self_improve(
            conversation=[
                {"role": "user", "content": "hello"},
                {"role": "assistant", "content": "hi there"},
            ],
            current_prompt="You are a basic assistant.",
            api_key="sk-test-key",
        )

        self.assertNotIn("error", result)
        self.assertEqual(result["improved_prompt"], "You are an improved assistant.")

    @patch("navixmind.agent.requests.post")
    def test_skips_thinking_blocks(self, mock_post):
        """Should only extract text blocks, not thinking blocks."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [
                {"type": "thinking", "thinking": "Deep thought here..."},
                {"type": "text", "text": "Part 1"},
                {"type": "thinking", "thinking": "More thinking..."},
                {"type": "text", "text": "Part 2"},
            ],
            "usage": {"input_tokens": 100, "output_tokens": 50},
        }
        mock_post.return_value = mock_response

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="old prompt",
            api_key="sk-test-key",
        )

        self.assertEqual(result["improved_prompt"], "Part 1\nPart 2")

    @patch("navixmind.agent.requests.post")
    def test_api_error_status_code(self, mock_post):
        """Should return error on non-200 API response."""
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.json.return_value = {
            "error": {"message": "Invalid API key"}
        }
        mock_post.return_value = mock_response

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-bad-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("Invalid API key", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_timeout_returns_error(self, mock_post):
        """Should return error on timeout."""
        import requests
        mock_post.side_effect = requests.Timeout("Connection timed out")

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("timed out", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_network_error_returns_error(self, mock_post):
        """Should return error on network failure."""
        import requests
        mock_post.side_effect = requests.ConnectionError("No connection")

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("Network error", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_empty_response_content(self, mock_post):
        """Should return error when API returns empty content."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [],
            "usage": {"input_tokens": 10, "output_tokens": 0},
        }
        mock_post.return_value = mock_response

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("No improved prompt", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_only_thinking_blocks_returns_error(self, mock_post):
        """Should return error when response has only thinking, no text."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [
                {"type": "thinking", "thinking": "I thought a lot"},
            ],
            "usage": {"input_tokens": 100, "output_tokens": 50},
        }
        mock_post.return_value = mock_response

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("No improved prompt", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_records_usage(self, mock_post):
        """Should record API usage for cost tracking."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [{"type": "text", "text": "improved prompt"}],
            "usage": {"input_tokens": 500, "output_tokens": 200},
        }
        mock_post.return_value = mock_response

        self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        # Bridge _send should be called for record_usage
        self.mock_bridge._send.assert_called()
        call_args = self.mock_bridge._send.call_args[0][0]
        self.assertEqual(call_args["method"], "record_usage")
        self.assertEqual(call_args["params"]["input_tokens"], 500)
        self.assertEqual(call_args["params"]["output_tokens"], 200)

    @patch("navixmind.agent.requests.post")
    def test_uses_correct_api_params(self, mock_post):
        """Should use extended thinking, temperature 1, and 180s timeout."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [{"type": "text", "text": "improved"}],
            "usage": {"input_tokens": 10, "output_tokens": 10},
        }
        mock_post.return_value = mock_response

        self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        call_kwargs = mock_post.call_args
        body = call_kwargs.kwargs.get("json") or call_kwargs[1].get("json")
        timeout = call_kwargs.kwargs.get("timeout") or call_kwargs[1].get("timeout")

        self.assertEqual(body["thinking"]["type"], "enabled")
        self.assertEqual(body["thinking"]["budget_tokens"], 10000)
        self.assertEqual(body["temperature"], 1)
        self.assertEqual(timeout, 180)

    @patch("navixmind.agent.requests.post")
    def test_whitespace_only_response_returns_error(self, mock_post):
        """Should return error when improved prompt is whitespace only."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "content": [{"type": "text", "text": "   \n  \n  "}],
            "usage": {"input_tokens": 10, "output_tokens": 5},
        }
        mock_post.return_value = mock_response

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("No improved prompt", result["message"])

    @patch("navixmind.agent.requests.post")
    def test_unexpected_exception_returns_error(self, mock_post):
        """Should handle unexpected exceptions gracefully."""
        mock_post.side_effect = RuntimeError("Something unexpected")

        result = self_improve(
            conversation=[{"role": "user", "content": "test"}],
            current_prompt="prompt",
            api_key="sk-test-key",
        )

        self.assertTrue(result["error"])
        self.assertIn("Unexpected error", result["message"])


class TestHandleRequestSelfImprove(unittest.TestCase):
    """Tests for handle_request routing to self_improve."""

    def setUp(self):
        self.bridge_patcher = patch("navixmind.agent.get_bridge")
        self.mock_get_bridge = self.bridge_patcher.start()
        self.mock_bridge = MagicMock()
        self.mock_get_bridge.return_value = self.mock_bridge

    def tearDown(self):
        self.bridge_patcher.stop()

    @patch("navixmind.agent.self_improve")
    def test_routes_to_self_improve(self, mock_self_improve):
        """handle_request should dispatch 'self_improve' method correctly."""
        mock_self_improve.return_value = {"improved_prompt": "better prompt"}

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-123",
            "method": "self_improve",
            "params": {
                "conversation": [{"role": "user", "content": "hi"}],
                "current_prompt": "old prompt",
                "api_key": "sk-test",
            },
        })

        response = json.loads(handle_request(request))

        self.assertEqual(response["id"], "test-123")
        self.assertEqual(response["result"]["improved_prompt"], "better prompt")
        mock_self_improve.assert_called_once_with(
            conversation=[{"role": "user", "content": "hi"}],
            current_prompt="old prompt",
            api_key="sk-test",
        )

    @patch("navixmind.agent.self_improve")
    def test_routes_with_missing_params_uses_defaults(self, mock_self_improve):
        """Should use empty defaults for missing params."""
        mock_self_improve.return_value = {"error": True, "message": "No conversation"}

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-456",
            "method": "self_improve",
            "params": {},
        })

        response = json.loads(handle_request(request))

        self.assertEqual(response["id"], "test-456")
        mock_self_improve.assert_called_once_with(
            conversation=[],
            current_prompt="",
            api_key="",
        )

    def test_unknown_method_returns_error(self):
        """Unknown methods should return method-not-found error."""
        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-789",
            "method": "nonexistent_method",
            "params": {},
        })

        response = json.loads(handle_request(request))

        self.assertIn("error", response)
        self.assertEqual(response["error"]["code"], -32601)


if __name__ == "__main__":
    unittest.main()
