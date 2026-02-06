"""
Session State - In-memory cache of current conversation

This module manages the hot cache of conversation context,
avoiding repeated bridge calls for context retrieval.
"""

from typing import Any, Dict, List, Optional


class SessionState:
    """
    In-memory cache of current conversation.
    Lives as long as Python runtime is alive.
    """

    def __init__(self):
        self.conversation_id: Optional[int] = None
        self.messages: List[Dict[str, Any]] = []
        self.summary: Optional[str] = None
        self.total_tokens: int = 0

    def apply_delta(self, delta: dict) -> None:
        """
        Apply incremental update from Flutter.
        Called instead of sending full history every time.

        Args:
            delta: Delta update containing action and data
        """
        action = delta.get('action')

        if action == 'new_conversation':
            self.conversation_id = delta['conversation_id']
            self.messages = []
            self.summary = None
            self.total_tokens = 0
            self._file_map = {}  # Clear file map on new conversation

        elif action == 'add_message':
            message = delta['message']
            self.messages.append(message)
            self.total_tokens += message.get('token_count', 0)

        elif action == 'set_summary':
            # When Flutter compacts old messages into summary
            self.summary = delta['summary']
            # Remove messages that are now summarized
            cutoff_id = delta['summarized_up_to_id']
            self.messages = [m for m in self.messages if m['id'] > cutoff_id]
            # Recalculate tokens
            self.total_tokens = sum(m.get('token_count', 0) for m in self.messages)

        elif action == 'sync_full':
            # Full sync - used on cold start or after crash recovery
            self.conversation_id = delta['conversation_id']
            self.messages = delta['messages']
            self.summary = delta.get('summary')
            self.total_tokens = sum(m.get('token_count', 0) for m in self.messages)
            # Rebuild file map from attachment data in synced messages
            import os
            self._file_map = {}
            for msg in self.messages:
                for att in msg.get('attachments', []):
                    local_path = att.get('local_path', '')
                    original_name = att.get('original_name', '')
                    if local_path and original_name:
                        self._file_map[original_name] = local_path
                    elif local_path:
                        self._file_map[os.path.basename(local_path)] = local_path

    def get_context_for_llm(self, max_tokens: int = 150000) -> List[Dict[str, Any]]:
        """
        Build context window for LLM call.
        Respects token limits, includes summary if available.

        Args:
            max_tokens: Maximum tokens to include in context

        Returns:
            List of messages formatted for LLM
        """
        context = []

        # Always include summary if we have one
        if self.summary:
            context.append({
                "role": "system",
                "content": f"[Previous conversation summary]\n{self.summary}"
            })

        # Estimate summary tokens
        summary_tokens = len(self.summary) // 4 if self.summary else 0
        remaining_tokens = max_tokens - summary_tokens

        # Add recent messages, newest first, until we hit limit
        messages_to_include = []

        for msg in reversed(self.messages):
            msg_tokens = msg.get('token_count', len(msg.get('content', '')) // 4)
            if remaining_tokens - msg_tokens < 0:
                break
            messages_to_include.insert(0, self._format_message(msg))
            remaining_tokens -= msg_tokens

        context.extend(messages_to_include)
        return context

    def _format_message(self, msg: dict) -> Dict[str, Any]:
        """Format a message for LLM consumption."""
        role = msg.get('role', 'user')

        # Map our roles to LLM roles
        role_map = {
            'user': 'user',
            'assistant': 'assistant',
            'system': 'system',
            'tool_result': 'user',  # Tool results go as user messages
        }

        formatted = {
            "role": role_map.get(role, 'user'),
            "content": msg.get('content', '')
        }

        # Handle attachments
        attachments = msg.get('attachments', [])
        if attachments:
            # Append attachment info to content
            attachment_text = "\n\n[Attachments: "
            attachment_text += ", ".join(a.get('original_name', 'file') for a in attachments)
            attachment_text += "]"
            formatted["content"] += attachment_text

        return formatted

    def add_message(
        self,
        role: str,
        content: str,
        token_count: Optional[int] = None
    ) -> dict:
        """
        Add a new message to the session.

        Args:
            role: Message role (user, assistant, system, tool_result)
            content: Message content
            token_count: Optional pre-computed token count

        Returns:
            The created message dict
        """
        if token_count is None:
            token_count = len(content) // 4  # Rough estimate

        message = {
            'id': len(self.messages) + 1,  # Local ID
            'role': role,
            'content': content,
            'token_count': token_count,
        }

        self.messages.append(message)
        self.total_tokens += token_count

        return message

    def clear(self) -> None:
        """Clear all session state."""
        self.conversation_id = None
        self.messages = []
        self.summary = None
        self.total_tokens = 0


# Global session state instance
_session: Optional[SessionState] = None


def get_session() -> SessionState:
    """Get the global session state."""
    global _session
    if _session is None:
        _session = SessionState()
    return _session


def apply_delta(delta: dict) -> None:
    """Apply a delta update to the session."""
    get_session().apply_delta(delta)
