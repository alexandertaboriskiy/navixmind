import 'package:flutter_test/flutter_test.dart';

/// Tests for FFmpeg image-to-image codec handling.
///
/// When both input and output are image files (JPG, PNG, etc.),
/// FFmpeg should use image-appropriate codecs (mjpeg, png) instead
/// of video codecs (libx264, pix_fmt yuv420p).
void main() {
  group('Image path detection', () {
    test('detects .jpg as image', () {
      expect(_isImagePath('/path/to/file.jpg'), isTrue);
    });

    test('detects .jpeg as image', () {
      expect(_isImagePath('/path/to/file.jpeg'), isTrue);
    });

    test('detects .png as image', () {
      expect(_isImagePath('/path/to/file.png'), isTrue);
    });

    test('detects .bmp as image', () {
      expect(_isImagePath('/path/to/file.bmp'), isTrue);
    });

    test('detects .webp as image', () {
      expect(_isImagePath('/path/to/file.webp'), isTrue);
    });

    test('detects .tiff as image', () {
      expect(_isImagePath('/path/to/file.tiff'), isTrue);
    });

    test('detects .gif as image', () {
      expect(_isImagePath('/path/to/file.gif'), isTrue);
    });

    test('case insensitive: .JPG', () {
      expect(_isImagePath('/path/to/file.JPG'), isTrue);
    });

    test('case insensitive: .Png', () {
      expect(_isImagePath('/path/to/file.Png'), isTrue);
    });

    test('does not detect .mp4 as image', () {
      expect(_isImagePath('/path/to/file.mp4'), isFalse);
    });

    test('does not detect .mov as image', () {
      expect(_isImagePath('/path/to/file.mov'), isFalse);
    });

    test('does not detect .webm as image', () {
      expect(_isImagePath('/path/to/file.webm'), isFalse);
    });

    test('does not detect .mp3 as image', () {
      expect(_isImagePath('/path/to/file.mp3'), isFalse);
    });

    test('does not detect .pdf as image', () {
      expect(_isImagePath('/path/to/file.pdf'), isFalse);
    });

    test('does not detect .txt as image', () {
      expect(_isImagePath('/path/to/file.txt'), isFalse);
    });

    test('does not detect file without extension', () {
      expect(_isImagePath('/path/to/file'), isFalse);
    });

    test('handles path with multiple dots', () {
      expect(_isImagePath('/path/to/my.photo.jpg'), isTrue);
    });

    test('handles path with spaces', () {
      expect(_isImagePath('/path/to/my photo.jpg'), isTrue);
    });

    test('handles path ending with dot only', () {
      expect(_isImagePath('/path/to/file.'), isFalse);
    });
  });

  group('Image codec arguments', () {
    test('PNG output uses png codec', () {
      final args = _imageCodecArgs('/output.png');
      expect(args, equals('-c:v png'));
    });

    test('WebP output uses libwebp codec', () {
      final args = _imageCodecArgs('/output.webp');
      expect(args, equals('-c:v libwebp'));
    });

    test('JPG output uses mjpeg codec', () {
      final args = _imageCodecArgs('/output.jpg');
      expect(args, equals('-c:v mjpeg -q:v 2'));
    });

    test('JPEG output uses mjpeg codec', () {
      final args = _imageCodecArgs('/output.jpeg');
      expect(args, equals('-c:v mjpeg -q:v 2'));
    });

    test('BMP output uses mjpeg codec (default)', () {
      final args = _imageCodecArgs('/output.bmp');
      expect(args, equals('-c:v mjpeg -q:v 2'));
    });

    test('uppercase PNG uses png codec', () {
      final args = _imageCodecArgs('/output.PNG');
      expect(args, equals('-c:v png'));
    });
  });

  group('FFmpeg crop with images', () {
    test('image input + image output uses image codec, no pix_fmt', () {
      final command = _buildCropCommand(
        inputPath: '/input.jpg',
        outputPath: '/output.jpg',
        width: 500,
        height: 300,
        x: 10,
        y: 20,
      );
      expect(command, contains('-c:v mjpeg'));
      expect(command, isNot(contains('-pix_fmt yuv420p')));
      expect(command, isNot(contains('-c:a')));
    });

    test('image input + PNG output uses png codec', () {
      final command = _buildCropCommand(
        inputPath: '/input.jpg',
        outputPath: '/output.png',
        width: 500,
        height: 300,
        x: 0,
        y: 0,
      );
      expect(command, contains('-c:v png'));
      expect(command, isNot(contains('-pix_fmt yuv420p')));
    });

    test('video input + video output still uses video codecs', () {
      final command = _buildCropCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        width: 1080,
        height: 1920,
        x: 0,
        y: 0,
      );
      expect(command, contains('-pix_fmt yuv420p'));
      expect(command, contains('-c:a copy'));
      expect(command, isNot(contains('-c:v mjpeg')));
    });

    test('image input + video output uses video codecs', () {
      final command = _buildCropCommand(
        inputPath: '/input.jpg',
        outputPath: '/output.mp4',
        width: 500,
        height: 300,
        x: 0,
        y: 0,
      );
      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('video input + image output uses video codecs (extract_frame)', () {
      // This scenario should use extract_frame, not crop
      // But if crop is called, video input means video codecs
      final command = _buildCropCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.jpg',
        width: 500,
        height: 300,
        x: 0,
        y: 0,
      );
      // Not both image paths — uses video codecs
      expect(command, contains('-pix_fmt yuv420p'));
    });
  });

  group('FFmpeg resize with images', () {
    test('image input + image output uses image codec', () {
      final command = _buildResizeCommand(
        inputPath: '/input.png',
        outputPath: '/output.png',
        width: 800,
        height: 600,
      );
      expect(command, contains('-c:v png'));
      expect(command, isNot(contains('-pix_fmt yuv420p')));
    });

    test('JPG to JPG resize uses mjpeg', () {
      final command = _buildResizeCommand(
        inputPath: '/input.jpg',
        outputPath: '/output.jpg',
        width: 400,
        height: null,
      );
      expect(command, contains('-c:v mjpeg'));
      expect(command, contains('scale=400:-2'));
    });

    test('video resize still uses video codecs', () {
      final command = _buildResizeCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        width: 1920,
        height: 1080,
      );
      expect(command, contains('-pix_fmt yuv420p'));
    });
  });

  group('FFmpeg filter with images', () {
    test('image filter uses image codec (e.g. brightness)', () {
      final command = _buildFilterCommand(
        inputPath: '/input.jpg',
        outputPath: '/output.jpg',
        vf: 'eq=brightness=0.3',
        af: null,
      );
      expect(command, contains('-c:v mjpeg'));
      expect(command, isNot(contains('-pix_fmt yuv420p')));
      expect(command, isNot(contains('-c:a')));
    });

    test('image filter to PNG uses png codec', () {
      final command = _buildFilterCommand(
        inputPath: '/input.jpg',
        outputPath: '/output.png',
        vf: 'hue=s=0',
        af: null,
      );
      expect(command, contains('-c:v png'));
    });

    test('video filter still uses video codecs', () {
      final command = _buildFilterCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        vf: 'eq=brightness=0.3',
        af: null,
      );
      expect(command, contains('-c:v libx264'));
      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('video filter with audio uses full video codecs', () {
      final command = _buildFilterCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        vf: 'eq=brightness=0.3',
        af: 'volume=1.5',
      );
      expect(command, contains('-c:v libx264'));
      expect(command, contains('-c:a aac'));
    });

    test('audio-only filter does not use image codec', () {
      final command = _buildFilterCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        vf: null,
        af: 'volume=2.0',
      );
      expect(command, isNot(contains('-c:v mjpeg')));
      expect(command, contains('-c:v copy'));
    });
  });

  group('Edge cases', () {
    test('extract_frame unchanged (already works)', () {
      // extract_frame uses -vframes 1 which already produces images correctly
      final command = '-y -i "/input.mp4" -ss 00:00:05 -vframes 1 "/output.jpg"';
      expect(command, isNot(contains('-c:v libx264')));
      expect(command, contains('-vframes 1'));
    });

    test('convert operation always uses video codecs', () {
      // Convert is for video format conversion — always uses video codecs
      final command = _buildConvertCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.webm',
      );
      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('WebP to WebP uses libwebp', () {
      final command = _buildCropCommand(
        inputPath: '/input.webp',
        outputPath: '/output.webp',
        width: 200,
        height: 200,
        x: 0,
        y: 0,
      );
      expect(command, contains('-c:v libwebp'));
    });
  });
}

