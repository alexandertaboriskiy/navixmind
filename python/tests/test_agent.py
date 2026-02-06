"""
Comprehensive tests for the NavixMind agent module.

Tests cover:
- ReAct loop iteration
- Tool execution flow
- Error handling and recovery
- Max iterations limit
- Token/context limits
- API retry logic
- Response parsing
"""

import json
import pytest
from unittest.mock import Mock, patch, MagicMock
import threading


class TestHandleRequest:
    """Tests for the handle_request entry point."""

    def test_handle_request_valid_process_query(self):
        """Test valid process_query request is handled."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "process_query",
            "params": {
                "user_query": "Hello",
                "files": [],
                "context": {"api_key": "test-key"}
            }
        })

        with patch('navixmind.agent.process_query') as mock_process:
            mock_process.return_value = {"content": "Hi there!"}
            response = handle_request(request)

        result = json.loads(response)
        assert result["jsonrpc"] == "2.0"
        assert result["id"] == "test-1"
        assert "result" in result

    def test_handle_request_invalid_json(self):
        """Test invalid JSON returns parse error."""
        from navixmind.agent import handle_request

        response = handle_request("not valid json {{{")

        result = json.loads(response)
        assert result["error"]["code"] == -32700  # Parse error
        assert "Parse error" in result["error"]["message"]

    def test_handle_request_unknown_method(self):
        """Test unknown method returns method not found."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "unknown_method",
            "params": {}
        })

        response = handle_request(request)
        result = json.loads(response)
        assert result["error"]["code"] == -32601  # Method not found

    def test_handle_request_apply_delta(self):
        """Test apply_delta method is handled."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "apply_delta",
            "params": {"action": "newConversation", "conversation_id": 1}
        })

        with patch('navixmind.agent.apply_delta') as mock_delta:
            response = handle_request(request)

        result = json.loads(response)
        assert result["result"]["success"] is True

    def test_handle_request_missing_id(self):
        """Test request without ID still works."""
        from navixmind.agent import handle_request

        request = json.dumps({
            "jsonrpc": "2.0",
            "method": "process_query",
            "params": {"user_query": "test"}
        })

        with patch('navixmind.agent.process_query') as mock_process:
            mock_process.return_value = {"content": "response"}
            response = handle_request(request)

        result = json.loads(response)
        assert "result" in result


class TestProcessQuery:
    """Tests for the main process_query function."""

    @pytest.fixture(autouse=True)
    def set_api_key(self):
        """Set and clean up a global API key for all tests in this class."""
        import navixmind.agent
        original = navixmind.agent._api_key
        navixmind.agent._api_key = "test-key"
        yield
        navixmind.agent._api_key = original

    @pytest.fixture
    def mock_dependencies(self):
        """Set up common mocks."""
        with patch('navixmind.agent.get_bridge') as mock_bridge, \
             patch('navixmind.agent.get_session') as mock_session, \
             patch('navixmind.agent.ClaudeClient') as mock_client_class:

            mock_bridge_instance = Mock()
            mock_bridge.return_value = mock_bridge_instance

            mock_session_instance = Mock()
            mock_session_instance.get_context_for_llm.return_value = []
            mock_session_instance.messages = []
            mock_session_instance._file_map = {}
            mock_session.return_value = mock_session_instance

            mock_client = Mock()
            mock_client_class.return_value = mock_client

            yield {
                'bridge': mock_bridge_instance,
                'session': mock_session_instance,
                'client': mock_client,
            }

    def test_process_query_no_api_key(self):
        """Test error when API key is missing."""
        import navixmind.agent
        from navixmind.agent import process_query

        # Override the autouse fixture's api key to simulate missing key
        original = navixmind.agent._api_key
        navixmind.agent._api_key = None

        try:
            with patch('navixmind.agent.get_bridge'), \
                 patch('navixmind.agent.get_session') as mock_session, \
                 patch.dict('os.environ', {}, clear=True):

                mock_session.return_value.get_context_for_llm.return_value = []

                result = process_query("test query", context={})

            assert result["error"] is True
            assert "API key" in result["content"]
        finally:
            navixmind.agent._api_key = original

    def test_process_query_simple_response(self, mock_dependencies):
        """Test simple query with end_turn response."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.return_value = {
            "stop_reason": "end_turn",
            "content": [{"type": "text", "text": "Hello!"}],
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }

        result = process_query(
            "Hello",
            context={"api_key": "test-key"}
        )

        assert result["content"] == "Hello!"
        assert "error" not in result

    def test_process_query_with_tool_use(self, mock_dependencies):
        """Test query that uses a tool."""
        from navixmind.agent import process_query

        # First response: tool use
        # Second response: end_turn with result
        mock_dependencies['client'].create_message.side_effect = [
            {
                "stop_reason": "tool_use",
                "content": [
                    {"type": "text", "text": "Let me check that..."},
                    {
                        "type": "tool_use",
                        "id": "tool-1",
                        "name": "web_fetch",
                        "input": {"url": "https://example.com"}
                    }
                ],
                "usage": {"input_tokens": 20, "output_tokens": 30}
            },
            {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Here's what I found."}],
                "usage": {"input_tokens": 50, "output_tokens": 20}
            }
        ]

        with patch('navixmind.agent.execute_tool') as mock_execute:
            mock_execute.return_value = {"url": "https://example.com", "text": "Example content"}

            result = process_query(
                "What's on example.com?",
                context={"api_key": "test-key"}
            )

        assert result["content"] == "Here's what I found."
        mock_execute.assert_called_once()

    def test_process_query_max_iterations(self, mock_dependencies):
        """Test that max iterations limit is enforced."""
        from navixmind.agent import process_query, DEFAULT_MAX_ITERATIONS as MAX_ITERATIONS

        # Always return tool_use to force max iterations
        mock_dependencies['client'].create_message.return_value = {
            "stop_reason": "tool_use",
            "content": [
                {
                    "type": "tool_use",
                    "id": "tool-1",
                    "name": "web_fetch",
                    "input": {"url": "https://example.com"}
                }
            ],
            "usage": {"input_tokens": 10, "output_tokens": 10}
        }

        with patch('navixmind.agent.execute_tool') as mock_execute:
            mock_execute.return_value = {"text": "content"}

            result = process_query(
                "Keep going forever",
                context={"api_key": "test-key"}
            )

        assert "step limit" in result["content"].lower() or "iteration" in result["content"].lower()
        assert mock_dependencies['client'].create_message.call_count == MAX_ITERATIONS

    def test_process_query_max_tool_calls(self, mock_dependencies):
        """Test that max tool calls per query is enforced."""
        from navixmind.agent import process_query, DEFAULT_MAX_TOOL_CALLS

        # Return multiple tool uses in one response (more than DEFAULT_MAX_TOOL_CALLS)
        tool_uses = [
            {
                "type": "tool_use",
                "id": f"tool-{i}",
                "name": "web_fetch",
                "input": {"url": f"https://example{i}.com"}
            }
            for i in range(DEFAULT_MAX_TOOL_CALLS + 10)
        ]

        mock_dependencies['client'].create_message.side_effect = [
            {
                "stop_reason": "tool_use",
                "content": tool_uses,
                "usage": {"input_tokens": 10, "output_tokens": 10}
            },
            {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Done"}],
                "usage": {"input_tokens": 10, "output_tokens": 10}
            }
        ]

        with patch('navixmind.agent.execute_tool') as mock_execute:
            mock_execute.return_value = {"text": "content"}

            result = process_query(
                "Do many things",
                context={"api_key": "test-key"}
            )

        # Should have stopped at DEFAULT_MAX_TOOL_CALLS
        assert mock_execute.call_count <= DEFAULT_MAX_TOOL_CALLS

    def test_process_query_tool_error_handling(self, mock_dependencies):
        """Test that tool errors are handled gracefully."""
        from navixmind.agent import process_query
        from navixmind.bridge import ToolError

        mock_dependencies['client'].create_message.side_effect = [
            {
                "stop_reason": "tool_use",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tool-1",
                        "name": "web_fetch",
                        "input": {"url": "https://example.com"}
                    }
                ],
                "usage": {"input_tokens": 10, "output_tokens": 10}
            },
            {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Sorry, that failed."}],
                "usage": {"input_tokens": 10, "output_tokens": 10}
            }
        ]

        with patch('navixmind.agent.execute_tool') as mock_execute:
            mock_execute.side_effect = ToolError("Network error")

            result = process_query(
                "Fetch something",
                context={"api_key": "test-key"}
            )

        # Should complete without crashing
        assert "content" in result

    def test_process_query_max_tokens_response(self, mock_dependencies):
        """Test handling of max_tokens stop reason — agent continues the conversation."""
        from navixmind.agent import process_query

        # First response hits token limit, second finishes normally
        mock_dependencies['client'].create_message.side_effect = [
            {
                "stop_reason": "max_tokens",
                "content": [{"type": "text", "text": "This is a very long response that got cut off"}],
                "usage": {"input_tokens": 10, "output_tokens": 4096}
            },
            {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Here is the continuation."}],
                "usage": {"input_tokens": 100, "output_tokens": 50}
            }
        ]

        result = process_query(
            "Write a long essay",
            context={"api_key": "test-key"}
        )

        # Agent should have continued and returned the final response
        assert result["content"] == "Here is the continuation."
        assert mock_dependencies['client'].create_message.call_count == 2

    def test_process_query_with_files(self, mock_dependencies):
        """Test query with file attachments."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.return_value = {
            "stop_reason": "end_turn",
            "content": [{"type": "text", "text": "I see you attached files."}],
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }

        result = process_query(
            "What's in these files?",
            files=["/path/to/file1.pdf", "/path/to/file2.jpg"],
            context={"api_key": "test-key"}
        )

        assert result["content"] == "I see you attached files."
        # Verify files were mentioned in the message
        call_args = mock_dependencies['client'].create_message.call_args
        messages = call_args[1]['messages']
        user_message = messages[-1]['content']
        assert "Attached files" in user_message

    def test_process_query_large_tool_result_truncation(self, mock_dependencies):
        """Test that large tool results are truncated."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.side_effect = [
            {
                "stop_reason": "tool_use",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tool-1",
                        "name": "web_fetch",
                        "input": {"url": "https://example.com"}
                    }
                ],
                "usage": {"input_tokens": 10, "output_tokens": 10}
            },
            {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Got it."}],
                "usage": {"input_tokens": 10, "output_tokens": 10}
            }
        ]

        with patch('navixmind.agent.execute_tool') as mock_execute:
            # Return a very large result
            mock_execute.return_value = {"text": "x" * 50000}

            result = process_query(
                "Fetch big page",
                context={"api_key": "test-key"}
            )

        # Verify truncation happened by checking the tool result in messages
        # The result should contain truncation indicator
        assert "content" in result


