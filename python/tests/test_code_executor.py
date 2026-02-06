"""
Tests for the secure Python code executor.

Tests both functionality and security restrictions.
"""

import pytest
from navixmind.tools.code_executor import (
    execute_python,
    validate_code,
    python_execute,
    SAFE_MODULES,
    BLOCKED_MODULES,
    SecurityError,
)


class TestCodeValidation:
    """Test code validation before execution."""

    def test_valid_simple_code(self):
        """Valid simple code should pass validation."""
        code = "x = 1 + 1\nprint(x)"
        is_valid, errors = validate_code(code)
        assert is_valid
        assert not errors

    def test_valid_import_safe_module(self):
        """Import of safe modules should pass."""
        code = "import math\nprint(math.pi)"
        is_valid, errors = validate_code(code)
        assert is_valid

    def test_invalid_import_os(self):
        """Import of os should fail validation."""
        code = "import os\nos.system('ls')"
        is_valid, errors = validate_code(code)
        assert not is_valid
        assert any('os' in e for e in errors)

    def test_invalid_import_subprocess(self):
        """Import of subprocess should fail validation."""
        code = "import subprocess\nsubprocess.run(['ls'])"
        is_valid, errors = validate_code(code)
        assert not is_valid

    def test_invalid_eval_call(self):
        """Call to eval should fail validation."""
        code = "eval('1+1')"
        is_valid, errors = validate_code(code)
        assert not is_valid
        assert any('eval' in e for e in errors)

    def test_invalid_exec_call(self):
        """Call to exec should fail validation."""
        code = "exec('print(1)')"
        is_valid, errors = validate_code(code)
        assert not is_valid

    def test_syntax_error(self):
        """Syntax errors should be caught."""
        code = "def foo(\nprint('broken')"
        is_valid, errors = validate_code(code)
        assert not is_valid
        assert any('Syntax error' in e for e in errors)


class TestCodeExecution:
    """Test actual code execution."""

    def test_simple_calculation(self):
        """Simple calculation should work."""
        result = execute_python("x = 2 + 2\nprint(x)")
        assert result['success']
        assert '4' in result['output']

    def test_expression_result(self):
        """Last expression value should be captured."""
        result = execute_python("2 + 2")
        assert result['success']
        assert result['result'] == '4'

    def test_print_output(self):
        """Print statements should be captured."""
        result = execute_python("print('hello')\nprint('world')")
        assert result['success']
        assert 'hello' in result['output']
        assert 'world' in result['output']

    def test_import_math(self):
        """Importing math should work."""
        result = execute_python("import math\nprint(math.sqrt(16))")
        assert result['success']
        assert '4' in result['output']

    def test_import_json(self):
        """Importing json should work."""
        result = execute_python("import json\nprint(json.dumps({'a': 1}))")
        assert result['success']
        assert 'a' in result['output']

    def test_import_numpy(self):
        """Importing numpy should work."""
        result = execute_python("import numpy as np\nprint(np.array([1,2,3]).sum())")
        assert result['success']
        assert '6' in result['output']

    def test_import_datetime(self):
        """Importing datetime should work."""
        result = execute_python("from datetime import date\nprint(date.today().year)")
        assert result['success']
        assert '202' in result['output']  # Year starts with 202x

    def test_list_comprehension(self):
        """List comprehensions should work."""
        result = execute_python("[x**2 for x in range(5)]")
        assert result['success']
        assert '[0, 1, 4, 9, 16]' in result['result']

    def test_multiline_function(self):
        """Defining and calling functions should work."""
        code = """
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n-1)

print(factorial(5))
"""
        result = execute_python(code)
        assert result['success']
        assert '120' in result['output']

    def test_exception_in_code(self):
        """Exceptions in user code should be caught and reported."""
        result = execute_python("1/0")
        assert not result['success']
        assert 'ZeroDivisionError' in result['error']

    def test_name_error(self):
        """NameError should be caught."""
        result = execute_python("print(undefined_variable)")
        assert not result['success']
        assert 'NameError' in result['error']


