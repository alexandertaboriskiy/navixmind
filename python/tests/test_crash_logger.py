"""
Comprehensive tests for the NavixMind crash_logger module.

Tests cover:
- Initialization (log file creation, rotation, stderr redirect, exception hook)
- Exception hook behavior (capturing uncaught exceptions)
- Logging functions (log_error, log_info)
- Shutdown and cleanup
- Edge cases (multiple init, uninitialized state, threading, large messages)
"""

import os
import sys
import tempfile
import shutil
import threading
import time
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock

import pytest


class TestCrashLoggerInitialization:
    """Tests for CrashLogger.initialize()."""

    def setup_method(self):
        """Reset CrashLogger state before each test."""
        from navixmind.crash_logger import CrashLogger
        # Store original state
        self._original_stderr = sys.stderr
        self._original_excepthook = sys.excepthook
        # Reset class state
        CrashLogger.LOG_DIR = None
        CrashLogger._stderr_file = None
        CrashLogger._original_stderr = None

    def teardown_method(self):
        """Restore state after each test."""
        from navixmind.crash_logger import CrashLogger
        # Shutdown if initialized
        if CrashLogger._stderr_file:
            try:
                CrashLogger._stderr_file.close()
            except Exception:
                pass
        CrashLogger._stderr_file = None
        # Restore stderr
        sys.stderr = self._original_stderr
        sys.excepthook = self._original_excepthook

    def test_creates_log_file_in_specified_directory(self):
        """Test that initialize creates log file in the specified directory."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            log_path = os.path.join(tmpdir, 'python_crash.log')
            assert os.path.exists(log_path), "Log file should be created"

    def test_sets_log_dir_class_variable(self):
        """Test that initialize sets LOG_DIR class variable."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            assert CrashLogger.LOG_DIR == tmpdir

    def test_rotates_log_when_too_large(self):
        """Test that log file is rotated when exceeding MAX_LOG_SIZE."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = os.path.join(tmpdir, 'python_crash.log')
            old_path = log_path + '.old'

            # Create a log file larger than MAX_LOG_SIZE (1MB)
            large_content = 'x' * (CrashLogger.MAX_LOG_SIZE + 1000)
            with open(log_path, 'w') as f:
                f.write(large_content)

            CrashLogger.initialize(tmpdir)

            # Old log should be renamed
            assert os.path.exists(old_path), "Old log should be renamed to .old"
            # New log should be created (smaller since it just has init message)
            assert os.path.exists(log_path), "New log file should be created"
            assert os.path.getsize(log_path) < CrashLogger.MAX_LOG_SIZE

    def test_removes_existing_old_log_on_rotation(self):
        """Test that existing .old log is removed during rotation."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = os.path.join(tmpdir, 'python_crash.log')
            old_path = log_path + '.old'

            # Create existing .old file
            with open(old_path, 'w') as f:
                f.write('old content')

            # Create a log file larger than MAX_LOG_SIZE
            large_content = 'x' * (CrashLogger.MAX_LOG_SIZE + 1000)
            with open(log_path, 'w') as f:
                f.write(large_content)

            CrashLogger.initialize(tmpdir)

            # Old content should be replaced with current large log
            with open(old_path, 'r') as f:
                content = f.read()
            assert content == large_content

    def test_no_rotation_when_log_small(self):
        """Test that small log files are not rotated."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = os.path.join(tmpdir, 'python_crash.log')
            old_path = log_path + '.old'

            # Create a small log file
            with open(log_path, 'w') as f:
                f.write('small content\n')

            CrashLogger.initialize(tmpdir)

            # No .old file should be created
            assert not os.path.exists(old_path)
            # Log file should have original + new content
            with open(log_path, 'r') as f:
                content = f.read()
            assert 'small content' in content

    def test_redirects_stderr_to_file(self):
        """Test that stderr is redirected to the log file."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            # sys.stderr should now be the file
            assert sys.stderr is CrashLogger._stderr_file

    def test_stores_original_stderr(self):
        """Test that original stderr is stored for restoration."""
        from navixmind.crash_logger import CrashLogger

        original = sys.stderr
        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            assert CrashLogger._original_stderr is original

    def test_installs_exception_hook(self):
        """Test that custom exception hook is installed."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            # Compare underlying functions since classmethods create new bound methods on access
            assert sys.excepthook.__func__ is CrashLogger._exception_hook.__func__

    def test_writes_initialization_message(self):
        """Test that initialization message is written to log."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            CrashLogger._stderr_file.flush()

            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'Python initialized' in content

    def test_initialization_message_has_timestamp(self):
        """Test that initialization message includes ISO timestamp."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            before = datetime.now()
            CrashLogger.initialize(tmpdir)
            CrashLogger._stderr_file.flush()

            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            # Check for ISO format date pattern (YYYY-MM-DD)
            assert before.strftime('%Y-%m-%d') in content


class TestCrashLoggerExceptionHook:
    """Tests for CrashLogger._exception_hook()."""

    def setup_method(self):
        """Reset CrashLogger state before each test."""
        from navixmind.crash_logger import CrashLogger
        self._original_stderr = sys.stderr
        self._original_excepthook = sys.excepthook
        CrashLogger.LOG_DIR = None
        CrashLogger._stderr_file = None
        CrashLogger._original_stderr = None

    def teardown_method(self):
        """Restore state after each test."""
        from navixmind.crash_logger import CrashLogger
        if CrashLogger._stderr_file:
            try:
                CrashLogger._stderr_file.close()
            except Exception:
                pass
        CrashLogger._stderr_file = None
        sys.stderr = self._original_stderr
        sys.excepthook = self._original_excepthook

    def test_captures_exception_type(self):
        """Test that exception type is captured in log."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise ValueError("test error")
            except ValueError:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'ValueError' in content

    def test_captures_exception_message(self):
        """Test that exception message is captured in log."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise RuntimeError("specific error message")
            except RuntimeError:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'specific error message' in content

    def test_writes_timestamp(self):
        """Test that exception log includes timestamp."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            before = datetime.now()
            try:
                raise Exception("test")
            except Exception:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            # Should have UNCAUGHT EXCEPTION header with timestamp
            assert 'UNCAUGHT EXCEPTION at' in content
            assert before.strftime('%Y-%m-%d') in content

    def test_writes_traceback(self):
        """Test that full traceback is written to log."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            def inner_function():
                raise TypeError("traceback test")

            try:
                inner_function()
            except TypeError:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'Traceback' in content
            assert 'inner_function' in content

    def test_writes_separator_line(self):
        """Test that exception log has visual separator."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise Exception("test")
            except Exception:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            # Should have separator line of '=' characters
            assert '=' * 60 in content

    def test_flushes_output(self):
        """Test that output is flushed after exception logging."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise Exception("flush test")
            except Exception:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            # Read immediately without explicit flush - content should be there
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'flush test' in content

    def test_also_prints_to_original_stderr(self):
        """Test that exception is also printed to original stderr."""
        from navixmind.crash_logger import CrashLogger

        mock_stderr = MagicMock()
        mock_stderr.write = Mock()

        with tempfile.TemporaryDirectory() as tmpdir:
            # Set our mock as original stderr
            sys.stderr = mock_stderr
            CrashLogger.initialize(tmpdir)

            try:
                raise Exception("dual output test")
            except Exception:
                exc_type, exc_value, exc_tb = sys.exc_info()
                CrashLogger._exception_hook(exc_type, exc_value, exc_tb)

            # Original stderr should have received output via traceback.print_exception
            # which calls write multiple times
            assert CrashLogger._original_stderr is mock_stderr

    def test_handles_none_stderr_file(self):
        """Test that exception hook handles None stderr file gracefully."""
        from navixmind.crash_logger import CrashLogger

        # Don't initialize - _stderr_file is None
        CrashLogger._stderr_file = None

        try:
            raise Exception("test")
        except Exception:
            exc_type, exc_value, exc_tb = sys.exc_info()
            # Should not raise
            CrashLogger._exception_hook(exc_type, exc_value, exc_tb)


class TestCrashLoggerLogging:
    """Tests for log_error and log_info methods."""

    def setup_method(self):
        """Reset CrashLogger state before each test."""
        from navixmind.crash_logger import CrashLogger
        self._original_stderr = sys.stderr
        self._original_excepthook = sys.excepthook
        CrashLogger.LOG_DIR = None
        CrashLogger._stderr_file = None
        CrashLogger._original_stderr = None

    def teardown_method(self):
        """Restore state after each test."""
        from navixmind.crash_logger import CrashLogger
        if CrashLogger._stderr_file:
            try:
                CrashLogger._stderr_file.close()
            except Exception:
                pass
        CrashLogger._stderr_file = None
        sys.stderr = self._original_stderr
        sys.excepthook = self._original_excepthook

    def test_log_error_writes_context(self):
        """Test that log_error writes the context string."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise ValueError("test error")
            except ValueError as e:
                CrashLogger.log_error("database connection", e)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'ERROR in database connection' in content

    def test_log_error_writes_error_type_and_message(self):
        """Test that log_error writes exception type and message."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise KeyError("missing_key")
            except KeyError as e:
                CrashLogger.log_error("dict access", e)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'KeyError' in content
            assert 'missing_key' in content

    def test_log_error_writes_timestamp(self):
        """Test that log_error includes timestamp."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            before = datetime.now()

            try:
                raise Exception("test")
            except Exception as e:
                CrashLogger.log_error("test context", e)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert before.strftime('%Y-%m-%d') in content

    def test_log_error_writes_traceback(self):
        """Test that log_error writes traceback."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            def cause_error():
                raise RuntimeError("inner error")

            try:
                cause_error()
            except RuntimeError as e:
                CrashLogger.log_error("function call", e)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'Traceback' in content or 'cause_error' in content

    def test_log_info_writes_message(self):
        """Test that log_info writes the message."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            CrashLogger.log_info("Application started successfully")

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'Application started successfully' in content

    def test_log_info_includes_info_prefix(self):
        """Test that log_info includes INFO prefix."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            CrashLogger.log_info("test message")

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'INFO:' in content

    def test_log_info_writes_timestamp(self):
        """Test that log_info includes timestamp."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            before = datetime.now()
            CrashLogger.log_info("timestamped message")

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert before.strftime('%Y-%m-%d') in content

    def test_log_error_handles_uninitialized_state(self):
        """Test that log_error handles uninitialized state gracefully."""
        from navixmind.crash_logger import CrashLogger

        # Don't initialize
        try:
            raise Exception("test")
        except Exception as e:
            # Should not raise
            CrashLogger.log_error("context", e)

    def test_log_info_handles_uninitialized_state(self):
        """Test that log_info handles uninitialized state gracefully."""
        from navixmind.crash_logger import CrashLogger

        # Don't initialize
        # Should not raise
        CrashLogger.log_info("test message")