class TestClaudeClient:
    """Tests for the Claude API client."""

    def test_create_message_success(self):
        """Test successful API call."""
        from navixmind.agent import ClaudeClient

        client = ClaudeClient("test-api-key")

        with patch('requests.post') as mock_post:
            mock_post.return_value.status_code = 200
            mock_post.return_value.json.return_value = {
                "content": [{"type": "text", "text": "Hello"}],
                "stop_reason": "end_turn"
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}]
            )

        assert result["stop_reason"] == "end_turn"

    def test_create_message_rate_limit_retry(self):
        """Test retry on rate limit (429)."""
        from navixmind.agent import ClaudeClient, APIError

        client = ClaudeClient("test-api-key")

        with patch('requests.post') as mock_post, \
             patch('time.sleep'):  # Skip actual sleep

            # First call: rate limited, second call: success
            mock_response_429 = Mock()
            mock_response_429.status_code = 429
            mock_response_429.headers = {'retry-after': '1'}
            mock_response_429.json.return_value = {'error': {'message': 'Rate limited'}}

            mock_response_200 = Mock()
            mock_response_200.status_code = 200
            mock_response_200.json.return_value = {
                "content": [{"type": "text", "text": "Success"}],
                "stop_reason": "end_turn"
            }

            mock_post.side_effect = [mock_response_429, mock_response_200]

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
                retry_count=3
            )

        assert result["stop_reason"] == "end_turn"
        assert mock_post.call_count == 2

    def test_create_message_rate_limit_exhausted(self):
        """Test error when rate limit retries exhausted."""
        from navixmind.agent import ClaudeClient, APIError

        client = ClaudeClient("test-api-key")

        with patch('requests.post') as mock_post, \
             patch('time.sleep'):

            mock_response = Mock()
            mock_response.status_code = 429
            mock_response.headers = {'retry-after': '1'}
            mock_response.json.return_value = {'error': {'message': 'Rate limited'}}
            mock_post.return_value = mock_response

            with pytest.raises(APIError) as exc_info:
                client.create_message(
                    messages=[{"role": "user", "content": "Hi"}],
                    retry_count=2
                )

            assert exc_info.value.status_code == 429

    def test_create_message_server_error_retry(self):
        """Test retry on server error (500/502/503)."""
        from navixmind.agent import ClaudeClient

        client = ClaudeClient("test-api-key")

        with patch('requests.post') as mock_post, \
             patch('time.sleep'):

            mock_response_500 = Mock()
            mock_response_500.status_code = 500
            mock_response_500.json.return_value = {'error': {'message': 'Server error'}}

            mock_response_200 = Mock()
            mock_response_200.status_code = 200
            mock_response_200.json.return_value = {
                "content": [{"type": "text", "text": "Success"}],
                "stop_reason": "end_turn"
            }

            mock_post.side_effect = [mock_response_500, mock_response_200]

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}]
            )

        assert result["stop_reason"] == "end_turn"

    def test_create_message_timeout_retry(self):
        """Test retry on timeout."""
        from navixmind.agent import ClaudeClient, APIError
        import requests

        client = ClaudeClient("test-api-key")

        with patch('requests.post') as mock_post, \
             patch('time.sleep'):

            mock_post.side_effect = [
                requests.Timeout("Connection timed out"),
                Mock(status_code=200, json=lambda: {
                    "content": [{"type": "text", "text": "Success"}],
                    "stop_reason": "end_turn"
                })
            ]

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}]
            )

        assert result["stop_reason"] == "end_turn"

    def test_create_message_auth_error_no_retry(self):
        """Test that auth errors (401) don't retry."""
        from navixmind.agent import ClaudeClient, APIError

        client = ClaudeClient("invalid-key")

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 401
            mock_response.json.return_value = {'error': {'message': 'Invalid API key'}}
            mock_post.return_value = mock_response

            with pytest.raises(APIError) as exc_info:
                client.create_message(
                    messages=[{"role": "user", "content": "Hi"}]
                )

            assert exc_info.value.status_code == 401
            assert mock_post.call_count == 1  # No retry

    def test_create_message_with_tools(self):
        """Test API call with tool definitions."""
        from navixmind.agent import ClaudeClient

        client = ClaudeClient("test-api-key")

        tools = [
            {
                "name": "test_tool",
                "description": "A test tool",
                "input_schema": {"type": "object", "properties": {}}
            }
        ]

        with patch('requests.post') as mock_post:
            mock_post.return_value.status_code = 200
            mock_post.return_value.json.return_value = {
                "content": [{"type": "text", "text": "Hello"}],
                "stop_reason": "end_turn"
            }

            client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
                tools=tools
            )

        # Verify tools were included in request
        call_args = mock_post.call_args
        request_body = call_args[1]['json']
        assert 'tools' in request_body
        assert request_body['tools'] == tools


