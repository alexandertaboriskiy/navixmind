"""
Tests for LocalLLMClient and offline model support in the agent module.

Tests cover:
- LocalLLMClient message conversion (Claude → OpenAI format)
- Tool schema conversion (Claude → OpenAI function calling)
- _select_model with offline models
- Garbled output / parsing fallback
- process_query with offline model selection
- OFFLINE_SYSTEM_PROMPT usage
- Max token capping per model size
"""

import json
import pytest
from unittest.mock import Mock, patch, MagicMock


class TestLocalLLMClientToolConversion:
    """Tests for _convert_tools_to_openai static method."""

    def test_convert_single_tool(self):
        from navixmind.agent import LocalLLMClient

        claude_tools = [{
            "name": "python_execute",
            "description": "Run Python code",
            "input_schema": {
                "type": "object",
                "properties": {
                    "code": {"type": "string", "description": "Python code"}
                },
                "required": ["code"]
            }
        }]

        result = LocalLLMClient._convert_tools_to_openai(claude_tools)

        assert len(result) == 1
        assert result[0]["type"] == "function"
        assert result[0]["function"]["name"] == "python_execute"
        assert result[0]["function"]["description"] == "Run Python code"
        assert result[0]["function"]["parameters"]["type"] == "object"
        assert "code" in result[0]["function"]["parameters"]["properties"]

    def test_convert_multiple_tools(self):
        from navixmind.agent import LocalLLMClient

        claude_tools = [
            {"name": "tool_a", "description": "A", "input_schema": {"type": "object", "properties": {}}},
            {"name": "tool_b", "description": "B", "input_schema": {"type": "object", "properties": {}}},
            {"name": "tool_c", "description": "C", "input_schema": {"type": "object", "properties": {}}},
        ]

        result = LocalLLMClient._convert_tools_to_openai(claude_tools)
        assert len(result) == 3
        assert [t["function"]["name"] for t in result] == ["tool_a", "tool_b", "tool_c"]

    def test_convert_empty_tools(self):
        from navixmind.agent import LocalLLMClient

        result = LocalLLMClient._convert_tools_to_openai([])
        assert result == []

    def test_convert_tool_missing_schema(self):
        from navixmind.agent import LocalLLMClient

        claude_tools = [{"name": "test", "description": "desc"}]
        result = LocalLLMClient._convert_tools_to_openai(claude_tools)

        assert result[0]["function"]["parameters"] == {"type": "object", "properties": {}}


class TestLocalLLMClientMessageConversion:
    """Tests for _convert_messages method."""

    def test_simple_text_messages(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there!"},
        ]

        result = client._convert_messages(messages, "You are a bot.")

        assert result[0] == {"role": "system", "content": "You are a bot."}
        assert result[1] == {"role": "user", "content": "Hello"}
        assert result[2] == {"role": "assistant", "content": "Hi there!"}

    def test_assistant_with_tool_use_blocks(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {"role": "user", "content": "calc 2+2"},
            {
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "Let me calculate..."},
                    {
                        "type": "tool_use",
                        "id": "call_123",
                        "name": "python_execute",
                        "input": {"code": "print(2+2)"}
                    },
                ]
            },
        ]

        result = client._convert_messages(messages, "system")
        # System + user + assistant (flattened to plain text, no tool_calls)
        assert len(result) == 3
        assert result[2]["role"] == "assistant"
        assert "tool_calls" not in result[2]
        # Should contain <tool_call> text with the tool call JSON
        assert "<tool_call>" in result[2]["content"]
        assert "python_execute" in result[2]["content"]
        assert "Let me calculate..." in result[2]["content"]
        # Verify the embedded JSON is parseable
        import re
        tc_match = re.search(r'<tool_call>\s*(\{.*?\})\s*</tool_call>', result[2]["content"], re.DOTALL)
        assert tc_match is not None
        call_data = json.loads(tc_match.group(1))
        assert call_data["name"] == "python_execute"
        assert call_data["arguments"] == {"code": "print(2+2)"}

    def test_tool_result_messages(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "call_123",
                        "content": "4"
                    }
                ]
            }
        ]

        result = client._convert_messages(messages, "system")
        # System + user message (flattened, not tool role)
        assert len(result) == 2
        assert result[1]["role"] == "user"
        assert "[Tool Result]" in result[1]["content"]
        assert "call_123" in result[1]["content"]
        assert "4" in result[1]["content"]

    def test_empty_messages(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        result = client._convert_messages([], "system prompt")

        assert len(result) == 1
        assert result[0]["role"] == "system"


class TestLocalLLMClientCreateMessage:
    """Tests for create_message method."""

    def test_successful_generation(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        mock_response = {
            "stop_reason": "end_turn",
            "content": [{"type": "text", "text": "Hello!"}],
            "usage": {"input_tokens": 5, "output_tokens": 3}
        }

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps(mock_response)
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
            )

        assert result["stop_reason"] == "end_turn"
        assert result["content"][0]["text"] == "Hello!"

    def test_garbled_json_fallback(self):
        """Garbled response should be treated as plain text."""
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": "This is not valid JSON {{{garbled"
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
            )

        assert result["stop_reason"] == "end_turn"
        assert "garbled" in result["content"][0]["text"]

    def test_garbled_tool_call_fallback(self):
        """Invalid tool call input should be converted to text."""
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        bad_response = {
            "stop_reason": "tool_use",
            "content": [
                {
                    "type": "tool_use",
                    "id": "call_bad",
                    "name": "python_execute",
                    "input": "not a dict"  # Should be a dict
                }
            ],
            "usage": {"input_tokens": 5, "output_tokens": 10}
        }

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps(bad_response)
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "test"}],
            )

        # Should convert to text and change stop_reason
        assert result["stop_reason"] == "end_turn"
        assert result["content"][0]["type"] == "text"
        assert "trouble" in result["content"][0]["text"]

    def test_timeout_raises_api_error(self):
        """Timeout should raise APIError."""
        from navixmind.agent import LocalLLMClient, APIError

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.side_effect = TimeoutError("timed out")

            with pytest.raises(APIError) as exc:
                client.create_message(
                    messages=[{"role": "user", "content": "Hi"}],
                )
            assert exc.value.status_code == 408

    def test_max_tokens_capped_by_model_size(self):
        """Max tokens should be capped by OFFLINE_MAX_TOKENS."""
        from navixmind.agent import LocalLLMClient, OFFLINE_MAX_TOKENS

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps({
                    "stop_reason": "end_turn",
                    "content": [],
                    "usage": {}
                })
            }

            client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
                max_tokens=99999,  # Way over limit
            )

            # Check the actual max_tokens passed in args
            call_args = mock_bridge.call_native.call_args
            args_dict = call_args[0][1]  # Second positional arg (args dict)
            assert args_dict['max_tokens'] == OFFLINE_MAX_TOKENS['qwen2.5-coder-0.5b']


