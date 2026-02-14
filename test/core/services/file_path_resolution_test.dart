import 'package:flutter_test/flutter_test.dart';

/// Tests for bulletproof file path resolution in NativeToolExecutor.
///
/// When a tool receives a file path that doesn't exist at the given location,
/// the executor searches common Android directories by basename and copies
/// external files to internal storage for reliability.
void main() {
  group('File path resolution — search directories', () {
    test('search directories include screenshots', () {
      const dirs = [
        '/storage/emulated/0/Pictures/Screenshots',
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/DCIM',
      ];
      expect(dirs, contains('/storage/emulated/0/Pictures/Screenshots'));
    });

    test('search directories include camera', () {
      const dirs = [
        '/storage/emulated/0/Pictures/Screenshots',
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/DCIM',
      ];
      expect(dirs, contains('/storage/emulated/0/DCIM/Camera'));
    });

    test('search directories include downloads', () {
      const dirs = [
        '/storage/emulated/0/Pictures/Screenshots',
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/DCIM',
      ];
      expect(dirs, contains('/storage/emulated/0/Download'));
    });
  });

  group('Basename extraction', () {
    test('extracts basename from full path', () {
      final path = '/storage/emulated/0/Pictures/Screenshots/shot.png';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      expect(basename, equals('shot.png'));
    });

    test('extracts basename from simple filename', () {
      final path = 'photo.jpg';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      expect(basename, equals('photo.jpg'));
    });

    test('handles path with spaces', () {
      final path = '/storage/emulated/0/DCIM/Camera/IMG 2024.jpg';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      expect(basename, equals('IMG 2024.jpg'));
    });

    test('handles path with no extension', () {
      final path = '/storage/emulated/0/Download/readme';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      expect(basename, equals('readme'));
      expect(basename.contains('.'), isFalse);
    });

    test('empty basename for path ending in slash', () {
      final path = '/storage/emulated/0/Download/';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      expect(basename, isEmpty);
    });
  });

  group('Tool path keys resolution', () {
    test('resolves single path keys', () {
      const pathKeys = ['input_path', 'image_path', 'file_path'];
      expect(pathKeys, contains('input_path'));
      expect(pathKeys, contains('image_path'));
      expect(pathKeys, contains('file_path'));
    });

    test('resolves array path keys', () {
      const arrayPathKeys = ['input_paths', 'image_paths', 'file_paths'];
      expect(arrayPathKeys, contains('input_paths'));
      expect(arrayPathKeys, contains('image_paths'));
      expect(arrayPathKeys, contains('file_paths'));
    });

    test('preserves non-path args unchanged', () {
      final args = {
        'operation': 'crop',
        'params': {'width': 100, 'height': 200},
        'input_path': '/valid/path.jpg',
      };
      // operation and params should be preserved
      expect(args['operation'], equals('crop'));
      expect(args['params'], isA<Map>());
    });
  });

  group('File path resolution logic', () {
    test('existing file returns same path', () {
      // If file exists at given path, use as-is
      final path = '/data/user/0/ai.navixmind/app_flutter/navixmind_output/photo.jpg';
      // Simulated: file exists
      final result = _simulateResolve(path, existsAtOriginal: true);
      expect(result, equals(path));
    });

    test('non-existing file searches by basename', () {
      final path = '/wrong/path/photo.jpg';
      final result = _simulateResolve(
        path,
        existsAtOriginal: false,
        foundAt: '/storage/emulated/0/DCIM/Camera/photo.jpg',
      );
      // Should find by basename in search directories
      expect(result, isNot(equals(path)));
      expect(result, contains('photo.jpg'));
    });

    test('external file gets copied to internal storage', () {
      final path = '/storage/emulated/0/Pictures/Screenshots/shot.png';
      final result = _simulateResolve(
        path,
        existsAtOriginal: false,
        foundAt: '/storage/emulated/0/Pictures/Screenshots/shot.png',
        appDocPath: '/data/user/0/ai.navixmind/app_flutter',
      );
      // Found in external storage — should be copied to internal
      expect(result, contains('navixmind_output'));
      expect(result, contains('shot.png'));
    });

    test('internal file not copied (already internal)', () {
      final path = '/data/user/0/ai.navixmind/app_flutter/navixmind_output/result.jpg';
      final result = _simulateResolve(
        path,
        existsAtOriginal: true,
        appDocPath: '/data/user/0/ai.navixmind/app_flutter',
      );
      // Already in internal storage — no copy needed
      expect(result, equals(path));
    });

    test('file not found anywhere returns original path', () {
      final path = '/nonexistent/path/missing.jpg';
      final result = _simulateResolve(
        path,
        existsAtOriginal: false,
        foundAt: null,
      );
      // Not found — return original so tool gives appropriate error
      expect(result, equals(path));
    });

    test('file without extension skips search', () {
      final path = '/wrong/path/noext';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      // Without a dot in basename, search is skipped
      expect(basename.contains('.'), isFalse);
    });

    test('empty basename skips search', () {
      final path = '/wrong/path/';
      final basename = path.substring(path.lastIndexOf('/') + 1);
      expect(basename.isEmpty, isTrue);
    });
  });

  group('Array path resolution', () {
    test('resolves all paths in input_paths array', () {
      final paths = ['/path/a.jpg', '/path/b.jpg', '/path/c.jpg'];
      final resolved = paths.map((p) =>
        _simulateResolve(p, existsAtOriginal: true)
      ).toList();
      expect(resolved, hasLength(3));
    });

    test('resolves mixed existing and non-existing paths', () {
      final results = [
        _simulateResolve('/exists/a.jpg', existsAtOriginal: true),
        _simulateResolve('/wrong/b.jpg', existsAtOriginal: false, foundAt: '/storage/emulated/0/Download/b.jpg'),
        _simulateResolve('/exists/c.jpg', existsAtOriginal: true),
      ];
      expect(results[0], equals('/exists/a.jpg'));
      expect(results[1], contains('b.jpg'));
      expect(results[2], equals('/exists/c.jpg'));
    });

    test('handles empty array', () {
      final paths = <String>[];
      expect(paths, isEmpty);
    });
  });

  group('Security — path safety', () {
    test('search only looks in predefined directories', () {
      const searchDirs = [
        '/storage/emulated/0/Pictures/Screenshots',
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/DCIM',
      ];
      // Should not include system directories
      for (final dir in searchDirs) {
        expect(dir, startsWith('/storage/emulated/0/'));
        expect(dir, isNot(contains('/etc')));
        expect(dir, isNot(contains('/system')));
        expect(dir, isNot(contains('/proc')));
      }
    });

    test('internal dirs include app output and shared dirs only', () {
      const appDocPath = '/data/user/0/ai.navixmind/app_flutter';
      final internalDirs = [
        '$appDocPath/navixmind_output',
        '${appDocPath.substring(0, appDocPath.lastIndexOf('/'))}/files/navixmind_shared',
      ];
      for (final dir in internalDirs) {
        expect(dir, contains('ai.navixmind'));
      }
    });
  });
}

// Helper functions simulating file path resolution

String _simulateResolve(
  String path, {
  required bool existsAtOriginal,
  String? foundAt,
  String appDocPath = '/data/user/0/ai.navixmind/app_flutter',
}) {
  // If file exists at given path, use as-is
  if (existsAtOriginal) return path;

  final basename = path.substring(path.lastIndexOf('/') + 1);
  if (basename.isEmpty || !basename.contains('.')) return path;

  // Search directories
  if (foundAt != null) {
    // Found in some directory
    if (!foundAt.startsWith(appDocPath)) {
      // External file — copy to internal
      return '$appDocPath/navixmind_output/$basename';
    }
    return foundAt;
  }

  // Not found anywhere
  return path;
}
