"""
Secure Python Code Executor

Provides sandboxed Python code execution for the ReAct agent.
Allows the LLM to write and run arbitrary Python code with safety restrictions.

Security measures:
1. Restricted builtins (no eval, exec, compile, open for writing)
2. Module whitelist (safe modules only)
3. Execution timeout (prevents infinite loops)
4. Memory limit via output truncation
5. No network access (use web_fetch tool instead)
6. File access only to explicitly provided paths
"""

import ast
import io
import os as _os
import sys
import traceback
import threading
from contextlib import redirect_stdout, redirect_stderr
from typing import Any, Dict, List, Optional, Tuple
from functools import wraps

# Set non-interactive matplotlib backend before anything imports it
_os.environ['MPLBACKEND'] = 'Agg'

from ..bridge import ToolError


# Maximum execution time in seconds
EXECUTION_TIMEOUT = 30

# Maximum output size in characters
MAX_OUTPUT_SIZE = 50000

# Whitelisted modules that are safe to import
SAFE_MODULES = {
    # Built-in safe modules
    'math',
    'cmath',
    'decimal',
    'fractions',
    'random',
    'statistics',

    # String and text
    'string',
    're',
    'unicodedata',
    'textwrap',

    # Data structures
    'collections',
    'heapq',
    'bisect',
    'array',
    'copy',
    'enum',

    # Functional programming
    'itertools',
    'functools',
    'operator',

    # Date and time
    'datetime',
    'calendar',
    'time',  # Only time.time(), time.sleep() blocked

    # Data formats
    'json',
    'csv',
    'base64',
    'hashlib',
    'hmac',

    # Type hints
    'typing',
    'types',

    # Other safe modules
    'dataclasses',
    'abc',
    'contextlib',
    'warnings',

    # Installed packages (safe subset)
    'numpy',
    'dateutil',
    'dateutil.parser',

    # Data analysis
    'pandas',

    # Plotting
    'matplotlib',
    'matplotlib.pyplot',
    'matplotlib.figure',
    'matplotlib.colors',
    'matplotlib.cm',
    'matplotlib.ticker',
    'matplotlib.dates',
    'matplotlib.patches',

}

# Explicitly blocked modules
BLOCKED_MODULES = {
    'os',
    'sys',
    'subprocess',
    'shutil',
    'pathlib',  # Can traverse filesystem
    'glob',
    'socket',
    'http',
    'urllib',
    'requests',  # Use web_fetch tool instead
    'ftplib',
    'smtplib',
    'telnetlib',
    'ssl',
    'asyncio',  # Complex, can bypass restrictions
    'multiprocessing',
    'threading',  # Already using for timeout
    'concurrent',
    'ctypes',
    'importlib',
    'builtins',
    '__builtins__',
    'code',
    'codeop',
    'compile',
    'pickle',  # Security risk
    'marshal',
    'shelve',
    'dbm',
    'sqlite3',  # Use app's database instead
    'tempfile',
    'pty',
    'tty',
    'termios',
    'resource',
    'sysconfig',
    'distutils',
    'setuptools',
    'pip',
}


class TimeoutError(Exception):
    """Raised when code execution times out."""
    pass


class SecurityError(Exception):
    """Raised when code attempts unsafe operations."""
    pass


def _timeout_handler(signum, frame):
    """Signal handler for timeout."""
    raise TimeoutError(f"Code execution timed out after {EXECUTION_TIMEOUT} seconds")


class RestrictedImporter:
    """
    Custom importer that only allows whitelisted modules.
    """

    def __init__(self, allowed_modules: set):
        self.allowed_modules = allowed_modules
        self.blocked_modules = BLOCKED_MODULES

    def find_module(self, name: str, path=None):
        """Check if module is allowed."""
        # Get the top-level module name
        top_level = name.split('.')[0]

        if top_level in self.blocked_modules:
            raise SecurityError(f"Import of '{name}' is not allowed for security reasons")

        if top_level not in self.allowed_modules:
            raise SecurityError(
                f"Import of '{name}' is not allowed. "
                f"Only these modules are available: {', '.join(sorted(self.allowed_modules))}"
            )

        # Return None to let the normal import machinery handle it
        return None