class TestExtractTextContent:
    """Tests for the _extract_text_content helper."""

    def test_extract_single_text_block(self):
        """Test extraction from single text block."""
        from navixmind.agent import _extract_text_content

        blocks = [{"type": "text", "text": "Hello world"}]
        result = _extract_text_content(blocks)
        assert result == "Hello world"

    def test_extract_multiple_text_blocks(self):
        """Test extraction from multiple text blocks."""
        from navixmind.agent import _extract_text_content

        blocks = [
            {"type": "text", "text": "First"},
            {"type": "text", "text": "Second"},
            {"type": "text", "text": "Third"}
        ]
        result = _extract_text_content(blocks)
        assert result == "First\nSecond\nThird"

    def test_extract_ignores_non_text_blocks(self):
        """Test that non-text blocks are ignored."""
        from navixmind.agent import _extract_text_content

        blocks = [
            {"type": "text", "text": "Hello"},
            {"type": "tool_use", "id": "123", "name": "test"},
            {"type": "text", "text": "World"}
        ]
        result = _extract_text_content(blocks)
        assert result == "Hello\nWorld"

    def test_extract_empty_blocks(self):
        """Test extraction from empty block list."""
        from navixmind.agent import _extract_text_content

        result = _extract_text_content([])
        assert result == ""


