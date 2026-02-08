import 'dart:io';

/// File size limits in bytes (matching Python limits).
/// Generous because all processing is local (Python/FFmpeg on device),
/// files are never sent raw to LLM cloud APIs.
const Map<String, int> fileSizeLimits = {
  'pdf': 500 * 1024 * 1024, // 500MB
  'image': 500 * 1024 * 1024, // 500MB
  'video': 500 * 1024 * 1024, // 500MB
  'audio': 500 * 1024 * 1024, // 500MB
  'document': 500 * 1024 * 1024, // 500MB
  'default': 500 * 1024 * 1024, // 500MB
};

/// Exception thrown when file is too large
class FileTooLargeException implements Exception {
  final String message;
  final int fileSize;
  final int limit;

  FileTooLargeException({
    required this.message,
    required this.fileSize,
    required this.limit,
  });

  @override
  String toString() => message;
}

/// Validates files before processing
class FileValidator {
  /// Validate file size before sending to Python
  static Future<void> validate(File file, String type) async {
    final size = await file.length();
    final limit = fileSizeLimits[type] ?? fileSizeLimits['default']!;

    if (size > limit) {
      throw FileTooLargeException(
        message:
            'File is too large (${_formatSize(size)}). Maximum: ${_formatSize(limit)}',
        fileSize: size,
        limit: limit,
      );
    }
  }

  /// Detect file type from extension
  static String detectFileType(String? extension) {
    if (extension == null) return 'default';

    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
      case 'heif':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
      case 'ogg':
      case 'flac':
        return 'audio';
      case 'doc':
      case 'docx':
      case 'pptx':
      case 'ppt':
      case 'xlsx':
      case 'xls':
      case 'xlsm':
      case 'odt':
      case 'rtf':
      case 'txt':
        return 'document';
      default:
        return 'default';
    }
  }

  /// Get limit for a file type
  static int getLimitForType(String type) {
    return fileSizeLimits[type] ?? fileSizeLimits['default']!;
  }

  /// Format file size for display
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Check if a path is within allowed directories
  static bool isPathAllowed(String path) {
    // Resolve any ../ tricks
    final resolved = File(path).absolute.path;

    // Allowed roots (will be set at runtime based on app directories)
    // This is a simplified check; the actual implementation would
    // verify against actual app directory paths
    return !resolved.contains('..');
  }
}