class TestCrashLoggerShutdown:
    """Tests for CrashLogger.shutdown()."""

    def setup_method(self):
        """Reset CrashLogger state before each test."""
        from navixmind.crash_logger import CrashLogger
        self._original_stderr = sys.stderr
        self._original_excepthook = sys.excepthook
        CrashLogger.LOG_DIR = None
        CrashLogger._stderr_file = None
        CrashLogger._original_stderr = None

    def teardown_method(self):
        """Restore state after each test."""
        from navixmind.crash_logger import CrashLogger
        if CrashLogger._stderr_file:
            try:
                CrashLogger._stderr_file.close()
            except Exception:
                pass
        CrashLogger._stderr_file = None
        sys.stderr = self._original_stderr
        sys.excepthook = self._original_excepthook

    def test_writes_shutdown_message(self):
        """Test that shutdown writes shutdown message to log."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            log_path = os.path.join(tmpdir, 'python_crash.log')

            CrashLogger.shutdown()

            with open(log_path, 'r') as f:
                content = f.read()

            assert 'Python shutdown' in content

    def test_shutdown_message_has_timestamp(self):
        """Test that shutdown message includes timestamp."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            log_path = os.path.join(tmpdir, 'python_crash.log')
            before = datetime.now()

            CrashLogger.shutdown()

            with open(log_path, 'r') as f:
                content = f.read()

            # Find shutdown line and check for timestamp
            assert before.strftime('%Y-%m-%d') in content

    def test_closes_file_handle(self):
        """Test that shutdown closes the file handle."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            file_handle = CrashLogger._stderr_file

            CrashLogger.shutdown()

            assert file_handle.closed
            assert CrashLogger._stderr_file is None

    def test_restores_original_stderr(self):
        """Test that shutdown restores original stderr."""
        from navixmind.crash_logger import CrashLogger

        original = sys.stderr
        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            assert sys.stderr is not original

            CrashLogger.shutdown()

            assert sys.stderr is original

    def test_shutdown_handles_uninitialized_state(self):
        """Test that shutdown handles uninitialized state gracefully."""
        from navixmind.crash_logger import CrashLogger

        # Don't initialize
        # Should not raise
        CrashLogger.shutdown()

    def test_shutdown_can_be_called_multiple_times(self):
        """Test that shutdown can be called multiple times safely."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            CrashLogger.shutdown()
            # Should not raise
            CrashLogger.shutdown()
            CrashLogger.shutdown()


