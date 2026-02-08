import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/bridge/bridge.dart';
import '../../../core/constants/defaults.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_queue_manager.dart';
import '../../../core/services/share_receiver_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/spinner.dart';
import 'widgets/message_list.dart';
import 'widgets/input_bar.dart';
import 'widgets/status_banner.dart';
import 'widgets/context_bar.dart';

/// Main chat screen - the "Living Log" interface
class ChatScreen extends StatefulWidget {
  final bool initializing;

  const ChatScreen({
    super.key,
    this.initializing = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  bool _isProcessing = false;
  String? _statusMessage;
  String? _activeMode;
  List<String> _attachedFiles = [];
  bool _isGoogleConnected = false;
  bool _showQuickActions = true;
  bool _awaitingApiKey = false;
  bool _hasApiKey = false;
  bool _selfImproveEnabled = false;
  double _lastKeyboardHeight = 0;
  bool _pendingMetricsCheck = false;
  List<String> _externalFiles = [];
  StreamSubscription<SharedFilesEvent>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkApiKey();
    _loadSelfImproveSetting();
    _listenToPythonStatus();
    _listenToLogs();
    _listenToConnectivity();
    _listenToAuth();
    _listenToSharedFiles();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Scroll to bottom when keyboard appears.
    // Debounce: only check once per frame to avoid lag from repeated metric changes.
    if (_pendingMetricsCheck) return;
    _pendingMetricsCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingMetricsCheck = false;
      if (!mounted) return;
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      if (keyboardHeight > _lastKeyboardHeight && _messages.isNotEmpty) {
        _scrollToBottom();
      }
      _lastKeyboardHeight = keyboardHeight;
    });
  }

  Future<void> _loadSelfImproveSetting() async {
    final enabled = await StorageService.instance.isSelfImproveEnabled();
    if (mounted) {
      setState(() => _selfImproveEnabled = enabled);
    }
  }

  Future<void> _checkApiKey() async {
    final hasKey = await StorageService.instance.hasApiKey();
    setState(() {
      _hasApiKey = hasKey;
      if (!hasKey) {
        _awaitingApiKey = true;
        _messages.add(ChatMessage(
          role: MessageRole.system,
          content: 'Welcome to NavixMind! Please enter your Claude API key to get started.\n\nYou can get one at console.anthropic.com',
          timestamp: DateTime.now(),
        ));
      }
    });

    // If we have an API key, send it to Python when bridge is ready
    if (hasKey) {
      _sendStoredApiKeyToPython();
    }
  }

  void _sendStoredApiKeyToPython() {
    // Try immediately if ready
    if (PythonBridge.instance.status == PythonStatus.ready) {
      _doSendApiKey();
      return;
    }

    // Otherwise, listen for ready status
    StreamSubscription<PythonStatus>? subscription;
    subscription = PythonBridge.instance.statusStream.listen((status) {
      if (status == PythonStatus.ready) {
        _doSendApiKey();
        subscription?.cancel();
      }
    });

    // Clean up after a reasonable timeout
    Future.delayed(const Duration(seconds: 30), () {
      subscription?.cancel();
    });
  }

  Future<void> _doSendApiKey() async {
    final apiKey = await StorageService.instance.getApiKey();
    if (apiKey != null) {
      try {
        await PythonBridge.instance.setApiKey(apiKey);
      } catch (e) {
        debugPrint('Failed to send API key to Python: $e');
      }
    }
  }

  Future<void> _handleApiKeyInput(String input) async {
    final key = input.trim();
    _inputController.clear();

    // Basic validation - Claude API keys start with "sk-"
    if (!key.startsWith('sk-')) {
      setState(() {
        _messages.add(ChatMessage(
          role: MessageRole.system,
          content: 'That doesn\'t look like a valid Claude API key. It should start with "sk-". Please try again.',
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    // Save the API key
    await StorageService.instance.setApiKey(key);

    setState(() {
      _awaitingApiKey = false;
      _hasApiKey = true;
      _messages.add(ChatMessage(
        role: MessageRole.system,
        content: 'API key saved! You can now start chatting with NavixMind.',
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    // Send the API key to Python bridge
    await PythonBridge.instance.setApiKey(key);
  }

  void _listenToConnectivity() {
    ConnectivityService.instance.statusStream.listen((isConnected) {
      setState(() {});
    });
  }

  void _listenToAuth() {
    // Set initial state
    _isGoogleConnected = AuthService.instance.isSignedIn;

    // Listen for changes (sign-in / sign-out from Settings)
    AuthService.instance.userStream.listen((user) {
      if (mounted) {
        setState(() {
          _isGoogleConnected = user != null;
        });
      }
    });
  }

  void _listenToSharedFiles() {
    _shareSubscription = ShareReceiverService.instance.stream.listen((event) {
      _applySharedFiles(event);
    });

    // Check for buffered cold-start event — must defer to after build
    // to avoid setState() during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ShareReceiverService.instance.consumePending();
      if (pending != null) {
        _applySharedFiles(pending);
      }
    });
  }

  void _applySharedFiles(SharedFilesEvent event) {
    final validFiles = <String>[];
    final errors = <String>[];

    for (final file in event.files) {
      if (file.error != null) {
        errors.add(file.error!);
      } else if (file.path.isNotEmpty) {
        validFiles.add(file.path);
      }
    }

    setState(() {
      // Show error messages for failed files
      for (final error in errors) {
        _messages.add(ChatMessage(
          role: MessageRole.error,
          content: error,
          timestamp: DateTime.now(),
        ));
      }

      if (validFiles.isNotEmpty) {
        // Append to existing attached files
        _attachedFiles = [..._attachedFiles, ...validFiles];
        _externalFiles = [..._externalFiles, ...validFiles];

        _messages.add(ChatMessage(
          role: MessageRole.system,
          content: 'Received ${validFiles.length} file(s) from share. Add a prompt and send.',
          timestamp: DateTime.now(),
        ));
      }

      // If extra text was shared, put it in the input field
      if (event.text != null && event.text!.isNotEmpty) {
        _inputController.text = event.text!;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: event.text!.length),
        );
      }
    });

    _scrollToBottom();
  }

  void _listenToPythonStatus() {
    PythonBridge.instance.statusStream.listen((status) {
      setState(() {
        switch (status) {
          case PythonStatus.initializing:
            _statusMessage = 'Initializing...';
            break;
          case PythonStatus.importing:
            _statusMessage = 'Loading modules...';
            break;
          case PythonStatus.ready:
            _statusMessage = null;
            break;
          case PythonStatus.error:
            _statusMessage = 'Connection error';
            break;
          case PythonStatus.restarting:
            _statusMessage = 'Reconnecting...';
            break;
          default:
            break;
        }
      });
    });
  }

  void _listenToLogs() {
    PythonBridge.instance.logStream.listen((log) {
      if (!mounted) return;

      // Only process logs while we're actively processing a query
      if (!_isProcessing) {
        return;
      }

      // Show important messages as chat messages (thinking, tool use, results)
      final msg = log.message;
      final shouldShowInChat = msg.startsWith('Thinking:') ||
          msg.startsWith('Tool:') ||
          msg.startsWith('Result:') ||
          msg.startsWith('Executing') ||
          msg.startsWith('Code:') ||
          msg.startsWith('File:') ||
          log.isError ||
          log.isWarning;

      if (shouldShowInChat) {
        // Choose icon based on message type
        String icon;
        if (log.isError) {
          icon = '⚠️';
        } else if (log.isWarning) {
          icon = '⚡';
        } else if (msg.startsWith('Thinking:')) {
          icon = '💭';
        } else if (msg.startsWith('Tool:')) {
          icon = '🔧';
        } else if (msg.startsWith('Executing')) {
          icon = '⚙️';
        } else if (msg.startsWith('Result:')) {
          icon = '📋';
        } else if (msg.startsWith('Code:')) {
          icon = '💻';
        } else if (msg.startsWith('File:')) {
          icon = '📎';
        } else {
          icon = '💭';
        }
        setState(() {
          _messages.add(ChatMessage(
            role: MessageRole.system,
            content: '$icon $msg',
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }

      // Also update status bar for progress and simple status
      if (log.hasProgress) {
        // If progress is 100%, we're done - don't show status
        if (log.progress! >= 1.0) {
          return;
        }
        setState(() {
          _statusMessage = '${log.message} (${(log.progress! * 100).toInt()}%)';
        });
      } else {
        setState(() {
          _statusMessage = msg;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedFiles.isEmpty) return;

    // Handle API key input
    if (_awaitingApiKey) {
      await _handleApiKeyInput(text);
      return;
    }

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        role: MessageRole.user,
        content: text,
        timestamp: DateTime.now(),
        attachments: _attachedFiles.isNotEmpty ? List.from(_attachedFiles) : null,
      ));
      _inputController.clear();
    });

    _scrollToBottom();

    // If offline, queue the message (fresh check to avoid stale cache)
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      await OfflineQueueManager.instance.queueMessage(
        query: text,
        attachmentPaths: _attachedFiles.isNotEmpty ? _attachedFiles : null,
      );

      setState(() {
        _messages.add(ChatMessage(
          role: MessageRole.system,
          content: '⏳ Message queued. Will send when online.',
          timestamp: DateTime.now(),
        ));
        _attachedFiles = [];
      });
      _scrollToBottom();
      return;
    }

    // Track message sent
    await AnalyticsService.instance.messageSent(
      hasAttachments: _attachedFiles.isNotEmpty,
      attachmentCount: _attachedFiles.length,
    );

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Thinking...';
    });

    final stopwatch = Stopwatch()..start();
    try {
      debugPrint('Sending query to Python...');
      final response = await PythonBridge.instance.sendQuery(
        query: text,
        filePaths: _attachedFiles.isNotEmpty ? _attachedFiles : null,
      );

      if (!mounted) return;

      if (response.isSuccess && response.result != null) {
        final content = response.result!['content'] as String? ?? '';
        final hasError = response.result!['error'] == true;
        final createdFiles = response.result!['created_files'] as List<dynamic>?;
        setState(() {
          _messages.add(ChatMessage(
            role: hasError ? MessageRole.error : MessageRole.assistant,
            content: content,
            timestamp: DateTime.now(),
          ));
          // Add tappable file links for every created file
          if (createdFiles != null && !hasError) {
            for (final filePath in createdFiles) {
              _messages.add(ChatMessage(
                role: MessageRole.system,
                content: '\u{1F4CE} File: $filePath',
                timestamp: DateTime.now(),
              ));
            }
          }
        });
      } else if (response.isError) {
        setState(() {
          _messages.add(ChatMessage(
            role: MessageRole.error,
            content: response.error?.message ?? 'Unknown error',
            timestamp: DateTime.now(),
          ));
        });
      } else {
        // Unexpected response format
        debugPrint('Unexpected response: $response');
        setState(() {
          _messages.add(ChatMessage(
            role: MessageRole.error,
            content: 'Unexpected response from agent',
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('Error in _sendMessage: $e');
      debugPrint('Stack trace: $stackTrace');
      await AnalyticsService.instance.queryFailed(error: e.toString());
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: MessageRole.error,
          content: e.toString(),
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _attachedFiles = [];
          _externalFiles = [];
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleSelfImprove(int messageIndex) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing conversation...';
    });

    try {
      // Build conversation up to the selected message
      final conversationMessages = <Map<String, String>>[];
      for (var i = 0; i <= messageIndex && i < _messages.length; i++) {
        final msg = _messages[i];
        if (msg.role == MessageRole.user || msg.role == MessageRole.assistant) {
          conversationMessages.add({
            'role': msg.role == MessageRole.user ? 'user' : 'assistant',
            'content': msg.content,
          });
        }
      }

      if (conversationMessages.isEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            role: MessageRole.system,
            content: 'No conversation to analyze.',
            timestamp: DateTime.now(),
          ));
        });
        return;
      }

      // Get current system prompt
      final currentPrompt = await StorageService.instance.getSystemPrompt();
      final promptToImprove = currentPrompt ?? defaultSystemPrompt;

      final response = await PythonBridge.instance.selfImprove(
        conversationMessages: conversationMessages,
        currentSystemPrompt: promptToImprove,
      );

      if (!mounted) return;

      if (response.isSuccess && response.result != null) {
        final improvedPrompt = response.result!['improved_prompt'] as String?;
        if (improvedPrompt != null && improvedPrompt.isNotEmpty) {
          await StorageService.instance.setSystemPrompt(improvedPrompt);
          setState(() {
            _messages.add(ChatMessage(
              role: MessageRole.system,
              content: 'System prompt improved and saved. It will be used for future queries.',
              timestamp: DateTime.now(),
            ));
          });
        } else {
          setState(() {
            _messages.add(ChatMessage(
              role: MessageRole.system,
              content: 'Self-improve returned no changes.',
              timestamp: DateTime.now(),
            ));
          });
        }
      } else {
        final errorMsg = response.error?.message ?? 'Unknown error';
        setState(() {
          _messages.add(ChatMessage(
            role: MessageRole.error,
            content: 'Self-improve failed: $errorMsg',
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: MessageRole.error,
          content: 'Self-improve error: $e',
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openMenu() async {
    final wasAwaitingApiKey = _awaitingApiKey;
    await Navigator.pushNamed(context, '/settings');

    // Reload self-improve setting (may have changed in Settings)
    _loadSelfImproveSetting();

    // Check if API key was saved via Settings while we were showing the welcome message
    if (wasAwaitingApiKey && mounted) {
      final hasKey = await StorageService.instance.hasApiKey();
      if (hasKey) {
        final apiKey = await StorageService.instance.getApiKey();
        if (apiKey != null) {
          setState(() {
            _awaitingApiKey = false;
            _hasApiKey = true;
            _messages.add(ChatMessage(
              role: MessageRole.system,
              content: 'API key saved! You can now start chatting with NavixMind.',
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();

          // Send the API key to Python bridge
          await PythonBridge.instance.setApiKey(apiKey);
        }
      }
    }
  }

  void _connectGoogle() {
    // Navigate to settings to connect Google account
    Navigator.pushNamed(context, '/settings', arguments: {'section': 'google'});
  }

  void _handleQuickAction(String action) {
    _inputController.text = action;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: action.length),
    );

    // Detect active mode from action
    if (action.startsWith('/calendar')) {
      setState(() => _activeMode = 'Calendar');
    } else if (action.startsWith('/email')) {
      setState(() => _activeMode = 'Email');
    } else if (action.startsWith('/crop') || action.startsWith('/extract')) {
      setState(() => _activeMode = 'Media');
    } else if (action.startsWith('/ocr')) {
      setState(() => _activeMode = 'OCR');
    }

    // Hide quick actions after selection
    setState(() => _showQuickActions = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPythonReady = PythonBridge.instance.status == PythonStatus.ready;

    return Scaffold(
      backgroundColor: NavixTheme.background,
      appBar: AppBar(
        backgroundColor: NavixTheme.background,
        title: const Text('NavixMind'),
        leading: IconButton(
          icon: Text(
            NavixTheme.iconMenu,
            style: TextStyle(
              fontSize: 24,
              color: NavixTheme.textPrimary,
            ),
          ),
          onPressed: _openMenu,
          tooltip: 'Menu',
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: BrailleSpinner(size: 20),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status banner
            if (_statusMessage != null || !isPythonReady)
              StatusBanner(
                message: _statusMessage ?? 'Connecting...',
                isError: PythonBridge.instance.status == PythonStatus.error,
              ),

            // Smart context bar
            SmartContextBar(
              isGoogleConnected: _isGoogleConnected,
              isOffline: !ConnectivityService.instance.isConnected,
              activeMode: _activeMode,
              attachedFileCount: _attachedFiles.length,
              onConnectGoogle: _connectGoogle,
              onClearMode: () => setState(() => _activeMode = null),
            ),

            // Message list
            Expanded(
              child: MessageList(
                messages: _messages,
                scrollController: _scrollController,
                selfImproveEnabled: _selfImproveEnabled,
                isProcessing: _isProcessing,
                onSelfImprove: _handleSelfImprove,
              ),
            ),

            // Quick action pills (show when no messages and idle)
            if (_messages.isEmpty && _showQuickActions && !_isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: QuickActionPills(
                  onAction: _handleQuickAction,
                ),
              ),

            // Input bar
            InputBar(
              controller: _inputController,
              onSend: _sendMessage,
              enabled: (isPythonReady || _awaitingApiKey) && !_isProcessing,
              isProcessing: _isProcessing,
              externalFiles: _externalFiles,
              onFilesSelected: (files) {
                setState(() {
                  _attachedFiles = files;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Chat message model
class ChatMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<String>? attachments;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachments,
  });
}

enum MessageRole {
  user,
  assistant,
  system,
  error,
}
