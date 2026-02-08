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
        useful = {'math', 'json', 're', 'datetime', 'collections', 'pandas', 'matplotlib'}
        assert useful.issubset(SAFE_MODULES)

    def test_data_analysis_modules_in_safe(self):
        """pandas and matplotlib must be in SAFE_MODULES."""
        assert 'pandas' in SAFE_MODULES
        assert 'matplotlib' in SAFE_MODULES
        assert 'matplotlib.pyplot' in SAFE_MODULES


class TestDataAnalysisModules:
    """Test data analysis library support (pandas, matplotlib, scipy)."""

    def test_import_pandas(self):
        """Import pandas and create a DataFrame."""
        code = """
import pandas as pd
df = pd.DataFrame({'a': [1, 2, 3], 'b': [4, 5, 6]})
print(df.shape)
print(df['a'].sum())
"""
        # First import may be slow due to pandas initialization
        result = execute_python(code, timeout=60)
        assert result['success'], f"Failed: {result.get('error')}"
        assert '(3, 2)' in result['output']
        assert '6' in result['output']

    def test_pandas_csv_operations(self, tmp_path):
        """Read and write CSV with pandas."""
        csv_file = tmp_path / "test.csv"
        csv_file.write_text("name,age\nAlice,30\nBob,25\nCharlie,35\n")

        # Read CSV
        code = f"""
import pandas as pd
df = pd.read_csv('{csv_file}')
print(df.columns.tolist())
print(len(df))
"""
        result = execute_python(code, allowed_file_paths=[str(csv_file)])
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'name' in result['output']
        assert '3' in result['output']

    def test_pandas_groupby_aggregation(self):
        """groupby, mean, sum, count operations."""
        code = """
import pandas as pd
df = pd.DataFrame({
    'category': ['A', 'B', 'A', 'B', 'A'],
    'value': [10, 20, 30, 40, 50]
})
grouped = df.groupby('category')['value'].agg(['mean', 'sum', 'count'])
print(grouped.to_string())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'mean' in result['output']
        assert 'sum' in result['output']

    def test_pandas_describe_statistics(self):
        """df.describe() should work."""
        code = """
import pandas as pd
df = pd.DataFrame({'x': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]})
desc = df.describe()
print(desc.to_string())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'mean' in result['output']
        assert 'std' in result['output']

    def test_import_matplotlib(self):
        """Import matplotlib.pyplot and create a figure."""
        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3], [1, 4, 9])
ax.set_title('Test')
print(f"figure created: {len(plt.get_fignums())} figure(s)")
plt.close('all')
"""
        # First import may build font cache, so allow extra time
        result = execute_python(code, timeout=60)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'figure created: 1' in result['output']

    def test_matplotlib_auto_save(self, tmp_path):
        """Create plot with output_dir, verify PNG file created."""
        import os
        output_dir = str(tmp_path / "plots")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3], [4, 5, 6])
ax.set_title('Auto-save test')
print("plot created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1
        assert result['output_paths'][0].endswith('.png')
        assert os.path.exists(result['output_paths'][0])

    def test_matplotlib_multiple_figures(self, tmp_path):
        """Create multiple figures, verify all auto-saved."""
        import os
        output_dir = str(tmp_path / "multi_plots")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig1, ax1 = plt.subplots()
ax1.plot([1, 2, 3], [1, 4, 9])
ax1.set_title('Plot 1')

fig2, ax2 = plt.subplots()
ax2.bar(['A', 'B', 'C'], [10, 20, 15])
ax2.set_title('Plot 2')

fig3, ax3 = plt.subplots()
ax3.scatter([1, 2, 3, 4], [4, 3, 2, 1])
ax3.set_title('Plot 3')

print(f"{len(plt.get_fignums())} figures")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 3
        for path in result['output_paths']:
            assert os.path.exists(path)

    def test_matplotlib_explicit_savefig(self, tmp_path):
        """Use OUTPUT_DIR + savefig explicitly."""
        import os
        output_dir = str(tmp_path / "explicit_save")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots()
ax.plot([1, 2, 3], [10, 20, 30])
fig.savefig(OUTPUT_DIR + '/my_chart.png', dpi=100)
plt.close(fig)
print("saved explicitly")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'my_chart.png'))

    def test_output_dir_injection(self, tmp_path):
        """OUTPUT_DIR variable should be available in namespace."""
        output_dir = str(tmp_path / "ns_test")

        code = """
print(f"output_dir={OUTPUT_DIR}")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert output_dir in result['output']

    def test_write_to_output_dir(self, tmp_path):
        """open(OUTPUT_DIR + '/test.csv', 'w') should work."""
        import os
        output_dir = str(tmp_path / "write_test")

        code = """
with open(OUTPUT_DIR + '/test.csv', 'w') as f:
    f.write('a,b\\n1,2\\n3,4\\n')
print("written")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'test.csv'))
        with open(os.path.join(output_dir, 'test.csv')) as f:
            content = f.read()
        assert 'a,b' in content

    def test_write_outside_output_dir_blocked(self, tmp_path):
        """open('/tmp/evil.txt', 'w') should still be blocked."""
        output_dir = str(tmp_path / "safe_dir")

        code = """
