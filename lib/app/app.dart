import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import 'theme.dart';
import 'routes.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/legal/legal_acceptance_dialog.dart';

class NavixMindApp extends StatelessWidget {
  final bool initializing;
  final Isar? isar;

  const NavixMindApp({
    super.key,
    this.initializing = false,
    this.isar,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NavixMind',
      debugShowCheckedModeBanner: false,
      theme: NavixTheme.darkTheme,
      home: _LegalGate(initializing: initializing),
      onGenerateRoute: NavixMindRoutes.onGenerateRoute,
    );
  }
}

/// Wraps the main screen with a first-run legal acceptance check.
class _LegalGate extends StatefulWidget {
  final bool initializing;

  const _LegalGate({required this.initializing});

  @override
  State<_LegalGate> createState() => _LegalGateState();
}

class _LegalGateState extends State<_LegalGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // Schedule legal check after the first frame so context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLegal());
  }

  Future<void> _checkLegal() async {
    final accepted = await LegalAcceptanceDialog.checkAndShow(context);
    if (!accepted && mounted) {
      LegalAcceptanceDialog.handleDeclined(context);
      return;
    }
    if (mounted) {
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      // Show a minimal splash while the legal dialog is pending.
      return Scaffold(
        backgroundColor: NavixTheme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return ChatScreen(initializing: widget.initializing);
  }
}
