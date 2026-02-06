"""
Tests for system prompt completeness and self-improve meta-prompt quality.

Ensures the default system prompt includes all necessary tool references,
guidance sections, and error handling patterns so the agent works correctly
from the first query without needing self-improve iterations.
"""

import unittest

from navixmind.agent import SYSTEM_PROMPT, self_improve, TOOLS_SCHEMA
from navixmind.tools import TOOLS_SCHEMA as TOOLS_SCHEMA_FROM_TOOLS


class TestSystemPromptToolCoverage(unittest.TestCase):
    """Every registered tool should be mentioned in the system prompt."""

    def test_all_tool_names_in_prompt(self):
        """System prompt must reference every tool by name."""
        for tool in TOOLS_SCHEMA:
            tool_name = tool["name"]
            self.assertIn(
                tool_name,
                SYSTEM_PROMPT,
                f"Tool '{tool_name}' is registered but NOT mentioned in SYSTEM_PROMPT",
            )

    def test_python_execute_mentioned(self):
        self.assertIn("python_execute", SYSTEM_PROMPT)

    def test_web_fetch_mentioned(self):
        self.assertIn("web_fetch", SYSTEM_PROMPT)

    def test_google_calendar_mentioned(self):
        self.assertIn("google_calendar", SYSTEM_PROMPT)

    def test_gmail_mentioned(self):
        self.assertIn("gmail", SYSTEM_PROMPT)

    def test_ffmpeg_process_mentioned(self):
        self.assertIn("ffmpeg_process", SYSTEM_PROMPT)

    def test_create_pdf_mentioned(self):
        self.assertIn("create_pdf", SYSTEM_PROMPT)

    def test_create_zip_mentioned(self):
        self.assertIn("create_zip", SYSTEM_PROMPT)

    def test_ocr_image_mentioned(self):
        self.assertIn("ocr_image", SYSTEM_PROMPT)

    def test_read_pdf_mentioned(self):
        self.assertIn("read_pdf", SYSTEM_PROMPT)

    def test_file_info_mentioned(self):
        self.assertIn("file_info", SYSTEM_PROMPT)

    def test_smart_crop_mentioned(self):
        self.assertIn("smart_crop", SYSTEM_PROMPT)

    def test_download_media_mentioned(self):
        self.assertIn("download_media", SYSTEM_PROMPT)

    def test_headless_browser_mentioned(self):
        self.assertIn("headless_browser", SYSTEM_PROMPT)

    def test_convert_document_mentioned(self):
        self.assertIn("convert_document", SYSTEM_PROMPT)


class TestSystemPromptGuidance(unittest.TestCase):
    """System prompt should include critical guidance sections."""

    def test_google_not_connected_guidance(self):
        """Must tell agent what to do when Google isn't connected."""
        self.assertIn("not connected", SYSTEM_PROMPT.lower())
        self.assertIn("Settings", SYSTEM_PROMPT)

    def test_google_do_not_retry_guidance(self):
        """Must tell agent not to retry Google tools when not connected."""
        self.assertIn("Do NOT retry", SYSTEM_PROMPT)

    def test_file_handling_section(self):
        """Must include file handling guidance."""
        self.assertIn("FILE HANDLING", SYSTEM_PROMPT)

    def test_file_basename_guidance(self):
        """Must tell agent to use basenames for file references."""
        self.assertIn("basename", SYSTEM_PROMPT.lower())

    def test_error_handling_section(self):
        """Must include error handling guidance."""
        self.assertIn("ERROR HANDLING", SYSTEM_PROMPT)

    def test_forbidden_modules_listed(self):
        """Must list forbidden Python modules."""
        self.assertIn("subprocess", SYSTEM_PROMPT)
        self.assertIn("FORBIDDEN", SYSTEM_PROMPT)

    def test_python_cannot_access_network(self):
        """Must mention python can't access network."""
        self.assertIn("cannot access the network", SYSTEM_PROMPT)

    def test_style_section(self):
        """Must include style guidance for mobile."""
        self.assertIn("mobile", SYSTEM_PROMPT.lower())
        self.assertIn("concise", SYSTEM_PROMPT.lower())

    def test_no_youtube_warning(self):
        """Must warn that YouTube download is not supported."""
        self.assertIn("NOT YouTube", SYSTEM_PROMPT)

    def test_ffmpeg_no_percent_pattern_warning(self):
        """Must warn agent NOT to use % patterns in FFmpeg output filenames."""
        self.assertIn("%", SYSTEM_PROMPT)
        self.assertIn("single output file", SYSTEM_PROMPT)
        # Must suggest trim as alternative for segmenting
        self.assertIn("trim", SYSTEM_PROMPT)

    def test_ffmpeg_segment_guidance(self):
        """Must tell agent to use multiple trim calls instead of segment muxer."""
        # The prompt should mention using multiple trim calls for splitting
        prompt_lower = SYSTEM_PROMPT.lower()
        self.assertIn("multiple trim", prompt_lower)


