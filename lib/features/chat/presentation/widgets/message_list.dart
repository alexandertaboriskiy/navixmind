import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../chat_screen.dart';
import 'message_bubble.dart';

/// Virtualized list of chat messages
class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool selfImproveEnabled;
  final bool isProcessing;
  final void Function(int index)? onSelfImprove;

  const MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.selfImproveEnabled = false,
    this.isProcessing = false,
    this.onSelfImprove,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showTimestamp = _shouldShowTimestamp(index);

        final showSelfImprove = selfImproveEnabled &&
            !isProcessing &&
            message.role == MessageRole.assistant;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTimestamp)
                _TimestampDivider(timestamp: message.timestamp),
              MessageBubble(message: message),
              if (showSelfImprove)
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => onSelfImprove?.call(index),
                      icon: Text(
                        '✦',
                        style: TextStyle(
                          fontSize: 14,
                          color: NavixTheme.textTertiary,
                        ),
                      ),
                      label: Text(
                        'Self Improve',
                        style: TextStyle(
                          fontSize: 12,
                          color: NavixTheme.textTertiary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final current = messages[index].timestamp;
    final previous = messages[index - 1].timestamp;
    // Show timestamp if more than 5 minutes apart
    return current.difference(previous).inMinutes > 5;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '⊕',
            style: TextStyle(
              fontSize: 48,
              color: NavixTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: NavixTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything or share a file to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NavixTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TimestampDivider extends StatelessWidget {
  final DateTime timestamp;

  const _TimestampDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: NavixTheme.surfaceVariant,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatTimestamp(timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NavixTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: NavixTheme.surfaceVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year;

    if (isToday) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