class SafeBuiltins:
    """
    Provides a restricted set of Python builtins.
    """

    # Dangerous builtins to remove
    BLOCKED_BUILTINS = {
        'eval',
        'exec',
        'compile',
        '__import__',
        'open',  # We provide a safe version
        'input',
        'breakpoint',
        'credits',
        'copyright',
        'license',
        'help',
        'quit',
        'exit',
    }

    @classmethod
    def get_safe_builtins(cls) -> Dict[str, Any]:
        """Return a dict of safe builtins."""
        import builtins

        safe = {}
        for name in dir(builtins):
            if not name.startswith('_') and name not in cls.BLOCKED_BUILTINS:
                safe[name] = getattr(builtins, name)

        # Add our safe __import__
        safe['__import__'] = cls._safe_import

        # Add restricted open (read-only, specific paths only)
        safe['open'] = cls._safe_open

        # Add print (captured via redirect_stdout)
        safe['print'] = print

        return safe

    @staticmethod
    def _safe_import(name: str, globals=None, locals=None, fromlist=(), level=0):
        """Safe import that checks against whitelist."""
        top_level = name.split('.')[0]

        if top_level in BLOCKED_MODULES:
            raise SecurityError(f"Import of '{name}' is not allowed for security reasons")

        if top_level not in SAFE_MODULES:
            raise SecurityError(
                f"Import of '{name}' is not allowed. "
                f"Available modules: {', '.join(sorted(SAFE_MODULES))}"
            )

        # Use the real __import__
        import builtins
        return builtins.__import__(name, globals, locals, fromlist, level)

    # Class variable to store allowed paths
    _allowed_paths: List[str] = []

    # Class variable to store writable output directory
    _output_dir: str = ''

    @classmethod
    def set_allowed_paths(cls, paths: List[str]):
        """Set the list of file paths that can be read."""
        cls._allowed_paths = [str(p) for p in paths]

    @classmethod
    def set_output_dir(cls, path: str):
        """Set the output directory where files can be written."""
        cls._output_dir = str(path) if path else ''

    @classmethod
    def _safe_open(cls, file, mode='r', *args, **kwargs):
        """Safe open that only allows reading specific files and writing to output_dir."""
        file_str = str(file)

        # Check write modes
        if 'w' in mode or 'a' in mode or 'x' in mode or '+' in mode:
            # Allow writes only inside output_dir
            if cls._output_dir and file_str.startswith(cls._output_dir):
                import builtins
                return builtins.open(file, mode, *args, **kwargs)
            raise SecurityError("Writing files is not allowed outside the output directory.")

        # Check if file is in allowed paths
        if not any(file_str == allowed or file_str.startswith(allowed) for allowed in cls._allowed_paths):
            raise SecurityError(
                f"Reading '{file}' is not allowed. "
                f"Only files explicitly provided by the user can be read."
            )

        # Use the real open
        import builtins
        return builtins.open(file, mode, *args, **kwargs)