class TestSystemPromptSyncWithDart(unittest.TestCase):
    """Python and Dart system prompts should be identical."""

    def test_prompts_match(self):
        """Read the Dart default prompt and compare to Python."""
        import os
        dart_path = os.path.join(
            os.path.dirname(__file__),
            "..",
            "..",
            "lib",
            "core",
            "constants",
            "defaults.dart",
        )
        if not os.path.exists(dart_path):
            self.skipTest("Dart file not found (running outside project root)")

        with open(dart_path, "r") as f:
            dart_content = f.read()

        # Extract the prompt string between the triple-quotes
        start = dart_content.index("'''") + 3
        end = dart_content.index("'''", start)
        dart_prompt = dart_content[start:end]

        # Both should have the same content (Python has triple-double-quotes)
        self.assertEqual(
            SYSTEM_PROMPT.strip(),
            dart_prompt.strip(),
            "Python SYSTEM_PROMPT and Dart defaultSystemPrompt are out of sync!",
        )


class TestSelfImproveMetaPrompt(unittest.TestCase):
    """Self-improve meta-prompt should include tool context."""

    def setUp(self):
        from unittest.mock import patch, MagicMock
        self.bridge_patcher = patch("navixmind.agent.get_bridge")
        self.mock_get_bridge = self.bridge_patcher.start()
        self.mock_bridge = MagicMock()
        self.mock_get_bridge.return_value = self.mock_bridge

    def tearDown(self):
        self.bridge_patcher.stop()

    def test_meta_prompt_includes_tool_names(self):
        """The meta-prompt sent to Claude should list available tools."""
        from unittest.mock import patch, MagicMock

        captured_body = {}

        def capture_post(url, **kwargs):
            captured_body.update(kwargs.get("json", {}))
            mock_resp = MagicMock()
            mock_resp.status_code = 200
            mock_resp.json.return_value = {
                "content": [{"type": "text", "text": "improved prompt"}],
                "usage": {"input_tokens": 10, "output_tokens": 10},
            }
            return mock_resp

        with patch("navixmind.agent.requests.post", side_effect=capture_post):
            self_improve(
                conversation=[{"role": "user", "content": "test"}],
                current_prompt="old prompt",
                api_key="sk-test",
            )

        # The meta-prompt (user message content) should mention tool names
        messages = captured_body.get("messages", [])
        self.assertTrue(len(messages) > 0)
        meta_prompt_text = messages[0]["content"]

        for tool in TOOLS_SCHEMA:
            self.assertIn(
                tool["name"],
                meta_prompt_text,
                f"Tool '{tool['name']}' not included in self-improve meta-prompt",
            )

    def test_meta_prompt_asks_about_tool_failures(self):
        """Meta-prompt should ask about tool misuse."""
        from unittest.mock import patch, MagicMock

        captured_body = {}

        def capture_post(url, **kwargs):
            captured_body.update(kwargs.get("json", {}))
            mock_resp = MagicMock()
            mock_resp.status_code = 200
            mock_resp.json.return_value = {
                "content": [{"type": "text", "text": "improved"}],
                "usage": {"input_tokens": 10, "output_tokens": 10},
            }
            return mock_resp

        with patch("navixmind.agent.requests.post", side_effect=capture_post):
            self_improve(
                conversation=[{"role": "user", "content": "test"}],
                current_prompt="old prompt",
                api_key="sk-test",
            )

        messages = captured_body.get("messages", [])
        meta_prompt_text = messages[0]["content"]

        # Should ask about tool misuse/failure
        self.assertIn("tools", meta_prompt_text.lower())
        self.assertIn("fail", meta_prompt_text.lower())

    def test_meta_prompt_asks_to_keep_tool_names(self):
        """Meta-prompt should instruct to keep tool names."""
        from unittest.mock import patch, MagicMock

        captured_body = {}

        def capture_post(url, **kwargs):
            captured_body.update(kwargs.get("json", {}))
            mock_resp = MagicMock()
            mock_resp.status_code = 200
            mock_resp.json.return_value = {
                "content": [{"type": "text", "text": "improved"}],
                "usage": {"input_tokens": 10, "output_tokens": 10},
            }
            return mock_resp

        with patch("navixmind.agent.requests.post", side_effect=capture_post):
            self_improve(
                conversation=[{"role": "user", "content": "test"}],
                current_prompt="old prompt",
                api_key="sk-test",
            )

        messages = captured_body.get("messages", [])
        meta_prompt_text = messages[0]["content"]

        # Should instruct not to remove tool names
        self.assertIn("tool name", meta_prompt_text.lower())


