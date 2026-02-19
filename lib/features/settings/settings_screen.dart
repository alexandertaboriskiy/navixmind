import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme.dart';
import '../../core/bridge/bridge.dart';
import '../../core/constants/defaults.dart';
import '../../core/models/model_registry.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_llm_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/database/database.dart';
import '../../core/database/collections/api_usage.dart';
import '../legal/terms_of_service.dart';
import '../legal/privacy_policy.dart';

bool _extraLicensesRegistered = false;

void _registerExtraLicenses() {
  if (_extraLicensesRegistered) return;
  _extraLicensesRegistered = true;

  LicenseRegistry.addLicense(() async* {
    const entries = <(String package, String license, String text)>[
      // Python packages (runtime, via Chaquopy)
      ('requests', 'Apache-2.0',
          'Copyright 2019 Kenneth Reitz\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      ('beautifulsoup4', 'MIT',
          'Copyright (c) Leonard Richardson\n\n'
              'Permission is hereby granted, free of charge, to any person obtaining a copy '
              'of this software and associated documentation files (the "Software"), to deal '
              'in the Software without restriction, including without limitation the rights '
              'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
              'copies of the Software, and to permit persons to whom the Software is '
              'furnished to do so, subject to the following conditions:\n\n'
              'The above copyright notice and this permission notice shall be included in all '
              'copies or substantial portions of the Software.\n\n'
              'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.'),
      ('lxml', 'BSD-3-Clause',
          'Copyright (c) lxml project\n\n'
              'Redistribution and use in source and binary forms, with or without '
              'modification, are permitted provided that the following conditions are met:\n\n'
              '1. Redistributions of source code must retain the above copyright notice.\n'
              '2. Redistributions in binary form must reproduce the above copyright notice.\n'
              '3. Neither the name of the project nor the names of its contributors may be '
              'used to endorse or promote products derived from this software without '
              'specific prior written permission.\n\n'
              'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS".'),
      ('pypdf', 'BSD-3-Clause',
          'Copyright (c) pypdf contributors\n\n'
              'Redistribution and use in source and binary forms, with or without '
              'modification, are permitted provided that the following conditions are met:\n\n'
              '1. Redistributions of source code must retain the above copyright notice.\n'
              '2. Redistributions in binary form must reproduce the above copyright notice.\n'
              '3. Neither the name of the project nor the names of its contributors may be '
              'used to endorse or promote products derived from this software without '
              'specific prior written permission.\n\n'
              'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS".'),
      ('reportlab', 'BSD-3-Clause',
          'Copyright (c) ReportLab Europe Ltd. 2000-2024\n\n'
              'Redistribution and use in source and binary forms, with or without '
              'modification, are permitted provided that the following conditions are met:\n\n'
              '1. Redistributions of source code must retain the above copyright notice.\n'
              '2. Redistributions in binary form must reproduce the above copyright notice.\n'
              '3. Neither the name of the project nor the names of its contributors may be '
              'used to endorse or promote products derived from this software without '
              'specific prior written permission.\n\n'
              'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS".'),
      ('python-docx', 'MIT',
          'Copyright (c) Steve Canny\n\n'
              'Permission is hereby granted, free of charge, to any person obtaining a copy '
              'of this software and associated documentation files (the "Software"), to deal '
              'in the Software without restriction, including without limitation the rights '
              'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
              'copies of the Software, and to permit persons to whom the Software is '
              'furnished to do so, subject to the following conditions:\n\n'
              'The above copyright notice and this permission notice shall be included in all '
              'copies or substantial portions of the Software.\n\n'
              'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.'),
      ('Pillow', 'HPND',
          'The Python Imaging Library (PIL) is\n\n'
              '    Copyright (c) 1997-2011 by Secret Labs AB\n'
              '    Copyright (c) 1995-2011 by Fredrik Lundh and contributors\n\n'
              'Pillow is the friendly PIL fork. It is\n\n'
              '    Copyright (c) 2010-2024 by Jeffrey A. Clark and contributors\n\n'
              'Like PIL, Pillow is licensed under the open source HPND License.'),
      ('yt-dlp', 'Unlicense',
          'This is free and unencumbered software released into the public domain.\n\n'
              'Anyone is free to copy, modify, publish, use, compile, sell, or distribute '
              'this software, either in source code form or as a compiled binary, for any '
              'purpose, commercial or non-commercial, and by any means.'),
      ('numpy', 'BSD-3-Clause',
          'Copyright (c) 2005-2024 NumPy Developers\n\n'
              'Redistribution and use in source and binary forms, with or without '
              'modification, are permitted provided that the following conditions are met:\n\n'
              '1. Redistributions of source code must retain the above copyright notice.\n'
              '2. Redistributions in binary form must reproduce the above copyright notice.\n'
              '3. Neither the name of the project nor the names of its contributors may be '
              'used to endorse or promote products derived from this software without '
              'specific prior written permission.\n\n'
              'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS".'),
      ('pandas', 'BSD-3-Clause',
          'Copyright (c) 2008-2024 AQR Capital Management, LLC, Lambda Foundry, Inc. '
              'and PyData Development Team\n\n'
              'Redistribution and use in source and binary forms, with or without '
              'modification, are permitted provided that the following conditions are met:\n\n'
              '1. Redistributions of source code must retain the above copyright notice.\n'
              '2. Redistributions in binary form must reproduce the above copyright notice.\n'
              '3. Neither the name of the project nor the names of its contributors may be '
              'used to endorse or promote products derived from this software without '
              'specific prior written permission.\n\n'
              'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS".'),
      ('matplotlib', 'PSF-based',
          'Copyright (c) 2012-2024 Matplotlib Development Team\n\n'
              'Matplotlib is licensed under the terms of a license based on the '
              'Python Software Foundation (PSF) license.\n\n'
              '1. This LICENSE AGREEMENT is between the Matplotlib Development Team '
              'and the Individual or Organization ("Licensee") accessing and otherwise '
              'using matplotlib software in source or binary form and its associated '
              'documentation.\n\n'
              '2. Subject to the terms and conditions of this License Agreement, the '
              'Matplotlib Development Team hereby grants Licensee a nonexclusive, '
              'royalty-free, world-wide license to reproduce, analyze, test, perform '
              'and/or display publicly, prepare derivative works, distribute, and '
              'otherwise use matplotlib alone or in any derivative version.\n\n'
              'https://matplotlib.org/stable/users/project/license.html'),
      ('python-dateutil', 'Apache-2.0 / BSD',
          'Copyright (c) Gustavo Niemeyer, Paul Ganssle\n\n'
              'Licensed under the Apache License, Version 2.0, or the BSD 3-Clause License, '
              'at your option.'),
      ('urllib3', 'MIT',
          'Copyright (c) Andrey Petrov and contributors\n\n'
              'Permission is hereby granted, free of charge, to any person obtaining a copy '
              'of this software and associated documentation files (the "Software"), to deal '
              'in the Software without restriction, including without limitation the rights '
              'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
              'copies of the Software, and to permit persons to whom the Software is '
              'furnished to do so, subject to the following conditions:\n\n'
              'The above copyright notice and this permission notice shall be included in all '
              'copies or substantial portions of the Software.\n\n'
              'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.'),
      // Native / Android libraries
      ('FFmpeg (via ffmpeg_kit)', 'LGPL-3.0',
          'Copyright (c) FFmpeg contributors\n\n'
              'FFmpeg is free software; you can redistribute it and/or modify it under the '
              'terms of the GNU Lesser General Public License as published by the Free '
              'Software Foundation; either version 3 of the License, or (at your option) '
              'any later version.\n\n'
              'FFmpeg is distributed in the hope that it will be useful, but WITHOUT ANY '
              'WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR '
              'A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.'),
      ('Chaquopy', 'MIT',
          'Copyright (c) Chaquo Ltd\n\n'
              'Permission is hereby granted, free of charge, to any person obtaining a copy '
              'of this software and associated documentation files (the "Software"), to deal '
              'in the Software without restriction, including without limitation the rights '
              'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
              'copies of the Software, and to permit persons to whom the Software is '
              'furnished to do so, subject to the following conditions:\n\n'
              'The above copyright notice and this permission notice shall be included in all '
              'copies or substantial portions of the Software.\n\n'
              'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.'),
      ('ML Kit Text Recognition', 'Google APIs Terms of Service',
          'Copyright (c) Google LLC\n\n'
              'Use of ML Kit is subject to the Google APIs Terms of Service and the '
              'Google ML Kit Terms of Service.\n\n'
              'https://developers.google.com/ml-kit/terms'),
      ('ML Kit Face Detection', 'Google APIs Terms of Service',
          'Copyright (c) Google LLC\n\n'
              'Use of ML Kit is subject to the Google APIs Terms of Service and the '
              'Google ML Kit Terms of Service.\n\n'
              'https://developers.google.com/ml-kit/terms'),
      ('Firebase', 'Apache-2.0',
          'Copyright (c) Google LLC\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      ('Kotlin Coroutines', 'Apache-2.0',
          'Copyright (c) JetBrains s.r.o. and Kotlin Programming Language contributors\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      // On-device LLM inference
      ('MLC LLM', 'Apache-2.0',
          'Copyright (c) 2023-2025 MLC LLM Contributors\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      ('Qwen2.5-Coder 0.5B / 1.5B', 'Apache-2.0',
          'Copyright (c) 2024 Alibaba Cloud\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      ('Ministral-3-3B-Instruct', 'Apache-2.0',
          'Copyright (c) 2024-2025 Mistral AI\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      ('Qwen3 4B', 'Apache-2.0',
          'Copyright (c) 2025 Alibaba Cloud\n\n'
              'Licensed under the Apache License, Version 2.0 (the "License"); '
              'you may not use this file except in compliance with the License. '
              'You may obtain a copy of the License at\n\n'
              '    http://www.apache.org/licenses/LICENSE-2.0\n\n'
              'Unless required by applicable law or agreed to in writing, software '
              'distributed under the License is distributed on an "AS IS" BASIS, '
              'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'),
      ('Qwen2.5-Coder 3B', 'Qwen Research License',
          'Copyright (c) 2024 Alibaba Cloud. All Rights Reserved.\n\n'
              'Qwen2.5-Coder-3B-Instruct is licensed under the Qwen Research License Agreement. '
              'This license permits non-commercial use only. Commercial use requires a separate '
              'license from Alibaba Cloud.\n\n'
              'https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct/blob/main/LICENSE'),
    ];

    for (final (package, license, text) in entries) {
      yield LicenseEntryWithLineBreaks(
        [package],
        '$license\n\n$text',
      );
    }
  });
}

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
  bool _hasMentioraKey = false;
  Map<String, OfflineModelState> _offlineModelStates = {};
  StreamSubscription<Map<String, OfflineModelState>>? _offlineStateSubscription;
  ModelLoadState _modelLoadState = ModelLoadState.unloaded;
  StreamSubscription<ModelLoadState>? _loadStateSubscription;
  int _gpuMemoryMB = -1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initOfflineModelListener();
    _queryGpuMemory();
    AnalyticsService.instance.settingsOpened();
  }

  void _initOfflineModelListener() {
    _offlineModelStates = LocalLLMService.instance.modelStates;
    _modelLoadState = LocalLLMService.instance.loadState;
    _offlineStateSubscription =
        LocalLLMService.instance.stateStream.listen((states) {
      if (mounted) {
        setState(() => _offlineModelStates = states);
      }
    });
    _loadStateSubscription =
        LocalLLMService.instance.loadStateStream.listen((state) {
      if (mounted) {
        setState(() => _modelLoadState = state);
      }
    });
  }

  Future<void> _queryGpuMemory() async {
    final mb = await LocalLLMService.instance.getGpuMemoryMB();
    if (mounted && mb > 0) {
      setState(() => _gpuMemoryMB = mb);
    }
  }

  @override
  void dispose() {
    _offlineStateSubscription?.cancel();
    _loadStateSubscription?.cancel();
    super.dispose();
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
    final hasMentioraKey = await StorageService.instance.hasMentioraApiKey();

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
      _hasMentioraKey = hasMentioraKey;
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

  Future<void> _setMentioraKey() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mentiora Tracing Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter key (leave empty to remove)',
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
        await StorageService.instance.deleteMentioraApiKey();
        setState(() {
          _hasMentioraKey = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mentiora key removed')),
          );
        }
      } else {
        await StorageService.instance.setMentioraApiKey(result);
        // Send to Python immediately so tracing activates without restart
        try {
          await PythonBridge.instance.setMentioraApiKey(result);
        } catch (e) {
          debugPrint('Failed to send Mentiora key to Python: $e');
        }
        setState(() {
          _hasMentioraKey = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mentiora key saved')),
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
          _SettingsTile(
            title: 'Mentiora Tracing Key',
            subtitle: _isLoading
                ? 'Loading...'
                : (_hasMentioraKey ? 'Configured' : 'Optional'),
            trailing: _isLoading
                ? null
                : (_hasMentioraKey
                    ? Text(
                        NavixTheme.iconCheck,
                        style: TextStyle(
                          fontSize: 20,
                          color: NavixTheme.success,
                        ),
                      )
                    : null),
            onTap: _isLoading ? null : _setMentioraKey,
          ),

          // Model Selection
          _ModelSelector(
            selectedModel: _isLoading ? '' : _preferredModel,
            offlineModelStates: _offlineModelStates,
            loadedModelId: LocalLLMService.instance.loadedModelId,
            modelLoadState: _modelLoadState,
            gpuMemoryMB: _gpuMemoryMB,
            onChanged: (model) async {
              await StorageService.instance.setPreferredModel(model);
              setState(() => _preferredModel = model);
            },
            onDownloadModel: (modelId) async {
              await LocalLLMService.instance.downloadModel(modelId);
            },
            onCancelDownload: (modelId) async {
              await LocalLLMService.instance.cancelDownload(modelId);
            },
            onUnloadModel: () async {
              await LocalLLMService.instance.unloadModel();
            },
            onDeleteModel: (modelId) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Model'),
                  content: Text(
                    'Delete ${ModelRegistry.getById(modelId)?.displayName ?? modelId}? '
                    'You can re-download it later.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Delete',
                        style: TextStyle(color: NavixTheme.error),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await LocalLLMService.instance.deleteModel(modelId);
                // If the deleted model was selected, switch back to auto
                if (_preferredModel == modelId) {
                  await StorageService.instance.setPreferredModel('auto');
                  setState(() => _preferredModel = 'auto');
                }
              }
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
              _registerExtraLicenses();
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
  final Map<String, OfflineModelState> offlineModelStates;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onDownloadModel;
  final ValueChanged<String> onDeleteModel;
  final ValueChanged<String> onCancelDownload;
  final String? loadedModelId;
  final ModelLoadState modelLoadState;
  final VoidCallback? onUnloadModel;
  final int gpuMemoryMB;

  const _ModelSelector({
    required this.selectedModel,
    required this.offlineModelStates,
    required this.onChanged,
    required this.onDownloadModel,
    required this.onDeleteModel,
    required this.onCancelDownload,
    this.loadedModelId,
    this.modelLoadState = ModelLoadState.unloaded,
    this.onUnloadModel,
    this.gpuMemoryMB = -1,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cloud Models section
            Text(
              'Cloud Models (API Key Required)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: NavixTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            ...ModelRegistry.cloudModels.map(
              (model) => _buildCloudModelTile(context, model),
            ),

            const Divider(height: 24),

            // Offline Models section
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Offline Models (On-Device)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: NavixTheme.textSecondary,
                        ),
                  ),
                ),
                if (gpuMemoryMB > 0)
                  Text(
                    'GPU: ${(gpuMemoryMB / 1024).toStringAsFixed(1)} GB',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textTertiary,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...ModelRegistry.offlineModels.map(
              (model) => _buildOfflineModelTile(context, model),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudModelTile(BuildContext context, ModelInfo model) {
    final isSelected = selectedModel == model.id;
    return InkWell(
      onTap: () => onChanged(model.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Radio<String>(
              value: model.id,
              groupValue: selectedModel,
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              activeColor: NavixTheme.primary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.displayName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isSelected
                              ? NavixTheme.textPrimary
                              : NavixTheme.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                  Text(
                    model.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineModelTile(BuildContext context, ModelInfo model) {
    final state = offlineModelStates[model.id];
    final downloadState = state?.downloadState ?? ModelDownloadState.notDownloaded;
    final isDownloaded = downloadState == ModelDownloadState.downloaded;
    final isSelected = selectedModel == model.id;
    final estimatedVramMB = (model.estimatedSizeBytes ?? 0) ~/ (1024 * 1024);
    final tooLargeForGpu = gpuMemoryMB > 0 && estimatedVramMB > gpuMemoryMB;

    return InkWell(
      onTap: () {
        if (isDownloaded) {
          onChanged(model.id);
        } else {
          _showDownloadFirstDialog(context, model);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Radio<String>(
              value: model.id,
              groupValue: isDownloaded ? selectedModel : null,
              onChanged: isDownloaded
                  ? (value) {
                      if (value != null) onChanged(value);
                    }
                  : null,
              activeColor: NavixTheme.primary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        model.displayName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isSelected && isDownloaded
                                  ? NavixTheme.textPrimary
                                  : NavixTheme.textSecondary,
                              fontWeight: isSelected && isDownloaded
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '~${model.estimatedSizeFormatted}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: NavixTheme.textTertiary,
                            ),
                      ),
                      if (model.isResearchOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: NavixTheme.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Research only',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: NavixTheme.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    model.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textTertiary,
                        ),
                  ),
                  if (tooLargeForGpu)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'May exceed GPU memory (${estimatedVramMB} MB > ${gpuMemoryMB} MB)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: NavixTheme.error,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  _buildOfflineModelActions(context, model, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineModelActions(
    BuildContext context,
    ModelInfo model,
    OfflineModelState? state,
  ) {
    final downloadState =
        state?.downloadState ?? ModelDownloadState.notDownloaded;

    switch (downloadState) {
      case ModelDownloadState.notDownloaded:
        return SizedBox(
          height: 28,
          child: OutlinedButton.icon(
            onPressed: () => onDownloadModel(model.id),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
              side: BorderSide(color: NavixTheme.primary),
            ),
          ),
        );

      case ModelDownloadState.downloading:
        final progress = state?.downloadProgress ?? 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: NavixTheme.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(NavixTheme.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NavixTheme.textTertiary,
                      ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  child: TextButton(
                    onPressed: () => onCancelDownload(model.id),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 11),
                      foregroundColor: NavixTheme.error,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        );

      case ModelDownloadState.downloaded:
        final isLoaded = loadedModelId == model.id;
        final isLoading = isLoaded && modelLoadState == ModelLoadState.loading;
        return Row(
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NavixTheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NavixTheme.primary,
                    ),
              ),
            ] else if (isLoaded && modelLoadState == ModelLoadState.loaded) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: NavixTheme.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Loaded',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NavixTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: TextButton(
                  onPressed: onUnloadModel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 11),
                    foregroundColor: NavixTheme.textTertiary,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Unload'),
                ),
              ),
            ] else ...[
              Text(
                NavixTheme.iconCheck,
                style: TextStyle(
                  fontSize: 14,
                  color: NavixTheme.success,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                state?.diskUsageFormatted ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NavixTheme.success,
                    ),
              ),
            ],
            const SizedBox(width: 8),
            if (!isLoaded)
              SizedBox(
                height: 28,
                child: TextButton(
                  onPressed: () => onDeleteModel(model.id),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    foregroundColor: NavixTheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ),
          ],
        );

      case ModelDownloadState.error:
        return Row(
          children: [
            Text(
              NavixTheme.iconError,
              style: TextStyle(
                fontSize: 14,
                color: NavixTheme.error,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                state?.errorMessage ?? 'Download failed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NavixTheme.error,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: OutlinedButton(
                onPressed: () => onDownloadModel(model.id),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12),
                  side: BorderSide(color: NavixTheme.primary),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        );
    }
  }

  void _showDownloadFirstDialog(BuildContext context, ModelInfo model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Required'),
        content: Text(
          'Download ${model.displayName} (~${model.estimatedSizeFormatted}) '
          'to use it offline?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDownloadModel(model.id);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
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