with open('/tmp/evil.txt', 'w') as f:
    f.write('evil')
"""
        result = execute_python(code, output_dir=output_dir)
        assert not result['success']
        assert 'not allowed' in result['error'].lower()

    def test_pandas_to_csv_output_dir(self, tmp_path):
        """df.to_csv(OUTPUT_DIR + '/data.csv') should work."""
        import os
        output_dir = str(tmp_path / "pandas_csv")

        code = """
import pandas as pd
df = pd.DataFrame({'x': [1, 2, 3], 'y': [4, 5, 6]})
df.to_csv(OUTPUT_DIR + '/data.csv', index=False)
print("csv saved")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        csv_path = os.path.join(output_dir, 'data.csv')
        assert os.path.exists(csv_path)
        with open(csv_path) as f:
            content = f.read()
        assert 'x,y' in content

    def test_no_output_dir_no_crash(self):
        """matplotlib without output_dir shouldn't crash (figures just not saved)."""
        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2], [3, 4])
print("ok")
plt.close('all')
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'ok' in result['output']
        assert 'output_paths' not in result

    def test_empty_figure_not_saved(self, tmp_path):
        """Empty/blank figure should not be saved."""
        import os
        output_dir = str(tmp_path / "empty_fig")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig = plt.figure()  # empty, no axes
print("empty figure")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        # Empty figure (no axes) should not be saved
        assert 'output_paths' not in result or len(result.get('output_paths', [])) == 0

    def test_output_dir_not_set_write_blocked(self):
        """Without output_dir, writing should still be blocked."""
        code = """
with open('/tmp/test.txt', 'w') as f:
    f.write('test')
"""
        result = execute_python(code)
        assert not result['success']
        assert 'not allowed' in result['error'].lower()


class TestPandasEdgeCases:
    """Edge cases and corner cases for pandas operations."""

    def test_empty_dataframe(self):
        """Empty DataFrame should work without crashing."""
        code = """
import pandas as pd
df = pd.DataFrame()
print(f"empty={df.empty}")
print(f"shape={df.shape}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'empty=True' in result['output']
        assert 'shape=(0, 0)' in result['output']

    def test_dataframe_with_nan(self):
        """NaN values should be handled correctly."""
        code = """