class TestCriticalToolUseRule(unittest.TestCase):
    """System prompt must instruct the model to always use tools for new requests."""

    def test_critical_rule_present(self):
        """System prompt must contain rule about calling tools for each new request."""
        self.assertIn("CRITICAL RULE", SYSTEM_PROMPT)

    def test_never_assume_previous_results(self):
        """System prompt must warn against assuming previous results apply."""
        lower = SYSTEM_PROMPT.lower()
        self.assertTrue(
            "never assume previous results" in lower
            or "never assume" in lower,
            "System prompt must instruct model to never assume previous results satisfy current request",
        )

    def test_must_call_tool(self):
        """System prompt must say 'MUST call' tools."""
        self.assertIn("MUST call", SYSTEM_PROMPT)


class TestStoredResponseNoCreatedFiles(unittest.TestCase):
    """Verify that stored assistant responses do NOT append [Created files: ...]."""

    def test_stored_response_is_plain_text(self):
        """process_query should store plain assistant text without file annotations."""
        from unittest.mock import patch, Mock

        import navixmind.agent
        original_key = navixmind.agent._api_key
        navixmind.agent._api_key = "test-key"

        try:
            with patch('navixmind.agent.get_bridge') as mock_bridge, \
                 patch('navixmind.agent.get_session') as mock_session, \
                 patch('navixmind.agent.ClaudeClient') as mock_client_class:

                mock_bridge.return_value = Mock()
                mock_session_instance = Mock()
                mock_session_instance.get_context_for_llm.return_value = []
                mock_session_instance.messages = []
                mock_session_instance._file_map = {}
                mock_session.return_value = mock_session_instance

                mock_client = Mock()
                mock_client_class.return_value = mock_client

                # First call: tool_use, second: end_turn
                mock_client.create_message.side_effect = [
                    {
                        "stop_reason": "tool_use",
                        "content": [{"type": "tool_use", "id": "t1", "name": "create_pdf", "input": {"output_path": "/out/doc.pdf"}}],
                        "usage": {"input_tokens": 100, "output_tokens": 50},
                    },
                    {
                        "stop_reason": "end_turn",
                        "content": [{"type": "text", "text": "Here is your PDF."}],
                        "usage": {"input_tokens": 10, "output_tokens": 5},
                    },
                ]

                with patch('navixmind.agent.execute_tool') as mock_exec:
                    mock_exec.return_value = {"success": True, "output_path": "/out/doc.pdf", "page_count": 1}
                    navixmind.agent.process_query("Create a PDF", context={})

                # Check that the stored assistant message does NOT contain [Created files:]
                add_message_calls = mock_session_instance.add_message.call_args_list
                assistant_calls = [c for c in add_message_calls if c.args[0] == "assistant"]
                self.assertTrue(len(assistant_calls) > 0, "Expected at least one assistant message stored")

                stored_text = assistant_calls[-1].args[1]
                self.assertNotIn("[Created files:", stored_text)
                self.assertEqual(stored_text, "Here is your PDF.")
        finally:
            navixmind.agent._api_key = original_key


if __name__ == "__main__":
    unittest.main()