class TestSelectModelOffline:
    """Tests for _select_model with offline model preferences."""

    def test_qwen_model_returns_as_is(self):
        from navixmind.agent import _select_model

        model, reason = _select_model("test query", {"preferred_model": "qwen2.5-coder-0.5b"})
        assert model == "qwen2.5-coder-0.5b"
        assert "offline" in reason.lower()

    def test_qwen_15b_model_returns_as_is(self):
        from navixmind.agent import _select_model

        model, reason = _select_model("test query", {"preferred_model": "qwen2.5-coder-1.5b"})
        assert model == "qwen2.5-coder-1.5b"

    def test_qwen_3b_model_returns_as_is(self):
        from navixmind.agent import _select_model

        model, reason = _select_model("test query", {"preferred_model": "qwen2.5-coder-3b"})
        assert model == "qwen2.5-coder-3b"

    def test_qwen_overrides_cost_threshold(self):
        """Offline model should be selected even when cost budget is high."""
        from navixmind.agent import _select_model

        model, _ = _select_model("test", {
            "preferred_model": "qwen2.5-coder-0.5b",
            "cost_percent_used": 95,
        })
        assert model == "qwen2.5-coder-0.5b"

    def test_non_qwen_falls_through(self):
        """Non-qwen model should use normal selection logic."""
        from navixmind.agent import _select_model, DEFAULT_MODEL

        model, _ = _select_model("analyze this data", {"preferred_model": "auto"})
        # "analyze" is a complex pattern, should use default model
        assert model == DEFAULT_MODEL


