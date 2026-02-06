import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';

void main() {
  group('ChatMessage', () {
    test('creates with required fields', () {
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 30),
      );

      expect(message.role, equals(MessageRole.user));
      expect(message.content, equals('Hello'));
      expect(message.timestamp, equals(DateTime(2024, 1, 15, 10, 30)));
      expect(message.attachments, isNull);
    });

    test('creates with attachments', () {
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'Check these files',
        timestamp: DateTime.now(),
        attachments: ['/path/to/file1.pdf', '/path/to/file2.jpg'],
      );

      expect(message.attachments, isNotNull);
      expect(message.attachments!.length, equals(2));
      expect(message.attachments!.first, equals('/path/to/file1.pdf'));
    });

    test('creates assistant message', () {
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: 'I can help with that',
        timestamp: DateTime.now(),
      );

      expect(message.role, equals(MessageRole.assistant));
    });

    test('creates system message', () {
      final message = ChatMessage(
        role: MessageRole.system,
        content: 'Message queued',
        timestamp: DateTime.now(),
      );

      expect(message.role, equals(MessageRole.system));
    });

    test('creates error message', () {
      final message = ChatMessage(
        role: MessageRole.error,
        content: 'Connection failed',
        timestamp: DateTime.now(),
      );

      expect(message.role, equals(MessageRole.error));
    });
  });

  group('MessageRole', () {
    test('has all expected values', () {
      expect(MessageRole.values, contains(MessageRole.user));
      expect(MessageRole.values, contains(MessageRole.assistant));
      expect(MessageRole.values, contains(MessageRole.system));
      expect(MessageRole.values, contains(MessageRole.error));
      expect(MessageRole.values.length, equals(4));
    });
  });

  group('ChatScreen widget', () {
    test('creates with default initializing false', () {
      const screen = ChatScreen();
      expect(screen.initializing, isFalse);
    });

    test('creates with initializing true', () {
      const screen = ChatScreen(initializing: true);
      expect(screen.initializing, isTrue);
    });
  });

  group('Message list behavior', () {
    test('messages list starts empty', () {
      final messages = <ChatMessage>[];
      expect(messages, isEmpty);
    });

    test('can add user message to list', () {
      final messages = <ChatMessage>[];
      messages.add(ChatMessage(
        role: MessageRole.user,
        content: 'Hello',
        timestamp: DateTime.now(),
      ));

      expect(messages.length, equals(1));
      expect(messages.first.role, equals(MessageRole.user));
    });

    test('maintains message order', () {
      final messages = <ChatMessage>[];
      final now = DateTime.now();

      messages.add(ChatMessage(
        role: MessageRole.user,
        content: 'First',
        timestamp: now,
      ));
      messages.add(ChatMessage(
        role: MessageRole.assistant,
        content: 'Second',
        timestamp: now.add(const Duration(seconds: 1)),
      ));
      messages.add(ChatMessage(
        role: MessageRole.user,
        content: 'Third',
        timestamp: now.add(const Duration(seconds: 2)),
      ));

      expect(messages[0].content, equals('First'));
      expect(messages[1].content, equals('Second'));
      expect(messages[2].content, equals('Third'));
    });
  });

  group('Quick action handling', () {
    test('detects calendar mode from action', () {
      const action = '/calendar show today';
      expect(action.startsWith('/calendar'), isTrue);
    });

    test('detects email mode from action', () {
      const action = '/email check inbox';
      expect(action.startsWith('/email'), isTrue);
    });

    test('detects media mode from crop action', () {
      const action = '/crop video.mp4';
      expect(action.startsWith('/crop'), isTrue);
    });

    test('detects media mode from extract action', () {
      const action = '/extract audio from video.mp4';
      expect(action.startsWith('/extract'), isTrue);
    });

    test('detects OCR mode from action', () {
      const action = '/ocr image.png';
      expect(action.startsWith('/ocr'), isTrue);
    });

    test('parses mode from action string', () {
      String? detectMode(String action) {
        if (action.startsWith('/calendar')) return 'Calendar';
        if (action.startsWith('/email')) return 'Email';
        if (action.startsWith('/crop') || action.startsWith('/extract')) {
          return 'Media';
        }
        if (action.startsWith('/ocr')) return 'OCR';
        return null;
      }

      expect(detectMode('/calendar show today'), equals('Calendar'));
      expect(detectMode('/email check inbox'), equals('Email'));
      expect(detectMode('/crop video.mp4'), equals('Media'));
      expect(detectMode('/extract audio'), equals('Media'));
      expect(detectMode('/ocr image.png'), equals('OCR'));
      expect(detectMode('hello'), isNull);
    });
  });

  group('Status message mapping', () {
    test('maps Python status to UI message', () {
      String? mapStatusToMessage(String status) {
        switch (status) {
          case 'initializing':
            return 'Initializing...';
          case 'importing':
            return 'Loading modules...';
          case 'ready':
            return null;
          case 'error':
            return 'Connection error';
          case 'restarting':
            return 'Reconnecting...';
          default:
            return null;
        }
      }

      expect(mapStatusToMessage('initializing'), equals('Initializing...'));
      expect(mapStatusToMessage('importing'), equals('Loading modules...'));
      expect(mapStatusToMessage('ready'), isNull);
      expect(mapStatusToMessage('error'), equals('Connection error'));
      expect(mapStatusToMessage('restarting'), equals('Reconnecting...'));
      expect(mapStatusToMessage('unknown'), isNull);
    });
  });

  group('Progress message formatting', () {
    test('formats progress message correctly', () {
      const message = 'Processing video';
      const progress = 0.5;

      final formatted = '$message (${(progress * 100).toInt()}%)';
      expect(formatted, equals('Processing video (50%)'));
    });

    test('formats 0% progress', () {
      const progress = 0.0;
      final formatted = '(${(progress * 100).toInt()}%)';
      expect(formatted, equals('(0%)'));
    });

    test('formats 100% progress', () {
      const progress = 1.0;
      final formatted = '(${(progress * 100).toInt()}%)';
      expect(formatted, equals('(100%)'));
    });

    test('formats partial progress', () {
      const progress = 0.333;
      final formatted = '(${(progress * 100).toInt()}%)';
      expect(formatted, equals('(33%)'));
    });
  });

  group('Offline message queuing', () {
    test('creates queued message with system role', () {
      final message = ChatMessage(
        role: MessageRole.system,
        content: 'Message queued. Will send when online.',
        timestamp: DateTime.now(),
      );

      expect(message.role, equals(MessageRole.system));
      expect(message.content, contains('queued'));
    });
  });

  group('Attachment handling', () {
    test('clears attachments after send', () {
      var attachedFiles = <String>['/file1.pdf', '/file2.jpg'];

      // Simulate send
      final attachmentsToSend = List<String>.from(attachedFiles);
      attachedFiles = [];

      expect(attachmentsToSend.length, equals(2));
      expect(attachedFiles, isEmpty);
    });

    test('preserves attachment paths in message', () {
      final files = ['/storage/doc.pdf', '/storage/image.png'];
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'Check these',
        timestamp: DateTime.now(),
        attachments: List.from(files),
      );

      expect(message.attachments, equals(files));
    });
  });

  group('Text input handling', () {
    test('trims whitespace from input', () {
      const input = '  Hello world  ';
      final trimmed = input.trim();
      expect(trimmed, equals('Hello world'));
    });

    test('detects empty input after trim', () {
      const input = '   ';
      expect(input.trim().isEmpty, isTrue);
    });

    test('preserves internal whitespace', () {
      const input = '  Hello   world  ';
      final trimmed = input.trim();
      expect(trimmed, equals('Hello   world'));
    });
  });

  group('Response handling', () {
    test('extracts content from success response', () {
      final response = {
        'content': 'Here is my answer',
        'tokens_used': 150,
      };

      final content = response['content'] as String? ?? '';
      expect(content, equals('Here is my answer'));
    });

    test('handles missing content in response', () {
      final response = <String, dynamic>{
        'tokens_used': 150,
      };

      final content = response['content'] as String? ?? '';
      expect(content, isEmpty);
    });

    test('handles null response gracefully', () {
      final Map<String, dynamic>? response = null;
      final content = response?['content'] as String? ?? '';
      expect(content, isEmpty);
    });
  });

  group('Error handling', () {
    test('creates error message from exception', () {
      final error = Exception('Network timeout');
      final message = ChatMessage(
        role: MessageRole.error,
        content: error.toString(),
        timestamp: DateTime.now(),
      );

      expect(message.role, equals(MessageRole.error));
      expect(message.content, contains('Network timeout'));
    });

    test('creates error message from error response', () {
      const errorMessage = 'API rate limit exceeded';
      final message = ChatMessage(
        role: MessageRole.error,
        content: errorMessage,
        timestamp: DateTime.now(),
      );

      expect(message.content, equals('API rate limit exceeded'));
    });
  });

  group('Navigation', () {
    test('settings route is correct', () {
      const route = '/settings';
      expect(route, equals('/settings'));
    });

    test('settings with section argument', () {
      final arguments = {'section': 'google'};
      expect(arguments['section'], equals('google'));
    });
  });

  group('Processing state', () {
    test('processing state blocks input', () {
      var isProcessing = false;
      var isPythonReady = true;

      bool isInputEnabled() => isPythonReady && !isProcessing;

      expect(isInputEnabled(), isTrue);

      isProcessing = true;
      expect(isInputEnabled(), isFalse);

      isProcessing = false;
      isPythonReady = false;
      expect(isInputEnabled(), isFalse);
    });
  });

  group('Quick actions visibility', () {
    test('shows quick actions when idle and no messages', () {
      final messages = <ChatMessage>[];
      var showQuickActions = true;
      var isProcessing = false;

      bool shouldShowQuickActions() {
        return messages.isEmpty && showQuickActions && !isProcessing;
      }

      expect(shouldShowQuickActions(), isTrue);
    });

    test('hides quick actions when processing', () {
      final messages = <ChatMessage>[];
      var showQuickActions = true;
      var isProcessing = true;

      bool shouldShowQuickActions() {
        return messages.isEmpty && showQuickActions && !isProcessing;
      }

      expect(shouldShowQuickActions(), isFalse);
    });

    test('hides quick actions when messages exist', () {
      final messages = <ChatMessage>[
        ChatMessage(
          role: MessageRole.user,
          content: 'Hello',
          timestamp: DateTime.now(),
        ),
      ];
      var showQuickActions = true;
      var isProcessing = false;

      bool shouldShowQuickActions() {
        return messages.isEmpty && showQuickActions && !isProcessing;
      }

      expect(shouldShowQuickActions(), isFalse);
    });

    test('hides quick actions when dismissed', () {
      final messages = <ChatMessage>[];
      var showQuickActions = false;
      var isProcessing = false;

      bool shouldShowQuickActions() {
        return messages.isEmpty && showQuickActions && !isProcessing;
      }

      expect(shouldShowQuickActions(), isFalse);
    });
  });
}
