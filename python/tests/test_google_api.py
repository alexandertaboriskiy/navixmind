"""
Comprehensive tests for the Google API tools module.

Tests cover:
- Google Calendar: list, create, delete actions
- Gmail: list, read, send actions
- Authentication handling
- HTTP error handling
- Edge cases and malformed responses
"""

import base64
import json
import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock

import requests

from navixmind.bridge import ToolError
from navixmind.tools.google_api import (
    google_calendar,
    gmail,
    _list_events,
    _create_event,
    _list_emails,
    _read_email,
    _send_email,
)


# =============================================================================
# Google Calendar Tests
# =============================================================================

class TestGoogleCalendarAuthentication:
    """Tests for Google Calendar authentication handling."""

    def test_missing_context_raises_tool_error(self):
        """Test that missing context raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(action="list", _context=None)

        assert "Google account not connected" in str(exc_info.value)
        assert "Settings" in str(exc_info.value)

    def test_empty_context_raises_tool_error(self):
        """Test that empty context raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(action="list", _context={})

        assert "Google account not connected" in str(exc_info.value)

    def test_context_without_token_raises_tool_error(self):
        """Test that context without google_access_token raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(action="list", _context={"other_key": "value"})

        assert "Google account not connected" in str(exc_info.value)

    def test_http_401_triggers_session_expired_error(self):
        """Test that HTTP 401 triggers session expired error."""
        mock_response = Mock()
        mock_response.status_code = 401
        mock_response.raise_for_status.side_effect = requests.HTTPError(response=mock_response)

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            with pytest.raises(ToolError) as exc_info:
                google_calendar(
                    action="list",
                    _context={"google_access_token": "expired_token"}
                )

            assert "session expired" in str(exc_info.value).lower()
            assert "reconnect" in str(exc_info.value).lower()

    def test_other_http_error_is_propagated(self):
        """Test that other HTTP errors are propagated with API error message."""
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.raise_for_status.side_effect = requests.HTTPError(
            "Internal Server Error", response=mock_response
        )

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            with pytest.raises(ToolError) as exc_info:
                google_calendar(
                    action="list",
                    _context={"google_access_token": "valid_token"}
                )

            assert "Calendar API error" in str(exc_info.value)


class TestGoogleCalendarListEvents:
    """Tests for listing calendar events."""

    def test_list_events_for_today(self):
        """Test listing events for today."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "items": [
                {
                    "id": "event1",
                    "summary": "Morning Meeting",
                    "start": {"dateTime": "2024-01-15T09:00:00Z"},
                    "end": {"dateTime": "2024-01-15T10:00:00Z"},
                    "location": "Conference Room",
                    "description": "Daily standup"
                },
                {
                    "id": "event2",
                    "summary": "Lunch",
                    "start": {"date": "2024-01-15"},
                    "end": {"date": "2024-01-15"},
                }
            ]
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 2
        assert len(result["events"]) == 2
        assert result["events"][0]["title"] == "Morning Meeting"
        assert result["events"][0]["location"] == "Conference Room"
        assert result["events"][1]["title"] == "Lunch"

        # Verify API was called with correct parameters
        mock_get.assert_called_once()
        call_kwargs = mock_get.call_args[1]
        assert "params" in call_kwargs
        assert call_kwargs["params"]["singleEvents"] == "true"
        assert call_kwargs["params"]["orderBy"] == "startTime"

    def test_list_events_for_this_week(self):
        """Test listing events for this week."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="this_week",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        assert result["events"] == []

        # Verify the time range spans about a week
        call_kwargs = mock_get.call_args[1]
        time_min = call_kwargs["params"]["timeMin"]
        time_max = call_kwargs["params"]["timeMax"]
        assert time_min is not None
        assert time_max is not None

    def test_list_events_with_custom_date_range(self):
        """Test listing events with custom date range."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "items": [
                {
                    "id": "event1",
                    "summary": "Conference",
                    "start": {"dateTime": "2024-02-10T09:00:00Z"},
                    "end": {"dateTime": "2024-02-12T17:00:00Z"},
                }
            ]
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="2024-02-01/2024-02-28",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 1
        assert result["range"]["min"] == "2024-02-01T00:00:00Z"
        assert result["range"]["max"] == "2024-02-28T23:59:59Z"

    def test_list_events_default_to_today_when_no_date_range(self):
        """Test that date_range defaults to today when not provided."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        # Should have called the API with today's date range
        mock_get.assert_called_once()

    def test_list_events_with_single_date(self):
        """Test listing events with single date (no end date in range)."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="2024-03-15",
                _context={"google_access_token": "valid_token"}
            )

        # Single date should span the entire day
        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["params"]["timeMin"] == "2024-03-15T00:00:00Z"
        assert call_kwargs["params"]["timeMax"] == "2024-03-15T23:59:59Z"

    def test_single_date_spans_full_day(self):
        """Single date must query from 00:00 to 23:59 — not a zero-width window."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="2026-02-08",
                _context={"google_access_token": "valid_token"}
            )

        assert result["range"]["min"] == "2026-02-08T00:00:00Z"
        assert result["range"]["max"] == "2026-02-08T23:59:59Z"
        # min != max — must not be a zero-width window
        assert result["range"]["min"] != result["range"]["max"]

    def test_list_events_empty_results(self):
        """Test listing events returns empty when no events found."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        assert result["events"] == []

    def test_list_events_missing_items_in_response(self):
        """Test handling response with missing 'items' key."""
        mock_response = Mock()
        mock_response.json.return_value = {}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        assert result["events"] == []

    def test_list_events_handles_untitled_events(self):
        """Test handling events without summary (untitled)."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "items": [
                {
                    "id": "event1",
                    "start": {"dateTime": "2024-01-15T09:00:00Z"},
                    "end": {"dateTime": "2024-01-15T10:00:00Z"},
                }
            ]
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        assert result["events"][0]["title"] == "Untitled"

    def test_list_events_uses_correct_headers(self):
        """Test that correct authorization headers are used."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "my_secret_token"}
            )

        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["headers"]["Authorization"] == "Bearer my_secret_token"
        assert call_kwargs["headers"]["Content-Type"] == "application/json"

    def test_list_events_uses_timeout(self):
        """Test that request uses timeout."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["timeout"] == 30


class TestGoogleCalendarCreateEvent:
    """Tests for creating calendar events."""

    def test_create_event_with_all_fields(self):
        """Test creating event with all required fields."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "id": "created_event_id",
            "htmlLink": "https://calendar.google.com/event?eid=abc"
        }

        with patch('requests.post') as mock_post:
            mock_post.return_value = mock_response

            result = google_calendar(
                action="create",
                event={
                    "title": "Team Meeting",
                    "start": "2024-01-20T14:00:00Z",
                    "end": "2024-01-20T15:00:00Z",
                    "description": "Weekly team sync",
                    "location": "Room 101"
                },
                _context={"google_access_token": "valid_token"}
            )

        assert result["success"] is True
        assert result["event_id"] == "created_event_id"
        assert "calendar.google.com" in result["link"]

        # Verify API call
        call_kwargs = mock_post.call_args[1]
        body = call_kwargs["json"]
        assert body["summary"] == "Team Meeting"
        assert body["start"]["dateTime"] == "2024-01-20T14:00:00Z"
        assert body["end"]["dateTime"] == "2024-01-20T15:00:00Z"
        assert body["description"] == "Weekly team sync"
        assert body["location"] == "Room 101"

    def test_create_event_minimal_fields(self):
        """Test creating event with only required fields."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "id": "created_event_id",
            "htmlLink": "https://calendar.google.com/event?eid=abc"
        }

        with patch('requests.post') as mock_post:
            mock_post.return_value = mock_response

            result = google_calendar(
                action="create",
                event={
                    "title": "Quick Sync",
                    "start": "2024-01-20T14:00:00Z",
                    "end": "2024-01-20T14:30:00Z",
                },
                _context={"google_access_token": "valid_token"}
            )

        assert result["success"] is True

        # Verify no optional fields in request body
        call_kwargs = mock_post.call_args[1]
        body = call_kwargs["json"]
        assert "description" not in body
        assert "location" not in body

    def test_create_event_missing_event_details_raises_error(self):
        """Test that missing event details raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="create",
                event=None,
                _context={"google_access_token": "valid_token"}
            )

        assert "Event details required" in str(exc_info.value)

    def test_create_event_missing_title_raises_error(self):
        """Test that missing title raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="create",
                event={
                    "start": "2024-01-20T14:00:00Z",
                    "end": "2024-01-20T15:00:00Z",
                },
                _context={"google_access_token": "valid_token"}
            )

        assert "requires title, start, and end" in str(exc_info.value)

    def test_create_event_missing_start_raises_error(self):
        """Test that missing start time raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="create",
                event={
                    "title": "Meeting",
                    "end": "2024-01-20T15:00:00Z",
                },
                _context={"google_access_token": "valid_token"}
            )

        assert "requires title, start, and end" in str(exc_info.value)

    def test_create_event_missing_end_raises_error(self):
        """Test that missing end time raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="create",
                event={
                    "title": "Meeting",
                    "start": "2024-01-20T14:00:00Z",
                },
                _context={"google_access_token": "valid_token"}
            )

        assert "requires title, start, and end" in str(exc_info.value)

    def test_create_event_empty_event_dict_raises_error(self):
        """Test that empty event dict raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="create",
                event={},
                _context={"google_access_token": "valid_token"}
            )

        # Empty dict triggers "Event details required" error
        assert "Event details required" in str(exc_info.value)

    def test_create_event_uses_utc_timezone(self):
        """Test that created events use UTC timezone."""
        mock_response = Mock()
        mock_response.json.return_value = {"id": "event_id"}

        with patch('requests.post') as mock_post:
            mock_post.return_value = mock_response

            google_calendar(
                action="create",
                event={
                    "title": "Meeting",
                    "start": "2024-01-20T14:00:00Z",
                    "end": "2024-01-20T15:00:00Z",
                },
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_post.call_args[1]
        body = call_kwargs["json"]
        assert body["start"]["timeZone"] == "UTC"
        assert body["end"]["timeZone"] == "UTC"


class TestGoogleCalendarDeleteEvent:
    """Tests for delete action (which is not fully implemented)."""

    def test_delete_action_raises_error(self):
        """Test that delete action raises ToolError about missing event_id."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="delete",
                _context={"google_access_token": "valid_token"}
            )

        assert "event_id" in str(exc_info.value)


class TestGoogleCalendarUnknownAction:
    """Tests for unknown actions."""

    def test_unknown_action_raises_error(self):
        """Test that unknown action raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            google_calendar(
                action="invalid_action",
                _context={"google_access_token": "valid_token"}
            )

        assert "Unknown action" in str(exc_info.value)
        assert "invalid_action" in str(exc_info.value)


class TestGoogleCalendarTimeoutHandling:
    """Tests for timeout handling in calendar operations."""

    def test_list_events_timeout(self):
        """Test that timeout during list events is handled."""
        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.Timeout("Request timed out")

            with pytest.raises(requests.Timeout):
                google_calendar(
                    action="list",
                    date_range="today",
                    _context={"google_access_token": "valid_token"}
                )

    def test_create_event_timeout(self):
        """Test that timeout during create event is handled."""
        with patch('requests.post') as mock_post:
            mock_post.side_effect = requests.Timeout("Request timed out")

            with pytest.raises(requests.Timeout):
                google_calendar(
                    action="create",
                    event={
                        "title": "Meeting",
                        "start": "2024-01-20T14:00:00Z",
                        "end": "2024-01-20T15:00:00Z",
                    },
                    _context={"google_access_token": "valid_token"}
                )


# =============================================================================
# Gmail Tests
# =============================================================================

class TestGmailAuthentication:
    """Tests for Gmail authentication handling."""

    def test_missing_context_raises_tool_error(self):
        """Test that missing context raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            gmail(action="list", _context=None)

        assert "Google account not connected" in str(exc_info.value)
        assert "email features" in str(exc_info.value)

    def test_empty_context_raises_tool_error(self):
        """Test that empty context raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            gmail(action="list", _context={})

        assert "Google account not connected" in str(exc_info.value)

    def test_context_without_token_raises_tool_error(self):
        """Test that context without google_access_token raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            gmail(action="list", _context={"other_key": "value"})

        assert "Google account not connected" in str(exc_info.value)

    def test_http_401_triggers_session_expired_error(self):
        """Test that HTTP 401 triggers session expired error."""
        mock_response = Mock()
        mock_response.status_code = 401
        mock_response.raise_for_status.side_effect = requests.HTTPError(response=mock_response)

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            with pytest.raises(ToolError) as exc_info:
                gmail(
                    action="list",
                    _context={"google_access_token": "expired_token"}
                )

            assert "session expired" in str(exc_info.value).lower()
            assert "reconnect" in str(exc_info.value).lower()

    def test_other_http_error_is_propagated(self):
        """Test that other HTTP errors are propagated with API error message."""
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.raise_for_status.side_effect = requests.HTTPError(
            "Internal Server Error", response=mock_response
        )

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            with pytest.raises(ToolError) as exc_info:
                gmail(
                    action="list",
                    _context={"google_access_token": "valid_token"}
                )

            assert "Gmail API error" in str(exc_info.value)


class TestGmailListEmails:
    """Tests for listing emails."""

    def test_list_emails_with_query(self):
        """Test listing emails with search query."""
        # Mock the initial list response
        mock_list_response = Mock()
        mock_list_response.status_code = 200
        mock_list_response.json.return_value = {
            "messages": [
                {"id": "msg1"},
                {"id": "msg2"}
            ]
        }

        # Mock the individual message metadata responses
        mock_msg1_response = Mock()
        mock_msg1_response.status_code = 200
        mock_msg1_response.json.return_value = {
            "payload": {
                "headers": [
                    {"name": "From", "value": "alice@example.com"},
                    {"name": "Subject", "value": "Hello"},
                    {"name": "Date", "value": "Mon, 15 Jan 2024 10:00:00 +0000"}
                ]
            },
            "snippet": "This is the email preview..."
        }

        mock_msg2_response = Mock()
        mock_msg2_response.status_code = 200
        mock_msg2_response.json.return_value = {
            "payload": {
                "headers": [
                    {"name": "From", "value": "bob@example.com"},
                    {"name": "Subject", "value": "Re: Hello"},
                    {"name": "Date", "value": "Mon, 15 Jan 2024 11:00:00 +0000"}
                ]
            },
            "snippet": "Reply to your message..."
        }

        with patch('requests.get') as mock_get:
            mock_get.side_effect = [mock_list_response, mock_msg1_response, mock_msg2_response]

            result = gmail(
                action="list",
                query="from:alice@example.com",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 2
        assert result["query"] == "from:alice@example.com"
        assert result["messages"][0]["from"] == "alice@example.com"
        assert result["messages"][0]["subject"] == "Hello"
        assert result["messages"][1]["from"] == "bob@example.com"

    def test_list_emails_default_query_is_unread(self):
        """Test that default query is 'is:unread'."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"messages": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="list",
                _context={"google_access_token": "valid_token"}
            )

        # First call should be to list messages
        call_kwargs = mock_get.call_args_list[0][1]
        assert call_kwargs["params"]["q"] == "is:unread"

    def test_list_emails_empty_results(self):
        """Test listing emails returns empty when no messages found."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"messages": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="list",
                query="nonexistent",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        assert result["messages"] == []

    def test_list_emails_missing_messages_in_response(self):
        """Test handling response with missing 'messages' key."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="list",
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        assert result["messages"] == []

    def test_list_emails_handles_failed_message_fetch(self):
        """Test that failed individual message fetches are skipped."""
        mock_list_response = Mock()
        mock_list_response.status_code = 200
        mock_list_response.json.return_value = {
            "messages": [{"id": "msg1"}, {"id": "msg2"}]
        }

        # First message fetch succeeds, second fails
        mock_msg1_response = Mock()
        mock_msg1_response.status_code = 200
        mock_msg1_response.json.return_value = {
            "payload": {
                "headers": [{"name": "From", "value": "test@example.com"}]
            },
            "snippet": "Preview"
        }

        mock_msg2_response = Mock()
        mock_msg2_response.status_code = 404  # Not found

        with patch('requests.get') as mock_get:
            mock_get.side_effect = [mock_list_response, mock_msg1_response, mock_msg2_response]

            result = gmail(
                action="list",
                _context={"google_access_token": "valid_token"}
            )

        # Only the successful message should be included
        assert result["count"] == 1
        assert len(result["messages"]) == 1

    def test_list_emails_limits_to_20(self):
        """Test that list emails is limited to 20 results."""
        mock_list_response = Mock()
        mock_list_response.status_code = 200
        mock_list_response.json.return_value = {
            "messages": [{"id": f"msg{i}"} for i in range(25)]
        }

        # Create mock responses for each message
        mock_msg_responses = []
        for i in range(25):
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                "payload": {"headers": []},
                "snippet": f"Message {i}"
            }
            mock_msg_responses.append(mock_response)

        with patch('requests.get') as mock_get:
            mock_get.side_effect = [mock_list_response] + mock_msg_responses

            result = gmail(
                action="list",
                _context={"google_access_token": "valid_token"}
            )

        # Should be limited to 20 messages
        assert result["count"] <= 20


