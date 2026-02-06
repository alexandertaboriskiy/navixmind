"""
Google API Tools - Calendar and Gmail integration
"""

from datetime import datetime, timedelta
from typing import Any, Dict, Optional

import requests

from ..bridge import ToolError


def google_calendar(
    action: str,
    date_range: Optional[str] = None,
    event: Optional[dict] = None,
    _context: Optional[Dict[str, Any]] = None
) -> dict:
    """
    Interact with Google Calendar.

    Args:
        action: "list", "create", or "delete"
        date_range: For list: "today", "this_week", or ISO date range
        event: For create: {title, start, end, description}
        _context: Internal context with auth tokens

    Returns:
        Dict with calendar data or confirmation
    """
    token = _context.get('google_access_token') if _context else None
    if not token:
        raise ToolError(
            "Google account not connected. Please connect in Settings to use calendar features."
        )

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    base_url = "https://www.googleapis.com/calendar/v3"

    try:
        if action == "list":
            return _list_events(base_url, headers, date_range)
        elif action == "create":
            return _create_event(base_url, headers, event)
        elif action == "delete":
            raise ToolError("Delete action requires event_id parameter")
        else:
            raise ToolError(f"Unknown action: {action}")

    except requests.HTTPError as e:
        if e.response.status_code == 401:
            raise ToolError("Google session expired. Please reconnect in Settings.")
        if e.response.status_code == 403:
            raise ToolError("Calendar access not authorized. User needs to grant Calendar permission in Settings.")
        raise ToolError(f"Calendar API error: {str(e)}")


def _list_events(base_url: str, headers: dict, date_range: Optional[str]) -> dict:
    """List calendar events."""
    now = datetime.utcnow()

    if date_range == "today" or not date_range:
        time_min = now.replace(hour=0, minute=0, second=0).isoformat() + "Z"
        time_max = now.replace(hour=23, minute=59, second=59).isoformat() + "Z"
    elif date_range == "this_week":
        # Start of week (Monday)
        start_of_week = now - timedelta(days=now.weekday())
        time_min = start_of_week.replace(hour=0, minute=0, second=0).isoformat() + "Z"
        time_max = (start_of_week + timedelta(days=7)).isoformat() + "Z"
    else:
        # Assume ISO format range "2024-01-01/2024-01-31" or single date "2024-01-01"
        # Handle dates that may already include time components (e.g. "2024-01-01T00:00:00")
        parts = date_range.strip().split("/")
        start = parts[0].strip()
        end = parts[1].strip() if len(parts) > 1 else start

        # Normalize to RFC3339: append time if missing, ensure trailing Z
        def _to_rfc3339(dt_str, default_time):
            if "T" not in dt_str:
                dt_str = dt_str + "T" + default_time
            return dt_str.rstrip("Z") + "Z"

        time_min = _to_rfc3339(start, "00:00:00")
        time_max = _to_rfc3339(end, "23:59:59")

    params = {
        "timeMin": time_min,
        "timeMax": time_max,
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": 50
    }

    response = requests.get(
        f"{base_url}/calendars/primary/events",
        headers=headers,
        params=params,
        timeout=30
    )
    response.raise_for_status()

    data = response.json()
    events = []

    for item in data.get("items", []):
        start = item.get("start", {})
        end = item.get("end", {})

        events.append({
            "id": item.get("id"),
            "title": item.get("summary", "Untitled"),
            "start": start.get("dateTime") or start.get("date"),
            "end": end.get("dateTime") or end.get("date"),
            "location": item.get("location"),
            "description": item.get("description"),
        })

    return {
        "events": events,
        "count": len(events),
        "range": {"min": time_min, "max": time_max}
    }


def _create_event(base_url: str, headers: dict, event: Optional[dict]) -> dict:
    """Create a calendar event."""
    if not event:
        raise ToolError("Event details required for create action")

    title = event.get("title")
    start = event.get("start")
    end = event.get("end")

    if not all([title, start, end]):
        raise ToolError("Event requires title, start, and end")

    body = {
        "summary": title,
        "start": {"dateTime": start, "timeZone": "UTC"},
        "end": {"dateTime": end, "timeZone": "UTC"},
    }

    if event.get("description"):
        body["description"] = event["description"]

    if event.get("location"):
        body["location"] = event["location"]

    response = requests.post(
        f"{base_url}/calendars/primary/events",
        headers=headers,
        json=body,
        timeout=30
    )
    response.raise_for_status()

    created = response.json()
    return {
        "success": True,
        "event_id": created.get("id"),
        "link": created.get("htmlLink")
    }


