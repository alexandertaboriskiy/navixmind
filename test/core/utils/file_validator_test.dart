import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/utils/file_validator.dart';

void main() {
  group('FileValidator', () {
    group('detectFileType', () {
      test('detects PDF files', () {
        expect(FileValidator.detectFileType('pdf'), equals('pdf'));
        expect(FileValidator.detectFileType('PDF'), equals('pdf'));
      });

      test('detects image files', () {
        expect(FileValidator.detectFileType('jpg'), equals('image'));
        expect(FileValidator.detectFileType('jpeg'), equals('image'));
        expect(FileValidator.detectFileType('png'), equals('image'));
        expect(FileValidator.detectFileType('gif'), equals('image'));
        expect(FileValidator.detectFileType('webp'), equals('image'));
        expect(FileValidator.detectFileType('heic'), equals('image'));
      });

      test('detects video files', () {
        expect(FileValidator.detectFileType('mp4'), equals('video'));
        expect(FileValidator.detectFileType('mov'), equals('video'));
        expect(FileValidator.detectFileType('avi'), equals('video'));
        expect(FileValidator.detectFileType('mkv'), equals('video'));
        expect(FileValidator.detectFileType('webm'), equals('video'));
      });

      test('detects audio files', () {
        expect(FileValidator.detectFileType('mp3'), equals('audio'));
        expect(FileValidator.detectFileType('wav'), equals('audio'));
        expect(FileValidator.detectFileType('m4a'), equals('audio'));
        expect(FileValidator.detectFileType('aac'), equals('audio'));
        expect(FileValidator.detectFileType('ogg'), equals('audio'));
        expect(FileValidator.detectFileType('flac'), equals('audio'));
      });

      test('detects document files', () {
        expect(FileValidator.detectFileType('doc'), equals('document'));
        expect(FileValidator.detectFileType('docx'), equals('document'));
        expect(FileValidator.detectFileType('odt'), equals('document'));
        expect(FileValidator.detectFileType('rtf'), equals('document'));
        expect(FileValidator.detectFileType('txt'), equals('document'));
      });

      test('returns default for unknown extensions', () {
        expect(FileValidator.detectFileType('xyz'), equals('default'));
        expect(FileValidator.detectFileType(''), equals('default'));
        expect(FileValidator.detectFileType(null), equals('default'));
      });
    });

    group('getLimitForType', () {
      test('returns correct limit for PDF', () {
        expect(
          FileValidator.getLimitForType('pdf'),
          equals(500 * 1024 * 1024),
        );
      });

      test('returns correct limit for image', () {
        expect(
          FileValidator.getLimitForType('image'),
          equals(500 * 1024 * 1024),
        );
      });

      test('returns correct limit for video', () {
        expect(
          FileValidator.getLimitForType('video'),
          equals(500 * 1024 * 1024),
        );
      });

      test('returns correct limit for audio', () {
        expect(
          FileValidator.getLimitForType('audio'),
          equals(500 * 1024 * 1024),
        );
      });

      test('returns correct limit for document', () {
        expect(
          FileValidator.getLimitForType('document'),
          equals(500 * 1024 * 1024),
        );
      });

      test('returns default limit for unknown type', () {
        expect(
          FileValidator.getLimitForType('unknown'),
          equals(500 * 1024 * 1024),
        );
      });
    });

    group('isPathAllowed', () {
      test('rejects paths with ..', () {
        expect(FileValidator.isPathAllowed('/data/app/../../../etc/passwd'), isFalse);
      });

      test('allows normal paths', () {
        expect(FileValidator.isPathAllowed('/data/app/files/test.pdf'), isTrue);
      });
    });
  });

  group('FileTooLargeException', () {
    test('stores file size and limit', () {
      final exception = FileTooLargeException(
        message: 'File too large',
        fileSize: 100 * 1024 * 1024,
        limit: 50 * 1024 * 1024,
      );

      expect(exception.fileSize, equals(100 * 1024 * 1024));
      expect(exception.limit, equals(50 * 1024 * 1024));
      expect(exception.toString(), equals('File too large'));
    });
  });
}