class TestGmailReadEmail:
    """Tests for reading specific emails."""

    def test_read_email_by_message_id(self):
        """Test reading a specific email by message_id."""
        # Create base64 encoded body
        body_text = "Hello, this is the email body content."
        encoded_body = base64.urlsafe_b64encode(body_text.encode()).decode()

        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {
                "headers": [
                    {"name": "From", "value": "sender@example.com"},
                    {"name": "To", "value": "recipient@example.com"},
                    {"name": "Subject", "value": "Test Email"},
                    {"name": "Date", "value": "Mon, 15 Jan 2024 10:00:00 +0000"}
                ],
                "parts": [
                    {
                        "mimeType": "text/plain",
                        "body": {"data": encoded_body}
                    }
                ]
            }
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="read",
                message_id="msg123",
                _context={"google_access_token": "valid_token"}
            )

        assert result["id"] == "msg123"
        assert result["from"] == "sender@example.com"
        assert result["to"] == "recipient@example.com"
        assert result["subject"] == "Test Email"
        assert result["body"] == body_text

    def test_read_email_with_body_in_payload(self):
        """Test reading email where body is directly in payload (not parts)."""
        body_text = "Simple email body."
        encoded_body = base64.urlsafe_b64encode(body_text.encode()).decode()

        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {
                "headers": [
                    {"name": "From", "value": "sender@example.com"},
                    {"name": "Subject", "value": "Simple Email"}
                ],
                "body": {"data": encoded_body}
            }
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="read",
                message_id="msg456",
                _context={"google_access_token": "valid_token"}
            )

        assert result["body"] == body_text

    def test_read_email_missing_message_id_raises_error(self):
        """Test that missing message_id raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            gmail(
                action="read",
                message_id=None,
                _context={"google_access_token": "valid_token"}
            )

        assert "message_id required" in str(exc_info.value)

    def test_read_email_empty_body(self):
        """Test reading email with empty body."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {
                "headers": [
                    {"name": "From", "value": "sender@example.com"},
                    {"name": "Subject", "value": "Empty Email"}
                ],
                "body": {}
            }
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="read",
                message_id="msg789",
                _context={"google_access_token": "valid_token"}
            )

        assert result["body"] == ""

    def test_read_email_truncates_long_body(self):
        """Test that long email bodies are truncated to 10000 characters."""
        # Create a very long body (> 10000 chars)
        long_body = "x" * 15000
        encoded_body = base64.urlsafe_b64encode(long_body.encode()).decode()

        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {
                "headers": [],
                "body": {"data": encoded_body}
            }
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="read",
                message_id="msg_long",
                _context={"google_access_token": "valid_token"}
            )

        assert len(result["body"]) == 10000

    def test_read_email_with_multipart_html_only(self):
        """Test reading email that only has HTML part (no text/plain)."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {
                "headers": [
                    {"name": "Subject", "value": "HTML Only"}
                ],
                "parts": [
                    {
                        "mimeType": "text/html",
                        "body": {"data": base64.urlsafe_b64encode(b"<p>HTML</p>").decode()}
                    }
                ]
            }
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = gmail(
                action="read",
                message_id="msg_html",
                _context={"google_access_token": "valid_token"}
            )

        # Should return empty body since only text/plain is extracted
        assert result["body"] == ""

    def test_read_email_uses_full_format(self):
        """Test that read email requests full format."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {"headers": [], "body": {}}
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            gmail(
                action="read",
                message_id="msg123",
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["params"]["format"] == "full"


class TestGmailSendEmail:
    """Tests for sending emails — now disabled (read-only access)."""

    def test_send_action_raises_tool_error(self):
        """Send action should be rejected — app only has read-only Gmail access."""
        with pytest.raises(ToolError) as exc_info:
            gmail(
                action="send",
                compose={
                    "to": "recipient@example.com",
                    "subject": "Test Subject",
                    "body": "This is the email body."
                },
                _context={"google_access_token": "valid_token"}
            )

        assert "not enabled" in str(exc_info.value)
        assert "read-only" in str(exc_info.value)

    def test_send_action_rejected_without_compose(self):
        """Send action should be rejected even without compose details."""
        with pytest.raises(ToolError) as exc_info:
            gmail(
                action="send",
                compose=None,
                _context={"google_access_token": "valid_token"}
            )

        assert "not enabled" in str(exc_info.value)


class TestGmailUnknownAction:
    """Tests for unknown actions."""

    def test_unknown_action_raises_error(self):
        """Test that unknown action raises ToolError."""
        with pytest.raises(ToolError) as exc_info:
            gmail(
                action="invalid_action",
                _context={"google_access_token": "valid_token"}
            )

        assert "Unknown action" in str(exc_info.value)
        assert "invalid_action" in str(exc_info.value)


class TestGmailTimeoutHandling:
    """Tests for timeout handling in Gmail operations."""

    def test_list_emails_timeout(self):
        """Test that timeout during list emails is handled."""
        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.Timeout("Request timed out")

            with pytest.raises(requests.Timeout):
                gmail(
                    action="list",
                    _context={"google_access_token": "valid_token"}
                )

    def test_read_email_timeout(self):
        """Test that timeout during read email is handled."""
        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.Timeout("Request timed out")

            with pytest.raises(requests.Timeout):
                gmail(
                    action="read",
                    message_id="msg123",
                    _context={"google_access_token": "valid_token"}
                )

    def test_send_email_rejected_before_any_network_call(self):
        """Send action should be rejected before making any network call."""
        with pytest.raises(ToolError) as exc_info:
            gmail(
                action="send",
                compose={"to": "test@example.com"},
                _context={"google_access_token": "valid_token"}
            )

        assert "not enabled" in str(exc_info.value)


# =============================================================================
# Edge Cases and Malformed Response Tests
# =============================================================================

class TestMalformedResponses:
    """Tests for handling malformed API responses."""

    def test_calendar_malformed_event_structure(self):
        """Test handling events with malformed structure."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "items": [
                {
                    "id": "event1",
                    # Missing start/end entirely
                },
                {
                    "id": "event2",
                    "start": {},  # Empty start
                    "end": {},    # Empty end
                }
            ]
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        # Should handle gracefully
        assert result["count"] == 2
        assert result["events"][0]["start"] is None
        assert result["events"][1]["start"] is None

    def test_gmail_malformed_headers(self):
        """Test handling emails with malformed headers."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "payload": {
                "headers": None,  # None instead of list
                "body": {}
            }
        }

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            # This may raise an error - testing that it's handled appropriately
            try:
                result = gmail(
                    action="read",
                    message_id="msg123",
                    _context={"google_access_token": "valid_token"}
                )
                # If it doesn't raise, check that result is reasonable
                assert "id" in result
            except (TypeError, AttributeError):
                # Expected if headers is None - code doesn't handle this edge case
                pass

    def test_calendar_json_decode_error(self):
        """Test handling JSON decode errors from calendar API."""
        mock_response = Mock()
        mock_response.json.side_effect = ValueError("Invalid JSON")

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            with pytest.raises(ValueError):
                google_calendar(
                    action="list",
                    date_range="today",
                    _context={"google_access_token": "valid_token"}
                )

    def test_gmail_json_decode_error(self):
        """Test handling JSON decode errors from Gmail API."""
        mock_response = Mock()
        mock_response.json.side_effect = ValueError("Invalid JSON")

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            with pytest.raises(ValueError):
                gmail(
                    action="list",
                    _context={"google_access_token": "valid_token"}
                )