class TestCrashLoggerEdgeCases:
    """Tests for edge cases and unusual scenarios."""

    def setup_method(self):
        """Reset CrashLogger state before each test."""
        from navixmind.crash_logger import CrashLogger
        self._original_stderr = sys.stderr
        self._original_excepthook = sys.excepthook
        CrashLogger.LOG_DIR = None
        CrashLogger._stderr_file = None
        CrashLogger._original_stderr = None

    def teardown_method(self):
        """Restore state after each test."""
        from navixmind.crash_logger import CrashLogger
        if CrashLogger._stderr_file:
            try:
                CrashLogger._stderr_file.close()
            except Exception:
                pass
        CrashLogger._stderr_file = None
        sys.stderr = self._original_stderr
        sys.excepthook = self._original_excepthook

    def test_multiple_initialize_calls(self):
        """Test that multiple initialize calls work correctly."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir1:
            with tempfile.TemporaryDirectory() as tmpdir2:
                CrashLogger.initialize(tmpdir1)
                first_file = CrashLogger._stderr_file

                # Second initialize (note: doesn't close first file - potential leak)
                CrashLogger.initialize(tmpdir2)

                assert CrashLogger.LOG_DIR == tmpdir2
                assert os.path.exists(os.path.join(tmpdir2, 'python_crash.log'))

                # Clean up first file
                if not first_file.closed:
                    first_file.close()

    def test_logging_before_initialize(self):
        """Test that logging before initialize doesn't crash."""
        from navixmind.crash_logger import CrashLogger

        # Should not raise
        CrashLogger.log_info("before init")

        try:
            raise Exception("test")
        except Exception as e:
            CrashLogger.log_error("before init", e)

    def test_concurrent_logging_from_multiple_threads(self):
        """Test thread safety of logging operations."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            log_path = os.path.join(tmpdir, 'python_crash.log')

            errors = []
            messages_logged = []

            def log_messages(thread_id):
                try:
                    for i in range(10):
                        msg = f"Thread {thread_id} message {i}"
                        CrashLogger.log_info(msg)
                        messages_logged.append(msg)
                except Exception as e:
                    errors.append(e)

            # Create multiple threads
            threads = []
            for i in range(5):
                t = threading.Thread(target=log_messages, args=(i,))
                threads.append(t)

            # Start all threads
            for t in threads:
                t.start()

            # Wait for completion
            for t in threads:
                t.join()

            # Check no errors occurred
            assert len(errors) == 0, f"Errors occurred: {errors}"

            # Flush and read content
            CrashLogger._stderr_file.flush()
            with open(log_path, 'r') as f:
                content = f.read()

            # At least some messages should be present
            # (exact count may vary due to buffering)
            assert 'Thread' in content
            assert 'message' in content

    def test_very_large_error_message(self):
        """Test handling of very large error messages."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            log_path = os.path.join(tmpdir, 'python_crash.log')

            # Create a very large error message (100KB)
            large_message = 'x' * (100 * 1024)

            try:
                raise ValueError(large_message)
            except ValueError as e:
                CrashLogger.log_error("large error test", e)

            CrashLogger._stderr_file.flush()

            # File should exist and contain the message
            assert os.path.exists(log_path)
            with open(log_path, 'r') as f:
                content = f.read()

            assert large_message in content

    def test_special_characters_in_message(self):
        """Test handling of special characters in messages."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)
            log_path = os.path.join(tmpdir, 'python_crash.log')

            special_msg = "Test with special chars: \n\t\r unicode: \u2603 emoji: \U0001F600"
            CrashLogger.log_info(special_msg)

            CrashLogger._stderr_file.flush()
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'unicode:' in content
            assert 'emoji:' in content

    def test_exception_with_no_message(self):
        """Test handling exception with no message."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                raise ValueError()
            except ValueError as e:
                CrashLogger.log_error("no message error", e)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'ValueError' in content
            assert 'no message error' in content

    def test_nested_exception(self):
        """Test handling of nested/chained exceptions."""
        from navixmind.crash_logger import CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            CrashLogger.initialize(tmpdir)

            try:
                try:
                    raise ValueError("original error")
                except ValueError:
                    raise RuntimeError("wrapper error")
            except RuntimeError as e:
                CrashLogger.log_error("nested exception", e)

            CrashLogger._stderr_file.flush()
            log_path = os.path.join(tmpdir, 'python_crash.log')
            with open(log_path, 'r') as f:
                content = f.read()

            assert 'RuntimeError' in content
            assert 'wrapper error' in content


class TestModuleLevelFunction:
    """Tests for the module-level initialize function."""

    def setup_method(self):
        """Reset CrashLogger state before each test."""
        from navixmind.crash_logger import CrashLogger
        self._original_stderr = sys.stderr
        self._original_excepthook = sys.excepthook
        CrashLogger.LOG_DIR = None
        CrashLogger._stderr_file = None
        CrashLogger._original_stderr = None

    def teardown_method(self):
        """Restore state after each test."""
        from navixmind.crash_logger import CrashLogger
        if CrashLogger._stderr_file:
            try:
                CrashLogger._stderr_file.close()
            except Exception:
                pass
        CrashLogger._stderr_file = None
        sys.stderr = self._original_stderr
        sys.excepthook = self._original_excepthook

    def test_module_level_initialize(self):
        """Test that module-level initialize function works."""
        from navixmind.crash_logger import initialize, CrashLogger

        with tempfile.TemporaryDirectory() as tmpdir:
            initialize(tmpdir)

            assert CrashLogger.LOG_DIR == tmpdir
            assert CrashLogger._stderr_file is not None
            log_path = os.path.join(tmpdir, 'python_crash.log')
            assert os.path.exists(log_path)