class CodeValidator(ast.NodeVisitor):
    """
    AST visitor that checks for potentially dangerous code patterns.
    """

    def __init__(self):
        self.errors: List[str] = []

    def visit_Import(self, node: ast.Import):
        """Check import statements."""
        for alias in node.names:
            top_level = alias.name.split('.')[0]
            if top_level in BLOCKED_MODULES:
                self.errors.append(f"Import of '{alias.name}' is not allowed")
        self.generic_visit(node)

    def visit_ImportFrom(self, node: ast.ImportFrom):
        """Check from ... import statements."""
        if node.module:
            top_level = node.module.split('.')[0]
            if top_level in BLOCKED_MODULES:
                self.errors.append(f"Import from '{node.module}' is not allowed")
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call):
        """Check for dangerous function calls."""
        # Check for eval/exec calls
        if isinstance(node.func, ast.Name):
            if node.func.id in ('eval', 'exec', 'compile', '__import__'):
                self.errors.append(f"Call to '{node.func.id}' is not allowed")

        # Check for getattr tricks to access blocked functions
        if isinstance(node.func, ast.Attribute):
            if node.func.attr in ('system', 'popen', 'spawn', 'call', 'run'):
                self.errors.append(f"Call to '{node.func.attr}' is not allowed")

        self.generic_visit(node)

    def visit_Attribute(self, node: ast.Attribute):
        """Check for dangerous attribute access."""
        # Block access to __class__, __bases__, etc. which can be used to escape sandbox
        if node.attr.startswith('__') and node.attr.endswith('__'):
            if node.attr not in ('__init__', '__str__', '__repr__', '__len__',
                                 '__iter__', '__next__', '__getitem__', '__setitem__',
                                 '__contains__', '__eq__', '__ne__', '__lt__', '__le__',
                                 '__gt__', '__ge__', '__add__', '__sub__', '__mul__',
                                 '__truediv__', '__floordiv__', '__mod__', '__pow__',
                                 '__and__', '__or__', '__xor__', '__neg__', '__pos__',
                                 '__abs__', '__invert__', '__enter__', '__exit__',
                                 '__name__', '__doc__'):
                self.errors.append(f"Access to '{node.attr}' is restricted")

        self.generic_visit(node)


def validate_code(code: str) -> Tuple[bool, List[str]]:
    """
    Validate code for security issues before execution.

    Returns:
        Tuple of (is_valid, list_of_errors)
    """
    try:
        tree = ast.parse(code)
    except SyntaxError as e:
        return False, [f"Syntax error: {e}"]

    validator = CodeValidator()
    validator.visit(tree)

    return len(validator.errors) == 0, validator.errors