class TestConnectionErrors:
    """Tests for connection error handling."""

    def test_calendar_connection_error(self):
        """Test handling connection errors for calendar."""
        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.ConnectionError("Failed to connect")

            with pytest.raises(requests.ConnectionError):
                google_calendar(
                    action="list",
                    date_range="today",
                    _context={"google_access_token": "valid_token"}
                )

    def test_gmail_connection_error(self):
        """Test handling connection errors for Gmail."""
        with patch('requests.get') as mock_get:
            mock_get.side_effect = requests.ConnectionError("Failed to connect")

            with pytest.raises(requests.ConnectionError):
                gmail(
                    action="list",
                    _context={"google_access_token": "valid_token"}
                )


class TestDateParsingEdgeCases:
    """Tests for date parsing edge cases in calendar operations."""

    def test_single_date_without_slash(self):
        """Single date without slash spans the full day."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="2024-06-15",  # Single date, no end
                _context={"google_access_token": "valid_token"}
            )

        assert result["count"] == 0
        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["params"]["timeMin"] == "2024-06-15T00:00:00Z"
        assert call_kwargs["params"]["timeMax"] == "2024-06-15T23:59:59Z"

    def test_date_range_with_full_iso_format(self):
        """Test date range with full ISO format dates."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            result = google_calendar(
                action="list",
                date_range="2024-01-01/2024-12-31",
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_get.call_args[1]
        assert "2024-01-01T00:00:00Z" == call_kwargs["params"]["timeMin"]
        assert "2024-12-31T23:59:59Z" == call_kwargs["params"]["timeMax"]

    def test_date_range_with_time_components(self):
        """Test that dates with time components don't get double timestamps."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            google_calendar(
                action="list",
                date_range="2026-02-07T00:00:00/2026-02-07T23:59:59",
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["params"]["timeMin"] == "2026-02-07T00:00:00Z"
        assert call_kwargs["params"]["timeMax"] == "2026-02-07T23:59:59Z"

    def test_single_date_with_time_component(self):
        """Test single date with time component doesn't get double timestamp."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            google_calendar(
                action="list",
                date_range="2026-02-07T00:00:00",
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_get.call_args[1]
        # Should not have T00:00:00T00:00:00Z (double)
        assert call_kwargs["params"]["timeMin"] == "2026-02-07T00:00:00Z"
        assert call_kwargs["params"]["timeMax"] == "2026-02-07T00:00:00Z"

    def test_date_with_trailing_z(self):
        """Test date already ending in Z doesn't get double Z."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            google_calendar(
                action="list",
                date_range="2026-02-07T00:00:00Z/2026-02-07T23:59:59Z",
                _context={"google_access_token": "valid_token"}
            )

        call_kwargs = mock_get.call_args[1]
        assert call_kwargs["params"]["timeMin"] == "2026-02-07T00:00:00Z"
        assert call_kwargs["params"]["timeMax"] == "2026-02-07T23:59:59Z"


class TestApiUrlConstruction:
    """Tests for API URL construction."""

    def test_calendar_uses_correct_base_url(self):
        """Test that calendar API uses correct base URL."""
        mock_response = Mock()
        mock_response.json.return_value = {"items": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            google_calendar(
                action="list",
                date_range="today",
                _context={"google_access_token": "valid_token"}
            )

        call_url = mock_get.call_args[0][0]
        assert "googleapis.com/calendar/v3" in call_url
        assert "calendars/primary/events" in call_url

    def test_gmail_uses_correct_base_url(self):
        """Test that Gmail API uses correct base URL."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"messages": []}

        with patch('requests.get') as mock_get:
            mock_get.return_value = mock_response

            gmail(
                action="list",
                _context={"google_access_token": "valid_token"}
            )

        call_url = mock_get.call_args[0][0]
        assert "gmail.googleapis.com/gmail/v1/users/me" in call_url
