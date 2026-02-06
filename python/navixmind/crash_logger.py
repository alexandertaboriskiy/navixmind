"""
Crash Logger - Captures Python crashes for Flutter recovery

This module captures all Python output and crashes to a log file.
Flutter reads this file on startup to detect previous crashes.
"""

import sys
import os
import traceback
from datetime import datetime
from typing import Optional


class CrashLogger:
    """
    Captures all Python output and crashes to a log file.
    Flutter reads this file on startup to detect previous crashes.
    """

    LOG_DIR: Optional[str] = None
    MAX_LOG_SIZE = 1 * 1024 * 1024  # 1MB
    _stderr_file = None
    _original_stderr = None

    @classmethod
    def initialize(cls, log_dir: str) -> None:
        """
        Initialize crash logging.

        Args:
            log_dir: Directory to store crash logs
        """
        cls.LOG_DIR = log_dir
        log_path = os.path.join(log_dir, 'python_crash.log')

        # Rotate if too large
        if os.path.exists(log_path) and os.path.getsize(log_path) > cls.MAX_LOG_SIZE:
            old_path = log_path + '.old'
            if os.path.exists(old_path):
                os.remove(old_path)
            os.rename(log_path, old_path)

        # Store original stderr
        cls._original_stderr = sys.stderr

        # Redirect stderr to file (captures C-level errors too)
        cls._stderr_file = open(log_path, 'a', buffering=1)  # Line buffered
        sys.stderr = cls._stderr_file

        # Install exception hook for Python exceptions
        sys.excepthook = cls._exception_hook

        # Log initialization
        cls._stderr_file.write(f"\n[{datetime.now().isoformat()}] Python initialized\n")
        cls._stderr_file.flush()

    @classmethod
    def _exception_hook(cls, exc_type, exc_value, exc_tb) -> None:
        """Called on uncaught Python exceptions."""
        if cls._stderr_file is None:
            return

        timestamp = datetime.now().isoformat()
        cls._stderr_file.write(f"\n{'='*60}\n")
        cls._stderr_file.write(f"UNCAUGHT EXCEPTION at {timestamp}\n")
        cls._stderr_file.write(f"{'='*60}\n")
        traceback.print_exception(exc_type, exc_value, exc_tb, file=cls._stderr_file)
        cls._stderr_file.flush()

        # Also print to original stderr if available (for debugging)
        if cls._original_stderr:
            traceback.print_exception(exc_type, exc_value, exc_tb, file=cls._original_stderr)

    @classmethod
    def log_error(cls, context: str, error: Exception) -> None:
        """
        Explicit error logging.

        Args:
            context: Description of where the error occurred
            error: The exception that occurred
        """
        if cls._stderr_file is None:
            return

        timestamp = datetime.now().isoformat()
        cls._stderr_file.write(f"\n[{timestamp}] ERROR in {context}:\n")
        cls._stderr_file.write(f"{type(error).__name__}: {error}\n")
        cls._stderr_file.write(traceback.format_exc())
        cls._stderr_file.flush()

    @classmethod
    def log_info(cls, message: str) -> None:
        """Log an info message."""
        if cls._stderr_file is None:
            return

        timestamp = datetime.now().isoformat()
        cls._stderr_file.write(f"[{timestamp}] INFO: {message}\n")
        cls._stderr_file.flush()

    @classmethod
    def shutdown(cls) -> None:
        """Cleanup and close log file."""
        if cls._stderr_file:
            cls._stderr_file.write(f"\n[{datetime.now().isoformat()}] Python shutdown\n")
            cls._stderr_file.flush()
            cls._stderr_file.close()
            cls._stderr_file = None

        # Restore original stderr
        if cls._original_stderr:
            sys.stderr = cls._original_stderr


# Module-level convenience function
def initialize(log_dir: str) -> None:
    """Initialize crash logging."""
    CrashLogger.initialize(log_dir)
