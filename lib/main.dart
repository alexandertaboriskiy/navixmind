import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/bridge/bridge.dart';
import 'core/database/database.dart';
import 'core/services/analytics_service.dart';
import 'core/services/crash_detector.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/cost_manager.dart';
import 'core/services/native_tool_executor.dart';
import 'core/services/auth_service.dart';
import 'core/services/offline_queue_manager.dart';
import 'core/services/share_receiver_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register share receiver channel early so Kotlin can deliver buffered files
  ShareReceiverService.instance.initialize();

  // Initialize Firebase (optional - may not be configured)
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase not configured: $e');
  }

  // Initialize analytics and crashlytics (user consents via legal acceptance dialog)
  if (firebaseInitialized) {
    await AnalyticsService.instance.initialize();
    await CrashDetector.initialize();
    await AnalyticsService.instance.appOpen();
  }

  // Set system UI style for Cyber-Clean aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0F0F12),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock to portrait mode for optimal mobile experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Phase 1: Show UI immediately (skeleton state)
  runApp(const NavixMindApp(initializing: true));

  // Phase 2: Parallel initialization of fast components
  final futures = <Future<dynamic>>[
    _initializeDatabase(),
    _getLogDirectory(),
  ];
  if (firebaseInitialized) {
    futures.add(CrashDetector.checkForPreviousCrash());
  }
  final results = await Future.wait(futures);

  final isar = results[0] as Isar;
  final logDir = results[1] as String;

  // Report previous crash if found
  if (firebaseInitialized && results.length > 2) {
    final previousCrash = results[2] as String?;
    if (previousCrash != null) {
      await CrashDetector.reportCrash(previousCrash);
    }
  }

  // Initialize services
  await ConnectivityService.instance.initialize();

  // Restore Google sign-in session (silent, no UI)
  await AuthService.instance.initialize();

  // Initialize cost manager for API usage tracking
  CostManager.instance.initialize(isar);

  // Initialize native tool executor (FFmpeg, OCR, etc.)
  NativeToolExecutor.instance.initialize();

  // Initialize offline queue manager
  await OfflineQueueManager.instance.initialize(isar);

  // Phase 3: Python init (runs async, doesn't block UI)
  PythonBridge.instance.initialize(logDir);

  // Update app with initialized state
  runApp(NavixMindApp(
    initializing: false,
    isar: isar,
  ));
}

Future<Isar> _initializeDatabase() async {
  return await NavixDatabase.initialize();
}

Future<String> _getLogDirectory() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}
