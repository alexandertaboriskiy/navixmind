import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Testable system prompt storage that accepts an injected directory.
///
/// This replicates the file-based system prompt logic from StorageService
/// but replaces `getApplicationDocumentsDirectory()` with a constructor-injected
/// directory so we can test against a real temp directory without platform channels.
class TestableSystemPromptStorage {
  final Directory dir;
  TestableSystemPromptStorage(this.dir);

  File get _file => File('${dir.path}/system_prompt.txt');

  Future<File> getSystemPromptFile() async => _file;

  Future<String?> getSystemPrompt() async {
    if (await _file.exists()) {
      final content = await _file.readAsString();
      return content.isNotEmpty ? content : null;
    }
    return null;
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _file.writeAsString(prompt);
  }

  Future<void> resetSystemPrompt() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

void main() {
  late Directory tempDir;
  late TestableSystemPromptStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('system_prompt_test_');
    storage = TestableSystemPromptStorage(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SystemPromptStorage getSystemPrompt', () {
    test('returns null when no file exists', () async {
      final result = await storage.getSystemPrompt();

      expect(result, isNull);
    });

    test('returns null for empty file', () async {
      // Create an empty file manually
      final file = File('${tempDir.path}/system_prompt.txt');
      await file.writeAsString('');

      final result = await storage.getSystemPrompt();

      expect(result, isNull);
    });

    test('returns content when file exists with text', () async {
      final file = File('${tempDir.path}/system_prompt.txt');
      await file.writeAsString('You are a helpful assistant.');

      final result = await storage.getSystemPrompt();

      expect(result, equals('You are a helpful assistant.'));
    });
  });