class TestProcessQueryOffline:
    """Tests for process_query with offline model selection."""

    def test_offline_model_no_api_key_allowed(self):
        """Process query should work without API key when offline model selected."""
        from navixmind.agent import process_query

        with patch('navixmind.agent.get_api_key', return_value=None), \
             patch('navixmind.agent.get_bridge') as mock_bridge_fn, \
             patch('navixmind.agent.get_session') as mock_session_fn:

            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps({
                    "stop_reason": "end_turn",
                    "content": [{"type": "text", "text": "Hello from offline!"}],
                    "usage": {"input_tokens": 5, "output_tokens": 3}
                })
            }

            mock_session = MagicMock()
            mock_session.get_context_for_llm.return_value = []
            mock_session_fn.return_value = mock_session

            result = process_query(
                user_query="Hello",
                context={"preferred_model": "qwen2.5-coder-0.5b"},
            )

        assert result.get("error") is not True
        assert "Hello from offline!" in result.get("content", "")

    def test_no_api_key_no_offline_model_returns_error(self):
        """Without API key and without offline model, should return error."""
        from navixmind.agent import process_query

        with patch('navixmind.agent.get_api_key', return_value=None), \
             patch('navixmind.agent.get_bridge') as mock_bridge_fn, \
             patch('navixmind.agent.get_session') as mock_session_fn:

            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_session = MagicMock()
            mock_session_fn.return_value = mock_session

            result = process_query(
                user_query="Hello",
                context={"preferred_model": "auto"},
            )

        assert result.get("error") is True
        assert "API key" in result.get("content", "")

    def test_offline_model_uses_simplified_system_prompt(self):
        """Offline models should use OFFLINE_SYSTEM_PROMPT."""
        from navixmind.agent import process_query, OFFLINE_SYSTEM_PROMPT

        captured_system = None

        class FakeLocalClient:
            model = "qwen2.5-coder-0.5b"

            def create_message(self, messages, system, tools=None, max_tokens=2048):
                nonlocal captured_system
                captured_system = system
                return {
                    "stop_reason": "end_turn",
                    "content": [{"type": "text", "text": "Done"}],
                    "usage": {"input_tokens": 5, "output_tokens": 3}
                }

        with patch('navixmind.agent.get_api_key', return_value=None), \
             patch('navixmind.agent.get_bridge') as mock_bridge_fn, \
             patch('navixmind.agent.get_session') as mock_session_fn, \
             patch('navixmind.agent.LocalLLMClient', return_value=FakeLocalClient()):

            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_session = MagicMock()
            mock_session.get_context_for_llm.return_value = []
            mock_session_fn.return_value = mock_session

            process_query(
                user_query="Hello",
                context={"preferred_model": "qwen2.5-coder-0.5b"},
            )

        assert captured_system == OFFLINE_SYSTEM_PROMPT


