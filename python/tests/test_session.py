"""
Comprehensive tests for the NavixMind session module.

Tests cover:
- Session state management
- Delta sync operations
- Context windowing for LLM
- Token counting
"""

import pytest
from unittest.mock import Mock, patch


class TestSessionState:
    """Tests for the SessionState class."""

    def test_add_message(self):
        """Test adding a message to session."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "Hello")

        assert len(session.messages) == 1
        assert session.messages[0]["role"] == "user"
        assert session.messages[0]["content"] == "Hello"

    def test_add_message_with_token_count(self):
        """Test message with explicit token count."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "Test", token_count=10)

        assert session.messages[0]["token_count"] == 10
        assert session.total_tokens == 10

    def test_add_message_estimates_tokens(self):
        """Test message estimates tokens if not provided."""
        from navixmind.session import SessionState

        session = SessionState()
        content = "A" * 100  # 100 chars ~ 25 tokens
        session.add_message("user", content)

        assert session.messages[0]["token_count"] == 25
        assert session.total_tokens == 25

    def test_get_context_empty(self):
        """Test getting context from empty session."""
        from navixmind.session import SessionState

        session = SessionState()
        context = session.get_context_for_llm(max_tokens=100000)

        assert context == []

    def test_get_context_with_messages(self):
        """Test getting context with messages."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "Hello")
        session.add_message("assistant", "Hi there!")

        context = session.get_context_for_llm(max_tokens=100000)

        assert len(context) == 2
        assert context[0]["role"] == "user"
        assert context[1]["role"] == "assistant"

    def test_get_context_respects_token_limit(self):
        """Test context respects token limit."""
        from navixmind.session import SessionState

        session = SessionState()
        # Add messages with known token counts
        session.add_message("user", "First message", token_count=50)
        session.add_message("assistant", "Second message", token_count=50)
        session.add_message("user", "Third message", token_count=50)

        # Request only 60 tokens - should only fit the last message
        context = session.get_context_for_llm(max_tokens=60)

        assert len(context) == 1
        assert "Third" in context[0]["content"]

    def test_get_context_includes_summary(self):
        """Test context includes summary when available."""
        from navixmind.session import SessionState

        session = SessionState()
        session.summary = "Previous discussion about weather"
        session.add_message("user", "Continue the discussion")

        context = session.get_context_for_llm(max_tokens=100000)

        assert len(context) == 2
        assert context[0]["role"] == "system"
        assert "Previous discussion" in context[0]["content"]

    def test_clear(self):
        """Test clearing session state."""
        from navixmind.session import SessionState

        session = SessionState()
        session.conversation_id = 123
        session.add_message("user", "Test")
        session.summary = "Summary"

        session.clear()

        assert session.conversation_id is None
        assert len(session.messages) == 0
        assert session.summary is None
        assert session.total_tokens == 0


class TestApplyDelta:
    """Tests for delta sync operations."""

    def test_apply_new_conversation(self):
        """Test applying new_conversation delta."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "Old message")

        session.apply_delta({
            'action': 'new_conversation',
            'conversation_id': 42
        })

        assert session.conversation_id == 42
        assert len(session.messages) == 0
        assert session.summary is None

    def test_apply_add_message(self):
        """Test applying add_message delta."""
        from navixmind.session import SessionState

        session = SessionState()
        session.apply_delta({
            'action': 'add_message',
            'message': {
                'id': 1,
                'role': 'user',
                'content': 'Hello',
                'token_count': 5
            }
        })

        assert len(session.messages) == 1
        assert session.messages[0]['content'] == 'Hello'
        assert session.total_tokens == 5

    def test_apply_set_summary(self):
        """Test applying set_summary delta."""
        from navixmind.session import SessionState

        session = SessionState()
        # Add messages with IDs
        session.apply_delta({
            'action': 'add_message',
            'message': {'id': 1, 'role': 'user', 'content': 'msg1', 'token_count': 5}
        })
        session.apply_delta({
            'action': 'add_message',
            'message': {'id': 2, 'role': 'assistant', 'content': 'msg2', 'token_count': 5}
        })
        session.apply_delta({
            'action': 'add_message',
            'message': {'id': 3, 'role': 'user', 'content': 'msg3', 'token_count': 5}
        })

        # Set summary and cutoff at id 2
        session.apply_delta({
            'action': 'set_summary',
            'summary': 'Summary of first two messages',
            'summarized_up_to_id': 2
        })

        assert session.summary == 'Summary of first two messages'
        assert len(session.messages) == 1
        assert session.messages[0]['id'] == 3

    def test_apply_sync_full(self):
        """Test applying sync_full delta."""
        from navixmind.session import SessionState

        session = SessionState()
        session.apply_delta({
            'action': 'sync_full',
            'conversation_id': 100,
            'messages': [
                {'id': 1, 'role': 'user', 'content': 'Hello', 'token_count': 5},
                {'id': 2, 'role': 'assistant', 'content': 'Hi', 'token_count': 5},
            ],
            'summary': 'Previous summary'
        })

        assert session.conversation_id == 100
        assert len(session.messages) == 2
        assert session.summary == 'Previous summary'
        assert session.total_tokens == 10


