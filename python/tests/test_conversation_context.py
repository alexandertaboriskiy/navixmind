"""
Tests for conversation context preservation across queries.

Ensures that:
- Session stores user AND assistant messages on every code path
- Error responses are saved to session to prevent consecutive user messages
- Context from previous queries is included in subsequent API calls
- Session messages alternate user/assistant correctly
"""

import json
import unittest
from unittest.mock import patch, MagicMock, PropertyMock

from navixmind.session import SessionState, get_session


class TestSessionMessageAlternation(unittest.TestCase):
    """Session must always alternate user/assistant messages."""

    def test_normal_flow_alternates(self):
        """After a successful query, session has user then assistant."""
        session = SessionState()
        session.add_message("user", "Hello")
        session.add_message("assistant", "Hi there!")

        self.assertEqual(len(session.messages), 2)
        self.assertEqual(session.messages[0]['role'], 'user')
        self.assertEqual(session.messages[1]['role'], 'assistant')

    def test_multiple_queries_alternate(self):
        """Multiple query-response pairs alternate correctly."""
        session = SessionState()
        for i in range(5):
            session.add_message("user", f"Query {i}")
            session.add_message("assistant", f"Response {i}")

        self.assertEqual(len(session.messages), 10)
        for i, msg in enumerate(session.messages):
            expected_role = 'user' if i % 2 == 0 else 'assistant'
            self.assertEqual(msg['role'], expected_role)

    def test_context_includes_previous_messages(self):
        """get_context_for_llm returns previous messages."""
        session = SessionState()
        session.add_message("user", "What's the weather?")
        session.add_message("assistant", "It's sunny!")

        context = session.get_context_for_llm(150000)
        self.assertEqual(len(context), 2)
        self.assertEqual(context[0]['role'], 'user')
        self.assertEqual(context[0]['content'], "What's the weather?")
        self.assertEqual(context[1]['role'], 'assistant')
        self.assertEqual(context[1]['content'], "It's sunny!")

    def test_context_preserves_order(self):
        """Context messages are in chronological order."""
        session = SessionState()
        session.add_message("user", "First")
        session.add_message("assistant", "Response to first")
        session.add_message("user", "Second")
        session.add_message("assistant", "Response to second")

        context = session.get_context_for_llm(150000)
        contents = [m['content'] for m in context]
        self.assertEqual(contents, [
            "First", "Response to first",
            "Second", "Response to second"
        ])


