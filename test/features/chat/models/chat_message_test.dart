import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';

void main() {
  group('MessageRole enum', () {
    test('has exactly 4 values', () {
      expect(MessageRole.values.length, equals(4));
    });

    test('contains user role', () {
      expect(MessageRole.values, contains(MessageRole.user));
    });

    test('contains assistant role', () {
      expect(MessageRole.values, contains(MessageRole.assistant));
    });

    test('contains system role', () {
      expect(MessageRole.values, contains(MessageRole.system));
    });

    test('contains error role', () {
      expect(MessageRole.values, contains(MessageRole.error));
    });

    test('user role has correct name', () {
      expect(MessageRole.user.name, equals('user'));
    });

    test('assistant role has correct name', () {
      expect(MessageRole.assistant.name, equals('assistant'));
    });

    test('system role has correct name', () {
      expect(MessageRole.system.name, equals('system'));
    });

    test('error role has correct name', () {
      expect(MessageRole.error.name, equals('error'));
    });

    test('roles have distinct indices', () {
      final indices = MessageRole.values.map((r) => r.index).toSet();
      expect(indices.length, equals(4));
    });
  });

  group('ChatMessage', () {
    group('Constructor with required fields only', () {
      test('creates message with required fields', () {
        final timestamp = DateTime(2024, 6, 15, 10, 30, 45);
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Hello, world!',
          timestamp: timestamp,
        );

        expect(message.role, equals(MessageRole.user));
        expect(message.content, equals('Hello, world!'));
        expect(message.timestamp, equals(timestamp));
        expect(message.attachments, isNull);
      });

      test('creates message with assistant role', () {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'I can help you.',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.assistant));
      });

      test('creates message with system role', () {
        final message = ChatMessage(
          role: MessageRole.system,
          content: 'System notification',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.system));
      });

      test('creates message with error role', () {
        final message = ChatMessage(
          role: MessageRole.error,
          content: 'An error occurred',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.error));
      });
    });

    group('Constructor with attachments', () {
      test('creates message with single attachment', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Check this file',
          timestamp: DateTime.now(),
          attachments: ['/path/to/file.pdf'],
        );

        expect(message.attachments, isNotNull);
        expect(message.attachments!.length, equals(1));
        expect(message.attachments![0], equals('/path/to/file.pdf'));
      });

      test('creates message with multiple attachments', () {
        final attachments = [
          '/path/to/document.pdf',
          '/path/to/image.png',
          '/path/to/video.mp4',
        ];

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Multiple files',
          timestamp: DateTime.now(),
          attachments: attachments,
        );

        expect(message.attachments, isNotNull);
        expect(message.attachments!.length, equals(3));
        expect(message.attachments, equals(attachments));
      });

      test('creates message with empty attachments list', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'No files attached',
          timestamp: DateTime.now(),
          attachments: [],
        );

        expect(message.attachments, isNotNull);
        expect(message.attachments, isEmpty);
      });

      test('attachments can be null', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
          attachments: null,
        );

        expect(message.attachments, isNull);
      });

      test('attachments default to null when not provided', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
        );

        expect(message.attachments, isNull);
      });
    });

    group('Field storage and retrieval', () {
      test('stores all fields correctly', () {
        final timestamp = DateTime(2024, 12, 25, 14, 30, 0, 123, 456);
        final attachments = ['/file1.txt', '/file2.pdf'];

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Comprehensive test message',
          timestamp: timestamp,
          attachments: attachments,
        );

        expect(message.role, equals(MessageRole.assistant));
        expect(message.content, equals('Comprehensive test message'));
        expect(message.timestamp, equals(timestamp));
        expect(message.attachments, equals(attachments));
      });

      test('fields are final and immutable references', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
        );

        // These should be compile-time errors if uncommented:
        // message.role = MessageRole.assistant;
        // message.content = 'New content';
        // message.timestamp = DateTime.now();
        // message.attachments = [];

        // Verify fields exist and can be read
        expect(message.role, isNotNull);
        expect(message.content, isNotNull);
        expect(message.timestamp, isNotNull);
      });
    });

    group('Timestamp precision', () {
      test('preserves timestamp with full precision', () {
        final timestamp = DateTime(2024, 6, 15, 10, 30, 45, 123, 456);

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: timestamp,
        );

        expect(message.timestamp.year, equals(2024));
        expect(message.timestamp.month, equals(6));
        expect(message.timestamp.day, equals(15));
        expect(message.timestamp.hour, equals(10));
        expect(message.timestamp.minute, equals(30));
        expect(message.timestamp.second, equals(45));
        expect(message.timestamp.millisecond, equals(123));
        expect(message.timestamp.microsecond, equals(456));
      });

      test('preserves UTC timestamp', () {
        final utcTimestamp = DateTime.utc(2024, 1, 1, 0, 0, 0);

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: utcTimestamp,
        );

        expect(message.timestamp.isUtc, isTrue);
        expect(message.timestamp, equals(utcTimestamp));
      });

      test('preserves local timestamp', () {
        final localTimestamp = DateTime(2024, 7, 4, 12, 0, 0);

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: localTimestamp,
        );

        expect(message.timestamp.isUtc, isFalse);
        expect(message.timestamp, equals(localTimestamp));
      });

      test('handles epoch timestamp', () {
        final epochTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

        final message = ChatMessage(
          role: MessageRole.system,
          content: 'Epoch test',
          timestamp: epochTimestamp,
        );

        expect(message.timestamp.millisecondsSinceEpoch, equals(0));
      });

      test('handles far future timestamp', () {
        final futureTimestamp = DateTime(2100, 12, 31, 23, 59, 59);

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Future message',
          timestamp: futureTimestamp,
        );

        expect(message.timestamp.year, equals(2100));
      });
    });

    group('Content edge cases', () {
      test('content can be empty string', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: '',
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(''));
        expect(message.content.isEmpty, isTrue);
      });

      test('content can have leading and trailing whitespace', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: '  spaces around  ',
          timestamp: DateTime.now(),
        );

        expect(message.content, equals('  spaces around  '));
      });

      test('content can have newlines', () {
        final multilineContent = 'Line 1\nLine 2\nLine 3';

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: multilineContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(multilineContent));
        expect(message.content.split('\n').length, equals(3));
      });

      test('content can have tabs', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Column1\tColumn2\tColumn3',
          timestamp: DateTime.now(),
        );

        expect(message.content, contains('\t'));
      });

      test('content can have special characters', () {
        final specialContent = r'!@#$%^&*()_+-=[]{}|;:\",.<>?/~`';

        final message = ChatMessage(
          role: MessageRole.user,
          content: specialContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(specialContent));
      });

      test('content can have unicode characters', () {
        final unicodeContent = 'Hello \u4e16\u754c \u041f\u0440\u0438\u0432\u0435\u0442 \u3053\u3093\u306b\u3061\u306f';

        final message = ChatMessage(
          role: MessageRole.user,
          content: unicodeContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(unicodeContent));
        expect(message.content, contains('\u4e16\u754c')); // Chinese
        expect(message.content, contains('\u041f\u0440\u0438\u0432\u0435\u0442')); // Russian
        expect(message.content, contains('\u3053\u3093\u306b\u3061\u306f')); // Japanese
      });

      test('content can have emojis', () {
        final emojiContent = 'Hello! \u{1F600}\u{1F389}\u{2764}\u{FE0F}\u{1F680}\u{1F31F}';

        final message = ChatMessage(
          role: MessageRole.user,
          content: emojiContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(emojiContent));
      });

      test('content can have mixed emojis and text', () {
        final mixedContent = '\u{1F4AC} Message received! \u{1F44D} Great work \u{1F3C6}';

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: mixedContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(mixedContent));
      });

      test('content can be very long', () {
        final veryLongContent = 'A' * 100000;

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: veryLongContent,
          timestamp: DateTime.now(),
        );

        expect(message.content.length, equals(100000));
        expect(message.content, equals(veryLongContent));
      });

      test('content can have HTML-like content', () {
        final htmlContent = '<script>alert("test")</script><div class="test">Content</div>';

        final message = ChatMessage(
          role: MessageRole.user,
          content: htmlContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(htmlContent));
      });

      test('content can have markdown', () {
        final markdownContent = '''# Heading
**bold** and *italic*
- list item 1
- list item 2
```dart
print('code block');
```''';

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: markdownContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(markdownContent));
      });

      test('content can have JSON-like content', () {
        final jsonContent = '{"key": "value", "array": [1, 2, 3]}';

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: jsonContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(jsonContent));
      });

      test('content can have only whitespace', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: '   \n\t\r  ',
          timestamp: DateTime.now(),
        );

        expect(message.content, equals('   \n\t\r  '));
        expect(message.content.trim(), isEmpty);
      });

      test('content can have null character', () {
        final contentWithNull = 'before\x00after';

        final message = ChatMessage(
          role: MessageRole.user,
          content: contentWithNull,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(contentWithNull));
      });

      test('content can have escape sequences', () {
        final escapedContent = 'Line1\\nStill Line1\nActual Line2';

        final message = ChatMessage(
          role: MessageRole.user,
          content: escapedContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, equals(escapedContent));
      });
    });

    group('Attachments edge cases', () {
      test('single attachment with empty string path', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
          attachments: [''],
        );

        expect(message.attachments!.length, equals(1));
        expect(message.attachments![0], equals(''));
      });

      test('attachments with various file types', () {
        final attachments = [
          '/documents/report.pdf',
          '/images/photo.jpg',
          '/videos/clip.mp4',
          '/audio/song.mp3',
          '/data/file.json',
          '/archive/backup.zip',
        ];

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Multiple file types',
          timestamp: DateTime.now(),
          attachments: attachments,
        );

        expect(message.attachments!.length, equals(6));
        expect(message.attachments, equals(attachments));
      });

      test('attachments with special characters in paths', () {
        final attachments = [
          '/path/with spaces/file name.pdf',
          '/path/with-dashes/file-name.txt',
          '/path/with_underscores/file_name.doc',
          '/path/with.dots/file.name.ext',
        ];

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Special paths',
          timestamp: DateTime.now(),
          attachments: attachments,
        );

        expect(message.attachments, equals(attachments));
      });

      test('attachments with unicode paths', () {
        final attachments = [
          '/\u6587\u6863/\u6587\u4ef6.pdf',
          '/\u0434\u043e\u043a\u0443\u043c\u0435\u043d\u0442\u044b/\u0444\u0430\u0439\u043b.txt',
        ];

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Unicode paths',
          timestamp: DateTime.now(),
          attachments: attachments,
        );

        expect(message.attachments, equals(attachments));
      });

      test('attachments with very long paths', () {
        final longPath = '/very/${'long/' * 50}path/file.txt';

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Long path',
          timestamp: DateTime.now(),
          attachments: [longPath],
        );

        expect(message.attachments![0], equals(longPath));
      });

      test('many attachments', () {
        final manyAttachments = List.generate(
          100,
          (i) => '/path/to/file_$i.txt',
        );

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Many files',
          timestamp: DateTime.now(),
          attachments: manyAttachments,
        );

        expect(message.attachments!.length, equals(100));
        expect(message.attachments![50], equals('/path/to/file_50.txt'));
      });

      test('attachments list preserves order', () {
        final attachments = ['c.txt', 'a.txt', 'b.txt'];

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Order test',
          timestamp: DateTime.now(),
          attachments: attachments,
        );

        expect(message.attachments![0], equals('c.txt'));
        expect(message.attachments![1], equals('a.txt'));
        expect(message.attachments![2], equals('b.txt'));
      });

      test('attachments can have duplicate paths', () {
        final attachments = ['/same/file.txt', '/same/file.txt', '/same/file.txt'];

        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Duplicates',
          timestamp: DateTime.now(),
          attachments: attachments,
        );

        expect(message.attachments!.length, equals(3));
      });
    });

    group('Different message roles usage', () {
      test('user message typical usage', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'How do I create a Flutter app?',
          timestamp: DateTime.now(),
          attachments: ['/screenshots/error.png'],
        );

        expect(message.role, equals(MessageRole.user));
        expect(message.content, isNotEmpty);
        expect(message.attachments, isNotNull);
      });

      test('assistant message typical usage', () {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'To create a Flutter app, run: flutter create my_app',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.assistant));
        expect(message.attachments, isNull);
      });

      test('system message typical usage', () {
        final message = ChatMessage(
          role: MessageRole.system,
          content: '\u23f3 Message queued. Will send when online.',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.system));
      });

      test('error message typical usage', () {
        final message = ChatMessage(
          role: MessageRole.error,
          content: 'Network timeout: Unable to connect to server',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.error));
      });
    });

    group('Multiple messages', () {
      test('can create conversation thread', () {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Hello',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hi! How can I help?',
            timestamp: now.add(const Duration(seconds: 1)),
          ),
          ChatMessage(
            role: MessageRole.user,
            content: 'What is Flutter?',
            timestamp: now.add(const Duration(seconds: 5)),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Flutter is a UI toolkit...',
            timestamp: now.add(const Duration(seconds: 7)),
          ),
        ];

        expect(messages.length, equals(4));
        expect(messages[0].role, equals(MessageRole.user));
        expect(messages[1].role, equals(MessageRole.assistant));
        expect(messages[2].role, equals(MessageRole.user));
        expect(messages[3].role, equals(MessageRole.assistant));

        // Verify timestamps are in order
        for (int i = 1; i < messages.length; i++) {
          expect(
            messages[i].timestamp.isAfter(messages[i - 1].timestamp),
            isTrue,
          );
        }
      });

      test('messages are independent instances', () {
        final timestamp = DateTime.now();
        final message1 = ChatMessage(
          role: MessageRole.user,
          content: 'First',
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          role: MessageRole.user,
          content: 'Second',
          timestamp: timestamp,
        );

        expect(identical(message1, message2), isFalse);
        expect(message1.content, isNot(equals(message2.content)));
      });

      test('same content different roles', () {
        final content = 'Same text';
        final timestamp = DateTime.now();

        final userMessage = ChatMessage(
          role: MessageRole.user,
          content: content,
          timestamp: timestamp,
        );

        final assistantMessage = ChatMessage(
          role: MessageRole.assistant,
          content: content,
          timestamp: timestamp,
        );

        expect(userMessage.content, equals(assistantMessage.content));
        expect(userMessage.role, isNot(equals(assistantMessage.role)));
      });
    });

    group('Real-world scenarios', () {
      test('queued offline message', () {
        final message = ChatMessage(
          role: MessageRole.system,
          content: '\u23f3 Message queued. Will send when online.',
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.system));
        expect(message.content, contains('queued'));
      });

      test('message with code block', () {
        final codeContent = '''Here's an example:

```dart
void main() {
  print('Hello, World!');
}
```

This code prints a greeting.''';

        final message = ChatMessage(
          role: MessageRole.assistant,
          content: codeContent,
          timestamp: DateTime.now(),
        );

        expect(message.content, contains('```dart'));
        expect(message.content, contains('```'));
      });

      test('error with stack trace', () {
        final errorContent = '''Exception: Connection failed
    at NetworkService.connect (network_service.dart:42)
    at ApiClient.request (api_client.dart:128)
    at main (main.dart:15)''';

        final message = ChatMessage(
          role: MessageRole.error,
          content: errorContent,
          timestamp: DateTime.now(),
        );

        expect(message.role, equals(MessageRole.error));
        expect(message.content, contains('Exception'));
      });

      test('message with file references', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Please analyze these files',
          timestamp: DateTime.now(),
          attachments: [
            '/Users/user/Documents/report_q1.pdf',
            '/Users/user/Documents/report_q2.pdf',
            '/Users/user/Downloads/data.csv',
          ],
        );

        expect(message.attachments!.length, equals(3));
        expect(message.attachments!.every((p) => p.startsWith('/')), isTrue);
      });
    });
  });
}