class TestSecurityRestrictions:
    """Test that security restrictions are enforced."""

    def test_blocked_import_os(self):
        """Import os should be blocked at runtime."""
        result = execute_python("import os")
        assert not result['success']
        assert 'not allowed' in result['error'].lower() or 'security' in result['error'].lower()

    def test_blocked_import_subprocess(self):
        """Import subprocess should be blocked."""
        result = execute_python("import subprocess")
        assert not result['success']

    def test_blocked_import_socket(self):
        """Import socket should be blocked."""
        result = execute_python("import socket")
        assert not result['success']

    def test_blocked_import_requests(self):
        """Import requests should be blocked (use web_fetch instead)."""
        result = execute_python("import requests")
        assert not result['success']

    def test_blocked_eval(self):
        """eval() should be blocked."""
        result = execute_python("eval('1+1')")
        assert not result['success']

    def test_blocked_exec(self):
        """exec() should be blocked."""
        result = execute_python("exec('x=1')")
        assert not result['success']

    def test_blocked_compile(self):
        """compile() should be blocked."""
        result = execute_python("compile('x=1', '', 'exec')")
        assert not result['success']

    def test_blocked_open_write(self):
        """open() with write mode should be blocked."""
        result = execute_python("open('/tmp/test.txt', 'w')")
        assert not result['success']
        assert 'not allowed' in result['error'].lower()

    def test_blocked_open_unauthorized_file(self):
        """open() on unauthorized file should be blocked."""
        result = execute_python("open('/etc/passwd', 'r')")
        assert not result['success']
        assert 'not allowed' in result['error'].lower()

    def test_blocked_dunder_class(self):
        """Access to __class__ should be restricted."""
        result = execute_python("''.__class__.__bases__[0].__subclasses__()")
        assert not result['success']

    def test_blocked_import_builtins(self):
        """Import builtins should be blocked."""
        result = execute_python("import builtins")
        assert not result['success']

    def test_blocked_getattr_trick(self):
        """getattr tricks to access blocked functions should fail."""
        result = execute_python("getattr(__builtins__, 'eval')('1+1')")
        assert not result['success']


class TestTimeout:
    """Test timeout enforcement."""

    def test_infinite_loop_timeout(self):
        """Infinite loops should timeout."""
        result = execute_python("while True: pass", timeout=2)
        assert not result['success']
        assert 'timed out' in result['error'].lower()

    def test_long_computation_timeout(self):
        """Long computations should timeout."""
        code = """
result = 0
for i in range(10**10):
    result += i
print(result)
"""
        result = execute_python(code, timeout=2)
        assert not result['success']
        assert 'timed out' in result['error'].lower()


class TestFileAccess:
    """Test controlled file access."""

    def test_read_allowed_file(self, tmp_path):
        """Reading explicitly allowed files should work."""
        test_file = tmp_path / "test.txt"
        test_file.write_text("hello world")

        code = f"print(open('{test_file}').read())"
        result = execute_python(code, allowed_file_paths=[str(test_file)])
        assert result['success']
        assert 'hello world' in result['output']

    def test_read_disallowed_file(self, tmp_path):
        """Reading files not in allowed list should fail."""
        test_file = tmp_path / "secret.txt"
        test_file.write_text("secret data")

        code = f"print(open('{test_file}').read())"
        result = execute_python(code, allowed_file_paths=[])  # No files allowed
        assert not result['success']
        assert 'not allowed' in result['error'].lower()


class TestOutputLimits:
    """Test output size limits."""

    def test_large_output_truncated(self):
        """Large outputs should be truncated."""
        code = "print('x' * 100000)"
        result = execute_python(code)
        assert result['success']
        assert len(result['output']) <= 51000  # MAX_OUTPUT_SIZE + some buffer
        assert 'truncated' in result['output'].lower()


class TestToolInterface:
    """Test the tool interface function."""

    def test_python_execute_success(self):
        """python_execute should return proper format on success."""
        result = python_execute("print('test')")
        assert result['success']
        assert 'output' in result

    def test_python_execute_error(self):
        """python_execute should raise ToolError on failure."""
        from navixmind.bridge import ToolError
        with pytest.raises(ToolError):
            python_execute("import os")


class TestModuleLists:
    """Test that module lists are properly configured."""

    def test_no_overlap_safe_blocked(self):
        """Safe and blocked modules should not overlap."""
        overlap = SAFE_MODULES & BLOCKED_MODULES
        assert not overlap, f"Modules in both lists: {overlap}"

    def test_dangerous_modules_blocked(self):
        """Critical dangerous modules should be blocked."""
        critical = {'os', 'sys', 'subprocess', 'socket', 'requests'}
        assert critical.issubset(BLOCKED_MODULES)

    def test_useful_modules_safe(self):
        """Useful safe modules should be allowed."""
        useful = {'math', 'json', 're', 'datetime', 'collections'}
        assert useful.issubset(SAFE_MODULES)