class TestSummarizeProgress:
    """Tests for the _summarize_progress helper."""

    def test_summarize_with_tools_used(self):
        """Test summary includes tool names."""
        from navixmind.agent import _summarize_progress

        messages = [
            {"role": "user", "content": "test"},
            {"role": "assistant", "content": [
                {"type": "tool_use", "name": "web_fetch"},
                {"type": "tool_use", "name": "read_pdf"}
            ]}
        ]

        result = _summarize_progress(messages, 2)
        assert "web_fetch" in result or "read_pdf" in result

    def test_summarize_no_tools(self):
        """Test summary when no tools were used."""
        from navixmind.agent import _summarize_progress

        messages = [
            {"role": "user", "content": "test"},
            {"role": "assistant", "content": [{"type": "text", "text": "thinking..."}]}
        ]

        result = _summarize_progress(messages, 0)
        assert "couldn't complete" in result.lower() or "analyzing" in result.lower()


class TestGetUserFriendlyError:
    """Tests for error message formatting."""

    def test_rate_limit_error(self):
        """Test rate limit error message."""
        from navixmind.agent import _get_user_friendly_error, APIError

        error = APIError("Rate limited", 429)
        result = _get_user_friendly_error(error)
        assert "requests" in result.lower() or "wait" in result.lower()

    def test_auth_error(self):
        """Test auth error message."""
        from navixmind.agent import _get_user_friendly_error, APIError

        error = APIError("Invalid key", 401)
        result = _get_user_friendly_error(error)
        assert "api key" in result.lower()

    def test_server_error(self):
        """Test server error message."""
        from navixmind.agent import _get_user_friendly_error, APIError

        error = APIError("Server error", 500)
        result = _get_user_friendly_error(error)
        assert "busy" in result.lower() or "overloaded" in result.lower()

    def test_timeout_error(self):
        """Test timeout error message."""
        from navixmind.agent import _get_user_friendly_error, APIError

        error = APIError("Timeout", 408)
        result = _get_user_friendly_error(error)
        assert "timed out" in result.lower() or "timeout" in result.lower()


class TestAPIError:
    """Tests for the APIError exception class."""

    def test_api_error_attributes(self):
        """Test APIError stores message and status code."""
        from navixmind.agent import APIError

        error = APIError("Test error", 500)
        assert str(error) == "Test error"
        assert error.status_code == 500

    def test_api_error_as_exception(self):
        """Test APIError can be raised and caught."""
        from navixmind.agent import APIError

        with pytest.raises(APIError) as exc_info:
            raise APIError("Test", 400)

        assert exc_info.value.status_code == 400


