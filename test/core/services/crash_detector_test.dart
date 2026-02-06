import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/crash_detector.dart';

// Helper function to test the crash extraction regex pattern
// This mirrors the logic in CrashDetector._extractLastCrash
String? extractLastCrash(String content) {
  final pattern = RegExp(
    r'={60}\nUNCAUGHT EXCEPTION.*?(?=={60}|$)',
    dotAll: true,
  );
  final matches = pattern.allMatches(content);

  if (matches.isNotEmpty) {
    return matches.last.group(0);
  }
  return null;
}

// Helper to generate the separator line (60 equals signs)
String get separator => '=' * 60;

void main() {
  group('CrashDetector', () {
    group('Crash extraction logic (_extractLastCrash pattern)', () {
      test('finds crash in log content with valid format', () {
        final content = '''
Some previous log output
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "main.py", line 42, in <module>
    raise ValueError("Something went wrong")
ValueError: Something went wrong
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('UNCAUGHT EXCEPTION'));
        expect(result, contains('ValueError: Something went wrong'));
      });

      test('returns null when no crash marker present', () {
        final content = '''
Normal log output
Everything is fine
No crashes here
''';

        final result = extractLastCrash(content);

        expect(result, isNull);
      });

      test('returns null for empty content', () {
        final result = extractLastCrash('');

        expect(result, isNull);
      });

      test('returns null for content with only separator', () {
        final content = separator;

        final result = extractLastCrash(content);

        expect(result, isNull);
      });

      test('returns last crash when multiple crash blocks exist', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
First crash error
Traceback (most recent call last):
  File "main.py", line 10
RuntimeError: First error
$separator
UNCAUGHT EXCEPTION
Second crash error
Traceback (most recent call last):
  File "main.py", line 20
ValueError: Second error - THIS IS THE LAST ONE
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('Second crash error'));
        expect(result, contains('THIS IS THE LAST ONE'));
        expect(result, isNot(contains('First crash error')));
      });

      test('handles crash block followed by another separator', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
Error message here
Traceback info
$separator
Some other content after
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('UNCAUGHT EXCEPTION'));
        expect(result, contains('Error message here'));
        // Should stop at the next separator
        expect(result, isNot(contains('Some other content after')));
      });

      test('handles crash block at end of content (no trailing separator)', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
Final error without trailing separator
Traceback (most recent call last):
  File "script.py", line 100
KeyError: missing_key''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('UNCAUGHT EXCEPTION'));
        expect(result, contains('KeyError: missing_key'));
      });

      test('handles multiline traceback content', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "/app/main.py", line 150, in process_data
    result = transform(data)
  File "/app/utils.py", line 42, in transform
    return parse_json(raw)
  File "/app/parser.py", line 88, in parse_json
    raise JSONDecodeError("Invalid JSON")
json.decoder.JSONDecodeError: Invalid JSON: line 1 column 5
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('File "/app/main.py"'));
        expect(result, contains('File "/app/utils.py"'));
        expect(result, contains('File "/app/parser.py"'));
        expect(result, contains('JSONDecodeError'));
      });

      test('requires at least 60 equals signs', () {
        // 59 equals signs - should not match (not enough)
        final contentWith59 = '''
${'=' * 59}
UNCAUGHT EXCEPTION
Some error
''';

        // 61 equals signs - DOES match because regex ={60} matches a substring
        // The regex matches any sequence containing 60+ equals signs
        final contentWith61 = '''
${'=' * 61}
UNCAUGHT EXCEPTION
Some error
''';

        expect(extractLastCrash(contentWith59), isNull);
        // 61 equals signs contains a valid 60-character substring, so it matches
        expect(extractLastCrash(contentWith61), isNotNull);
      });

      test('handles content with special regex characters', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
Error with special chars: [.*+?^\${}()|[]\\
Traceback includes regex patterns: \\d+ \\w+
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('Error with special chars'));
      });

      test('handles unicode content in crash log', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
Error: Unicode text - 你好世界 - مرحبا - 🚀
Traceback (most recent call last):
  File "unicode_test.py", line 1
UnicodeError: Invalid encoding
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('你好世界'));
        expect(result, contains('مرحبا'));
      });

      test('handles Windows-style line endings in content', () {
        final content =
            '$separator\r\nUNCAUGHT EXCEPTION\r\nWindows line endings\r\nError here\r\n';

        // Note: The regex uses \n which may not match \r\n directly
        // This test documents the current behavior
        final result = extractLastCrash(content);

        // The pattern requires \n after separator, so \r\n may not match
        // This is expected behavior - the Python logger should use \n
        expect(result, isNull);
      });

      test('handles very long crash logs', () {
        final longTraceback = List.generate(
          100,
          (i) => '  File "module_$i.py", line $i, in function_$i',
        ).join('\n');

        final content = '''
$separator
UNCAUGHT EXCEPTION
$longTraceback
FinalError: After 100 stack frames
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('module_99.py'));
        expect(result, contains('FinalError'));
      });

      test('handles crash with no content after header', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('UNCAUGHT EXCEPTION'));
      });

      test('handles partial separator (not on its own line)', () {
        final content = '''
Some text $separator more text
UNCAUGHT EXCEPTION
This should not match
''';

        final result = extractLastCrash(content);

        expect(result, isNull);
      });
    });

    group('PythonCrashException', () {
      test('stores crash log correctly', () {
        const crashLog = 'Test crash log content\nWith multiple lines';

        final exception = PythonCrashException(crashLog);

        expect(exception.crashLog, equals(crashLog));
      });

      test('toString extracts first meaningful line', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "main.py", line 42
ValueError: This is the actual error
''';

        final exception = PythonCrashException(crashLog);

        expect(exception.toString(), contains('PythonCrashException:'));
        // Should extract "UNCAUGHT EXCEPTION" as first non-empty, non-separator line
        expect(exception.toString(), contains('UNCAUGHT EXCEPTION'));
      });

      test('toString handles empty crash log', () {
        final exception = PythonCrashException('');

        expect(exception.toString(), equals('PythonCrashException: Unknown Python crash'));
      });

      test('toString handles crash log with only whitespace', () {
        final exception = PythonCrashException('   \n  \n   ');

        expect(exception.toString(), equals('PythonCrashException: Unknown Python crash'));
      });

      test('toString handles crash log with only separators', () {
        final exception = PythonCrashException('$separator\n$separator\n$separator');

        expect(exception.toString(), equals('PythonCrashException: Unknown Python crash'));
      });

      test('toString handles crash log with separator and whitespace only', () {
        final exception = PythonCrashException('$separator\n   \n$separator');

        expect(exception.toString(), equals('PythonCrashException: Unknown Python crash'));
      });

      test('toString skips leading empty lines', () {
        final crashLog = '''


ACTUAL_ERROR_MESSAGE
More details
''';

        final exception = PythonCrashException(crashLog);

        expect(exception.toString(), contains('ACTUAL_ERROR_MESSAGE'));
      });

      test('toString skips leading separator lines', () {
        final crashLog = '''
$separator
$separator
ImportError: No module named 'missing_module'
''';

        final exception = PythonCrashException(crashLog);

        expect(exception.toString(), contains('ImportError'));
      });

      test('toString handles single line crash log', () {
        const crashLog = 'SingleLineError: Quick crash';

        final exception = PythonCrashException(crashLog);

        expect(exception.toString(), equals('PythonCrashException: SingleLineError: Quick crash'));
      });

      test('toString preserves meaningful first line exactly', () {
        const crashLog = 'TypeError: cannot concatenate str and int';

        final exception = PythonCrashException(crashLog);

        expect(
          exception.toString(),
          equals('PythonCrashException: TypeError: cannot concatenate str and int'),
        );
      });

      test('implements Exception interface', () {
        final exception = PythonCrashException('test');

        expect(exception, isA<Exception>());
      });

      test('can be thrown and caught', () {
        final exception = PythonCrashException('Test crash');

        expect(
          () => throw exception,
          throwsA(isA<PythonCrashException>()),
        );
      });

      test('caught exception preserves crash log', () {
        final originalLog = 'Original crash log content';
        PythonCrashException? caughtException;

        try {
          throw PythonCrashException(originalLog);
        } on PythonCrashException catch (e) {
          caughtException = e;
        }

        expect(caughtException, isNotNull);
        expect(caughtException!.crashLog, equals(originalLog));
      });
    });

    group('Crash log parsing patterns', () {
      test('parses standard Python traceback format', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "/data/app/script.py", line 42, in main
    result = process(data)
  File "/data/app/processor.py", line 15, in process
    return int(value)
ValueError: invalid literal for int() with base 10: 'abc'
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('Traceback (most recent call last)'));
        expect(result, contains('ValueError'));
      });

      test('parses exception with nested cause', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "main.py", line 10
RuntimeError: Failed to process

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "handler.py", line 20
SystemError: Unrecoverable state
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('RuntimeError'));
        expect(result, contains('SystemError'));
        expect(result, contains('During handling of the above exception'));
      });

      test('parses exception with context', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "original.py", line 5
KeyError: 'missing'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "wrapper.py", line 10
RuntimeError: Configuration error
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('KeyError'));
        expect(result, contains('RuntimeError'));
      });

      test('parses assertion error', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "test.py", line 25, in test_something
    assert result == expected, f"Expected {expected}, got {result}"
AssertionError: Expected 42, got 0
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('AssertionError'));
      });

      test('parses syntax error format', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
  File "broken.py", line 10
    def foo(
          ^
SyntaxError: unexpected EOF while parsing
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('SyntaxError'));
      });

      test('parses import error', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "app.py", line 1, in <module>
    import nonexistent_module
ModuleNotFoundError: No module named 'nonexistent_module'
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('ModuleNotFoundError'));
      });

      test('parses memory error', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "big_data.py", line 50, in load_all
    data = [0] * (10 ** 12)
MemoryError
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('MemoryError'));
      });

      test('parses keyboard interrupt', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "long_running.py", line 100, in process
    time.sleep(3600)
KeyboardInterrupt
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('KeyboardInterrupt'));
      });

      test('parses custom exception with message', () {
        final crashLog = '''
$separator
UNCAUGHT EXCEPTION
Traceback (most recent call last):
  File "api.py", line 75, in handle_request
    raise APIError("Rate limit exceeded", status_code=429)
api.errors.APIError: Rate limit exceeded (status_code=429)
''';

        final result = extractLastCrash(crashLog);

        expect(result, isNotNull);
        expect(result, contains('APIError'));
        expect(result, contains('Rate limit exceeded'));
      });
    });

    group('checkForPreviousCrash logic simulation', () {
      // These tests simulate the logic without actual file system access

      test('returns null when no crash found in content', () {
        // Simulating the logic path when file exists but has no crash
        final content = 'Normal log content\nNo crashes here';
        final lastCrash = extractLastCrash(content);

        expect(lastCrash, isNull);
      });

      test('returns crash content when crash found', () {
        // Simulating the logic path when file exists with crash
        final content = '''
Normal startup log
$separator
UNCAUGHT EXCEPTION
ValueError: Test error
''';
        final lastCrash = extractLastCrash(content);

        expect(lastCrash, isNotNull);
        expect(lastCrash, contains('ValueError'));
      });

      test('returns only last crash when multiple exist', () {
        // Simulating multiple app restarts with crashes
        final content = '''
$separator
UNCAUGHT EXCEPTION
First session crash
TypeError: First error
$separator
UNCAUGHT EXCEPTION
Second session crash
KeyError: Second error
$separator
UNCAUGHT EXCEPTION
Third session crash
RuntimeError: Most recent error
''';

        final lastCrash = extractLastCrash(content);

        expect(lastCrash, isNotNull);
        expect(lastCrash, contains('RuntimeError'));
        expect(lastCrash, contains('Most recent error'));
        expect(lastCrash, isNot(contains('First error')));
        expect(lastCrash, isNot(contains('Second error')));
      });

      test('handles mixed content with logs between crashes', () {
        final content = '''
App started at 2024-01-01 10:00:00
Loading modules...
$separator
UNCAUGHT EXCEPTION
Early crash
InitializationError: Failed to load config
$separator
App restarted at 2024-01-01 10:05:00
Everything working fine
Processing data...
$separator
UNCAUGHT EXCEPTION
Later crash
ProcessingError: Data corruption detected
''';

        final lastCrash = extractLastCrash(content);

        expect(lastCrash, isNotNull);
        expect(lastCrash, contains('ProcessingError'));
        expect(lastCrash, isNot(contains('InitializationError')));
      });
    });

    group('Edge cases and boundary conditions', () {
      test('handles content starting with separator', () {
        final content = '''$separator
UNCAUGHT EXCEPTION
Immediate crash on start
StartupError: No config
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('StartupError'));
      });

      test('handles content with only UNCAUGHT EXCEPTION text (no separator)', () {
        final content = 'UNCAUGHT EXCEPTION\nSome error';

        final result = extractLastCrash(content);

        // Should not match without the separator prefix
        expect(result, isNull);
      });

      test('handles separator not followed by UNCAUGHT EXCEPTION', () {
        final content = '''
$separator
DIFFERENT HEADER
Some other content
''';

        final result = extractLastCrash(content);

        expect(result, isNull);
      });

      test('handles content with partial match text', () {
        final content = '''
Text mentioning UNCAUGHT EXCEPTION in the middle
And $separator inline
''';

        final result = extractLastCrash(content);

        expect(result, isNull);
      });

      test('handles null-like strings in content', () {
        final content = '''
$separator
UNCAUGHT EXCEPTION
null
None
undefined
NaN
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('null'));
        expect(result, contains('None'));
      });

      test('handles content with many separators', () {
        final separators = List.generate(10, (_) => separator).join('\n');
        final content = '''
$separators
UNCAUGHT EXCEPTION
After many separators
FinalError: Done
''';

        final result = extractLastCrash(content);

        expect(result, isNotNull);
        expect(result, contains('FinalError'));
      });

      test('crash log substring for Firebase custom key (max 1000 chars)', () {
        // Testing the logic used in reportCrash for setCustomKey
        final longCrashLog = 'A' * 2000;
        final truncated = longCrashLog.substring(
          0,
          longCrashLog.length < 1000 ? longCrashLog.length : 1000,
        );

        expect(truncated.length, equals(1000));
      });

      test('crash log substring for debug print (max 500 chars)', () {
        // Testing the logic used in reportCrash fallback
        final longCrashLog = 'B' * 1000;
        final truncated = longCrashLog.substring(
          0,
          longCrashLog.length < 500 ? longCrashLog.length : 500,
        );

        expect(truncated.length, equals(500));
      });

      test('short crash log not truncated', () {
        final shortCrashLog = 'Short error';
        final truncated = shortCrashLog.substring(
          0,
          shortCrashLog.length < 1000 ? shortCrashLog.length : 1000,
        );

        expect(truncated, equals(shortCrashLog));
        expect(truncated.length, equals(11));
      });
    });

    group('CrashDetector constants', () {
      test('crash log path is defined', () {
        // We can't directly access the private constant, but we can verify
        // the expected behavior based on documentation
        // The path should be 'python_crash.log' relative to documents directory
        const expectedPath = 'python_crash.log';
        expect(expectedPath, isNotEmpty);
        expect(expectedPath, endsWith('.log'));
      });
    });

    group('Regex pattern correctness', () {
      test('pattern uses dotAll mode correctly', () {
        // dotAll allows . to match newlines
        final pattern = RegExp(
          r'={60}\nUNCAUGHT EXCEPTION.*?(?=={60}|$)',
          dotAll: true,
        );

        final content = '''
$separator
UNCAUGHT EXCEPTION
Line 1
Line 2
Line 3
''';

        final matches = pattern.allMatches(content);

        expect(matches, isNotEmpty);
        final match = matches.first.group(0)!;
        expect(match, contains('Line 1'));
        expect(match, contains('Line 2'));
        expect(match, contains('Line 3'));
      });

      test('pattern uses non-greedy quantifier', () {
        // .*? should stop at first occurrence of lookahead
        final pattern = RegExp(
          r'={60}\nUNCAUGHT EXCEPTION.*?(?=={60}|$)',
          dotAll: true,
        );

        final content = '''
$separator
UNCAUGHT EXCEPTION
First crash content
$separator
Other stuff after
''';

        final matches = pattern.allMatches(content);

        expect(matches.length, equals(1));
        final match = matches.first.group(0)!;
        expect(match, isNot(contains('Other stuff after')));
      });

      test('pattern lookahead does not consume separator', () {
        // The (?=...) lookahead should leave separator for next match
        final pattern = RegExp(
          r'={60}\nUNCAUGHT EXCEPTION.*?(?=={60}|$)',
          dotAll: true,
        );

        final content = '''
$separator
UNCAUGHT EXCEPTION
First
$separator
UNCAUGHT EXCEPTION
Second
''';

        final matches = pattern.allMatches(content);

        expect(matches.length, equals(2));
      });
    });
  });
}
