import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/services/auth_service.dart';
import '../chat_screen.dart';

/// Platform channel for native file operations
const _fileChannel = MethodChannel('ai.navixmind/file_opener');

/// Individual message bubble with role-based styling
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _accessibilityLabel,
      hint: 'Long press to copy',
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Row(
          mainAxisAlignment: _alignment,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.role == MessageRole.assistant)
              _RoleIndicator(role: message.role),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: message.role == MessageRole.assistant
                        ? const Radius.circular(4)
                        : null,
                    bottomRight: message.role == MessageRole.user
                        ? const Radius.circular(4)
                        : null,
                  ),
                  border: _border,
                ),
                child: _buildContent(context),
              ),
            ),
            if (message.role == MessageRole.user)
              _RoleIndicator(role: message.role),
          ],
        ),
      ),
    );
  }

  String get _accessibilityLabel {
    final roleLabel = switch (message.role) {
      MessageRole.user => 'You said',
      MessageRole.assistant => 'NavixMind replied',
      MessageRole.system => 'System message',
      MessageRole.error => 'Error',
    };
    return '$roleLabel: ${message.content}';
  }

  MainAxisAlignment get _alignment {
    switch (message.role) {
      case MessageRole.user:
        return MainAxisAlignment.end;
      case MessageRole.assistant:
      case MessageRole.system:
      case MessageRole.error:
        return MainAxisAlignment.start;
    }
  }

  Color get _backgroundColor {
    switch (message.role) {
      case MessageRole.user:
        return NavixTheme.primary.withOpacity(0.15);
      case MessageRole.assistant:
        return NavixTheme.surface;
      case MessageRole.system:
        return NavixTheme.surfaceVariant;
      case MessageRole.error:
        return NavixTheme.error.withOpacity(0.15);
    }
  }

  Border? get _border {
    if (message.role == MessageRole.error) {
      return Border.all(color: NavixTheme.error.withOpacity(0.5));
    }
    return null;
  }

  Widget _buildContent(BuildContext context) {
    if (message.role == MessageRole.error) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            NavixTheme.iconWarning,
            style: TextStyle(
              fontSize: 16,
              color: NavixTheme.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavixTheme.error,
              ),
            ),
          ),
        ],
      );
    }

    // Check if this is a file link (from tool output)
    if (message.content.startsWith('📎 File:')) {
      return _buildFileLink(context);
    }

    // Check if content contains code blocks
    if (message.content.contains('```')) {
      return _buildMarkdownContent(context);
    }

    // Check if message suggests connecting Google account
    final needsGoogleConnect = !AuthService.instance.isSignedIn &&
        message.role == MessageRole.assistant &&
        _mentionsGoogleConnect(message.content);

    if (needsGoogleConnect) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: NavixTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final account = await AuthService.instance.signIn();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(account != null
                          ? 'Google account connected!'
                          : 'Sign-in cancelled'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign-in failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.account_circle, size: 18),
            label: const Text('Connect Google Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NavixTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return SelectableText(
      message.content,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: NavixTheme.textPrimary,
      ),
    );
  }

  bool _mentionsGoogleConnect(String content) {
    final lower = content.toLowerCase();
    return (lower.contains('google') || lower.contains('gmail') || lower.contains('calendar')) &&
        (lower.contains('connect') || lower.contains('sign in') || lower.contains('settings') || lower.contains('authorize'));
  }

  Widget _buildFileLink(BuildContext context) {
    final filePath = message.content.replaceFirst('📎 File: ', '').trim();
    final fileName = filePath.split('/').last;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tappable file link - opens with Android default viewer
        Flexible(
          child: InkWell(
            onTap: () async {
              final file = File(filePath);
              if (await file.exists()) {
                try {
                  // Try to open with native file viewer
                  final opened = await _fileChannel.invokeMethod<bool>(
                    'openFile',
                    {'path': filePath},
                  );
                  if (opened != true && context.mounted) {
                    // Fallback to share if no app can open the file
                    await Share.shareXFiles([XFile(filePath)]);
                  }
                } catch (e) {
                  // Fallback to share on any error
                  if (context.mounted) {
                    await Share.shareXFiles([XFile(filePath)]);
                  }
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('File not found: $fileName')),
                  );
                }
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, size: 20, color: NavixTheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fileName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NavixTheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Share button
        InkWell(
          onTap: () async {
            final file = File(filePath);
            if (await file.exists()) {
              await Share.shareXFiles([XFile(filePath)]);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.share, size: 18, color: NavixTheme.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownContent(BuildContext context) {
    // Simple code block parsing
    final parts = <Widget>[];
    final regex = RegExp(r'```(\w*)\n?([\s\S]*?)```');
    var lastEnd = 0;

    for (final match in regex.allMatches(message.content)) {
      // Text before code block
      if (match.start > lastEnd) {
        final text = message.content.substring(lastEnd, match.start);
        if (text.trim().isNotEmpty) {
          parts.add(SelectableText(
            text.trim(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: NavixTheme.textPrimary,
            ),
          ));
        }
      }

      // Code block
      final language = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      parts.add(_CodeBlock(code: code.trim(), language: language));

      lastEnd = match.end;
    }

    // Text after last code block
    if (lastEnd < message.content.length) {
      final text = message.content.substring(lastEnd);
      if (text.trim().isNotEmpty) {
        parts.add(SelectableText(
          text.trim(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: NavixTheme.textPrimary,
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((w) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: w,
      )).toList(),
    );
  }

  void _showContextMenu(BuildContext context) {
    // Store reference to outer scaffold messenger before showing modal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      builder: (modalContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(modalContext);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleIndicator extends StatelessWidget {
  final MessageRole role;

  const _RoleIndicator({required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _icon,
            style: TextStyle(
              fontSize: 12,
              color: _color,
            ),
          ),
        ),
      ),
    );
  }

  String get _icon {
    switch (role) {
      case MessageRole.user:
        return '●';
      case MessageRole.assistant:
        return '◆';
      case MessageRole.system:
        return '◉';
      case MessageRole.error:
        return '!';
    }
  }

  Color get _color {
    switch (role) {
      case MessageRole.user:
        return NavixTheme.primary;
      case MessageRole.assistant:
        return NavixTheme.accentCyan;
      case MessageRole.system:
        return NavixTheme.textTertiary;
      case MessageRole.error:
        return NavixTheme.error;
    }
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  final String language;

  const _CodeBlock({
    required this.code,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NavixTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NavixTheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                language,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NavixTheme.textTertiary,
                ),
              ),
            ),
          SelectableText(
            code,
            style: NavixTheme.monoStyle,
          ),
        ],
      ),
    );
  }
}