def execute_python(
    code: str,
    allowed_file_paths: Optional[List[str]] = None,
    timeout: int = EXECUTION_TIMEOUT,
    context_vars: Optional[Dict[str, Any]] = None,
    output_dir: Optional[str] = None
) -> Dict[str, Any]:
    """
    Execute Python code in a sandboxed environment.

    Args:
        code: Python code to execute
        allowed_file_paths: List of file paths the code can read
        timeout: Maximum execution time in seconds
        context_vars: Variables to inject into the execution namespace
        output_dir: Directory where the code can write output files (plots, CSVs, etc.)

    Returns:
        Dict with:
            - success: bool
            - output: captured stdout
            - error: error message if failed
            - result: return value of last expression (if any)
            - output_paths: list of files created (if any)
    """
    # Validate code first
    is_valid, errors = validate_code(code)
    if not is_valid:
        return {
            'success': False,
            'output': '',
            'error': 'Code validation failed:\n' + '\n'.join(f'  - {e}' for e in errors),
            'result': None
        }

    # Set allowed file paths
    SafeBuiltins.set_allowed_paths(allowed_file_paths or [])

    # Set output directory for writing
    if output_dir:
        _os.makedirs(output_dir, exist_ok=True)
        SafeBuiltins.set_output_dir(output_dir)
    else:
        SafeBuiltins.set_output_dir('')

    # Create restricted execution environment
    safe_builtins = SafeBuiltins.get_safe_builtins()

    # Create namespace
    namespace = {
        '__builtins__': safe_builtins,
        '__name__': '__main__',
        '__doc__': None,
    }

    # Inject OUTPUT_DIR if provided
    if output_dir:
        namespace['OUTPUT_DIR'] = output_dir

    # Add context variables
    if context_vars:
        namespace.update(context_vars)

    # Capture output
    stdout_capture = io.StringIO()
    stderr_capture = io.StringIO()

    result = None
    error = None

    # Execute with timeout using threading
    execution_complete = threading.Event()
    execution_error = [None]
    execution_result = [None]

    def run_code():
        nonlocal result
        try:
            with redirect_stdout(stdout_capture), redirect_stderr(stderr_capture):
                # Try to get a return value from the last expression
                try:
                    tree = ast.parse(code)
                    if tree.body and isinstance(tree.body[-1], ast.Expr):
                        # Last statement is an expression - capture its value
                        last_expr = tree.body.pop()

                        # Execute all but last statement
                        if tree.body:
                            exec(compile(tree, '<sandbox>', 'exec'), namespace)

                        # Evaluate last expression
                        expr_code = compile(ast.Expression(last_expr.value), '<sandbox>', 'eval')
                        execution_result[0] = eval(expr_code, namespace)
                    else:
                        exec(compile(tree, '<sandbox>', 'exec'), namespace)
                except Exception as e:
                    execution_error[0] = e
        except Exception as e:
            execution_error[0] = e
        finally:
            execution_complete.set()

    # Start execution thread
    exec_thread = threading.Thread(target=run_code, daemon=True)
    exec_thread.start()

    # Wait with timeout
    if not execution_complete.wait(timeout=timeout):
        return {
            'success': False,
            'output': stdout_capture.getvalue()[:MAX_OUTPUT_SIZE],
            'error': f'Execution timed out after {timeout} seconds. Code may contain an infinite loop.',
            'result': None
        }

    # Check for errors
    if execution_error[0]:
        error_msg = ''.join(traceback.format_exception(
            type(execution_error[0]),
            execution_error[0],
            execution_error[0].__traceback__
        ))
        return {
            'success': False,
            'output': stdout_capture.getvalue()[:MAX_OUTPUT_SIZE],
            'error': error_msg,
            'result': None
        }

    # Auto-save matplotlib figures if output_dir is set
    output_paths = []
    if output_dir and 'matplotlib.pyplot' in sys.modules:
        try:
            plt = sys.modules['matplotlib.pyplot']
            fig_nums = plt.get_fignums()
            for i, num in enumerate(fig_nums):
                fig = plt.figure(num)
                # Skip completely empty figures (no axes or empty axes)
                if not fig.get_axes():
                    continue
                plot_path = _os.path.join(output_dir, f'plot_{i}.png')
                fig.savefig(plot_path, dpi=150, bbox_inches='tight')
                output_paths.append(plot_path)
            plt.close('all')
        except Exception:
            pass  # Don't fail execution because of plot saving issues

    # Get output
    output = stdout_capture.getvalue()
    if len(output) > MAX_OUTPUT_SIZE:
        output = output[:MAX_OUTPUT_SIZE] + f'\n\n[Output truncated at {MAX_OUTPUT_SIZE} characters]'

    # Format result
    result = execution_result[0]
    if result is not None:
        try:
            # Try to get a string representation
            result_str = repr(result)
            if len(result_str) > 10000:
                result_str = result_str[:10000] + '... [truncated]'
            result = result_str
        except:
            result = str(type(result))

    response = {
        'success': True,
        'output': output,
        'error': None,
        'result': result
    }

    if output_paths:
        response['output_paths'] = output_paths

    return response


# Tool function for the agent
def python_execute(
    code: str,
    file_paths: Optional[List[str]] = None,
    output_dir: Optional[str] = None,
    **kwargs
) -> Dict[str, Any]:
    """
    Execute Python code in a secure sandbox.

    This tool allows the agent to write and run Python code for:
    - Data processing and analysis
    - Mathematical calculations
    - Text manipulation
    - JSON/data parsing
    - Algorithm implementation

    Args:
        code: Python code to execute
        file_paths: Optional list of file paths the code can read
        output_dir: Optional directory for writing output files

    Returns:
        Dict with execution results
    """
    result = execute_python(
        code=code,
        allowed_file_paths=file_paths,
        timeout=EXECUTION_TIMEOUT,
        output_dir=output_dir
    )

    if not result['success']:
        raise ToolError(
            f"Code execution failed:\n{result['error']}\n\nOutput:\n{result['output']}"
        )

    # Format response
    response = {
        'success': True,
    }

    if result['output']:
        response['output'] = result['output']

    if result['result']:
        response['result'] = result['result']

    if result.get('output_paths'):
        response['output_paths'] = result['output_paths']

    if not result['output'] and not result['result'] and not result.get('output_paths'):
        response['message'] = 'Code executed successfully with no output'

    return response