def gmail(
    action: str,
    query: Optional[str] = None,
    message_id: Optional[str] = None,
    compose: Optional[dict] = None,
    _context: Optional[Dict[str, Any]] = None
) -> dict:
    """
    Interact with Gmail.

    Args:
        action: "list", "read", or "send"
        query: For list: Gmail search query
        message_id: For read: message ID
        compose: For send: {to, subject, body}
        _context: Internal context with auth tokens

    Returns:
        Dict with email data or confirmation
    """
    token = _context.get('google_access_token') if _context else None
    if not token:
        raise ToolError(
            "Google account not connected. Please connect in Settings to use email features."
        )

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    base_url = "https://gmail.googleapis.com/gmail/v1/users/me"

    try:
        if action == "list":
            return _list_emails(base_url, headers, query)
        elif action == "read":
            return _read_email(base_url, headers, message_id)
        elif action == "send":
            raise ToolError("Sending emails is not enabled. The app only has read-only Gmail access.")
        else:
            raise ToolError(f"Unknown action: {action}")

    except requests.HTTPError as e:
        if e.response.status_code == 401:
            raise ToolError("Google session expired. Please reconnect in Settings.")
        if e.response.status_code == 403:
            raise ToolError("Gmail access not authorized. User needs to grant Gmail permission in Settings.")
        raise ToolError(f"Gmail API error: {str(e)}")


def _list_emails(base_url: str, headers: dict, query: Optional[str]) -> dict:
    """List emails matching query."""
    params = {
        "maxResults": 20,
        "q": query or "is:unread"
    }

    response = requests.get(
        f"{base_url}/messages",
        headers=headers,
        params=params,
        timeout=30
    )
    response.raise_for_status()

    data = response.json()
    messages = []

    for item in data.get("messages", [])[:20]:
        # Get basic headers for each message
        msg_response = requests.get(
            f"{base_url}/messages/{item['id']}",
            headers=headers,
            params={"format": "metadata", "metadataHeaders": ["From", "Subject", "Date"]},
            timeout=30
        )
        if msg_response.status_code == 200:
            msg_data = msg_response.json()
            headers_list = msg_data.get("payload", {}).get("headers", [])
            msg_headers = {h["name"]: h["value"] for h in headers_list}

            messages.append({
                "id": item["id"],
                "from": msg_headers.get("From"),
                "subject": msg_headers.get("Subject"),
                "date": msg_headers.get("Date"),
                "snippet": msg_data.get("snippet")
            })

    return {
        "messages": messages,
        "count": len(messages),
        "query": query
    }


def _read_email(base_url: str, headers: dict, message_id: Optional[str]) -> dict:
    """Read a specific email."""
    if not message_id:
        raise ToolError("message_id required for read action")

    response = requests.get(
        f"{base_url}/messages/{message_id}",
        headers=headers,
        params={"format": "full"},
        timeout=30
    )
    response.raise_for_status()

    data = response.json()
    payload = data.get("payload", {})
    headers_list = payload.get("headers", [])
    msg_headers = {h["name"]: h["value"] for h in headers_list}

    # Extract body
    body = ""
    parts = payload.get("parts", [])
    if parts:
        for part in parts:
            if part.get("mimeType") == "text/plain":
                import base64
                body_data = part.get("body", {}).get("data", "")
                body = base64.urlsafe_b64decode(body_data).decode("utf-8")
                break
    else:
        import base64
        body_data = payload.get("body", {}).get("data", "")
        if body_data:
            body = base64.urlsafe_b64decode(body_data).decode("utf-8")

    return {
        "id": message_id,
        "from": msg_headers.get("From"),
        "to": msg_headers.get("To"),
        "subject": msg_headers.get("Subject"),
        "date": msg_headers.get("Date"),
        "body": body[:10000] if len(body) > 10000 else body  # Truncate long emails
    }


def _send_email(base_url: str, headers: dict, compose: Optional[dict]) -> dict:
    """Send an email."""
    if not compose:
        raise ToolError("compose details required for send action")

    to = compose.get("to")
    subject = compose.get("subject", "")
    body = compose.get("body", "")

    if not to:
        raise ToolError("'to' address required")

    # Construct raw email
    import base64
    from email.mime.text import MIMEText

    message = MIMEText(body)
    message["to"] = to
    message["subject"] = subject

    raw = base64.urlsafe_b64encode(message.as_bytes()).decode("utf-8")

    response = requests.post(
        f"{base_url}/messages/send",
        headers=headers,
        json={"raw": raw},
        timeout=30
    )
    response.raise_for_status()

    return {
        "success": True,
        "message_id": response.json().get("id")
    }