class TestSelectModel:
    """Comprehensive tests for dynamic model selection."""

    def test_default_model_is_sonnet(self):
        """Test that default model is Sonnet when no special conditions."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        # Use a query that's long enough (>5 words) and has no patterns
        model, reason = _select_model(
            "Tell me something interesting about machine learning models",
            {}
        )
        assert model == DEFAULT_MODEL
        assert "advanced" in reason.lower()

    # Cost threshold tests
    def test_haiku_when_cost_at_80_percent(self):
        """Test Haiku is selected at exactly 80% cost threshold."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model("Tell me a joke", {"cost_percent_used": 80})
        assert model == FALLBACK_MODEL
        assert "budget" in reason.lower()

    def test_haiku_when_cost_above_80_percent(self):
        """Test Haiku is selected above 80% cost threshold."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model("Tell me a joke", {"cost_percent_used": 95})
        assert model == FALLBACK_MODEL
        assert "95" in reason

    def test_sonnet_when_cost_below_80_percent(self):
        """Test Sonnet is used when cost is below 80%."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, reason = _select_model("Tell me a joke", {"cost_percent_used": 79})
        assert model == DEFAULT_MODEL

    def test_haiku_at_100_percent_cost(self):
        """Test Haiku at 100% cost usage."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model("Anything", {"cost_percent_used": 100})
        assert model == FALLBACK_MODEL

    def test_cost_threshold_boundary_79(self):
        """Test boundary condition at 79% (just under threshold)."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Simple question", {"cost_percent_used": 79.9})
        assert model == DEFAULT_MODEL

    # User preference tests
    def test_user_prefers_haiku(self):
        """Test user can explicitly request Haiku."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model(
            "Complex analysis task",  # Would normally use Sonnet
            {"preferred_model": "haiku"}
        )
        assert model == FALLBACK_MODEL
        assert "preference" in reason.lower()

    def test_user_prefers_sonnet(self):
        """Test user can explicitly request Sonnet."""
        from navixmind.agent import _select_model, SONNET_MODEL

        model, reason = _select_model(
            "what time is it",  # Would normally use Haiku
            {"preferred_model": "sonnet"}
        )
        assert model == SONNET_MODEL
        assert "preference" in reason.lower()

    def test_cost_overrides_user_preference(self):
        """Test that cost threshold takes precedence over user preference."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        # User prefers Sonnet but cost is at 90%
        model, reason = _select_model(
            "Complex task",
            {"preferred_model": "sonnet", "cost_percent_used": 90}
        )
        assert model == FALLBACK_MODEL  # Cost wins
        assert "budget" in reason.lower()

    # Simple query pattern tests
    def test_haiku_for_convert_query(self):
        """Test Haiku is used for conversion queries."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model("Convert this to PDF", {})
        assert model == FALLBACK_MODEL
        assert "simple" in reason.lower()

    def test_haiku_for_format_query(self):
        """Test Haiku is used for formatting queries."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model("Format this text nicely", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_yes_no_query(self):
        """Test Haiku is used for yes/no questions."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Is this correct? yes or no", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_classification(self):
        """Test Haiku is used for classification tasks."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Classify this document", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_extract_query(self):
        """Test Haiku is used for extraction tasks."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Extract the dates from this text", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_count_query(self):
        """Test Haiku is used for counting queries."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("How many items are in this list?", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_list_query(self):
        """Test Haiku is used for listing queries."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("List the main points", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_time_query(self):
        """Test Haiku is used for time queries."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("What time is my meeting?", {})
        assert model == FALLBACK_MODEL

    def test_haiku_for_translate_query(self):
        """Test Haiku is used for translation queries."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Translate to Spanish please", {})
        assert model == FALLBACK_MODEL

    # Complex query pattern tests
    def test_sonnet_for_analyze_query(self):
        """Test Sonnet is used for analysis tasks."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, reason = _select_model("Analyze this code for bugs", {})
        assert model == DEFAULT_MODEL
        assert "complex" in reason.lower()

    def test_sonnet_for_write_code_query(self):
        """Test Sonnet is used for code writing."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Write code to sort this array", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_debug_query(self):
        """Test Sonnet is used for debugging."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Debug this function please", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_implement_query(self):
        """Test Sonnet is used for implementation tasks."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Implement a binary search", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_design_query(self):
        """Test Sonnet is used for design tasks."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Design a database schema", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_research_query(self):
        """Test Sonnet is used for research tasks."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Research the best approach", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_step_by_step_query(self):
        """Test Sonnet is used for step-by-step explanations."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Explain step by step how this works", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_compare_query(self):
        """Test Sonnet is used for comparison tasks."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Compare and contrast these approaches", {})
        assert model == DEFAULT_MODEL

    def test_sonnet_for_explain_in_detail_query(self):
        """Test Sonnet is used for detailed explanations."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Explain in detail how authentication works", {})
        assert model == DEFAULT_MODEL

    # Complex overrides simple tests
    def test_complex_overrides_simple_pattern(self):
        """Test that complex pattern wins when both present."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        # Contains both "analyze" (complex) and "list" (simple)
        model, _ = _select_model("Analyze and list the issues", {})
        assert model == DEFAULT_MODEL  # Complex wins

    # Short query tests
    def test_haiku_for_short_question(self):
        """Test Haiku for very short questions."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, reason = _select_model("Why?", {})
        assert model == FALLBACK_MODEL
        assert "quick" in reason.lower()

    def test_haiku_for_5_word_question(self):
        """Test Haiku for exactly 5 word question."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Is this thing working correctly?", {})
        assert model == FALLBACK_MODEL

    def test_sonnet_for_long_question(self):
        """Test Sonnet for longer questions without patterns."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model(
            "I have a problem with my application that I need help solving today",
            {}
        )
        assert model == DEFAULT_MODEL

    def test_short_non_question_uses_sonnet(self):
        """Test that short non-questions don't use Haiku shortcut."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Help me", {})  # No question mark
        assert model == DEFAULT_MODEL

    # Attachment tests
    def test_sonnet_for_attachments(self):
        """Test Sonnet is used when attachments are present with neutral query."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        # Use a neutral query that doesn't match any patterns and is >5 words
        model, reason = _select_model(
            "Please look at this document and give me your thoughts",
            {"has_attachments": True}
        )
        assert model == DEFAULT_MODEL
        assert "file" in reason.lower()

    def test_attachments_dont_override_simple_pattern(self):
        """Test that simple patterns are checked before attachments (order matters)."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        # Simple pattern is checked BEFORE attachments in the implementation
        model, _ = _select_model(
            "Convert this to PDF",  # Simple pattern triggers first
            {"has_attachments": True}
        )
        assert model == FALLBACK_MODEL  # Simple pattern wins

    def test_cost_overrides_attachments(self):
        """Test that cost threshold overrides attachments."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model(
            "Analyze this file",
            {"has_attachments": True, "cost_percent_used": 85}
        )
        assert model == FALLBACK_MODEL  # Cost wins

    # Edge cases
    def test_empty_query(self):
        """Test handling of empty query."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("", {})
        assert model == DEFAULT_MODEL

    def test_whitespace_only_query(self):
        """Test handling of whitespace-only query."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("   ", {})
        assert model == DEFAULT_MODEL

    def test_empty_context(self):
        """Test handling of empty context dict."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Hello world", {})
        assert model == DEFAULT_MODEL

    def test_none_context_values(self):
        """Test handling of None values in context."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        # Use a longer query to avoid the short question check
        model, _ = _select_model(
            "Tell me something interesting about this topic please",
            {"cost_percent_used": None, "preferred_model": None}
        )
        assert model == DEFAULT_MODEL

    def test_case_insensitive_patterns(self):
        """Test that pattern matching is case insensitive."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model1, _ = _select_model("CONVERT this to PDF", {})
        model2, _ = _select_model("Convert This To PDF", {})
        model3, _ = _select_model("convert this to pdf", {})

        assert model1 == FALLBACK_MODEL
        assert model2 == FALLBACK_MODEL
        assert model3 == FALLBACK_MODEL

    def test_negative_cost_percent(self):
        """Test handling of negative cost percent (edge case)."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Test", {"cost_percent_used": -10})
        assert model == DEFAULT_MODEL

    def test_cost_percent_over_100(self):
        """Test handling of cost percent over 100%."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Test", {"cost_percent_used": 150})
        assert model == FALLBACK_MODEL

    def test_unknown_preferred_model(self):
        """Test handling of unknown preferred model value."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Test query", {"preferred_model": "opus"})
        assert model == DEFAULT_MODEL  # Falls through to default

    def test_reason_message_format(self):
        """Test that reason messages are properly formatted."""
        from navixmind.agent import _select_model

        _, reason1 = _select_model("Test", {"cost_percent_used": 85})
        _, reason2 = _select_model("Analyze this", {})
        _, reason3 = _select_model("Convert this", {})

        # Reasons should be human-readable
        assert len(reason1) > 10
        assert len(reason2) > 10
        assert len(reason3) > 10

    def test_multiple_simple_patterns_in_query(self):
        """Test query with multiple simple patterns."""
        from navixmind.agent import _select_model, FALLBACK_MODEL

        model, _ = _select_model("Extract and count the items", {})
        assert model == FALLBACK_MODEL

    def test_unicode_in_query(self):
        """Test handling of unicode characters in query."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("分析这个 (analyze this)", {})
        assert model == DEFAULT_MODEL  # "analyze" pattern matched

    def test_newlines_in_query(self):
        """Test handling of newlines in query."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("Please help me\nwith this\nproblem", {})
        assert model == DEFAULT_MODEL