class TestTokenEstimation:
    """Tests for token estimation."""

    def test_estimate_tokens_simple(self):
        """Test simple token estimation."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "Test")  # 4 chars = 1 token

        assert session.messages[0]["token_count"] == 1

    def test_estimate_tokens_empty(self):
        """Test estimation for empty content."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "")

        assert session.messages[0]["token_count"] == 0

    def test_estimate_tokens_long_text(self):
        """Test estimation for long text."""
        from navixmind.session import SessionState

        session = SessionState()
        content = "A" * 1000  # 1000 chars = 250 tokens
        session.add_message("user", content)

        assert session.messages[0]["token_count"] == 250


class TestGetSession:
    """Tests for get_session function."""

    def test_get_session_creates_instance(self):
        """Test get_session creates instance if none exists."""
        from navixmind import session as session_module

        # Reset the global
        session_module._session = None

        result = session_module.get_session()

        assert result is not None
        assert isinstance(result, session_module.SessionState)

    def test_get_session_returns_same_instance(self):
        """Test get_session returns same instance."""
        from navixmind import session as session_module

        session_module._session = None

        first = session_module.get_session()
        second = session_module.get_session()

        assert first is second


class TestApplyDeltaFunction:
    """Tests for the module-level apply_delta function."""

    def test_apply_delta_function(self):
        """Test module-level apply_delta."""
        from navixmind import session as session_module

        session_module._session = None

        session_module.apply_delta({
            'action': 'new_conversation',
            'conversation_id': 99
        })

        assert session_module.get_session().conversation_id == 99


class TestFormatMessage:
    """Tests for message formatting."""

    def test_format_message_basic(self):
        """Test basic message formatting."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "Hello")

        context = session.get_context_for_llm()

        assert context[0]["role"] == "user"
        assert context[0]["content"] == "Hello"

    def test_format_message_with_attachments(self):
        """Test message with attachments."""
        from navixmind.session import SessionState

        session = SessionState()
        session.messages.append({
            'role': 'user',
            'content': 'Check this file',
            'token_count': 10,
            'attachments': [
                {'original_name': 'document.pdf'}
            ]
        })

        context = session.get_context_for_llm()

        assert "[Attachments: document.pdf]" in context[0]["content"]

    def test_format_message_tool_result_role(self):
        """Test tool_result role maps to user."""
        from navixmind.session import SessionState

        session = SessionState()
        session.messages.append({
            'role': 'tool_result',
            'content': 'Tool output',
            'token_count': 5
        })

        context = session.get_context_for_llm()

        assert context[0]["role"] == "user"


class TestEdgeCases:
    """Edge case tests."""

    def test_empty_summary_not_included(self):
        """Test empty summary is not included."""
        from navixmind.session import SessionState

        session = SessionState()
        session.summary = None
        session.add_message("user", "Test")

        context = session.get_context_for_llm()

        assert len(context) == 1
        assert context[0]["role"] == "user"

    def test_multiple_messages_order_preserved(self):
        """Test message order is preserved."""
        from navixmind.session import SessionState

        session = SessionState()
        session.add_message("user", "First")
        session.add_message("assistant", "Second")
        session.add_message("user", "Third")

        context = session.get_context_for_llm()

        assert context[0]["content"] == "First"
        assert context[1]["content"] == "Second"
        assert context[2]["content"] == "Third"

    def test_message_id_auto_increments(self):
        """Test message IDs auto-increment."""
        from navixmind.session import SessionState

        session = SessionState()
        msg1 = session.add_message("user", "First")
        msg2 = session.add_message("assistant", "Second")

        assert msg1["id"] == 1
        assert msg2["id"] == 2