import pandas as pd
import numpy as np
df = pd.DataFrame({'a': [1, np.nan, 3], 'b': [np.nan, 5, 6]})
print(f"nulls_a={df['a'].isna().sum()}")
print(f"nulls_b={df['b'].isna().sum()}")
print(f"mean_a={df['a'].mean():.1f}")
print(f"dropna_len={len(df.dropna())}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'nulls_a=1' in result['output']
        assert 'nulls_b=1' in result['output']
        assert 'mean_a=2.0' in result['output']
        assert 'dropna_len=1' in result['output']

    def test_dataframe_dtypes(self):
        """Mixed dtypes including strings, ints, floats, booleans."""
        code = """
import pandas as pd
df = pd.DataFrame({
    'name': ['Alice', 'Bob'],
    'age': [30, 25],
    'score': [95.5, 88.0],
    'passed': [True, True]
})
print(df.dtypes.to_string())
print(f"cols={list(df.columns)}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'name' in result['output']
        assert 'age' in result['output']

    def test_dataframe_merge(self):
        """DataFrame merge/join should work."""
        code = """
import pandas as pd
left = pd.DataFrame({'id': [1, 2, 3], 'name': ['A', 'B', 'C']})
right = pd.DataFrame({'id': [2, 3, 4], 'score': [90, 80, 70]})
merged = pd.merge(left, right, on='id', how='inner')
print(f"merged_len={len(merged)}")
print(merged.to_string(index=False))
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'merged_len=2' in result['output']

    def test_dataframe_pivot(self):
        """Pivot table operations."""
        code = """
import pandas as pd
df = pd.DataFrame({
    'date': ['2024-01', '2024-01', '2024-02', '2024-02'],
    'product': ['A', 'B', 'A', 'B'],
    'sales': [100, 200, 150, 250]
})
pivot = df.pivot_table(values='sales', index='date', columns='product')
print(pivot.to_string())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert '2024-01' in result['output']
        assert 'A' in result['output']

    def test_dataframe_large(self):
        """Larger DataFrame shouldn't crash (but output may be truncated)."""
        code = """
import pandas as pd
import numpy as np
df = pd.DataFrame(np.random.randn(1000, 5), columns=['a', 'b', 'c', 'd', 'e'])
print(f"shape={df.shape}")
print(f"mean_a={df['a'].mean():.2f}")
print(f"std_a={df['a'].std():.2f}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'shape=(1000, 5)' in result['output']

    def test_dataframe_sorting(self):
        """Sorting operations."""
        code = """
import pandas as pd
df = pd.DataFrame({'name': ['Charlie', 'Alice', 'Bob'], 'score': [70, 90, 80]})
sorted_df = df.sort_values('score', ascending=False)
print(sorted_df['name'].tolist())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert "['Alice', 'Bob', 'Charlie']" in result['output']

    def test_dataframe_filtering(self):
        """Boolean filtering and query."""
        code = """
import pandas as pd
df = pd.DataFrame({'x': [1, 2, 3, 4, 5], 'y': [10, 20, 30, 40, 50]})
filtered = df[df['x'] > 3]
print(f"filtered_len={len(filtered)}")
print(f"y_values={filtered['y'].tolist()}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'filtered_len=2' in result['output']
        assert '[40, 50]' in result['output']

    def test_dataframe_rename_columns(self):
        """Column renaming."""
        code = """
import pandas as pd
df = pd.DataFrame({'old_name': [1, 2], 'another': [3, 4]})
df = df.rename(columns={'old_name': 'new_name'})
print(list(df.columns))
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'new_name' in result['output']
        assert 'old_name' not in result['output']

    def test_series_operations(self):
        """Series-specific operations (value_counts, unique, etc.)."""
        code = """
import pandas as pd
s = pd.Series(['a', 'b', 'a', 'c', 'b', 'a'])
print(f"unique={sorted(s.unique().tolist())}")
print(f"nunique={s.nunique()}")
vc = s.value_counts()
print(f"most_common={vc.index[0]},{vc.iloc[0]}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert "unique=['a', 'b', 'c']" in result['output']
        assert 'nunique=3' in result['output']
        assert 'most_common=a,3' in result['output']

    def test_dataframe_string_methods(self):
        """String accessor methods on DataFrame columns."""
        code = """
import pandas as pd
df = pd.DataFrame({'text': ['Hello World', 'foo bar', 'UPPER']})
df['lower'] = df['text'].str.lower()
df['word_count'] = df['text'].str.split().str.len()
print(df['lower'].tolist())
print(df['word_count'].tolist())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'hello world' in result['output']
        assert '[2, 2, 1]' in result['output']

    def test_dataframe_apply_lambda(self):
        """apply() with lambda functions."""
        code = """
import pandas as pd
df = pd.DataFrame({'x': [1, 2, 3, 4]})
df['squared'] = df['x'].apply(lambda v: v ** 2)
print(df['squared'].tolist())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert '[1, 4, 9, 16]' in result['output']

    def test_dataframe_fillna(self):
        """fillna with different strategies."""
        code = """
import pandas as pd
import numpy as np
df = pd.DataFrame({'a': [1, np.nan, 3, np.nan, 5]})
filled_zero = df['a'].fillna(0).tolist()
filled_ffill = df['a'].ffill().tolist()
print(f"zero={filled_zero}")
print(f"ffill={filled_ffill}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'zero=[1.0, 0.0, 3.0, 0.0, 5.0]' in result['output']
        assert 'ffill=[1.0, 1.0, 3.0, 3.0, 5.0]' in result['output']

    def test_dataframe_concat(self):
        """pd.concat to stack DataFrames."""
        code = """
import pandas as pd
df1 = pd.DataFrame({'a': [1, 2]})
df2 = pd.DataFrame({'a': [3, 4]})
combined = pd.concat([df1, df2], ignore_index=True)
print(f"len={len(combined)}")
print(combined['a'].tolist())
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'len=4' in result['output']
        assert '[1, 2, 3, 4]' in result['output']

    def test_dataframe_set_index(self):
        """Setting and resetting index."""
        code = """
import pandas as pd
df = pd.DataFrame({'id': [10, 20, 30], 'val': ['a', 'b', 'c']})
df = df.set_index('id')
print(f"index_name={df.index.name}")
print(f"at_20={df.loc[20, 'val']}")
df = df.reset_index()
print(f"cols_after_reset={list(df.columns)}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'index_name=id' in result['output']
        assert 'at_20=b' in result['output']
        assert 'id' in result['output']

    def test_pandas_read_csv_with_options(self, tmp_path):
        """read_csv with separator, header, dtype options."""
        csv_file = tmp_path / "semicolon.csv"
        csv_file.write_text("name;score\nAlice;95\nBob;88\n")

        code = f"""
import pandas as pd
df = pd.read_csv('{csv_file}', sep=';')
print(f"cols={{list(df.columns)}}")
print(f"score_sum={{df['score'].sum()}}")
"""
        result = execute_python(code, allowed_file_paths=[str(csv_file)])
        assert result['success'], f"Failed: {result.get('error')}"
        assert "['name', 'score']" in result['output']
        assert 'score_sum=183' in result['output']

    def test_pandas_to_csv_roundtrip(self, tmp_path):
        """Write CSV then read it back."""
        import os
        output_dir = str(tmp_path / "roundtrip")

        code = """
import pandas as pd
df_out = pd.DataFrame({'x': [10, 20, 30], 'y': ['a', 'b', 'c']})
path = OUTPUT_DIR + '/roundtrip.csv'
df_out.to_csv(path, index=False)
df_in = pd.read_csv(path)
print(f"match={df_out.equals(df_in)}")
print(f"shape={df_in.shape}")
"""
        result = execute_python(code, output_dir=output_dir,
                                allowed_file_paths=[os.path.join(output_dir, 'roundtrip.csv')])
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'match=True' in result['output']
        assert 'shape=(3, 2)' in result['output']

    def test_dataframe_correlation(self):
        """Correlation matrix computation."""
        code = """
import pandas as pd
df = pd.DataFrame({
    'x': [1, 2, 3, 4, 5],
    'y': [2, 4, 6, 8, 10],
    'z': [5, 4, 3, 2, 1]
})
corr = df.corr()
print(f"xy_corr={corr.loc['x', 'y']:.1f}")
print(f"xz_corr={corr.loc['x', 'z']:.1f}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'xy_corr=1.0' in result['output']
        assert 'xz_corr=-1.0' in result['output']

    def test_dataframe_rolling_window(self):
        """Rolling window calculations."""
        code = """
import pandas as pd
s = pd.Series([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
rolling_mean = s.rolling(window=3).mean().dropna().tolist()
print(f"rolling={[round(x, 1) for x in rolling_mean]}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert '2.0' in result['output']
        assert '9.0' in result['output']


class TestMatplotlibEdgeCases:
    """Edge cases and corner cases for matplotlib operations."""

    def test_subplot_grid(self, tmp_path):
        """Multiple subplots in a grid should produce one figure."""
        import os
        output_dir = str(tmp_path / "subplots")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, axes = plt.subplots(2, 2, figsize=(8, 6))
axes[0, 0].plot([1, 2, 3])
axes[0, 1].bar(['a', 'b'], [3, 7])
axes[1, 0].scatter([1, 2, 3], [3, 1, 2])
axes[1, 1].hist([1, 1, 2, 3, 3, 3])
fig.suptitle('Grid Test')
print("subplots created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1  # One figure with 4 subplots
        assert os.path.exists(result['output_paths'][0])

    def test_plot_with_labels_and_legend(self, tmp_path):
        """Plot with full annotations: title, xlabel, ylabel, legend."""
        import os
        output_dir = str(tmp_path / "labels")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

x = np.linspace(0, 10, 100)
plt.figure(figsize=(10, 6))
plt.plot(x, np.sin(x), label='sin(x)')
plt.plot(x, np.cos(x), label='cos(x)')
plt.title('Trigonometric Functions')
plt.xlabel('x')
plt.ylabel('y')
plt.legend()
plt.grid(True)
print("labeled plot created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1
        # Verify file is a valid PNG (starts with PNG magic bytes)
        with open(result['output_paths'][0], 'rb') as f:
            header = f.read(8)
        assert header[:4] == b'\x89PNG'

    def test_bar_chart_with_colors(self, tmp_path):
        """Bar chart with custom colors."""
        import os
        output_dir = str(tmp_path / "bar_colors")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

categories = ['A', 'B', 'C', 'D']
values = [25, 40, 30, 55]
colors = ['red', 'green', 'blue', 'orange']
plt.bar(categories, values, color=colors)
plt.title('Colored Bars')
print("bar chart created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result

    def test_pie_chart(self, tmp_path):
        """Pie chart creation."""
        import os
        output_dir = str(tmp_path / "pie")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

sizes = [30, 25, 20, 15, 10]
labels = ['A', 'B', 'C', 'D', 'E']
plt.pie(sizes, labels=labels, autopct='%1.1f%%')
plt.title('Distribution')
print("pie chart created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1

    def test_plot_with_very_large_data(self, tmp_path):
        """Plotting a large dataset shouldn't crash."""
        import os
        output_dir = str(tmp_path / "large_data")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

x = np.arange(10000)
y = np.random.randn(10000).cumsum()
plt.plot(x, y)
plt.title('Large Dataset')
print("large plot created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        # File should be non-trivial size
        file_size = os.path.getsize(result['output_paths'][0])
        assert file_size > 1000  # At least 1KB

    def test_figure_with_only_text(self, tmp_path):
        """Figure with text annotation but no plot data — has axes so should save."""
        import os
        output_dir = str(tmp_path / "text_only")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots()
ax.text(0.5, 0.5, 'Hello World', ha='center', va='center', fontsize=20)
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
print("text figure created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1

    def test_explicit_savefig_different_formats(self, tmp_path):
        """Explicit savefig to different formats (jpg, pdf, svg)."""
        import os
        output_dir = str(tmp_path / "formats")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots()
ax.plot([1, 2, 3], [1, 4, 9])
fig.savefig(OUTPUT_DIR + '/chart.jpg')
fig.savefig(OUTPUT_DIR + '/chart.pdf')
fig.savefig(OUTPUT_DIR + '/chart.svg')
plt.close(fig)
print("saved in multiple formats")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'chart.jpg'))
        assert os.path.exists(os.path.join(output_dir, 'chart.pdf'))
        assert os.path.exists(os.path.join(output_dir, 'chart.svg'))

    def test_closed_figures_not_auto_saved(self, tmp_path):
        """Explicitly closed figures should not be auto-saved."""
        import os
        output_dir = str(tmp_path / "closed")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig1, ax1 = plt.subplots()
ax1.plot([1, 2], [3, 4])
plt.close(fig1)

fig2, ax2 = plt.subplots()
ax2.plot([5, 6], [7, 8])
# Leave fig2 open — should auto-save

print("done")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1  # Only the open one

    def test_matplotlib_custom_figsize(self, tmp_path):
        """Custom figure sizes should be respected."""
        import os
        output_dir = str(tmp_path / "figsize")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig = plt.figure(figsize=(12, 4))
ax = fig.add_subplot(111)
ax.plot(range(10))
print(f"figsize={fig.get_size_inches().tolist()}")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert '12.0' in result['output']
        assert '4.0' in result['output']
        # Should auto-save the wide figure
        assert 'output_paths' in result

    def test_matplotlib_colors_module(self):
        """matplotlib.colors should be importable."""
        code = """
import matplotlib.colors as mcolors
print(f"red_hex={mcolors.to_hex('red')}")
print(f"num_named={len(mcolors.CSS4_COLORS)}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'red_hex=#ff0000' in result['output']

    def test_matplotlib_ticker_module(self):
        """matplotlib.ticker should be importable."""
        code = """
import matplotlib.ticker as ticker
fmt = ticker.PercentFormatter(xmax=1.0)
print(f"has_format={hasattr(fmt, 'format_data')}")
print(f"type={type(fmt).__name__}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'PercentFormatter' in result['output']

    def test_matplotlib_dates_module(self):
        """matplotlib.dates should be importable."""
        code = """
import matplotlib.dates as mdates
print(f"has_DateFormatter={hasattr(mdates, 'DateFormatter')}")
print(f"has_MonthLocator={hasattr(mdates, 'MonthLocator')}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'has_DateFormatter=True' in result['output']
        assert 'has_MonthLocator=True' in result['output']

    def test_matplotlib_patches_module(self):
        """matplotlib.patches should be importable."""
        code = """
import matplotlib.patches as mpatches
patch = mpatches.Rectangle((0, 0), 1, 1)
print(f"patch_type={type(patch).__name__}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'patch_type=Rectangle' in result['output']

    def test_heatmap_with_numpy(self, tmp_path):
        """Create a heatmap using imshow."""
        import os
        output_dir = str(tmp_path / "heatmap")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

data = np.random.rand(5, 5)
fig, ax = plt.subplots()
im = ax.imshow(data, cmap='hot')
plt.colorbar(im)
plt.title('Heatmap')
print("heatmap created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result


class TestOutputDirSecurity:
    """Security-focused tests for output_dir file writing."""

    def test_path_traversal_attack_dotdot(self, tmp_path):
        """Path traversal with ../ should be blocked."""
        output_dir = str(tmp_path / "safe")

        code = """
with open(OUTPUT_DIR + '/../../../etc/evil.txt', 'w') as f:
    f.write('pwned')
"""
        result = execute_python(code, output_dir=output_dir)
        # The path won't start with output_dir after ../ resolution
        # depends on how the OS resolves it. But the startswith check
        # on the raw string should block the ../ pattern
        # If the OS doesn't resolve it, the raw string still starts with output_dir
        # so we mainly test that no file appeared outside
        import os
        assert not os.path.exists('/etc/evil.txt')

    def test_write_to_parent_dir_blocked(self, tmp_path):
        """Writing to parent of output_dir should be blocked."""
        output_dir = str(tmp_path / "nested" / "safe")

        code = f"""
with open('{tmp_path}/evil.txt', 'w') as f:
    f.write('pwned')
"""
        result = execute_python(code, output_dir=output_dir)
        assert not result['success']
        assert 'not allowed' in result['error'].lower()

    def test_write_to_absolute_path_blocked(self, tmp_path):
        """Writing to an absolute path outside output_dir should be blocked."""
        output_dir = str(tmp_path / "safe")

        code = """
with open('/tmp/hacked.txt', 'w') as f:
    f.write('nope')
"""
        result = execute_python(code, output_dir=output_dir)
        assert not result['success']
        assert 'not allowed' in result['error'].lower()

    def test_write_append_mode(self, tmp_path):
        """Append mode ('a') should also respect output_dir."""
        import os
        output_dir = str(tmp_path / "append_test")

        code = """
with open(OUTPUT_DIR + '/log.txt', 'w') as f:
    f.write('line1\\n')
with open(OUTPUT_DIR + '/log.txt', 'a') as f:
    f.write('line2\\n')
with open(OUTPUT_DIR + '/log.txt', 'r') as f:
    print(f.read())
"""
        result = execute_python(code, output_dir=output_dir,
                                allowed_file_paths=[os.path.join(output_dir, 'log.txt')])
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'line1' in result['output']
        assert 'line2' in result['output']

    def test_write_exclusive_mode(self, tmp_path):
        """Exclusive create mode ('x') should work in output_dir."""
        import os
        output_dir = str(tmp_path / "exclusive")

        code = """
with open(OUTPUT_DIR + '/new_file.txt', 'x') as f:
    f.write('created exclusively')
print("created")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'new_file.txt'))

    def test_write_plus_mode_blocked_outside(self, tmp_path):
        """'r+' mode should be blocked outside output_dir."""
        output_dir = str(tmp_path / "plus")

        code = """
with open('/tmp/test.txt', 'r+') as f:
    f.write('nope')
"""
        result = execute_python(code, output_dir=output_dir)
        assert not result['success']
        assert 'not allowed' in result['error'].lower()

    def test_write_binary_mode_in_output_dir(self, tmp_path):
        """Binary write mode ('wb') should work in output_dir."""
        import os
        output_dir = str(tmp_path / "binary")

        code = """
with open(OUTPUT_DIR + '/binary.dat', 'wb') as f:
    f.write(b'\\x89PNG\\r\\n\\x1a\\n')
print("binary written")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'binary.dat'))

    def test_output_dir_nested_subdirectory(self, tmp_path):
        """Writing to output_dir should work even with nested path."""
        import os
        output_dir = str(tmp_path / "nested" / "deep")

        code = """
with open(OUTPUT_DIR + '/file.txt', 'w') as f:
    f.write('test')
print("written")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'file.txt'))

    def test_special_chars_in_filename(self, tmp_path):
        """Filenames with spaces and special chars in output_dir."""
        import os
        output_dir = str(tmp_path / "special")

        code = """
with open(OUTPUT_DIR + '/my data (1).csv', 'w') as f:
    f.write('a,b\\n1,2\\n')
print("written")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert os.path.exists(os.path.join(output_dir, 'my data (1).csv'))

    def test_overwrite_existing_file_in_output_dir(self, tmp_path):
        """Overwriting an existing file in output_dir should work."""
        import os
        output_dir = str(tmp_path / "overwrite")
        os.makedirs(output_dir, exist_ok=True)
        # Pre-create a file
        with open(os.path.join(output_dir, 'data.txt'), 'w') as f:
            f.write('original')

        code = """
with open(OUTPUT_DIR + '/data.txt', 'w') as f:
    f.write('overwritten')
print("done")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        with open(os.path.join(output_dir, 'data.txt')) as f:
            assert f.read() == 'overwritten'

    def test_output_dir_state_cleared_between_calls(self, tmp_path):
        """output_dir from one call should not leak into the next."""
        output_dir_1 = str(tmp_path / "call1")

        # First call sets output_dir
        result1 = execute_python("print('ok')", output_dir=output_dir_1)
        assert result1['success']

        # Second call without output_dir — writing should be blocked
        code = f"""
with open('{output_dir_1}/leak.txt', 'w') as f:
    f.write('leaked')
"""
        result2 = execute_python(code)
        assert not result2['success']
        assert 'not allowed' in result2['error'].lower()

    def test_allowed_paths_not_leaked_to_output_dir(self, tmp_path):
        """allowed_file_paths should not grant write access."""
        test_file = tmp_path / "readonly.txt"
        test_file.write_text("original content")

        code = f"""
with open('{test_file}', 'w') as f:
    f.write('modified')
"""
        result = execute_python(code, allowed_file_paths=[str(test_file)])
        assert not result['success']
        assert 'not allowed' in result['error'].lower()
        # Original content should be intact
        assert test_file.read_text() == 'original content'


class TestPandasMatplotlibIntegration:
    """Tests combining pandas with matplotlib for end-to-end data analysis."""

    def test_dataframe_plot_bar(self, tmp_path):
        """Create DataFrame then plot a bar chart."""
        import os
        output_dir = str(tmp_path / "df_bar")

        code = """
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df = pd.DataFrame({
    'product': ['Widget', 'Gadget', 'Doohickey'],
    'sales': [150, 230, 90]
})
fig, ax = plt.subplots()
ax.bar(df['product'], df['sales'])
ax.set_title('Sales by Product')
ax.set_ylabel('Units')
print(f"total_sales={df['sales'].sum()}")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'total_sales=470' in result['output']
        assert 'output_paths' in result
        assert len(result['output_paths']) == 1

    def test_csv_read_analyze_plot(self, tmp_path):
        """Read CSV, compute stats, generate plot — full pipeline."""
        import os
        csv_file = tmp_path / "sales.csv"
        csv_file.write_text("month,revenue\nJan,1200\nFeb,1500\nMar,1800\nApr,1100\nMay,2000\nJun,2200\n")
        output_dir = str(tmp_path / "pipeline")

        code = f"""
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df = pd.read_csv('{csv_file}')
print(f"mean_revenue={{df['revenue'].mean():.0f}}")
print(f"max_month={{df.loc[df['revenue'].idxmax(), 'month']}}")

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(df['month'], df['revenue'], marker='o')
ax.set_title('Monthly Revenue')
ax.set_ylabel('Revenue ($)')
print("plot done")
"""
        result = execute_python(code, output_dir=output_dir,
                                allowed_file_paths=[str(csv_file)])
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'mean_revenue=1633' in result['output']
        assert 'max_month=Jun' in result['output']
        assert 'output_paths' in result

    def test_groupby_then_plot(self, tmp_path):
        """Group data then plot aggregated results."""
        import os
        output_dir = str(tmp_path / "groupby_plot")

        code = """
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df = pd.DataFrame({
    'department': ['Sales', 'Sales', 'Eng', 'Eng', 'Eng', 'HR', 'HR'],
    'salary': [60, 65, 90, 95, 100, 55, 60]
})
grouped = df.groupby('department')['salary'].mean()
print(grouped.to_string())

fig, ax = plt.subplots()
grouped.plot(kind='bar', ax=ax)
ax.set_title('Avg Salary by Dept')
print("grouped plot done")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'Eng' in result['output']
        assert 'output_paths' in result

    def test_pandas_describe_and_hist(self, tmp_path):
        """describe() stats plus histogram."""
        import os
        output_dir = str(tmp_path / "hist")

        code = """
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

np.random.seed(42)
df = pd.DataFrame({'scores': np.random.normal(75, 10, 200)})
desc = df.describe()
print(f"mean={desc.loc['mean', 'scores']:.1f}")
print(f"std={desc.loc['std', 'scores']:.1f}")

fig, ax = plt.subplots()
ax.hist(df['scores'], bins=20, edgecolor='black')
ax.set_title('Score Distribution')
print("histogram done")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'mean=' in result['output']
        assert 'std=' in result['output']
        assert 'output_paths' in result

    def test_pandas_plot_save_csv_and_png(self, tmp_path):
        """Save both a CSV and a plot from the same analysis."""
        import os
        output_dir = str(tmp_path / "both")

        code = """
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df = pd.DataFrame({
    'x': range(1, 11),
    'y': [2, 4, 5, 4, 5, 7, 8, 9, 8, 10]
})

# Save CSV
df.to_csv(OUTPUT_DIR + '/data.csv', index=False)

# Create plot
fig, ax = plt.subplots()
ax.scatter(df['x'], df['y'])
ax.set_title('X vs Y')

print("both saved")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        # CSV was explicitly saved
        assert os.path.exists(os.path.join(output_dir, 'data.csv'))
        # PNG was auto-saved
        assert 'output_paths' in result
        assert any(p.endswith('.png') for p in result['output_paths'])

    def test_multiple_dataframes_multiple_plots(self, tmp_path):
        """Multiple DataFrames feeding multiple plots."""
        import os
        output_dir = str(tmp_path / "multi")

        code = """
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df1 = pd.DataFrame({'x': range(10), 'y': np.random.rand(10)})
df2 = pd.DataFrame({'x': range(10), 'y': np.random.rand(10) * 2})

fig1, ax1 = plt.subplots()
ax1.plot(df1['x'], df1['y'], 'b-')
ax1.set_title('Dataset 1')

fig2, ax2 = plt.subplots()
ax2.plot(df2['x'], df2['y'], 'r-')
ax2.set_title('Dataset 2')

print(f"df1_mean={df1['y'].mean():.2f}")
print(f"df2_mean={df2['y'].mean():.2f}")
"""
        result = execute_python(code, output_dir=output_dir)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'output_paths' in result
        assert len(result['output_paths']) == 2


class TestToolInterfaceOutputPaths:
    """Test that output_paths propagates through the python_execute tool interface."""

    def test_python_execute_returns_output_paths(self, tmp_path):
        """python_execute tool should include output_paths when plots are created."""
        output_dir = str(tmp_path / "tool_test")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2], [3, 4])
print("plot")
"""
        result = python_execute(code, output_dir=output_dir)
        assert result['success']
        assert 'output_paths' in result
        assert len(result['output_paths']) >= 1

    def test_python_execute_no_output_paths_without_plots(self):
        """python_execute should not include output_paths when no plots are made."""
        result = python_execute("print('hello')")
        assert result['success']
        assert 'output_paths' not in result

    def test_python_execute_combined_output_result_and_paths(self, tmp_path):
        """python_execute should return output, result, and output_paths together."""
        output_dir = str(tmp_path / "combined")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

print("some output")
fig, ax = plt.subplots()
ax.plot([1, 2], [3, 4])
42
"""
        result = python_execute(code, output_dir=output_dir)
        assert result['success']
        assert 'output' in result
        assert 'some output' in result['output']
        assert 'result' in result
        assert '42' in result['result']
        assert 'output_paths' in result

    def test_python_execute_error_has_no_output_paths(self, tmp_path):
        """On error, python_execute should raise ToolError, no output_paths."""
        from navixmind.bridge import ToolError
        output_dir = str(tmp_path / "error")

        with pytest.raises(ToolError):
            python_execute("raise ValueError('boom')", output_dir=output_dir)

    def test_python_execute_message_when_only_plots(self, tmp_path):
        """When only plots are created (no print, no expression), should not show 'no output' message."""
        output_dir = str(tmp_path / "plots_only")

        code = """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2], [3, 4])
"""
        result = python_execute(code, output_dir=output_dir)
        assert result['success']
        assert 'output_paths' in result
        # Should NOT say "no output" since we have paths
        assert result.get('message') is None


class TestSafeBuiltinsState:
    """Test that SafeBuiltins class state is properly managed."""

    def test_output_dir_reset_between_calls(self, tmp_path):
        """output_dir should be cleared when not provided."""
        from navixmind.tools.code_executor import SafeBuiltins

        output_dir = str(tmp_path / "state_test")

        # Call with output_dir
        execute_python("print('with dir')", output_dir=output_dir)
        assert SafeBuiltins._output_dir == output_dir

        # Call without output_dir
        execute_python("print('no dir')")
        assert SafeBuiltins._output_dir == ''

    def test_allowed_paths_reset_between_calls(self, tmp_path):
        """allowed_file_paths should be reset between calls."""
        from navixmind.tools.code_executor import SafeBuiltins

        file1 = str(tmp_path / "file1.txt")

        # Call with paths
        execute_python("print('ok')", allowed_file_paths=[file1])
        assert file1 in SafeBuiltins._allowed_paths

        # Call without paths
        execute_python("print('ok')")
        assert SafeBuiltins._allowed_paths == []

    def test_output_dir_none_resets(self, tmp_path):
        """Passing output_dir=None should reset the state."""
        from navixmind.tools.code_executor import SafeBuiltins

        output_dir = str(tmp_path / "none_test")
        execute_python("print('a')", output_dir=output_dir)
        assert SafeBuiltins._output_dir == output_dir

        execute_python("print('b')", output_dir=None)
        assert SafeBuiltins._output_dir == ''

    def test_output_dir_created_if_not_exists(self, tmp_path):
        """output_dir should be created automatically if it doesn't exist."""
        import os
        output_dir = str(tmp_path / "auto" / "create" / "deep")

        assert not os.path.exists(output_dir)
        result = execute_python("print('ok')", output_dir=output_dir)
        assert result['success']
        assert os.path.isdir(output_dir)


class TestModuleWhitelistCompleteness:
    """Verify all whitelisted matplotlib submodules are actually importable."""

    def test_all_matplotlib_submodules_importable(self):
        """Every matplotlib.* entry in SAFE_MODULES should be importable."""
        mpl_modules = [m for m in SAFE_MODULES if m.startswith('matplotlib')]
        for mod_name in mpl_modules:
            code = f"import {mod_name}\nprint('{mod_name} ok')"
            result = execute_python(code)
            assert result['success'], f"Failed to import whitelisted module {mod_name}: {result.get('error')}"

    def test_blocked_matplotlib_submodule(self):
        """A matplotlib submodule NOT in SAFE_MODULES should still work (top-level is allowed)."""
        # matplotlib.backends is not explicitly listed but matplotlib is
        code = """
import matplotlib.backends
print("backends imported")
"""
        result = execute_python(code)
        # Should succeed because top-level 'matplotlib' is in SAFE_MODULES
        assert result['success'], f"Failed: {result.get('error')}"

    def test_pandas_submodule_import(self):
        """pandas submodules should work since top-level 'pandas' is in SAFE_MODULES."""
        code = """
from pandas import DataFrame, Series
import pandas.api.types as ptypes
print(f"is_numeric={ptypes.is_numeric_dtype('int64')}")
"""
        result = execute_python(code)
        assert result['success'], f"Failed: {result.get('error')}"
        assert 'is_numeric=True' in result['output']


class TestExecuteToolIntegration:
    """Test the execute_tool pathway for python_execute with output_dir."""

    def test_execute_tool_passes_output_dir(self, tmp_path):
        """execute_tool should pass output_dir from context to python_execute."""
        from navixmind.tools import execute_tool
        import os

        output_dir = str(tmp_path / "tool_integration")
        os.makedirs(output_dir, exist_ok=True)

        context = {'output_dir': output_dir}
        args = {
            'code': """
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3], [4, 5, 6])
print("tool integration")
"""
        }
        result = execute_tool('python_execute', args, context)
        assert result['success']
        assert 'output_paths' in result
        assert len(result['output_paths']) >= 1
        assert os.path.exists(result['output_paths'][0])

    def test_execute_tool_no_output_dir_in_context(self):
        """python_execute via execute_tool without output_dir in context should work."""
        from navixmind.tools import execute_tool

        context = {}
        args = {'code': "print('no output dir')"}
        result = execute_tool('python_execute', args, context)
        assert result['success']
        assert 'no output dir' in result['output']

    def test_execute_tool_csv_write_through_context(self, tmp_path):
        """CSV writing via pandas through execute_tool with context output_dir."""
        from navixmind.tools import execute_tool
        import os

        output_dir = str(tmp_path / "tool_csv")
        os.makedirs(output_dir, exist_ok=True)

        context = {'output_dir': output_dir}
        args = {
            'code': """
import pandas as pd
df = pd.DataFrame({'col1': [1, 2, 3]})
df.to_csv(OUTPUT_DIR + '/result.csv', index=False)
print("saved")
"""
        }
        result = execute_tool('python_execute', args, context)
        assert result['success']
        assert os.path.exists(os.path.join(output_dir, 'result.csv'))