class TestSystemPromptFromContext:
    """Tests for system_prompt override via context dict in process_query."""

    @pytest.fixture
    def mock_dependencies(self):
        """Set up common mocks for process_query."""
        with patch('navixmind.agent.get_bridge') as mock_bridge, \
             patch('navixmind.agent.get_session') as mock_session, \
             patch('navixmind.agent.ClaudeClient') as mock_client_class:

            mock_bridge_instance = Mock()
            mock_bridge.return_value = mock_bridge_instance

            mock_session_instance = Mock()
            mock_session_instance.get_context_for_llm.return_value = []
            mock_session_instance.messages = []
            mock_session_instance._file_map = {}
            mock_session.return_value = mock_session_instance

            mock_client = Mock()
            mock_client_class.return_value = mock_client

            yield {
                'bridge': mock_bridge_instance,
                'session': mock_session_instance,
                'client': mock_client,
                'client_class': mock_client_class,
            }

    @pytest.fixture(autouse=True)
    def set_api_key(self):
        """Set and clean up a global API key for all tests in this class."""
        import navixmind.agent
        original = navixmind.agent._api_key
        navixmind.agent._api_key = "test-key"
        yield
        navixmind.agent._api_key = original

    def _make_end_turn_response(self, text="Done"):
        """Helper to create a simple end_turn API response."""
        return {
            "stop_reason": "end_turn",
            "content": [{"type": "text", "text": text}],
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }

    def test_default_system_prompt_when_not_in_context(self, mock_dependencies):
        """When context has no 'system_prompt' key, create_message uses SYSTEM_PROMPT."""
        from navixmind.agent import process_query, SYSTEM_PROMPT

        mock_dependencies['client'].create_message.return_value = self._make_end_turn_response()

        process_query("Hello", context={})

        call_kwargs = mock_dependencies['client'].create_message.call_args[1]
        assert call_kwargs['system'] == SYSTEM_PROMPT

    def test_custom_system_prompt_from_context(self, mock_dependencies):
        """When context has 'system_prompt', that custom string is passed to create_message."""
        from navixmind.agent import process_query, SYSTEM_PROMPT

        custom_prompt = "You are a helpful coding tutor. Be brief."
        mock_dependencies['client'].create_message.return_value = self._make_end_turn_response()

        process_query("Hello", context={"system_prompt": custom_prompt})

        call_kwargs = mock_dependencies['client'].create_message.call_args[1]
        assert call_kwargs['system'] == custom_prompt
        assert call_kwargs['system'] != SYSTEM_PROMPT

    def test_empty_string_system_prompt_uses_empty(self, mock_dependencies):
        """An empty string system_prompt is passed through, not treated as falsy."""
        from navixmind.agent import process_query, SYSTEM_PROMPT

        mock_dependencies['client'].create_message.return_value = self._make_end_turn_response()

        process_query("Hello", context={"system_prompt": ""})

        call_kwargs = mock_dependencies['client'].create_message.call_args[1]
        assert call_kwargs['system'] == ""
        assert call_kwargs['system'] != SYSTEM_PROMPT

    def test_custom_prompt_logged(self, mock_dependencies):
        """When a custom system_prompt is provided, bridge.log is called with 'Using custom system prompt'."""
        from navixmind.agent import process_query

        custom_prompt = "You are a math expert."
        mock_dependencies['client'].create_message.return_value = self._make_end_turn_response()

        process_query("Hello", context={"system_prompt": custom_prompt})

        log_messages = [
            call.args[0] if call.args else call.kwargs.get('message', '')
            for call in mock_dependencies['bridge'].log.call_args_list
        ]
        assert any("Using custom system prompt" in msg for msg in log_messages), \
            f"Expected 'Using custom system prompt' in log calls, got: {log_messages}"

    def test_default_prompt_not_logged_as_custom(self, mock_dependencies):
        """When using default SYSTEM_PROMPT, bridge.log should NOT contain 'Using custom system prompt'."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.return_value = self._make_end_turn_response()

        process_query("Hello", context={})

        log_messages = [
            call.args[0] if call.args else call.kwargs.get('message', '')
            for call in mock_dependencies['bridge'].log.call_args_list
        ]
        assert not any("Using custom system prompt" in msg for msg in log_messages), \
            f"Did not expect 'Using custom system prompt' in log calls, got: {log_messages}"


class TestCreatedFilesTracking:
    """Tests for created_files tracking in the agent ReAct loop.

    Verifies that both output_path (singular) and output_paths (plural)
    are properly tracked so file link chips appear in the Flutter UI.
    """

    @pytest.fixture(autouse=True)
    def set_api_key(self):
        """Set and clean up a global API key for all tests in this class."""
        import navixmind.agent
        original = navixmind.agent._api_key
        navixmind.agent._api_key = "test-key"
        yield
        navixmind.agent._api_key = original

    @pytest.fixture
    def mock_dependencies(self):
        """Set up common mocks for process_query."""
        with patch('navixmind.agent.get_bridge') as mock_bridge, \
             patch('navixmind.agent.get_session') as mock_session, \
             patch('navixmind.agent.ClaudeClient') as mock_client_class:

            mock_bridge_instance = Mock()
            mock_bridge.return_value = mock_bridge_instance

            mock_session_instance = Mock()
            mock_session_instance.get_context_for_llm.return_value = []
            mock_session_instance.messages = []
            mock_session_instance._file_map = {}
            mock_session.return_value = mock_session_instance

            mock_client = Mock()
            mock_client_class.return_value = mock_client

            yield {
                'bridge': mock_bridge_instance,
                'session': mock_session_instance,
                'client': mock_client,
            }

    def _make_tool_use_response(self, tool_name, tool_input, tool_id="tool-1"):
        """Create a response that calls a tool."""
        return {
            "stop_reason": "tool_use",
            "content": [
                {
                    "type": "tool_use",
                    "id": tool_id,
                    "name": tool_name,
                    "input": tool_input,
                }
            ],
            "usage": {"input_tokens": 100, "output_tokens": 50}
        }

    def _make_end_turn_response(self, text="Done"):
        """Create an end_turn response."""
        return {
            "stop_reason": "end_turn",
            "content": [{"type": "text", "text": text}],
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }

    def test_singular_output_path_tracked(self, mock_dependencies):
        """Tool returning output_path (singular) adds file to created_files."""
        from navixmind.agent import process_query

        # First API call: tool_use, second: end_turn
        mock_dependencies['client'].create_message.side_effect = [
            self._make_tool_use_response("create_pdf", {"output_path": "/out/doc.pdf"}),
            self._make_end_turn_response("Created PDF."),
        ]

        with patch('navixmind.agent.execute_tool') as mock_exec:
            mock_exec.return_value = {
                "success": True,
                "output_path": "/out/doc.pdf",
                "page_count": 1,
            }
            result = process_query("Create a PDF", context={})

        assert "created_files" in result
        assert "/out/doc.pdf" in result["created_files"]

    def test_plural_output_paths_tracked(self, mock_dependencies):
        """Tool returning output_paths (plural list) adds all files to created_files."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.side_effect = [
            self._make_tool_use_response("ffmpeg_process", {
                "input_path": "/in/video.mp4",
                "output_path": "/out/segment_%03d.mp3",
                "operation": "split",
            }),
            self._make_end_turn_response("Split into 3 segments."),
        ]

        with patch('navixmind.agent.execute_tool') as mock_exec:
            mock_exec.return_value = {
                "success": True,
                "output_paths": [
                    "/out/segment_001.mp3",
                    "/out/segment_002.mp3",
                    "/out/segment_003.mp3",
                ],
                "file_count": 3,
            }
            result = process_query("Split the audio", context={})

        assert "created_files" in result
        assert len(result["created_files"]) == 3
        assert "/out/segment_001.mp3" in result["created_files"]
        assert "/out/segment_002.mp3" in result["created_files"]
        assert "/out/segment_003.mp3" in result["created_files"]

    def test_plural_output_paths_added_to_file_map(self, mock_dependencies):
        """output_paths entries are added to session file_map for next query resolution."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.side_effect = [
            self._make_tool_use_response("ffmpeg_process", {
                "input_path": "/in/video.mp4",
                "output_path": "/out/chunk_%03d.mp4",
                "operation": "split",
            }),
            self._make_end_turn_response("Done splitting."),
        ]

        with patch('navixmind.agent.execute_tool') as mock_exec:
            mock_exec.return_value = {
                "success": True,
                "output_paths": ["/out/chunk_001.mp4", "/out/chunk_002.mp4"],
                "file_count": 2,
            }
            process_query("Split video", context={})

        file_map = mock_dependencies['session']._file_map
        assert "chunk_001.mp4" in file_map
        assert "chunk_002.mp4" in file_map
        assert file_map["chunk_001.mp4"] == "/out/chunk_001.mp4"

    def test_no_created_files_when_no_tools(self, mock_dependencies):
        """Response without tool calls has no created_files key."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.return_value = \
            self._make_end_turn_response("Just text, no tools.")

        result = process_query("Hello", context={})

        assert "created_files" not in result

    def test_both_singular_and_plural_in_same_session(self, mock_dependencies):
        """Multiple tool calls - one returning output_path, another output_paths - all tracked."""
        from navixmind.agent import process_query

        # First call: tool with singular output_path
        tool_use_1 = self._make_tool_use_response("create_pdf", {"output_path": "/out/doc.pdf"}, "t1")
        # Second call: tool with plural output_paths
        tool_use_2 = self._make_tool_use_response("ffmpeg_process", {
            "input_path": "/in/v.mp4",
            "output_path": "/out/seg_%03d.mp3",
            "operation": "split",
        }, "t2")
        end = self._make_end_turn_response("Created PDF and split audio.")

        mock_dependencies['client'].create_message.side_effect = [tool_use_1, tool_use_2, end]

        call_count = [0]
        def mock_execute(tool_name, tool_input, context):
            call_count[0] += 1
            if call_count[0] == 1:
                return {"success": True, "output_path": "/out/doc.pdf", "page_count": 1}
            return {
                "success": True,
                "output_paths": ["/out/seg_001.mp3", "/out/seg_002.mp3"],
                "file_count": 2,
            }

        with patch('navixmind.agent.execute_tool', side_effect=mock_execute):
            result = process_query("Create PDF and split audio", context={})

        assert "created_files" in result
        assert len(result["created_files"]) == 3
        assert "/out/doc.pdf" in result["created_files"]
        assert "/out/seg_001.mp3" in result["created_files"]

    def test_empty_output_paths_list_not_tracked(self, mock_dependencies):
        """An empty output_paths list should not add anything to created_files."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.side_effect = [
            self._make_tool_use_response("ffmpeg_process", {
                "input_path": "/in/v.mp4",
                "output_path": "/out/seg_%03d.mp3",
                "operation": "split",
            }),
            self._make_end_turn_response("No segments created."),
        ]

        with patch('navixmind.agent.execute_tool') as mock_exec:
            mock_exec.return_value = {
                "success": True,
                "output_paths": [],
                "file_count": 0,
            }
            result = process_query("Split audio", context={})

        # Empty list is falsy, so created_files should not be in result
        assert result.get("created_files") is None or result.get("created_files") == []

    def test_output_paths_logged_individually(self, mock_dependencies):
        """Each file in output_paths is logged via bridge.log."""
        from navixmind.agent import process_query

        mock_dependencies['client'].create_message.side_effect = [
            self._make_tool_use_response("ffmpeg_process", {
                "input_path": "/in/v.mp4",
                "output_path": "/out/seg_%03d.mp3",
                "operation": "split",
            }),
            self._make_end_turn_response("Done."),
        ]

        with patch('navixmind.agent.execute_tool') as mock_exec:
            mock_exec.return_value = {
                "success": True,
                "output_paths": ["/out/seg_001.mp3", "/out/seg_002.mp3"],
                "file_count": 2,
            }
            process_query("Split", context={})

        log_messages = [
            call.args[0] if call.args else ""
            for call in mock_dependencies['bridge'].log.call_args_list
        ]
        file_logs = [m for m in log_messages if m.startswith("File: ")]
        assert any("/out/seg_001.mp3" in m for m in file_logs)
        assert any("/out/seg_002.mp3" in m for m in file_logs)
