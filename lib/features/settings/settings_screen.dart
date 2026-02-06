import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme.dart';
import '../../core/constants/defaults.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/database/database.dart';
import '../../core/database/collections/api_usage.dart';
import '../legal/terms_of_service.dart';
import '../legal/privacy_policy.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _hasApiKey = false;
  bool _isGoogleConnected = false;
  int _todayTokens = 0;
  int _monthTokens = 0;
  int _dailyTokenLimit = 100000;
  int _monthlyTokenLimit = 1000000;
  bool _limitEnabled = true;
  String _preferredModel = 'auto';
  int _toolTimeout = 30;
  int _maxIterations = 50;
  int _maxToolCalls = 50;
  int _maxTokens = 16384;
  bool _hasCustomPrompt = false;
  bool _selfImproveEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    AnalyticsService.instance.settingsOpened();
  }

  Future<void> _loadSettings() async {
    final hasKey = await StorageService.instance.hasApiKey();
    final isConnected = AuthService.instance.isSignedIn;
    final usageRepo = ApiUsageRepository(NavixDatabase.instance);
    final dailyTokens = await usageRepo.getTodayTokens();
    final monthlyTokens = await usageRepo.getMonthTokens();
    final dailyLimit = await StorageService.instance.getDailyTokenLimit();
    final monthlyLimit = await StorageService.instance.getMonthlyTokenLimit();
    final limitEnabled = await StorageService.instance.isCostLimitEnabled();
    final preferredModel = await StorageService.instance.getPreferredModel();
    final toolTimeout = await StorageService.instance.getToolTimeout();
    final maxIterations = await StorageService.instance.getMaxIterations();
    final maxToolCalls = await StorageService.instance.getMaxToolCalls();
    final maxTokens = await StorageService.instance.getMaxTokens();
    final customPrompt = await StorageService.instance.getSystemPrompt();
    final selfImproveEnabled = await StorageService.instance.isSelfImproveEnabled();

    setState(() {
      _isLoading = false;
      _hasApiKey = hasKey;
      _isGoogleConnected = isConnected;
      _todayTokens = dailyTokens['total'] ?? 0;
      _monthTokens = monthlyTokens['total'] ?? 0;
      _dailyTokenLimit = dailyLimit;
      _monthlyTokenLimit = monthlyLimit;
      _limitEnabled = limitEnabled;
      _preferredModel = preferredModel;
      _toolTimeout = toolTimeout;
      _maxIterations = maxIterations;
      _maxToolCalls = maxToolCalls;
      _maxTokens = maxTokens;
      _hasCustomPrompt = customPrompt != null;
      _selfImproveEnabled = selfImproveEnabled;
    });
  }

  Future<void> _setApiKey() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claude API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'sk-ant-... (leave empty to remove)',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (result.isEmpty) {
        await StorageService.instance.deleteApiKey();
        setState(() {
          _hasApiKey = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key removed')),
          );
        }
      } else {
        await StorageService.instance.setApiKey(result);
        setState(() {
          _hasApiKey = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key saved')),
          );
        }
      }
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final account = await AuthService.instance.signIn();
      setState(() {
        _isGoogleConnected = AuthService.instance.isSignedIn;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(account != null
                ? 'Google account connected!'
                : 'Sign-in cancelled'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    await AuthService.instance.disconnect();
    setState(() {
      _isGoogleConnected = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account disconnected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavixTheme.background,
      appBar: AppBar(
        backgroundColor: NavixTheme.background,
        title: const Text('Settings'),
        leading: IconButton(
          icon: Text(
            NavixTheme.iconClose,
            style: TextStyle(
              fontSize: 24,
              color: NavixTheme.textPrimary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Key Section
          _SectionHeader(title: 'API Configuration'),
          _SettingsTile(
            title: 'Claude API Key',
            subtitle: _isLoading
                ? 'Loading...'
                : (_hasApiKey ? 'Configured' : 'Not configured'),
            trailing: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (_hasApiKey
                    ? Text(
                        NavixTheme.iconCheck,
                        style: TextStyle(
                          fontSize: 20,
                          color: NavixTheme.success,
                        ),
                      )
                    : null),
            onTap: _isLoading ? null : _setApiKey,
          ),

          // Model Selection
          _ModelSelector(
            selectedModel: _preferredModel,
            onChanged: (model) async {
              await StorageService.instance.setPreferredModel(model);
              setState(() => _preferredModel = model);
            },
          ),

          // System Prompt
          _SettingsTile(
            title: 'System Prompt',
            subtitle: _hasCustomPrompt ? 'Custom' : 'Default',
            onTap: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const _SystemPromptEditor(),
                ),
              );
              // Refresh state after returning
              final prompt = await StorageService.instance.getSystemPrompt();
              setState(() => _hasCustomPrompt = prompt != null);
            },
          ),

          // Self Improve
          _SettingsTile(
            title: 'Self Improve',
            subtitle: 'Show button to auto-improve system prompt from conversation',
            trailing: Switch(
              value: _selfImproveEnabled,
              onChanged: (value) async {
                await StorageService.instance.setSelfImproveEnabled(value);
                setState(() => _selfImproveEnabled = value);
              },
              activeColor: NavixTheme.primary,
            ),
          ),

          // Tool Timeout
          _SettingsTile(
            title: 'Tool Timeout',
            subtitle: '${_toolTimeout}s — max wait for native tools (OCR, etc.)',
            trailing: DropdownButton<int>(
              value: _toolTimeout,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15s')),
                DropdownMenuItem(value: 30, child: Text('30s')),
                DropdownMenuItem(value: 60, child: Text('60s')),
                DropdownMenuItem(value: 120, child: Text('120s')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  await StorageService.instance.setToolTimeout(value);
                  setState(() => _toolTimeout = value);
                }
              },
            ),
          ),

          // Agent Limits
          _SettingsTile(
            title: 'Max Steps per Query',
            subtitle: '$_maxIterations — reasoning steps before stopping',
            trailing: DropdownButton<int>(
              value: _maxIterations,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 25, child: Text('25')),
                DropdownMenuItem(value: 50, child: Text('50')),
                DropdownMenuItem(value: 100, child: Text('100')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  await StorageService.instance.setMaxIterations(value);
                  setState(() => _maxIterations = value);
                }
              },
            ),
          ),
          _SettingsTile(
            title: 'Max Tool Calls per Query',
            subtitle: '$_maxToolCalls — tool executions before stopping',
            trailing: DropdownButton<int>(
              value: _maxToolCalls,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15')),
                DropdownMenuItem(value: 25, child: Text('25')),
                DropdownMenuItem(value: 50, child: Text('50')),
                DropdownMenuItem(value: 100, child: Text('100')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  await StorageService.instance.setMaxToolCalls(value);
                  setState(() => _maxToolCalls = value);
                }
              },
            ),
          ),
          _SettingsTile(
            title: 'Max Response Tokens',
            subtitle: '$_maxTokens — per API call (higher = longer responses)',
            trailing: DropdownButton<int>(
              value: _maxTokens,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 4096, child: Text('4K')),
                DropdownMenuItem(value: 8192, child: Text('8K')),
                DropdownMenuItem(value: 16384, child: Text('16K')),
                DropdownMenuItem(value: 32768, child: Text('32K')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  await StorageService.instance.setMaxTokens(value);
                  setState(() => _maxTokens = value);
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // Google Account Section
          _SectionHeader(title: 'Connected Accounts'),
          _SettingsTile(
            title: 'Google Account',
            subtitle: _isGoogleConnected
                ? AuthService.instance.currentUser?.email ?? 'Connected'
                : 'Not connected',
            trailing: _isGoogleConnected
                ? TextButton(
                    onPressed: _disconnectGoogle,
                    child: const Text('Disconnect'),
                  )
                : ElevatedButton(
                    onPressed: _connectGoogle,
                    child: const Text('Connect'),
                  ),
          ),

          const SizedBox(height: 24),

          // Usage Section
          _SectionHeader(title: 'Usage & Limits'),

          // Token limits toggle
          _SettingsTile(
            title: 'Enable Token Limits',
            subtitle: 'Pause agent when limits are reached',
            trailing: Switch(
              value: _limitEnabled,
              onChanged: (value) async {
                await StorageService.instance.setCostLimitEnabled(value);
                setState(() => _limitEnabled = value);
              },
              activeColor: NavixTheme.primary,
            ),
          ),

          // Today's usage with progress bar
          _TokenUsageCard(
            title: 'Today',
            usedTokens: _todayTokens,
            tokenLimit: _dailyTokenLimit,
            enabled: _limitEnabled,
            onEditLimit: _setDailyTokenLimit,
          ),

          // Month's usage with progress bar
          _TokenUsageCard(
            title: 'This Month',
            usedTokens: _monthTokens,
            tokenLimit: _monthlyTokenLimit,
            enabled: _limitEnabled,
            onEditLimit: _setMonthlyTokenLimit,
          ),

          const SizedBox(height: 8),

          // Export usage button
          _SettingsTile(
            title: 'Export Usage Data',
            subtitle: 'Download usage history as CSV',
            trailing: const Icon(Icons.download, size: 20),
            onTap: _exportUsageData,
          ),

          const SizedBox(height: 24),

          // Legal Section
          _SectionHeader(title: 'Legal'),
          _SettingsTile(
            title: 'Terms of Service',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsOfServiceScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // About Section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            title: 'Version',
            subtitle: '1.0.0',
          ),
          _SettingsTile(
            title: 'Licenses',
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'NavixMind',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setDailyTokenLimit() async {
    final result = await _showTokenLimitDialog('Daily Token Limit', _dailyTokenLimit);
    if (result != null) {
      await StorageService.instance.setDailyTokenLimit(result);
      setState(() => _dailyTokenLimit = result);
    }
  }

  Future<void> _setMonthlyTokenLimit() async {
    final result = await _showTokenLimitDialog('Monthly Token Limit', _monthlyTokenLimit);
    if (result != null) {
      await StorageService.instance.setMonthlyTokenLimit(result);
      setState(() => _monthlyTokenLimit = result);
    }
  }

  Future<int?> _showTokenLimitDialog(String title, int currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Token limit',
                hintText: 'e.g. 100000',
                suffixText: 'tokens',
                helperText: 'Current: ${_formatTokens(currentValue)}',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [50000, 100000, 500000, 1000000, 5000000].map((preset) {
                return ActionChip(
                  label: Text(_formatTokens(preset)),
                  onPressed: () {
                    controller.text = preset.toString();
                    controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.text.length,
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), ''));
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M tokens';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(0)}K tokens';
    }
    return '$tokens tokens';
  }

  Future<void> _exportUsageData() async {
    try {
      final usageRepo = ApiUsageRepository(NavixDatabase.instance);
      final csvData = await usageRepo.exportToCsv();

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/navixmind_usage_$timestamp.csv';

      final file = File(filePath);
      await file.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $filePath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: NavixTheme.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  final String selectedModel;
  final ValueChanged<String> onChanged;

  const _ModelSelector({
    required this.selectedModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Model'),
                  Text(
                    _getModelDescription(selectedModel),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NavixTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: selectedModel,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: 'auto',
                  child: Text('Auto'),
                ),
                DropdownMenuItem(
                  value: 'opus',
                  child: Text('Opus'),
                ),
                DropdownMenuItem(
                  value: 'sonnet',
                  child: Text('Sonnet'),
                ),
                DropdownMenuItem(
                  value: 'haiku',
                  child: Text('Haiku'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getModelDescription(String model) {
    switch (model) {
      case 'auto':
        return 'Opus by default, Haiku when budget is low';
      case 'opus':
        return 'Best quality, highest cost';
      case 'sonnet':
        return 'Good quality, moderate cost';
      case 'haiku':
        return 'Faster, lower cost';
      default:
        return '';
    }
  }
}

class _TokenUsageCard extends StatelessWidget {
  final String title;
  final int usedTokens;
  final int tokenLimit;
  final bool enabled;
  final VoidCallback onEditLimit;

  const _TokenUsageCard({
    required this.title,
    required this.usedTokens,
    required this.tokenLimit,
    required this.enabled,
    required this.onEditLimit,
  });

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(2)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return '$tokens';
  }

  @override
  Widget build(BuildContext context) {
    final progress = tokenLimit > 0 ? (usedTokens / tokenLimit).clamp(0.0, 1.0) : 0.0;
    final isWarning = progress > 0.8;
    final isOver = progress >= 1.0;

    final progressColor = isOver
        ? NavixTheme.error
        : isWarning
            ? NavixTheme.warning
            : NavixTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                GestureDetector(
                  onTap: onEditLimit,
                  child: Row(
                    children: [
                      Text(
                        _formatTokens(usedTokens),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: progressColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        ' / ${_formatTokens(tokenLimit)} tokens',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: NavixTheme.textTertiary,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '✎',
                        style: TextStyle(
                          fontSize: 12,
                          color: NavixTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: enabled ? progress : 0,
                backgroundColor: NavixTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  enabled ? progressColor : NavixTheme.textTertiary,
                ),
                minHeight: 8,
              ),
            ),
            if (isWarning && enabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    NavixTheme.iconWarning,
                    style: TextStyle(
                      fontSize: 12,
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOver
                        ? 'Limit reached. Agent paused.'
                        : 'Approaching limit (${(progress * 100).toInt()}%)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: progressColor,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen editor for the system prompt.
class _SystemPromptEditor extends StatefulWidget {
  const _SystemPromptEditor();

  @override
  State<_SystemPromptEditor> createState() => _SystemPromptEditorState();
}

class _SystemPromptEditorState extends State<_SystemPromptEditor> {
  late TextEditingController _controller;
  bool _isLoading = true;
  bool _isDirty = false;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadPrompt();
  }

  Future<void> _loadPrompt() async {
    final custom = await StorageService.instance.getSystemPrompt();
    _controller.text = custom ?? defaultSystemPrompt;
    setState(() {
      _isLoading = false;
      _isCustom = custom != null;
      _isDirty = false;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || text == defaultSystemPrompt) {
      await StorageService.instance.resetSystemPrompt();
    } else {
      await StorageService.instance.setSystemPrompt(text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System prompt saved')),
      );
      Navigator.pop(context, true);
    }
  }

  void _resetToDefault() {
    _controller.text = defaultSystemPrompt;
    setState(() {
      _isDirty = true;
      _isCustom = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavixTheme.background,
      appBar: AppBar(
        backgroundColor: NavixTheme.background,
        title: const Text('System Prompt'),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: _isDirty ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCustom ? 'Custom prompt' : 'Default prompt',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_controller.text.length} characters',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textTertiary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: (_) {
                        if (!_isDirty) {
                          setState(() => _isDirty = true);
                        }
                        // Update char count
                        setState(() {
                          _isCustom = _controller.text.trim() != defaultSystemPrompt;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