  group('SystemPromptStorage setSystemPrompt', () {
    test('creates file and stores prompt', () async {
      await storage.setSystemPrompt('Be concise.');

      final file = File('${tempDir.path}/system_prompt.txt');
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals('Be concise.'));
    });

    test('overwrites existing prompt', () async {
      await storage.setSystemPrompt('First prompt');

      final first = await storage.getSystemPrompt();
      expect(first, equals('First prompt'));

      await storage.setSystemPrompt('Second prompt');

      final second = await storage.getSystemPrompt();
      expect(second, equals('Second prompt'));

      // Verify the old content is fully gone
      final file = File('${tempDir.path}/system_prompt.txt');
      final raw = await file.readAsString();
      expect(raw, equals('Second prompt'));
      expect(raw.contains('First'), isFalse);
    });

    test('preserves multiline text', () async {
      const multiline = 'Line one\nLine two\nLine three\n\nLine five after blank';

      await storage.setSystemPrompt(multiline);
      final result = await storage.getSystemPrompt();

      expect(result, equals(multiline));
    });

    test('preserves unicode characters', () async {
      const unicode =
          'Emoji: \u{1F600}\u{1F3A8}\u{1F680} '
          'CJK: \u4F60\u597D '
          'Arabic: \u0645\u0631\u062D\u0628\u0627 '
          'Math: \u2200x\u2208\u211D';

      await storage.setSystemPrompt(unicode);
      final result = await storage.getSystemPrompt();

      expect(result, equals(unicode));
    });

    test('handles very large prompts (10K chars)', () async {
      final largePrompt = 'A' * 10000;

      await storage.setSystemPrompt(largePrompt);
      final result = await storage.getSystemPrompt();

      expect(result, equals(largePrompt));
      expect(result!.length, equals(10000));
    });

    test('handles whitespace-only prompt as non-empty', () async {
      const whitespace = '   \t\n  ';

      await storage.setSystemPrompt(whitespace);
      final result = await storage.getSystemPrompt();

      // Whitespace-only is non-empty, so it should be returned
      expect(result, equals(whitespace));
    });

    test('handles single character prompt', () async {
      await storage.setSystemPrompt('X');
      final result = await storage.getSystemPrompt();

      expect(result, equals('X'));
    });

    test('handles prompt with special characters', () async {
      const special = r'Escape: \ "quotes" <tags> & $dollars {braces} `backticks`';

      await storage.setSystemPrompt(special);
      final result = await storage.getSystemPrompt();

      expect(result, equals(special));
    });

    test('handles prompt with null bytes', () async {
      const withNull = 'before\x00after';

      await storage.setSystemPrompt(withNull);
      final result = await storage.getSystemPrompt();

      expect(result, equals(withNull));
    });

    test('handles prompt with Windows-style line endings', () async {
      const crlf = 'line1\r\nline2\r\nline3';

      await storage.setSystemPrompt(crlf);
      final result = await storage.getSystemPrompt();

      expect(result, equals(crlf));
    });
  });

  group('SystemPromptStorage setSystemPrompt and getSystemPrompt round-trip', () {
    test('basic round-trip succeeds', () async {
      const prompt = 'You are a helpful coding assistant.';

      await storage.setSystemPrompt(prompt);
      final result = await storage.getSystemPrompt();

      expect(result, equals(prompt));
    });

    test('multiple set-get cycles return latest value', () async {
      for (int i = 0; i < 5; i++) {
        final prompt = 'Prompt iteration $i';
        await storage.setSystemPrompt(prompt);
        final result = await storage.getSystemPrompt();
        expect(result, equals(prompt));
      }
    });

    test('set then reset then get returns null', () async {
      await storage.setSystemPrompt('Temporary prompt');
      await storage.resetSystemPrompt();
      final result = await storage.getSystemPrompt();

      expect(result, isNull);
    });

    test('set then reset then set returns new value', () async {
      await storage.setSystemPrompt('First');
      await storage.resetSystemPrompt();
      await storage.setSystemPrompt('Second');

      final result = await storage.getSystemPrompt();
      expect(result, equals('Second'));
    });
  });

  group('SystemPromptStorage resetSystemPrompt', () {
    test('deletes the file when it exists', () async {
      await storage.setSystemPrompt('To be deleted');

      final file = File('${tempDir.path}/system_prompt.txt');
      expect(await file.exists(), isTrue);

      await storage.resetSystemPrompt();

      expect(await file.exists(), isFalse);
    });

    test('does not throw when no file exists', () async {
      // Ensure file does not exist
      final file = File('${tempDir.path}/system_prompt.txt');
      expect(await file.exists(), isFalse);

      // Should complete without error
      await expectLater(storage.resetSystemPrompt(), completes);
    });

    test('can be called multiple times without error', () async {
      await storage.setSystemPrompt('Some prompt');
      await storage.resetSystemPrompt();
      await storage.resetSystemPrompt();
      await storage.resetSystemPrompt();

      final result = await storage.getSystemPrompt();
      expect(result, isNull);
    });

    test('getSystemPrompt returns null after reset', () async {
      await storage.setSystemPrompt('Exists');
      expect(await storage.getSystemPrompt(), isNotNull);

      await storage.resetSystemPrompt();
      expect(await storage.getSystemPrompt(), isNull);
    });
  });

  group('SystemPromptStorage getSystemPromptFile', () {
    test('returns consistent path across multiple calls', () async {
      final file1 = await storage.getSystemPromptFile();
      final file2 = await storage.getSystemPromptFile();

      expect(file1.path, equals(file2.path));
    });

    test('path ends with system_prompt.txt', () async {
      final file = await storage.getSystemPromptFile();

      expect(file.path, endsWith('/system_prompt.txt'));
    });

    test('path is inside the injected directory', () async {
      final file = await storage.getSystemPromptFile();

      expect(file.path, startsWith(tempDir.path));
    });

    test('returned file object matches actual storage location', () async {
      await storage.setSystemPrompt('Test content');
      final file = await storage.getSystemPromptFile();

      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals('Test content'));
    });
  });

  group('SystemPromptStorage concurrent operations', () {
    test('concurrent reads return same value', () async {
      await storage.setSystemPrompt('Concurrent test');

      final results = await Future.wait([
        storage.getSystemPrompt(),
        storage.getSystemPrompt(),
        storage.getSystemPrompt(),
      ]);

      for (final result in results) {
        expect(result, equals('Concurrent test'));
      }
    });

    test('rapid set operations end with last value', () async {
      // Write multiple values in sequence
      for (int i = 0; i < 10; i++) {
        await storage.setSystemPrompt('Value $i');
      }

      final result = await storage.getSystemPrompt();
      expect(result, equals('Value 9'));
    });
  });

  group('SystemPromptStorage isolation', () {
    test('separate instances with different directories are independent', () async {
      final otherDir = Directory.systemTemp.createTempSync('system_prompt_test_other_');
      addTearDown(() {
        if (otherDir.existsSync()) {
          otherDir.deleteSync(recursive: true);
        }
      });

      final otherStorage = TestableSystemPromptStorage(otherDir);

      await storage.setSystemPrompt('Storage A');
      await otherStorage.setSystemPrompt('Storage B');

      expect(await storage.getSystemPrompt(), equals('Storage A'));
      expect(await otherStorage.getSystemPrompt(), equals('Storage B'));

      await storage.resetSystemPrompt();

      expect(await storage.getSystemPrompt(), isNull);
      expect(await otherStorage.getSystemPrompt(), equals('Storage B'));
    });
  });

  group('SystemPromptStorage edge cases', () {
    test('directory deleted externally causes error on set', () async {
      // Delete the temp directory to simulate external interference
      tempDir.deleteSync(recursive: true);

      // Writing to a file in a deleted directory should throw
      expect(
        () => storage.setSystemPrompt('Should fail'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('file deleted externally between set and get returns null', () async {
      await storage.setSystemPrompt('Will be deleted');

      // Externally delete the file
      final file = File('${tempDir.path}/system_prompt.txt');
      await file.delete();

      final result = await storage.getSystemPrompt();
      expect(result, isNull);
    });

    test('very long prompt (100K chars) round-trips', () async {
      final veryLarge = 'B' * 100000;

      await storage.setSystemPrompt(veryLarge);
      final result = await storage.getSystemPrompt();

      expect(result, equals(veryLarge));
      expect(result!.length, equals(100000));
    });

    test('prompt with mixed newline styles preserves all', () async {
      const mixed = 'unix\nwindows\r\nold-mac\rend';

      await storage.setSystemPrompt(mixed);
      final result = await storage.getSystemPrompt();

      expect(result, equals(mixed));
    });

    test('prompt with trailing newline is preserved', () async {
      const trailing = 'content\n';

      await storage.setSystemPrompt(trailing);
      final result = await storage.getSystemPrompt();

      expect(result, equals(trailing));
    });

    test('prompt with leading newline is preserved', () async {
      const leading = '\ncontent';

      await storage.setSystemPrompt(leading);
      final result = await storage.getSystemPrompt();

      expect(result, equals(leading));
    });
  });
}