class TestProcessQuerySessionSaves(unittest.TestCase):
    """process_query must always save assistant response to session."""

    def setUp(self):
        """Reset session and set up mocks."""
        import navixmind.session as session_module
        session_module._session = None

        self.bridge_patcher = patch("navixmind.agent.get_bridge")
        self.mock_get_bridge = self.bridge_patcher.start()
        self.mock_bridge = MagicMock()
        self.mock_get_bridge.return_value = self.mock_bridge

    def tearDown(self):
        self.bridge_patcher.stop()
        import navixmind.session as session_module
        session_module._session = None

    def _set_api_key(self):
        """Set a test API key."""
        from navixmind.agent import set_api_key
        set_api_key("sk-test-key-for-context-tests")

    def test_successful_query_saves_both_messages(self):
        """Successful query saves user + assistant to session."""
        self._set_api_key()
        from navixmind.agent import process_query

        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.return_value = {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Hello!"}],
                "usage": {"input_tokens": 10, "output_tokens": 5}
            }

            result = process_query("Hi", context={})

        self.assertEqual(result["content"], "Hello!")
        session = get_session()
        self.assertEqual(len(session.messages), 2)
        self.assertEqual(session.messages[0]['role'], 'user')
        self.assertEqual(session.messages[0]['content'], 'Hi')
        self.assertEqual(session.messages[1]['role'], 'assistant')
        self.assertEqual(session.messages[1]['content'], 'Hello!')

    def test_api_error_saves_assistant_message(self):
        """API error must still save an assistant message to session."""
        self._set_api_key()
        from navixmind.agent import process_query, APIError

        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.side_effect = APIError(
                "overloaded_error", "API is busy"
            )

            result = process_query("Hello", context={})

        self.assertTrue(result.get("error"))
        session = get_session()
        # Must have both user AND assistant messages
        self.assertEqual(len(session.messages), 2)
        self.assertEqual(session.messages[0]['role'], 'user')
        self.assertEqual(session.messages[1]['role'], 'assistant')

    def test_exception_saves_assistant_message(self):
        """General exception must still save an assistant message."""
        self._set_api_key()
        from navixmind.agent import process_query

        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.side_effect = RuntimeError("boom")

            result = process_query("Hello", context={})

        self.assertTrue(result.get("error"))
        session = get_session()
        self.assertEqual(len(session.messages), 2)
        self.assertEqual(session.messages[0]['role'], 'user')
        self.assertEqual(session.messages[1]['role'], 'assistant')

    def test_no_api_key_does_not_add_to_session(self):
        """No API key returns early without touching session."""
        from navixmind.agent import process_query, set_api_key, _api_key
        import navixmind.agent as agent_module
        old_key = agent_module._api_key
        agent_module._api_key = None

        try:
            result = process_query("Hello", context={})
            self.assertTrue(result.get("error"))
            session = get_session()
            # Should NOT add any messages (early return before user msg is added)
            self.assertEqual(len(session.messages), 0)
        finally:
            agent_module._api_key = old_key

    def test_consecutive_queries_preserve_context(self):
        """Multiple queries build up conversation history correctly."""
        self._set_api_key()
        from navixmind.agent import process_query

        responses = ["Response 1", "Response 2", "Response 3"]

        for i, resp_text in enumerate(responses):
            with patch("navixmind.agent.ClaudeClient") as MockClient:
                mock_client = MockClient.return_value
                mock_client.model = "test-model"
                mock_client.create_message.return_value = {
                    "stop_reason": "end_turn",
                    "content": [{"type": "text", "text": resp_text}],
                    "usage": {"input_tokens": 10, "output_tokens": 5}
                }

                process_query(f"Query {i}", context={})

        session = get_session()
        # 3 queries * 2 messages each = 6
        self.assertEqual(len(session.messages), 6)
        # Verify alternation
        for j, msg in enumerate(session.messages):
            expected_role = 'user' if j % 2 == 0 else 'assistant'
            self.assertEqual(msg['role'], expected_role)

    def test_error_then_success_preserves_alternation(self):
        """After an error, next query still works correctly."""
        self._set_api_key()
        from navixmind.agent import process_query, APIError

        # First query: API error
        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.side_effect = APIError(
                "overloaded_error", "busy"
            )
            process_query("Query 1", context={})

        # Second query: success
        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.return_value = {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Success!"}],
                "usage": {"input_tokens": 10, "output_tokens": 5}
            }
            result = process_query("Query 2", context={})

        self.assertEqual(result["content"], "Success!")
        session = get_session()
        # 4 messages: user1, error_assistant1, user2, assistant2
        self.assertEqual(len(session.messages), 4)
        roles = [m['role'] for m in session.messages]
        self.assertEqual(roles, ['user', 'assistant', 'user', 'assistant'])

    def test_max_iterations_saves_assistant_message(self):
        """Max iterations must save an assistant message to session."""
        self._set_api_key()
        from navixmind.agent import process_query

        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            # Always return tool_use to exhaust iterations
            mock_client.create_message.return_value = {
                "stop_reason": "tool_use",
                "content": [
                    {"type": "text", "text": "Let me try..."},
                    {
                        "type": "tool_use",
                        "id": "tool-1",
                        "name": "python_execute",
                        "input": {"code": "print('hi')"}
                    }
                ],
                "usage": {"input_tokens": 10, "output_tokens": 5}
            }

            with patch("navixmind.agent.execute_tool") as mock_exec:
                mock_exec.return_value = {"success": True, "output": "hi"}
                result = process_query("Do something", context={
                    'max_iterations': 2,
                    'max_tool_calls': 50,
                })

        session = get_session()
        # Session should have user + assistant (max iterations message)
        self.assertEqual(len(session.messages), 2)
        self.assertEqual(session.messages[0]['role'], 'user')
        self.assertEqual(session.messages[1]['role'], 'assistant')
        self.assertIn("step limit", session.messages[1]['content'])


class TestContextSentToAPI(unittest.TestCase):
    """Verify that previous conversation is included in API calls."""

    def setUp(self):
        import navixmind.session as session_module
        session_module._session = None

        self.bridge_patcher = patch("navixmind.agent.get_bridge")
        self.mock_get_bridge = self.bridge_patcher.start()
        self.mock_bridge = MagicMock()
        self.mock_get_bridge.return_value = self.mock_bridge

    def tearDown(self):
        self.bridge_patcher.stop()
        import navixmind.session as session_module
        session_module._session = None

    def test_second_query_includes_first_conversation(self):
        """Second query's API call includes messages from first query."""
        from navixmind.agent import set_api_key, process_query
        set_api_key("sk-test-context-check")

        captured_messages = []

        def capture_create_message(**kwargs):
            captured_messages.append(kwargs.get('messages', []))
            return {
                "stop_reason": "end_turn",
                "content": [{"type": "text", "text": "Response"}],
                "usage": {"input_tokens": 10, "output_tokens": 5}
            }

        # Query 1
        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.side_effect = capture_create_message
            process_query("First question", context={})

        # Query 2
        with patch("navixmind.agent.ClaudeClient") as MockClient:
            mock_client = MockClient.return_value
            mock_client.model = "test-model"
            mock_client.create_message.side_effect = capture_create_message
            process_query("Second question", context={})

        # First API call should have 1 message (just the first query)
        self.assertEqual(len(captured_messages[0]), 1)
        self.assertEqual(captured_messages[0][0]['content'], 'First question')

        # Second API call should have 3 messages (first Q, first A, second Q)
        self.assertEqual(len(captured_messages[1]), 3)
        self.assertEqual(captured_messages[1][0]['content'], 'First question')
        self.assertEqual(captured_messages[1][1]['content'], 'Response')
        self.assertEqual(captured_messages[1][2]['content'], 'Second question')


if __name__ == "__main__":
    unittest.main()