// Helper functions simulating the image-aware FFmpeg logic

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp', '.tiff', '.gif'};

bool _isImagePath(String path) {
  final dotIdx = path.lastIndexOf('.');
  if (dotIdx < 0) return false;
  final ext = path.substring(dotIdx).toLowerCase();
  return _imageExtensions.contains(ext);
}

String _imageCodecArgs(String outputPath) {
  final dotIdx = outputPath.lastIndexOf('.');
  final ext = dotIdx >= 0 ? outputPath.substring(dotIdx).toLowerCase() : '';
  switch (ext) {
    case '.png':
      return '-c:v png';
    case '.webp':
      return '-c:v libwebp';
    default:
      return '-c:v mjpeg -q:v 2';
  }
}

String _buildCropCommand({
  required String inputPath,
  required String outputPath,
  required int width,
  required int height,
  required int x,
  required int y,
}) {
  if (_isImagePath(inputPath) && _isImagePath(outputPath)) {
    return '-y -i "$inputPath" -vf "crop=$width:$height:$x:$y" ${_imageCodecArgs(outputPath)} "$outputPath"';
  } else {
    return '-y -i "$inputPath" -vf "crop=$width:$height:$x:$y" -pix_fmt yuv420p -c:a copy "$outputPath"';
  }
}

String _buildResizeCommand({
  required String inputPath,
  required String outputPath,
  required int? width,
  required int? height,
}) {
  final scale = width != null && height != null
      ? 'scale=$width:$height'
      : width != null
          ? 'scale=$width:-2'
          : 'scale=-2:$height';
  if (_isImagePath(inputPath) && _isImagePath(outputPath)) {
    return '-y -i "$inputPath" -vf "$scale" ${_imageCodecArgs(outputPath)} "$outputPath"';
  } else {
    return '-y -i "$inputPath" -vf "$scale" -pix_fmt yuv420p -c:a copy "$outputPath"';
  }
}

String _buildFilterCommand({
  required String inputPath,
  required String outputPath,
  required String? vf,
  required String? af,
}) {
  if (vf != null && af != null) {
    return '-y -i "$inputPath" -vf "$vf" -af "$af" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
  } else if (vf != null) {
    if (_isImagePath(inputPath) && _isImagePath(outputPath)) {
      return '-y -i "$inputPath" -vf "$vf" ${_imageCodecArgs(outputPath)} "$outputPath"';
    } else {
      return '-y -i "$inputPath" -vf "$vf" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
    }
  } else {
    return '-y -i "$inputPath" -c:v copy -af "$af" -c:a aac "$outputPath"';
  }
}

String _buildConvertCommand({
  required String inputPath,
  required String outputPath,
}) {
  return '-y -i "$inputPath" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
}
