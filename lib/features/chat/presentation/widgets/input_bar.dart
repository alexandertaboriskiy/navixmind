import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/file_validator.dart';
import '../../../../shared/widgets/spinner.dart';

/// Smart input bar with context chips and action pills
class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final bool isProcessing;
  final Function(List<String> paths)? onFilesSelected;
  final List<String> externalFiles;

  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.isProcessing = false,
    this.onFilesSelected,
    this.externalFiles = const [],
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _focusNode = FocusNode();
  final _attachedFiles = <AttachedFile>[];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _syncExternalFiles(widget.externalFiles);
  }

  @override
  void didUpdateWidget(covariant InputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalFiles != oldWidget.externalFiles) {
      _syncExternalFiles(widget.externalFiles);
    }
  }

  void _syncExternalFiles(List<String> externalPaths) {
    if (externalPaths.isEmpty) return;

    final existingPaths = _attachedFiles.map((f) => f.path).toSet();
    var added = false;

    for (final path in externalPaths) {
      if (existingPaths.contains(path)) continue;

      final file = File(path);
      final name = path.split('/').last;
      final ext = name.contains('.') ? name.split('.').last : null;
      final type = FileValidator.detectFileType(ext);
      final size = file.existsSync() ? file.lengthSync() : 0;

      _attachedFiles.add(AttachedFile(
        path: path,
        name: name,
        type: type,
        size: size,
      ));
      added = true;
    }

    // Don't call setState or onFilesSelected here — this runs during
    // initState/didUpdateWidget (i.e. during build). The parent already
    // tracks these paths in _attachedFiles via _applySharedFiles.
    // The widget will rebuild naturally since the parent triggered this.
    if (added && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    // Show suggestions when text starts with /
    final shouldShow = text.startsWith('/') && text.length > 1;
    // Only rebuild if suggestion visibility changed
    if (shouldShow != _showSuggestions) {
      setState(() {
        _showSuggestions = shouldShow;
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path == null) continue;

          final type = FileValidator.detectFileType(file.extension);
          final limit = FileValidator.getLimitForType(type);

          if (file.size > limit) {
            _showFileTooLargeError(file.name, file.size, limit);
            continue;
          }

          setState(() {
            _attachedFiles.add(AttachedFile(
              path: file.path!,
              name: file.name,
              type: type,
              size: file.size,
            ));
          });
        }

        widget.onFilesSelected?.call(
          _attachedFiles.map((f) => f.path).toList(),
        );
      }
    } catch (e) {
      _showError('Failed to pick files: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
    widget.onFilesSelected?.call(
      _attachedFiles.map((f) => f.path).toList(),
    );
  }

  void _showFileTooLargeError(String name, int size, int limit) {
    final sizeStr = _formatSize(size);
    final limitStr = _formatSize(limit);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name is too large ($sizeStr). Max: $limitStr'),
        backgroundColor: NavixTheme.error,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NavixTheme.error,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _onSubmit() {
    if (widget.controller.text.trim().isEmpty && _attachedFiles.isEmpty) {
      return;
    }
    widget.onSend();
    setState(() {
      _attachedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NavixTheme.surface,
        border: Border(
          top: BorderSide(
            color: NavixTheme.surfaceVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attached files chips
          if (_attachedFiles.isNotEmpty)
            _AttachedFilesRow(
              files: _attachedFiles,
              onRemove: _removeFile,
            ),

          // Suggestion pills
          if (_showSuggestions)
            _SuggestionPills(
              text: widget.controller.text,
              onSelect: (suggestion) {
                widget.controller.text = suggestion;
                widget.controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: suggestion.length),
                );
                setState(() {
                  _showSuggestions = false;
                });
              },
            ),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Add context button
              _IconButton(
                icon: NavixTheme.iconAdd,
                onPressed: widget.enabled ? _pickFiles : null,
                tooltip: 'Add file',
              ),

              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _onSubmit(),
                  decoration: InputDecoration(
                    hintText: widget.enabled
                        ? 'Type a message...'
                        : 'Connecting...',
                    filled: true,
                    fillColor: NavixTheme.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send button / processing indicator
              widget.isProcessing
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: BrailleSpinner(size: 24),
                      ),
                    )
                  : _IconButton(
                      icon: NavixTheme.iconSend,
                      onPressed: widget.enabled ? _onSubmit : null,
                      tooltip: 'Send',
                      primary: true,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }
}

class _IconButton extends StatelessWidget {
  final String icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool primary;

  const _IconButton({
    required this.icon,
    this.onPressed,
    required this.tooltip,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final color = isEnabled
        ? (primary ? NavixTheme.primary : NavixTheme.textPrimary)
        : NavixTheme.textTertiary;

    return Semantics(
      label: tooltip,
      button: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: primary && isEnabled
              ? NavixTheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              alignment: Alignment.center,
              child: Icon(
                icon == '→' ? Icons.arrow_forward : Icons.add,
                size: 24,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachedFilesRow extends StatelessWidget {
  final List<AttachedFile> files;
  final Function(int) onRemove;

  const _AttachedFilesRow({
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = files[index];
          return _FileChip(
            name: file.name,
            type: file.type,
            onRemove: () => onRemove(index),
          );
        },
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String name;
  final String type;
  final VoidCallback onRemove;

  const _FileChip({
    required this.name,
    required this.type,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NavixTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getIcon(),
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            name.length > 15 ? '${name.substring(0, 12)}...' : name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavixTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Text(
              NavixTheme.iconClose,
              style: TextStyle(
                fontSize: 14,
                color: NavixTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getIcon() {
    switch (type) {
      case 'image':
        return '◫';
      case 'video':
        return '▶';
      case 'audio':
        return '♪';
      case 'pdf':
        return '◰';
      case 'document':
        return '◳';
      default:
        return '◉';
    }
  }
}

class _SuggestionPills extends StatelessWidget {
  final String text;
  final Function(String) onSelect;

  const _SuggestionPills({
    required this.text,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = _getSuggestions(text);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command pills row
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cmd = suggestions[index];
                return _SlashCommandPill(
                  command: cmd,
                  onSelect: () => onSelect(cmd.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<SlashCommand> _getSuggestions(String text) {
    final query = text.toLowerCase().substring(1); // Remove leading /
    return NavixTheme.slashCommands.values
        .where((c) => c.name.toLowerCase().contains(query) ||
            c.description.toLowerCase().contains(query))
        .take(4)
        .toList();
  }
}

class _SlashCommandPill extends StatelessWidget {
  final SlashCommand command;
  final VoidCallback onSelect;

  const _SlashCommandPill({
    required this.command,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getCategoryColor().withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getCategoryColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              command.icon,
              style: TextStyle(
                fontSize: 14,
                color: _getCategoryColor(),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  command.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NavixTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (command.category) {
      case 'media':
        return NavixTheme.accentPurple;
      case 'text':
        return NavixTheme.accentBlue;
      case 'google':
        return NavixTheme.accentOrange;
      default:
        return NavixTheme.accentCyan;
    }
  }
}

class AttachedFile {
  final String path;
  final String name;
  final String type;
  final int size;

  AttachedFile({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
  });
}