class TestOfflineSystemPrompt:
    """Tests for OFFLINE_SYSTEM_PROMPT content."""

    def test_prompt_is_compact(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT, SYSTEM_PROMPT

        # Compact prompt should be much shorter than the full SYSTEM_PROMPT.
        assert len(OFFLINE_SYSTEM_PROMPT) > 0
        assert len(OFFLINE_SYSTEM_PROMPT) < len(SYSTEM_PROMPT)
        # Target: under 3000 chars (~750 tokens) including tool defs, FFmpeg patterns, and example
        assert len(OFFLINE_SYSTEM_PROMPT) < 3000

    def test_prompt_lists_key_tools(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        assert "python_execute" in OFFLINE_SYSTEM_PROMPT
        assert "ffmpeg_process" in OFFLINE_SYSTEM_PROMPT
        assert "smart_crop" in OFFLINE_SYSTEM_PROMPT
        assert "read_file" in OFFLINE_SYSTEM_PROMPT
        assert "write_file" in OFFLINE_SYSTEM_PROMPT
        assert "ocr_image" in OFFLINE_SYSTEM_PROMPT
        assert "read_pdf" in OFFLINE_SYSTEM_PROMPT
        assert "create_pdf" in OFFLINE_SYSTEM_PROMPT

    def test_prompt_mentions_navixmind(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        assert "NavixMind" in OFFLINE_SYSTEM_PROMPT

    def test_prompt_includes_tool_call_format(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        # Must show <tool_call> format so model knows how to call tools
        assert "<tool_call>" in OFFLINE_SYSTEM_PROMPT
        assert "</tool_call>" in OFFLINE_SYSTEM_PROMPT

    def test_prompt_includes_one_shot_example(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        # One-shot example helps small models follow the format
        assert "print(2+2)" in OFFLINE_SYSTEM_PROMPT

    def test_prompt_instructs_tool_calling(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        assert "Always call a tool" in OFFLINE_SYSTEM_PROMPT
        assert "Never" in OFFLINE_SYSTEM_PROMPT


class TestOfflineMaxTokens:
    """Tests for max token capping per model size."""

    def test_05b_max_tokens(self):
        from navixmind.agent import OFFLINE_MAX_TOKENS

        assert OFFLINE_MAX_TOKENS['qwen2.5-coder-0.5b'] == 512

    def test_15b_max_tokens(self):
        from navixmind.agent import OFFLINE_MAX_TOKENS

        assert OFFLINE_MAX_TOKENS['qwen2.5-coder-1.5b'] == 1024

    def test_3b_max_tokens(self):
        from navixmind.agent import OFFLINE_MAX_TOKENS

        assert OFFLINE_MAX_TOKENS['qwen2.5-coder-3b'] == 1024


class TestOfflineToolsSchema:
    """Tests for OFFLINE_TOOLS_SCHEMA — compact tool set for small models."""

    def test_offline_tools_are_subset(self):
        from navixmind.tools import TOOLS_SCHEMA, OFFLINE_TOOLS_SCHEMA

        full_names = {t["name"] for t in TOOLS_SCHEMA}
        offline_names = {t["name"] for t in OFFLINE_TOOLS_SCHEMA}
        # All offline tools must exist in the full schema
        assert offline_names.issubset(full_names)

    def test_offline_tools_are_compact(self):
        import json
        from navixmind.tools import TOOLS_SCHEMA, OFFLINE_TOOLS_SCHEMA

        full_size = len(json.dumps(TOOLS_SCHEMA))
        offline_size = len(json.dumps(OFFLINE_TOOLS_SCHEMA))
        # Offline tools should be smaller than full schema
        assert offline_size < full_size
        # Should have all offline-capable tools (no web/google tools)
        assert len(OFFLINE_TOOLS_SCHEMA) <= 15

    def test_offline_tools_include_essentials(self):
        from navixmind.tools import OFFLINE_TOOLS_SCHEMA

        names = {t["name"] for t in OFFLINE_TOOLS_SCHEMA}
        assert "python_execute" in names
        assert "ffmpeg_process" in names
        assert "smart_crop" in names
        assert "ocr_image" in names
        assert "read_file" in names
        assert "write_file" in names
        assert "file_info" in names
        assert "read_pdf" in names
        assert "create_pdf" in names

    def test_offline_tools_exclude_online_only(self):
        from navixmind.tools import OFFLINE_TOOLS_SCHEMA

        names = {t["name"] for t in OFFLINE_TOOLS_SCHEMA}
        # Tools that require internet or Google auth should NOT be in offline schema
        assert "web_fetch" not in names
        assert "headless_browser" not in names
        assert "download_media" not in names
        assert "google_calendar" not in names
        assert "gmail" not in names

    def test_offline_prompt_includes_ffmpeg_patterns(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        # Must include key FFmpeg usage patterns so model knows how to use the tool
        assert "trim" in OFFLINE_SYSTEM_PROMPT
        assert "resize" in OFFLINE_SYSTEM_PROMPT
        assert "extract_audio" in OFFLINE_SYSTEM_PROMPT
        assert "hue=s=0" in OFFLINE_SYSTEM_PROMPT

    def test_offline_prompt_warns_against_python_for_ffmpeg(self):
        from navixmind.agent import OFFLINE_SYSTEM_PROMPT

        # Must tell model NOT to use python_execute for FFmpeg
        assert "ffmpeg_process" in OFFLINE_SYSTEM_PROMPT
        assert "FORBIDDEN" in OFFLINE_SYSTEM_PROMPT

    def test_offline_tools_have_valid_schemas(self):
        from navixmind.tools import OFFLINE_TOOLS_SCHEMA

        for tool in OFFLINE_TOOLS_SCHEMA:
            assert "name" in tool
            assert "description" in tool
            assert "input_schema" in tool
            schema = tool["input_schema"]
            assert schema["type"] == "object"
            assert "properties" in schema
            assert "required" in schema

    def test_cloud_system_prompt_has_all_tools(self):
        from navixmind.agent import SYSTEM_PROMPT

        # The cloud prompt should mention all key tools
        assert "python_execute" in SYSTEM_PROMPT
        assert "ffmpeg_process" in SYSTEM_PROMPT
        assert "ocr_image" in SYSTEM_PROMPT
        assert "read_file" in SYSTEM_PROMPT
        assert "write_file" in SYSTEM_PROMPT
        assert "web_fetch" in SYSTEM_PROMPT
        assert "create_pdf" in SYSTEM_PROMPT
        assert "smart_crop" in SYSTEM_PROMPT

    def test_cloud_prompt_has_forbidden_modules(self):
        from navixmind.agent import SYSTEM_PROMPT

        assert "subprocess" in SYSTEM_PROMPT
        assert "os" in SYSTEM_PROMPT
        assert "sys" in SYSTEM_PROMPT
        assert "FORBIDDEN" in SYSTEM_PROMPT


class TestLocalLLMClientConversionEdgeCases:
    """Edge cases for message conversion."""

    def test_multiple_tool_uses_in_single_assistant_message(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {"role": "user", "content": "Do two things"},
            {
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "I'll do both."},
                    {
                        "type": "tool_use",
                        "id": "call_1",
                        "name": "python_execute",
                        "input": {"code": "print(1)"}
                    },
                    {
                        "type": "tool_use",
                        "id": "call_2",
                        "name": "read_file",
                        "input": {"path": "/tmp/a.txt"}
                    },
                ]
            },
        ]

        result = client._convert_messages(messages, "system")
        # System + user + assistant (flattened to plain text)
        assert len(result) == 3
        assistant_msg = result[2]
        assert assistant_msg["role"] == "assistant"
        assert "tool_calls" not in assistant_msg
        # Both tool calls should appear as <tool_call> blocks
        assert assistant_msg["content"].count("<tool_call>") == 2
        assert "python_execute" in assistant_msg["content"]
        assert "read_file" in assistant_msg["content"]
        # Text content should also be present
        assert "I'll do both." in assistant_msg["content"]

    def test_tool_result_with_json_content(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        json_content = json.dumps({"output": "42", "success": True})
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "call_abc",
                        "content": json_content
                    }
                ]
            }
        ]

        result = client._convert_messages(messages, "system")
        assert len(result) == 2  # system + user (not tool)
        assert result[1]["role"] == "user"
        assert "[Tool Result]" in result[1]["content"]
        assert "call_abc" in result[1]["content"]
        assert json_content in result[1]["content"]

    def test_tool_result_with_empty_content(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "call_empty",
                        "content": ""
                    }
                ]
            }
        ]

        result = client._convert_messages(messages, "system")
        assert len(result) == 2
        assert result[1]["role"] == "user"
        assert "[Tool Result]" in result[1]["content"]
        assert "call_empty" in result[1]["content"]

    def test_tool_result_with_error(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "call_err",
                        "content": "NameError: name 'foo' is not defined",
                        "is_error": True
                    }
                ]
            }
        ]

        result = client._convert_messages(messages, "system")
        assert len(result) == 2
        assert result[1]["role"] == "user"
        assert "[Tool Error]" in result[1]["content"]
        assert "call_err" in result[1]["content"]
        assert "NameError" in result[1]["content"]

    def test_assistant_message_with_only_tool_use_no_text(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {"role": "user", "content": "Do it"},
            {
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "call_only",
                        "name": "python_execute",
                        "input": {"code": "print('hi')"}
                    },
                ]
            },
        ]

        result = client._convert_messages(messages, "system")
        assistant_msg = result[2]
        assert assistant_msg["role"] == "assistant"
        assert "tool_calls" not in assistant_msg
        assert "<tool_call>" in assistant_msg["content"]
        assert "python_execute" in assistant_msg["content"]

    def test_nested_tool_input_with_complex_json(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        complex_input = {
            "code": "data = [1, 2, 3]",
            "metadata": {
                "tags": ["test", "nested"],
                "config": {"depth": 3, "items": [{"key": "val"}]}
            }
        }
        messages = [
            {"role": "user", "content": "Complex task"},
            {
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "call_complex",
                        "name": "python_execute",
                        "input": complex_input
                    },
                ]
            },
        ]

        result = client._convert_messages(messages, "system")
        assistant_msg = result[2]
        assert "tool_calls" not in assistant_msg
        # Extract the JSON from inside <tool_call> tags
        import re
        tc_match = re.search(r'<tool_call>\s*(\{.*?\})\s*</tool_call>', assistant_msg["content"], re.DOTALL)
        assert tc_match is not None
        call_data = json.loads(tc_match.group(1))
        assert call_data["name"] == "python_execute"
        assert call_data["arguments"] == complex_input
        assert call_data["arguments"]["metadata"]["config"]["items"][0]["key"] == "val"

    def test_full_tool_loop_conversation(self):
        """Test a full tool-call → tool-result → response cycle is flattened correctly."""
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")
        messages = [
            {"role": "user", "content": "What is 2+2?"},
            {
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "call_001",
                        "name": "python_execute",
                        "input": {"code": "print(2+2)"}
                    },
                ]
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "call_001",
                        "content": "4\n"
                    }
                ]
            },
        ]

        result = client._convert_messages(messages, "system")
        # system + user + assistant (flattened) + user (tool result as user)
        assert len(result) == 4
        assert result[0]["role"] == "system"
        assert result[1]["role"] == "user"
        assert result[1]["content"] == "What is 2+2?"
        assert result[2]["role"] == "assistant"
        assert "<tool_call>" in result[2]["content"]
        assert result[3]["role"] == "user"
        assert "[Tool Result]" in result[3]["content"]
        assert "4\n" in result[3]["content"]
        # No message should have role "tool"
        for msg in result:
            assert msg["role"] != "tool"
            assert "tool_calls" not in msg


