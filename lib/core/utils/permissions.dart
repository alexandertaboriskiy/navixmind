import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permission management with user-friendly rationale dialogs
class PermissionManager {
  /// Request camera permission with rationale
  static Future<bool> requestCamera(BuildContext context) async {
    return _requestWithRationale(
      context,
      permission: Permission.camera,
      title: 'Camera Access',
      rationale: 'Camera access lets you scan documents and take photos to add to your queries.',
    );
  }

  /// Request microphone permission with rationale
  static Future<bool> requestMicrophone(BuildContext context) async {
    return _requestWithRationale(
      context,
      permission: Permission.microphone,
      title: 'Microphone Access',
      rationale: 'Microphone access enables voice input and audio recording for transcription.',
    );
  }

  /// Request storage/media permission with rationale
  static Future<bool> requestStorage(BuildContext context) async {
    // On Android 13+, use granular media permissions
    if (await Permission.photos.isGranted || await Permission.videos.isGranted) {
      return true;
    }

    return _requestWithRationale(
      context,
      permission: Permission.photos,
      title: 'Media Access',
      rationale: 'Storage access lets you select and process files from your device.',
    );
  }

  /// Request notification permission with rationale
  static Future<bool> requestNotifications(BuildContext context) async {
    return _requestWithRationale(
      context,
      permission: Permission.notification,
      title: 'Notifications',
      rationale: 'Notifications alert you when long tasks (like video processing) complete.',
    );
  }

  static Future<bool> _requestWithRationale(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String rationale,
  }) async {
    // Check current status
    final status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // Show settings redirect dialog
      final shouldOpen = await _showSettingsDialog(context, title, rationale);
      if (shouldOpen) {
        await openAppSettings();
      }
      return false;
    }

    // Show rationale dialog first
    final shouldRequest = await _showRationaleDialog(context, title, rationale);
    if (!shouldRequest) {
      return false;
    }

    // Request permission
    final result = await permission.request();
    return result.isGranted;
  }

  static Future<bool> _showRationaleDialog(
    BuildContext context,
    String title,
    String rationale,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(rationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ?? false;
  }

  static Future<bool> _showSettingsDialog(
    BuildContext context,
    String title,
    String rationale,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rationale),
            const SizedBox(height: 16),
            const Text(
              'You previously denied this permission. '
              'Please enable it in Settings to use this feature.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    ) ?? false;
  }
}
