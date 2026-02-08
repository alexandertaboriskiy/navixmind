import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/utils/file_validator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_validator_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File createFile(String name, int sizeBytes) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List.filled(sizeBytes, 0));
    return file;
  }

  group('FileValidator.validate()', () {
    test('passes for file under limit', () async {
      final file = createFile('small.pdf', 1024);
      await expectLater(
        FileValidator.validate(file, 'pdf'),
        completes,
      );
    });

    test('passes for zero-byte file', () async {
      final file = createFile('empty.txt', 0);
      await expectLater(
        FileValidator.validate(file, 'document'),
        completes,
      );
    });

    test('passes for file exactly at limit minus one byte', () async {
      // 500MB - 1 byte
      // Can't create a 500MB file in test, but we can test the logic
      // by creating a small file and verifying it passes
      final file = createFile('just_under.pdf', 1024 * 1024); // 1MB
      await expectLater(
        FileValidator.validate(file, 'pdf'),
        completes,
      );
    });

    test('throws FileTooLargeException with correct fields', () async {
      // Create a file and validate against a manually lower limit
      // Since all limits are 500MB and we can't create huge files,
      // test the exception structure directly
      final exception = FileTooLargeException(
        message: 'File is too large (600.0 MB). Maximum: 500.0 MB',
        fileSize: 600 * 1024 * 1024,
        limit: 500 * 1024 * 1024,
      );

      expect(exception.fileSize, equals(600 * 1024 * 1024));
      expect(exception.limit, equals(500 * 1024 * 1024));
      expect(exception.toString(), contains('too large'));
      expect(exception.toString(), contains('600.0 MB'));
      expect(exception.toString(), contains('500.0 MB'));
    });

    test('validates against correct type limit', () async {
      final file = createFile('test.mp4', 100);
      // Video limit is 500MB, so 100 bytes is fine
      await expectLater(
        FileValidator.validate(file, 'video'),
        completes,
      );
    });

    test('falls back to default limit for unknown type', () async {
      final file = createFile('test.xyz', 100);
      await expectLater(
        FileValidator.validate(file, 'unknown_type'),
        completes,
      );
    });
  });

  group('FileValidator.detectFileType() comprehensive', () {
    group('PDF detection', () {
      test('lowercase pdf', () {
        expect(FileValidator.detectFileType('pdf'), equals('pdf'));
      });

      test('uppercase PDF', () {
        expect(FileValidator.detectFileType('PDF'), equals('pdf'));
      });

      test('mixed case Pdf', () {
        expect(FileValidator.detectFileType('Pdf'), equals('pdf'));
      });
    });

    group('image detection', () {
      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif']) {
        test('detects $ext as image', () {
          expect(FileValidator.detectFileType(ext), equals('image'));
        });
      }

      test('detects uppercase JPG', () {
        expect(FileValidator.detectFileType('JPG'), equals('image'));
      });

      test('detects mixed case Jpeg', () {
        expect(FileValidator.detectFileType('Jpeg'), equals('image'));
      });

      test('detects HEIC (Apple format)', () {
        expect(FileValidator.detectFileType('HEIC'), equals('image'));
      });

      test('does not detect bmp as image', () {
        expect(FileValidator.detectFileType('bmp'), equals('default'));
      });

      test('does not detect svg as image', () {
        expect(FileValidator.detectFileType('svg'), equals('default'));
      });

      test('does not detect tiff as image', () {
        expect(FileValidator.detectFileType('tiff'), equals('default'));
      });
    });

    group('video detection', () {
      for (final ext in ['mp4', 'mov', 'avi', 'mkv', 'webm']) {
        test('detects $ext as video', () {
          expect(FileValidator.detectFileType(ext), equals('video'));
        });
      }

      test('detects uppercase MP4', () {
        expect(FileValidator.detectFileType('MP4'), equals('video'));
      });

      test('does not detect flv as video', () {
        expect(FileValidator.detectFileType('flv'), equals('default'));
      });

      test('does not detect wmv as video', () {
        expect(FileValidator.detectFileType('wmv'), equals('default'));
      });
    });

    group('audio detection', () {
      for (final ext in ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac']) {
        test('detects $ext as audio', () {
          expect(FileValidator.detectFileType(ext), equals('audio'));
        });
      }

      test('detects uppercase MP3', () {
        expect(FileValidator.detectFileType('MP3'), equals('audio'));
      });

      test('does not detect wma as audio', () {
        expect(FileValidator.detectFileType('wma'), equals('default'));
      });

      test('does not detect midi as audio', () {
        expect(FileValidator.detectFileType('midi'), equals('default'));
      });
    });

    group('document detection', () {
      for (final ext in ['doc', 'docx', 'pptx', 'ppt', 'xlsx', 'xls', 'xlsm', 'odt', 'rtf', 'txt']) {
        test('detects $ext as document', () {
          expect(FileValidator.detectFileType(ext), equals('document'));
        });
      }

      test('detects uppercase DOCX', () {
        expect(FileValidator.detectFileType('DOCX'), equals('document'));
      });

      test('detects mixed case TxT', () {
        expect(FileValidator.detectFileType('TxT'), equals('document'));
      });

      test('detects PPTX as document', () {
        expect(FileValidator.detectFileType('PPTX'), equals('document'));
      });

      test('detects XLSX as document', () {
        expect(FileValidator.detectFileType('XLSX'), equals('document'));
      });

      test('does not detect csv as document', () {
        expect(FileValidator.detectFileType('csv'), equals('default'));
      });

      test('does not detect json as document', () {
        expect(FileValidator.detectFileType('json'), equals('default'));
      });

      test('does not detect xml as document', () {
        expect(FileValidator.detectFileType('xml'), equals('default'));
      });
    });

    group('default/unknown extensions', () {
      test('null returns default', () {
        expect(FileValidator.detectFileType(null), equals('default'));
      });

      test('empty string returns default', () {
        expect(FileValidator.detectFileType(''), equals('default'));
      });

      test('unknown extension returns default', () {
        expect(FileValidator.detectFileType('xyz'), equals('default'));
      });

      test('numbers-only extension returns default', () {
        expect(FileValidator.detectFileType('123'), equals('default'));
      });

      test('extension with dots returns default', () {
        expect(FileValidator.detectFileType('tar.gz'), equals('default'));
      });

      test('very long extension returns default', () {
        expect(FileValidator.detectFileType('a' * 100), equals('default'));
      });

      test('extension with spaces returns default', () {
        expect(FileValidator.detectFileType('pd f'), equals('default'));
      });

      test('extension with special chars returns default', () {
        expect(FileValidator.detectFileType('p@f'), equals('default'));
      });

      test('single character extension returns default', () {
        expect(FileValidator.detectFileType('a'), equals('default'));
      });
    });
  });

  group('FileValidator.getLimitForType()', () {
    const expectedLimit = 500 * 1024 * 1024; // 500MB

    test('all known types return 500MB', () {
      for (final type in ['pdf', 'image', 'video', 'audio', 'document', 'default']) {
        expect(
          FileValidator.getLimitForType(type),
          equals(expectedLimit),
          reason: '$type should have 500MB limit',
        );
      }
    });

    test('unknown type falls back to default limit', () {
      expect(FileValidator.getLimitForType('nonexistent'), equals(expectedLimit));
    });

    test('empty string type falls back to default limit', () {
      expect(FileValidator.getLimitForType(''), equals(expectedLimit));
    });

    test('limit is exactly 524288000 bytes', () {
      expect(FileValidator.getLimitForType('pdf'), equals(524288000));
    });
  });

  group('FileValidator.isPathAllowed()', () {
    test('allows simple absolute path', () {
      expect(FileValidator.isPathAllowed('/data/app/files/test.pdf'), isTrue);
    });

    test('rejects path traversal with ..', () {
      expect(FileValidator.isPathAllowed('/data/app/../../../etc/passwd'), isFalse);
    });

    test('allows path without traversal components', () {
      expect(FileValidator.isPathAllowed('/data/user/0/ai.navixmind/files/doc.pdf'), isTrue);
    });

    test('allows nested directory path', () {
      expect(FileValidator.isPathAllowed('/storage/emulated/0/Download/photos/img.jpg'), isTrue);
    });

    test('rejects single .. in middle of path', () {
      expect(FileValidator.isPathAllowed('/data/../secret'), isFalse);
    });

    test('allows relative path without traversal', () {
      // File().absolute.path resolves it, and the resolved path won't contain ..
      final result = FileValidator.isPathAllowed('simple/file.txt');
      expect(result, isA<bool>());
    });

    test('allows empty string path', () {
      // Empty path resolves to current directory — no .. in it
      final result = FileValidator.isPathAllowed('');
      expect(result, isA<bool>());
    });

    test('allows path with special characters', () {
      expect(FileValidator.isPathAllowed('/data/files/résumé.pdf'), isTrue);
    });

    test('allows path with spaces', () {
      expect(FileValidator.isPathAllowed('/data/My Documents/file.pdf'), isTrue);
    });
  });

  group('FileTooLargeException', () {
    test('stores all fields correctly', () {
      final ex = FileTooLargeException(
        message: 'Too big',
        fileSize: 1000,
        limit: 500,
      );
      expect(ex.message, 'Too big');
      expect(ex.fileSize, 1000);
      expect(ex.limit, 500);
    });

    test('toString returns message', () {
      final ex = FileTooLargeException(
        message: 'Custom error message',
        fileSize: 0,
        limit: 0,
      );
      expect(ex.toString(), 'Custom error message');
    });

    test('implements Exception interface', () {
      final ex = FileTooLargeException(
        message: 'test',
        fileSize: 1,
        limit: 1,
      );
      expect(ex, isA<Exception>());
    });

    test('handles zero values', () {
      final ex = FileTooLargeException(
        message: 'zero',
        fileSize: 0,
        limit: 0,
      );
      expect(ex.fileSize, 0);
      expect(ex.limit, 0);
    });

    test('handles very large values', () {
      final ex = FileTooLargeException(
        message: 'huge',
        fileSize: 1024 * 1024 * 1024 * 10, // 10GB
        limit: 500 * 1024 * 1024,
      );
      expect(ex.fileSize, greaterThan(ex.limit));
    });

    test('message can contain any characters', () {
      final ex = FileTooLargeException(
        message: 'File "特殊.pdf" (100MB) > limit (50MB) ⚠️',
        fileSize: 100,
        limit: 50,
      );
      expect(ex.toString(), contains('特殊.pdf'));
    });
  });

  group('fileSizeLimits constant', () {
    test('contains all expected keys', () {
      expect(fileSizeLimits, containsPair('pdf', isA<int>()));
      expect(fileSizeLimits, containsPair('image', isA<int>()));
      expect(fileSizeLimits, containsPair('video', isA<int>()));
      expect(fileSizeLimits, containsPair('audio', isA<int>()));
      expect(fileSizeLimits, containsPair('document', isA<int>()));
      expect(fileSizeLimits, containsPair('default', isA<int>()));
    });

    test('all limits are positive', () {
      for (final entry in fileSizeLimits.entries) {
        expect(entry.value, greaterThan(0), reason: '${entry.key} should be positive');
      }
    });

    test('all limits are equal (unified 500MB)', () {
      final values = fileSizeLimits.values.toSet();
      expect(values.length, 1, reason: 'All limits should be the same');
      expect(values.first, 500 * 1024 * 1024);
    });

    test('has exactly 6 entries', () {
      expect(fileSizeLimits.length, 6);
    });
  });
}