class TestLocalLLMClientBridgeInteraction:
    """Tests for bridge call behavior."""

    def test_bridge_called_with_correct_tool_name(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps({
                    "stop_reason": "end_turn",
                    "content": [{"type": "text", "text": "ok"}],
                    "usage": {}
                })
            }

            client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
            )

            # Verify bridge was called with 'llm_generate' as tool name
            mock_bridge.call_native.assert_called_once()
            call_args = mock_bridge.call_native.call_args
            assert call_args[0][0] == 'llm_generate'

    def test_bridge_receives_serialized_messages(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps({
                    "stop_reason": "end_turn",
                    "content": [],
                    "usage": {}
                })
            }

            client.create_message(
                messages=[{"role": "user", "content": "Hello world"}],
            )

            call_args = mock_bridge.call_native.call_args
            args_dict = call_args[0][1]

            # messages_json should be a valid JSON string
            messages_parsed = json.loads(args_dict['messages_json'])
            # First message is system, second is user
            assert messages_parsed[0]['role'] == 'system'
            assert messages_parsed[1]['role'] == 'user'
            assert messages_parsed[1]['content'] == 'Hello world'

            # model_id should be set
            assert args_dict['model_id'] == 'qwen2.5-coder-0.5b'

    def test_bridge_error_propagates(self):
        from navixmind.agent import LocalLLMClient, APIError
        from navixmind.bridge import ToolError

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.side_effect = ToolError("Native engine crashed", code=-32000)

            with pytest.raises(APIError) as exc:
                client.create_message(
                    messages=[{"role": "user", "content": "crash test"}],
                )

            assert exc.value.status_code == 500
            assert "Local inference error" in str(exc.value)

    def test_empty_response_from_bridge(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            # Bridge returns empty dict for 'response' key
            mock_bridge.call_native.return_value = {
                "response": "{}"
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
            )

            # Empty dict should be returned as-is (with content sanitization)
            assert result.get('content', []) == []

    def test_null_response_from_bridge(self):
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-0.5b")

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            # Bridge returns no 'response' key — .get defaults to '{}'
            mock_bridge.call_native.return_value = {}

            result = client.create_message(
                messages=[{"role": "user", "content": "Hi"}],
            )

            # Missing 'response' key → defaults to '{}' → parsed as empty dict
            assert result.get('content', []) == []


class TestParseToolCallsFromText:
    """Tests for _parse_tool_calls_from_text — Hermes format extraction."""

    def test_single_tool_call_in_text(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"name": "python_execute", "arguments": {"code": "print(2+2)"}}\n</tool_call>'
            }],
            "usage": {"input_tokens": 10, "output_tokens": 20}
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert len(result["content"]) == 1
        assert result["content"][0]["type"] == "tool_use"
        assert result["content"][0]["name"] == "python_execute"
        assert result["content"][0]["input"] == {"code": "print(2+2)"}

    def test_tool_call_with_surrounding_text(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": 'Let me calculate that.\n<tool_call>\n{"name": "python_execute", "arguments": {"code": "print(42)"}}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert len(result["content"]) == 2
        assert result["content"][0]["type"] == "text"
        assert "Let me calculate" in result["content"][0]["text"]
        assert result["content"][1]["type"] == "tool_use"
        assert result["content"][1]["name"] == "python_execute"

    def test_multiple_tool_calls(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"name": "python_execute", "arguments": {"code": "x=1"}}\n</tool_call>\n<tool_call>\n{"name": "read_file", "arguments": {"path": "/tmp/a.txt"}}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_uses = [b for b in result["content"] if b["type"] == "tool_use"]
        assert len(tool_uses) == 2
        assert tool_uses[0]["name"] == "python_execute"
        assert tool_uses[1]["name"] == "read_file"

    def test_no_tool_calls_returns_unchanged(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{"type": "text", "text": "Here is the answer: 42"}],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "end_turn"
        assert result["content"][0]["text"] == "Here is the answer: 42"

    def test_already_tool_use_stop_reason_skipped(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "tool_use",
            "content": [{"type": "tool_use", "id": "call_1", "name": "test", "input": {}}],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        # Should not modify already-parsed tool calls
        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["type"] == "tool_use"

    def test_invalid_json_in_tool_call_tag(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\nnot valid json\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        # Invalid JSON should be left as text
        assert result["stop_reason"] == "end_turn"
        assert result["content"][0]["type"] == "text"

    def test_tool_call_with_string_arguments(self):
        """Arguments might be a JSON string instead of object."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"name": "python_execute", "arguments": "{\\"code\\": \\"print(1)\\"}"}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["name"] == "python_execute"
        assert result["content"][0]["input"] == {"code": "print(1)"}

    def test_tool_call_missing_name(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"arguments": {"code": "print(1)"}}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        # Missing name — should not be converted to tool_use
        assert result["stop_reason"] == "end_turn"

    def test_non_dict_arguments_fallback(self):
        """If arguments is not a string or dict, fall back to empty dict."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"name": "file_info", "arguments": [1, 2, 3]}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["input"] == {}

    def test_tool_call_ids_are_unique(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"name": "python_execute", "arguments": {"code": "a=1"}}\n</tool_call>\n<tool_call>\n{"name": "python_execute", "arguments": {"code": "b=2"}}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        tool_uses = [b for b in result["content"] if b["type"] == "tool_use"]
        ids = [t["id"] for t in tool_uses]
        assert len(set(ids)) == len(ids), "Tool call IDs must be unique"

    def test_mixed_text_and_tool_use_blocks(self):
        """Non-text blocks should be preserved as-is."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [
                {"type": "tool_use", "id": "existing", "name": "read_file", "input": {"path": "/tmp"}},
                {"type": "text", "text": '<tool_call>\n{"name": "python_execute", "arguments": {"code": "x=1"}}\n</tool_call>'},
            ],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["type"] == "tool_use"
        assert result["content"][0]["name"] == "read_file"
        assert result["content"][1]["type"] == "tool_use"
        assert result["content"][1]["name"] == "python_execute"

    def test_whitespace_variations_in_tool_call_tag(self):
        from navixmind.agent import LocalLLMClient

        # Various whitespace patterns the model might produce
        for text in [
            '<tool_call>{"name":"python_execute","arguments":{"code":"1"}}</tool_call>',
            '<tool_call>\n  {"name":"python_execute","arguments":{"code":"1"}}  \n</tool_call>',
            '<tool_call>\n\n{"name":"python_execute","arguments":{"code":"1"}}\n\n</tool_call>',
        ]:
            response = {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": text}],
            }
            result = LocalLLMClient._parse_tool_calls_from_text(response)
            assert result["stop_reason"] == "tool_use", f"Failed for: {text}"
            assert result["content"][0]["name"] == "python_execute"

    def test_end_to_end_with_bridge(self):
        """Full pipeline: bridge returns text with <tool_call>, should be parsed."""
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-3b")

        bridge_response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": 'I\'ll calculate that for you.\n<tool_call>\n{"name": "python_execute", "arguments": {"code": "print(2+2)"}}\n</tool_call>'
            }],
            "usage": {"input_tokens": 100, "output_tokens": 50}
        }

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps(bridge_response)
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "What is 2+2?"}],
            )

        assert result["stop_reason"] == "tool_use"
        tool_uses = [b for b in result["content"] if b["type"] == "tool_use"]
        assert len(tool_uses) == 1
        assert tool_uses[0]["name"] == "python_execute"
        assert tool_uses[0]["input"]["code"] == "print(2+2)"
        # Text before tool call should be preserved
        text_blocks = [b for b in result["content"] if b["type"] == "text"]
        assert len(text_blocks) == 1
        assert "calculate" in text_blocks[0]["text"]

    def test_empty_content_list(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)
        assert result["content"] == []
        assert result["stop_reason"] == "end_turn"

    def test_raw_json_tool_call(self):
        """Model outputs raw JSON without <tool_call> tags."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "python_execute", "arguments": {"code": "print(2+2)"}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert len(result["content"]) == 1
        assert result["content"][0]["type"] == "tool_use"
        assert result["content"][0]["name"] == "python_execute"
        assert result["content"][0]["input"] == {"code": "print(2+2)"}

    def test_raw_json_with_surrounding_text(self):
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": 'Let me calculate.\n{"name": "python_execute", "arguments": {"code": "print(42)"}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_uses = [b for b in result["content"] if b["type"] == "tool_use"]
        assert len(tool_uses) == 1
        assert tool_uses[0]["name"] == "python_execute"

    def test_raw_json_end_to_end_with_bridge(self):
        """Full pipeline: model returns raw JSON tool call as text."""
        from navixmind.agent import LocalLLMClient

        client = LocalLLMClient("qwen2.5-coder-3b")

        bridge_response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "python_execute", "arguments": {"code": "print(2+2)"}}'
            }],
            "usage": {"input_tokens": 277, "output_tokens": 95}
        }

        with patch('navixmind.agent.get_bridge') as mock_bridge_fn:
            mock_bridge = MagicMock()
            mock_bridge_fn.return_value = mock_bridge
            mock_bridge.call_native.return_value = {
                "response": json.dumps(bridge_response)
            }

            result = client.create_message(
                messages=[{"role": "user", "content": "What is 2+2?"}],
            )

        assert result["stop_reason"] == "tool_use"
        tool_uses = [b for b in result["content"] if b["type"] == "tool_use"]
        assert len(tool_uses) == 1
        assert tool_uses[0]["name"] == "python_execute"
        assert tool_uses[0]["input"]["code"] == "print(2+2)"

    def test_raw_json_with_nested_objects(self):
        """Model outputs ffmpeg_process with nested params object — must be parsed."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "ffmpeg_process", "arguments": {"input_path": "video.mp4", "output_path": "trimmed.mp4", "operation": "trim", "params": {"start": "00:00:05", "duration": "10"}}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert len(result["content"]) == 1
        assert result["content"][0]["type"] == "tool_use"
        assert result["content"][0]["name"] == "ffmpeg_process"
        assert result["content"][0]["input"]["operation"] == "trim"
        assert result["content"][0]["input"]["params"]["start"] == "00:00:05"
        assert result["content"][0]["input"]["params"]["duration"] == "10"

    def test_raw_json_with_deeply_nested_objects(self):
        """Handle multiple levels of nested braces."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "python_execute", "arguments": {"code": "d = {\\\"a\\\": {\\\"b\\\": 1}}\\nprint(d)"}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["type"] == "tool_use"
        assert result["content"][0]["name"] == "python_execute"

    def test_raw_json_ffmpeg_filter_with_nested_params(self):
        """ffmpeg_process filter operation with nested vf params."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "ffmpeg_process", "arguments": {"input_path": "video.mp4", "output_path": "bw.mp4", "operation": "filter", "params": {"vf": "hue=s=0"}}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["name"] == "ffmpeg_process"
        assert result["content"][0]["input"]["params"]["vf"] == "hue=s=0"

    def test_tool_call_tag_with_nested_objects(self):
        """<tool_call> tags with nested params should also work."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '<tool_call>\n{"name": "ffmpeg_process", "arguments": {"input_path": "v.mp4", "output_path": "out.mp4", "operation": "trim", "params": {"start": "0", "end": "30"}}}\n</tool_call>'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        assert result["content"][0]["name"] == "ffmpeg_process"
        assert result["content"][0]["input"]["params"]["end"] == "30"

    def test_malformed_json_missing_one_closing_brace(self):
        """3B model often drops the outermost closing brace."""
        from navixmind.agent import LocalLLMClient

        # Real example from device logs: 3 opening braces, only 2 closing
        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "ffmpeg_process", "arguments": {"input_path": "VID-20260131-WA0004.mp4", "output_path": "bright_and_loud.mp4", "operation": "trim", "params": {"start": "0", "duration": "6"}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_block = [b for b in result["content"] if b.get("type") == "tool_use"][0]
        assert tool_block["name"] == "ffmpeg_process"
        assert tool_block["input"]["operation"] == "trim"
        assert tool_block["input"]["params"]["start"] == "0"
        assert tool_block["input"]["params"]["duration"] == "6"

    def test_malformed_json_missing_two_closing_braces(self):
        """Handle deeply truncated JSON with 2 missing closing braces."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "ffmpeg_process", "arguments": {"input_path": "v.mp4", "output_path": "out.mp4", "operation": "filter", "params": {"vf": "eq=brightness=0.06"}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_block = [b for b in result["content"] if b.get("type") == "tool_use"][0]
        assert tool_block["name"] == "ffmpeg_process"
        assert tool_block["input"]["params"]["vf"] == "eq=brightness=0.06"

    def test_malformed_json_with_preceding_text(self):
        """Malformed JSON with text before it should still be repaired."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": 'I will process this video for you.\n{"name": "ffmpeg_process", "arguments": {"input_path": "v.mp4", "output_path": "out.mp4", "operation": "trim", "params": {"start": "0"}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_block = [b for b in result["content"] if b.get("type") == "tool_use"][0]
        assert tool_block["name"] == "ffmpeg_process"
        # Preceding text should be preserved
        text_blocks = [b for b in result["content"] if b.get("type") == "text"]
        assert any("process this video" in b["text"] for b in text_blocks)

    def test_malformed_json_simple_tool_no_nesting(self):
        """Simple tool call (no nested params) with missing closing brace."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "python_execute", "arguments": {"code": "print(2+2)"}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_block = [b for b in result["content"] if b.get("type") == "tool_use"][0]
        assert tool_block["name"] == "python_execute"
        assert tool_block["input"]["code"] == "print(2+2)"

    def test_complete_json_still_works_after_repair_logic(self):
        """Complete (well-formed) JSON should still work correctly."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"name": "python_execute", "arguments": {"code": "print(42)"}}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "tool_use"
        tool_block = [b for b in result["content"] if b.get("type") == "tool_use"][0]
        assert tool_block["name"] == "python_execute"
        assert tool_block["input"]["code"] == "print(42)"

    def test_malformed_json_not_repaired_if_no_name(self):
        """Incomplete JSON without 'name' key should NOT be repaired."""
        from navixmind.agent import LocalLLMClient

        response = {
            "stop_reason": "end_turn",
            "content": [{
                "type": "text",
                "text": '{"foo": "bar", "arguments": {"x": 1}'
            }],
        }

        result = LocalLLMClient._parse_tool_calls_from_text(response)

        assert result["stop_reason"] == "end_turn"  # No tool found

    def test_extract_json_objects_repair_directly(self):
        """Directly test _extract_json_objects with malformed input."""
        from navixmind.agent import _extract_json_objects

        # Missing 1 closing brace (depth=1 at end)
        text = '{"name": "ffmpeg_process", "arguments": {"operation": "trim", "params": {"start": "0"}}'
        results = _extract_json_objects(text)
        assert len(results) == 1
        import json
        parsed = json.loads(results[0])
        assert parsed["name"] == "ffmpeg_process"
        assert parsed["arguments"]["params"]["start"] == "0"

    def test_extract_json_objects_repair_missing_two_braces(self):
        """Directly test _extract_json_objects with 2 missing braces."""
        from navixmind.agent import _extract_json_objects

        text = '{"name": "x", "arguments": {"a": {"b": "c"}'
        results = _extract_json_objects(text)
        assert len(results) == 1
        import json
        parsed = json.loads(results[0])
        assert parsed["arguments"]["a"]["b"] == "c"
