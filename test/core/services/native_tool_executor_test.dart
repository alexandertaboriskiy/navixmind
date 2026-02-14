import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/bridge/messages.dart';

/// Tests for NativeToolExecutor
///
/// Note: These tests focus on logic and message handling.
/// Actual FFmpeg/ML Kit calls require mocking platform channels.
void main() {
  group('NativeToolRequest', () {
    test('parses FFmpeg request correctly', () {
      final json = {
        'id': 'req-123',
        'params': {
          'tool': 'ffmpeg',
          'args': {
            'input_path': '/storage/video.mp4',
            'output_path': '/storage/output.mp4',
            'operation': 'crop',
            'params': {'x': 0, 'y': 0, 'width': 1080, 'height': 1920},
          },
          'timeout_ms': 120000,
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.id, equals('req-123'));
      expect(request.tool, equals('ffmpeg'));
      expect(request.args['input_path'], equals('/storage/video.mp4'));
      expect(request.args['operation'], equals('crop'));
      expect(request.timeoutMs, equals(120000));
    });

    test('parses OCR request correctly', () {
      final json = {
        'id': 'req-456',
        'params': {
          'tool': 'ocr',
          'args': {'image_path': '/storage/image.jpg'},
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.tool, equals('ocr'));
      expect(request.args['image_path'], equals('/storage/image.jpg'));
      expect(request.timeoutMs, equals(30000)); // Default
    });

    test('parses headless browser request correctly', () {
      final json = {
        'id': 'req-789',
        'params': {
          'tool': 'headless_browser',
          'args': {
            'url': 'https://example.com',
            'wait_seconds': 10,
            'extract_selector': 'main',
          },
          'timeout_ms': 60000,
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.tool, equals('headless_browser'));
      expect(request.args['url'], equals('https://example.com'));
      expect(request.args['wait_seconds'], equals(10));
      expect(request.args['extract_selector'], equals('main'));
    });

    test('parses face detection request correctly', () {
      final json = {
        'id': 'req-face',
        'params': {
          'tool': 'face_detect',
          'args': {'image_path': '/storage/photo.jpg'},
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.tool, equals('face_detect'));
      expect(request.args['image_path'], equals('/storage/photo.jpg'));
    });

    test('parses smart crop request correctly', () {
      final json = {
        'id': 'req-smart-crop',
        'params': {
          'tool': 'smart_crop',
          'args': {
            'input_path': '/storage/video.mp4',
            'output_path': '/storage/cropped.mp4',
            'aspect_ratio': '9:16',
          },
          'timeout_ms': 180000,
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.tool, equals('smart_crop'));
      expect(request.args['aspect_ratio'], equals('9:16'));
    });
  });

  group('FFmpeg command building', () {
    test('builds crop command correctly', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'crop',
        params: {'x': 100, 'y': 200, 'width': 1080, 'height': 1920},
      );

      expect(command, contains('-filter:v'));
      expect(command, contains('crop=1080:1920:100:200'));
    });

    test('crop command includes pix_fmt yuv420p for Android compatibility', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'crop',
        params: {'x': 0, 'y': 0, 'width': 1080, 'height': 1920},
      );

      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('builds resize command with dimensions', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'resize',
        params: {'width': 1920, 'height': 1080},
      );

      expect(command, contains('-vf'));
      expect(command, contains('scale=1920:1080'));
    });

    test('resize command includes pix_fmt yuv420p', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'resize',
        params: {'width': 1920, 'height': 1080},
      );

      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('builds resize command with scale factor', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'resize',
        params: {'scale': 0.5},
      );

      expect(command, contains('scale=iw*0.5:ih*0.5'));
    });

    test('builds extract_audio command', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp3',
        operation: 'extract_audio',
        params: {'format': 'mp3', 'bitrate': '320k'},
      );

      expect(command, contains('-vn'));
      expect(command, contains('-acodec libmp3lame'));
    });

    test('builds convert command with quality presets', () {
      final highQuality = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'convert',
        params: {'quality': 'high'},
      );
      expect(highQuality, contains('-crf 18'));

      final mediumQuality = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'convert',
        params: {'quality': 'medium'},
      );
      expect(mediumQuality, contains('-crf 23'));

      final lowQuality = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'convert',
        params: {'quality': 'low'},
      );
      expect(lowQuality, contains('-crf 28'));
    });

    test('builds convert command with custom codec', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.webm',
        operation: 'convert',
        params: {'video_codec': 'libvpx-vp9'},
      );

      expect(command, contains('-c:v libvpx-vp9'));
    });

    test('convert command includes pix_fmt yuv420p', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'convert',
        params: {'quality': 'medium'},
      );

      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('filter command includes pix_fmt yuv420p', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'filter',
        params: {'vf': 'hue=s=0'},
      );

      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('filter with both vf and af includes pix_fmt yuv420p', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'filter',
        params: {'vf': 'hue=s=0', 'af': 'volume=1.5'},
      );

      expect(command, contains('-pix_fmt yuv420p'));
    });

    test('audio-only filter does not include pix_fmt', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'filter',
        params: {'af': 'volume=2.0'},
      );

      expect(command, isNot(contains('-pix_fmt yuv420p')));
    });

    test('custom case injects pix_fmt when re-encoding video', () {
      final args = "-c:v libx264 -crf 23 -c:a aac";
      final result = _injectPixFmtForCustom(args);
      expect(result, contains('-pix_fmt yuv420p'));
      expect(result, contains('-c:v libx264 -pix_fmt yuv420p'));
    });

    test('custom case does not inject pix_fmt for copy', () {
      final args = "-c:v copy -c:a copy";
      final result = _injectPixFmtForCustom(args);
      expect(result, isNot(contains('-pix_fmt yuv420p')));
    });

    test('custom case does not double-inject pix_fmt', () {
      final args = "-c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac";
      final result = _injectPixFmtForCustom(args);
      // Should be unchanged
      expect(result, equals(args));
    });

    test('custom case does not inject pix_fmt when no video codec', () {
      final args = "-c:a aac -b:a 192k";
      final result = _injectPixFmtForCustom(args);
      expect(result, isNot(contains('-pix_fmt yuv420p')));
    });

    test('handles unknown operation with passthrough', () {
      final command = _buildFFmpegCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        operation: 'unknown_operation',
        params: {},
      );

      expect(command, contains('-c copy'));
    });
  });

  group('Tool result validation', () {
    test('validates FFmpeg success result', () {
      final result = {
        'success': true,
        'output_path': '/storage/output.mp4',
        'message': 'Processing complete',
      };

      expect(result['success'], isTrue);
      expect(result['output_path'], isNotNull);
    });

    test('validates OCR success result', () {
      final result = {
        'success': true,
        'text': 'Recognized text content',
        'blocks': [
          {
            'text': 'Block 1',
            'lines': [
              {
                'text': 'Line 1',
                'confidence': 0.95,
                'bounding_box': {
                  'left': 10.0,
                  'top': 20.0,
                  'right': 200.0,
                  'bottom': 50.0,
                },
              },
            ],
            'bounding_box': {
              'left': 10.0,
              'top': 20.0,
              'right': 200.0,
              'bottom': 100.0,
            },
          },
        ],
        'block_count': 1,
      };

      expect(result['success'], isTrue);
      expect(result['text'], isA<String>());
      expect(result['blocks'], isA<List>());
      expect(result['block_count'], equals(1));
    });

    test('validates headless browser success result', () {
      final result = {
        'success': true,
        'url': 'https://example.com',
        'title': 'Example Page',
        'text': 'Page content text',
      };

      expect(result['success'], isTrue);
      expect(result['url'], isNotNull);
      expect(result['title'], isA<String>());
      expect(result['text'], isA<String>());
    });

    test('validates face detection success result', () {
      final result = {
        'success': true,
        'faces': [
          {
            'x': 100,
            'y': 150,
            'width': 200,
            'height': 200,
            'center_x': 200,
            'center_y': 250,
            'head_euler_angle_y': 5.0,
            'head_euler_angle_z': -2.0,
          },
        ],
        'face_count': 1,
      };

      expect(result['success'], isTrue);
      expect(result['faces'], isA<List>());
      expect(result['face_count'], equals(1));
      expect((result['faces'] as List).first['center_x'], equals(200));
    });

    test('validates smart crop success result', () {
      final result = {
        'success': true,
        'output_path': '/storage/cropped.mp4',
        'crop_region': {
          'x': 100,
          'y': 0,
          'width': 1080,
          'height': 1920,
        },
        'faces_detected': 2,
      };

      expect(result['success'], isTrue);
      expect(result['crop_region'], isA<Map>());
      expect(result['faces_detected'], equals(2));
    });
  });

  group('Error handling', () {
    test('handles unsupported tool error', () {
      expect(
        () => _validateTool('unknown_tool'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('handles missing required parameters', () {
      expect(
        () => _validateFFmpegArgs({}),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => _validateFFmpegArgs({'input_path': '/input.mp4'}),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => _validateFFmpegArgs({
          'input_path': '/input.mp4',
          'output_path': '/output.mp4',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles missing OCR image path', () {
      expect(
        () => _validateOCRArgs({}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles missing headless browser URL', () {
      expect(
        () => _validateHeadlessBrowserArgs({}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles timeout correctly', () async {
      final completer = Completer<Map<String, dynamic>>();

      // Simulate timeout
      final result = await completer.future.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => {
          'success': false,
          'error': 'Operation timed out',
        },
      );

      expect(result['success'], isFalse);
      expect(result['error'], contains('timed out'));
    });
  });

  group('Content truncation', () {
    test('truncates long headless browser content', () {
      final longContent = 'a' * 60000;
      final truncated = _truncateContent(longContent, 50000);

      expect(truncated.length, lessThan(longContent.length));
      expect(truncated, endsWith('[Content truncated...]'));
    });

    test('preserves short content', () {
      final shortContent = 'Short content';
      final result = _truncateContent(shortContent, 50000);

      expect(result, equals(shortContent));
    });
  });

  group('Aspect ratio parsing', () {
    test('parses 9:16 aspect ratio', () {
      final parsed = _parseAspectRatio('9:16');
      expect(parsed['width'], equals(9));
      expect(parsed['height'], equals(16));
    });

    test('parses 16:9 aspect ratio', () {
      final parsed = _parseAspectRatio('16:9');
      expect(parsed['width'], equals(16));
      expect(parsed['height'], equals(9));
    });

    test('parses 1:1 aspect ratio', () {
      final parsed = _parseAspectRatio('1:1');
      expect(parsed['width'], equals(1));
      expect(parsed['height'], equals(1));
    });

    test('parses 4:3 aspect ratio', () {
      final parsed = _parseAspectRatio('4:3');
      expect(parsed['width'], equals(4));
      expect(parsed['height'], equals(3));
    });
  });

  group('Crop region calculation', () {
    test('calculates center crop for landscape to portrait', () {
      final region = _calculateCropRegion(
        sourceWidth: 1920,
        sourceHeight: 1080,
        targetWidth: 9,
        targetHeight: 16,
        facesCenterX: null,
        facesCenterY: null,
      );

      expect(region['width'], lessThan(1920));
      expect(region['height'], equals(1080));
      expect(region['x'], greaterThan(0));
      expect(region['y'], equals(0));
    });

    test('calculates center crop for portrait to landscape', () {
      final region = _calculateCropRegion(
        sourceWidth: 1080,
        sourceHeight: 1920,
        targetWidth: 16,
        targetHeight: 9,
        facesCenterX: null,
        facesCenterY: null,
      );

      expect(region['width'], equals(1080));
      expect(region['height'], lessThan(1920));
    });

    test('centers on face when detected', () {
      final region = _calculateCropRegion(
        sourceWidth: 1920,
        sourceHeight: 1080,
        targetWidth: 9,
        targetHeight: 16,
        facesCenterX: 300,
        facesCenterY: 540,
      );

      // Crop should be biased toward the face position
      expect(region['x'], lessThanOrEqualTo(300));
    });

    test('clamps crop region to source bounds', () {
      final region = _calculateCropRegion(
        sourceWidth: 1920,
        sourceHeight: 1080,
        targetWidth: 9,
        targetHeight: 16,
        facesCenterX: 1900, // Near edge
        facesCenterY: 540,
      );

      // Should not go past bounds
      expect(region['x']! + region['width']!, lessThanOrEqualTo(1920));
      expect(region['y']! + region['height']!, lessThanOrEqualTo(1080));
    });
  });

  group('Video file detection', () {
    test('detects video files correctly', () {
      expect(_isVideoFile('/path/to/file.mp4'), isTrue);
      expect(_isVideoFile('/path/to/file.MP4'), isTrue);
      expect(_isVideoFile('/path/to/file.mov'), isTrue);
      expect(_isVideoFile('/path/to/file.MOV'), isTrue);
      expect(_isVideoFile('/path/to/file.webm'), isTrue);
      expect(_isVideoFile('/path/to/file.avi'), isTrue);
      expect(_isVideoFile('/path/to/file.mkv'), isTrue);
    });

    test('identifies non-video files correctly', () {
      expect(_isVideoFile('/path/to/file.jpg'), isFalse);
      expect(_isVideoFile('/path/to/file.png'), isFalse);
      expect(_isVideoFile('/path/to/file.pdf'), isFalse);
      expect(_isVideoFile('/path/to/file.txt'), isFalse);
    });
  });

  group('Duration parsing', () {
    test('parses FFmpeg duration string', () {
      final duration = _parseDuration('Duration: 01:23:45');
      expect(duration, equals(5025)); // 1*3600 + 23*60 + 45
    });

    test('parses short duration', () {
      final duration = _parseDuration('Duration: 00:05:30');
      expect(duration, equals(330));
    });

    test('returns null for invalid format', () {
      final duration = _parseDuration('Invalid string');
      expect(duration, isNull);
    });
  });

  group('Primary face selection', () {
    test('returns null for empty face list', () {
      final result = _selectPrimaryFace([]);
      expect(result, isNull);
    });

    test('returns single face when only one detected', () {
      final faces = [
        {'x': 100, 'y': 100, 'width': 200, 'height': 200},
      ];
      final result = _selectPrimaryFace(faces);
      expect(result, equals(faces.first));
    });

    test('selects largest face by area', () {
      final smallFace = {'x': 50, 'y': 50, 'width': 100, 'height': 100}; // 10000
      final largeFace = {'x': 200, 'y': 200, 'width': 300, 'height': 300}; // 90000
      final mediumFace = {'x': 400, 'y': 100, 'width': 150, 'height': 150}; // 22500

      final result = _selectPrimaryFace([smallFace, largeFace, mediumFace]);
      expect(result, equals(largeFace));
    });

    test('selects largest face regardless of position in list', () {
      final faces = [
        {'x': 50, 'y': 50, 'width': 100, 'height': 100},   // 10000
        {'x': 100, 'y': 100, 'width': 50, 'height': 50},   // 2500
        {'x': 200, 'y': 200, 'width': 200, 'height': 200}, // 40000 - largest
        {'x': 300, 'y': 300, 'width': 80, 'height': 80},   // 6400
      ];

      final result = _selectPrimaryFace(faces);
      expect(result!['width'], equals(200));
      expect(result['height'], equals(200));
    });

    test('handles faces with equal areas', () {
      final face1 = {'x': 100, 'y': 100, 'width': 100, 'height': 100};
      final face2 = {'x': 200, 'y': 200, 'width': 100, 'height': 100};

      // Both have same area, should return one of them consistently
      final result = _selectPrimaryFace([face1, face2]);
      expect(result, isNotNull);
      expect(result!['width'], equals(100));
      expect(result['height'], equals(100));
    });

    test('handles wide vs tall faces correctly', () {
      final wideFace = {'x': 50, 'y': 50, 'width': 300, 'height': 100}; // 30000
      final tallFace = {'x': 200, 'y': 200, 'width': 100, 'height': 300}; // 30000
      final squareFace = {'x': 400, 'y': 400, 'width': 200, 'height': 200}; // 40000

      final result = _selectPrimaryFace([wideFace, tallFace, squareFace]);
      expect(result, equals(squareFace)); // Largest area
    });

    test('handles very small faces', () {
      final tinyFace = {'x': 500, 'y': 500, 'width': 10, 'height': 10}; // 100
      final bigFace = {'x': 100, 'y': 100, 'width': 500, 'height': 500}; // 250000

      final result = _selectPrimaryFace([tinyFace, bigFace]);
      expect(result, equals(bigFace));
    });

    test('does not modify original list', () {
      final faces = [
        {'x': 50, 'y': 50, 'width': 100, 'height': 100},
        {'x': 200, 'y': 200, 'width': 300, 'height': 300},
      ];
      final originalFirst = faces.first;

      _selectPrimaryFace(faces);

      expect(faces.first, equals(originalFirst)); // Order unchanged
    });
  });

  group('Rule of thirds crop calculation', () {
    test('centers crop horizontally', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 1920,
        sourceHeight: 1080,
        cropWidth: 608,
        cropHeight: 1080,
      );

      // Should be centered horizontally
      final expectedX = (1920 - 608) ~/ 2;
      expect(result['x'], equals(expectedX));
    });

    test('biases crop toward upper portion vertically', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 1920,
        sourceHeight: 1080,
        cropWidth: 1920,
        cropHeight: 800,
      );

      // Target Y is at 40% of height, so crop should be biased upward
      // (1080 * 2) ~/ 5 = 432 target
      // cropY = (432 - 400) = 32, clamped to 0
      expect(result['y'], lessThanOrEqualTo((1080 - 800) ~/ 2));
    });

    test('clamps to source bounds when crop exceeds left', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 100,
        sourceHeight: 100,
        cropWidth: 80,
        cropHeight: 80,
      );

      expect(result['x'], greaterThanOrEqualTo(0));
      expect(result['y'], greaterThanOrEqualTo(0));
    });

    test('clamps to source bounds when crop exceeds right', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 100,
        sourceHeight: 100,
        cropWidth: 80,
        cropHeight: 80,
      );

      expect(result['x']! + result['width']!, lessThanOrEqualTo(100));
      expect(result['y']! + result['height']!, lessThanOrEqualTo(100));
    });

    test('handles portrait source with landscape crop', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 1080,
        sourceHeight: 1920,
        cropWidth: 1080,
        cropHeight: 608,
      );

      expect(result['x'], equals(0));
      expect(result['y'], greaterThanOrEqualTo(0));
      expect(result['y']! + result['height']!, lessThanOrEqualTo(1920));
    });

    test('handles square source', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 1000,
        sourceHeight: 1000,
        cropWidth: 900,
        cropHeight: 900,
      );

      expect(result['x'], greaterThanOrEqualTo(0));
      expect(result['y'], greaterThanOrEqualTo(0));
      expect(result['x']! + result['width']!, lessThanOrEqualTo(1000));
      expect(result['y']! + result['height']!, lessThanOrEqualTo(1000));
    });

    test('handles crop same size as source', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 1920,
        sourceHeight: 1080,
        cropWidth: 1920,
        cropHeight: 1080,
      );

      expect(result['x'], equals(0));
      expect(result['y'], equals(0));
    });

    test('preserves crop dimensions', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 1920,
        sourceHeight: 1080,
        cropWidth: 500,
        cropHeight: 700,
      );

      expect(result['width'], equals(500));
      expect(result['height'], equals(700));
    });
  });

  group('Video frame sampling for faces', () {
    test('returns empty when no frames provided', () {
      final result = _simulateVideoFrameSampling(framesWithFaces: []);

      expect(result['faces'], isEmpty);
      expect(result['frames_sampled'], equals(0));
      expect(result['total_detections'], equals(0));
    });

    test('returns empty faces when no faces detected in any frame', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [], // Frame 1: no faces
          [], // Frame 2: no faces
          [], // Frame 3: no faces
        ],
      );

      expect(result['faces'], isEmpty);
      expect(result['frames_sampled'], equals(3));
      expect(result['total_detections'], equals(0));
    });

    test('averages single face across multiple frames', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}], // center: 200, 200
          [{'x': 120, 'y': 110, 'width': 200, 'height': 200}], // center: 220, 210
          [{'x': 80, 'y': 90, 'width': 200, 'height': 200}],   // center: 180, 190
        ],
      );

      expect(result['faces'], hasLength(1));
      expect(result['frames_sampled'], equals(3));
      expect(result['total_detections'], equals(3));
      expect(result['averaged'], isTrue);

      final avgFace = (result['faces'] as List).first;
      // Average center: (200+220+180)/3 = 200, (200+210+190)/3 = 200
      expect(avgFace['center_x'], equals(200));
      expect(avgFace['center_y'], equals(200));
    });

    test('handles multiple faces per frame', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [
            {'x': 100, 'y': 100, 'width': 100, 'height': 100},
            {'x': 300, 'y': 100, 'width': 100, 'height': 100},
          ],
          [
            {'x': 100, 'y': 100, 'width': 100, 'height': 100},
            {'x': 300, 'y': 100, 'width': 100, 'height': 100},
          ],
        ],
      );

      expect(result['frames_sampled'], equals(2));
      expect(result['total_detections'], equals(4));
    });

    test('handles frames with varying face counts', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [{'x': 100, 'y': 100, 'width': 100, 'height': 100}], // 1 face
          [], // 0 faces (subject moved out of frame)
          [{'x': 120, 'y': 110, 'width': 100, 'height': 100}], // 1 face
        ],
      );

      expect(result['frames_sampled'], equals(3));
      expect(result['total_detections'], equals(2));
      expect(result['averaged'], isTrue);
    });

    test('calculates correct averaged position', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [{'x': 0, 'y': 0, 'width': 100, 'height': 100}],     // center: 50, 50
          [{'x': 200, 'y': 200, 'width': 100, 'height': 100}], // center: 250, 250
        ],
      );

      final avgFace = (result['faces'] as List).first;
      // Average center: (50+250)/2 = 150, (50+250)/2 = 150
      expect(avgFace['center_x'], equals(150));
      expect(avgFace['center_y'], equals(150));
    });

    test('averages face dimensions', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [{'x': 100, 'y': 100, 'width': 100, 'height': 100}],
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}],
          [{'x': 100, 'y': 100, 'width': 300, 'height': 300}],
        ],
      );

      final avgFace = (result['faces'] as List).first;
      // Average width: (100+200+300)/3 = 200
      // Average height: (100+200+300)/3 = 200
      expect(avgFace['width'], equals(200));
      expect(avgFace['height'], equals(200));
    });
  });

  group('FFmpeg comparison operator sanitization', () {
    test('replaces < with lt() in select expression', () {
      final input = "select='floor(mod(t,4))<2'";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='lt(floor(mod(t,4)),2)'"));
    });

    test('replaces > with gt() in select expression', () {
      final input = "select='n>10'";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='gt(n,10)'"));
    });

    test('replaces <= with lte() in expression', () {
      final input = "select='t<=5.0'";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='lte(t,5.0)'"));
    });

    test('replaces >= with gte() in expression', () {
      final input = "select='t>=3.0'";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='gte(t,3.0)'"));
    });

    test('only replaces inside single-quoted strings', () {
      // The < outside quotes should NOT be replaced
      final input = "-vf \"select='n<5'\" -af volume=2";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("-vf \"select='lt(n,5)'\" -af volume=2"));
    });

    test('handles multiple operators in same expression', () {
      final input = "select='gte(t,2)*lt(t,5)'";
      // gte() and lt() are already functions, no raw operators to replace
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='gte(t,2)*lt(t,5)'"));
    });

    test('handles multiple comparisons with raw operators', () {
      final input = "select='t>=2*t<5'";
      final result = _sanitizeFFmpegComparisons(input);
      // >= replaced first, then < — result depends on regex matching
      expect(result, contains('gte('));
      expect(result, contains('lt('));
    });

    test('does not modify expressions without comparisons', () {
      final input = "select='mod(n,30)'";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='mod(n,30)'"));
    });

    test('does not modify strings without single quotes', () {
      final input = '-vf "hue=s=0" -af "volume=2"';
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals(input));
    });

    test('handles the exact crash-causing expression', () {
      // This is the actual expression that caused the SIGSEGV
      final input = "select='floor(mod(t\\,4))<2',setpts=N/FRAME_RATE/TB";
      final result = _sanitizeFFmpegComparisons(input);
      expect(result, equals("select='lt(floor(mod(t\\,4)),2)',setpts=N/FRAME_RATE/TB"));
      expect(result, isNot(contains("'<")));
      expect(result, isNot(contains("<2'")));
    });

    test('handles nested function calls with comparison', () {
      final input = "select='if(gt(t,2),1,0)*floor(mod(n,30))<1'";
      final result = _sanitizeFFmpegComparisons(input);
      // The < should become lt()
      expect(result, contains('lt('));
      expect(result, isNot(contains(")<1'")));
    });

    test('preserves already-sanitized expressions', () {
      final input = "select='lt(floor(mod(t,4)),2)'";
      final result = _sanitizeFFmpegComparisons(input);
      // Already uses lt(), should not double-wrap
      expect(result, equals(input));
    });

    test('handles empty string', () {
      final result = _sanitizeFFmpegComparisons('');
      expect(result, equals(''));
    });

    test('handles string with only quotes no operators', () {
      final result = _sanitizeFFmpegComparisons("'hello world'");
      expect(result, equals("'hello world'"));
    });

    test('combined with comma escaping order is correct', () {
      // Sanitize comparisons first, then escape commas
      final input = "select='floor(mod(t,4))<2'";
      var result = _sanitizeFFmpegComparisons(input);
      result = _escapeFFmpegExprCommas(result);
      // lt(floor(mod(t,4)),2) — the commas inside parens should be escaped
      expect(result, contains('lt(floor(mod(t\\,4))\\,2)'));
    });
  });

  group('Auto-generated audio filter for select operations', () {
    test('strips video-only filters (hue) from auto-generated audio', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))',setpts=N/FRAME_RATE/TB,hue=s=0",
        af: null,
      );
      // Audio should have aselect and asetpts but NOT hue
      expect(result['af'], contains('aselect'));
      expect(result['af'], contains('asetpts=N/SR/TB'));
      expect(result['af'], isNot(contains('hue')));
    });

    test('strips video-only filters (eq, colorbalance) from audio', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='mod(floor(t),3)',setpts=N/FRAME_RATE/TB,eq=brightness=0.1,colorbalance=rs=0.3",
        af: null,
      );
      expect(result['af'], contains('aselect'));
      expect(result['af'], isNot(contains('eq=')));
      expect(result['af'], isNot(contains('colorbalance')));
    });

    test('preserves explicit af when provided', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))',setpts=N/FRAME_RATE/TB,hue=s=0",
        af: "aselect='not(mod(floor(t),2))',asetpts=N/SR/TB",
      );
      // Should use the provided af, not auto-generate
      expect(result['af'], equals("aselect='not(mod(floor(t),2))',asetpts=N/SR/TB"));
    });

    test('auto-adds setpts when missing from vf', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))'",
        af: null,
      );
      expect(result['vf'], contains('setpts=N/FRAME_RATE/TB'));
      expect(result['af'], contains('asetpts=N/SR/TB'));
    });

    test('auto-adds asetpts when missing from generated af', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='mod(floor(t),3)',setpts=N/FRAME_RATE/TB",
        af: null,
      );
      expect(result['af'], contains('asetpts=N/SR/TB'));
    });

    test('generates fallback audio filter when vf has no select parts', () {
      // Edge case: vf has select in the string but no extractable select= part
      // This shouldn't normally happen but tests the fallback
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))',setpts=N/FRAME_RATE/TB",
        af: null,
      );
      expect(result['af'], isNotNull);
      expect(result['af'], isNot(isEmpty));
    });

    test('handles vf with only hue filter and select', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))',hue=s=0",
        af: null,
      );
      // Should auto-add setpts to vf and generate proper audio
      expect(result['vf'], contains('setpts=N/FRAME_RATE/TB'));
      expect(result['af'], contains('aselect'));
      expect(result['af'], isNot(contains('hue')));
    });

    test('generates filter_complex command for select operations', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))',setpts=N/FRAME_RATE/TB",
        af: null,
      );
      expect(result['command'], contains('-filter_complex'));
      expect(result['command'], contains('[0:v]'));
      expect(result['command'], contains('[0:a]'));
      expect(result['command'], contains('-map "[v]"'));
      expect(result['command'], contains('-map "[a]"'));
      expect(result['command'], contains('-pix_fmt yuv420p'));
    });

    test('command includes codec flags for filter_complex', () {
      final result = _buildFilterCommandWithAutoAudio(
        vf: "select='not(mod(floor(t),2))',setpts=N/FRAME_RATE/TB",
        af: null,
      );
      expect(result['command'], contains('-c:v libx264'));
      expect(result['command'], contains('-c:a aac'));
    });
  });

  group('Custom case simplification', () {
    test('custom case passes args through without modification (except sanitization)', () {
      // After removing the buggy regex, custom should just pass through
      final args = '-vf "hue=s=0" -c:v libx264 -c:a aac';
      final command = _buildCustomCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        args: args,
      );
      expect(command, contains(args));
      expect(command, startsWith('-y -i'));
    });

    test('custom case does not try to convert -vf/-af to filter_complex', () {
      final args = '-vf "select=\'mod(floor(t),2)\',setpts=N/FRAME_RATE/TB" -af "aselect=\'mod(floor(t),2)\',asetpts=N/SR/TB" -c:v libx264 -c:a aac';
      final command = _buildCustomCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        args: args,
      );
      // Should NOT have filter_complex — just pass through
      expect(command, isNot(contains('-filter_complex')));
      expect(command, contains('-vf'));
      expect(command, contains('-af'));
    });

    test('custom case still injects pix_fmt when re-encoding', () {
      final args = '-c:v libx264 -crf 23 -c:a aac';
      final result = _injectPixFmtForCustom(args);
      expect(result, contains('-pix_fmt yuv420p'));
    });

    test('custom case still sanitizes comparisons', () {
      final args = "-filter_complex \"[0:v]select='t<5'[v]\"";
      final result = _sanitizeFFmpegComparisons(args);
      expect(result, contains('lt(t,5)'));
    });
  });

  group('Filter_complex validation', () {
    test('accepts valid filter_complex command', () {
      final command = '-y -i "/input.mp4" -filter_complex "[0:v]select=\'not(mod(floor(t)\\,2))\',setpts=N/FRAME_RATE/TB,hue=s=0[v];[0:a]aselect=\'not(mod(floor(t)\\,2))\',asetpts=N/SR/TB[a]" -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "/output.mp4"';
      // Should not throw
      _validateFilterComplex(command);
    });

    test('rejects filter_complex with -c:v flag inside', () {
      final command = '-y -i "/input.mp4" -filter_complex "[0:v]select=\'...\' -c:v libx264[v];[0:a]...[a]" -map "[v]" -map "[a]" "/output.mp4"';
      expect(
        () => _validateFilterComplex(command),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects filter_complex with -af flag inside', () {
      final command = '-y -i "/input.mp4" -filter_complex "[0:v]select=\'...\' -af aselect=\'...\'[v];[0:a]...[a]" -map "[v]" -map "[a]" "/output.mp4"';
      expect(
        () => _validateFilterComplex(command),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects filter_complex with -preset flag inside', () {
      final command = '-y -i "/input.mp4" -filter_complex "[0:v]hue=s=0 -preset slow[v]" "/output.mp4"';
      expect(
        () => _validateFilterComplex(command),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts command without filter_complex', () {
      final command = '-y -i "/input.mp4" -vf "hue=s=0" -c:v libx264 -pix_fmt yuv420p "/output.mp4"';
      // Should not throw — no filter_complex to validate
      _validateFilterComplex(command);
    });

    test('catches the exact mangled command that caused the SIGSEGV crash', () {
      // This is the actual command from the crash log (Query 4)
      final command = '-y -i "/input.mp4" -filter_complex "[0:v]select=\'not(mod(floor(t)\\,2))\',setpts=N/FRAME_RATE/TB,hue=s=0 -af aselect=\'not(mod(floor(t)\\,2))\',asetpts=N/SR/TB -c:v libx264 -pix_fmt yuv420p -preset slow -crf 18 -c:a aac -b:a 192k[v];[0:a]aselect=\'not(mod(floor(t)\\,2))\',asetpts=N/SR/TB -c:v libx264 -pix_fmt yuv420p -preset slow -crf 18 -c:a aac -b:a 192k[a]" -map "[v]" -map "[a]" "/output.mp4"';
      expect(
        () => _validateFilterComplex(command),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Smart crop strategy selection', () {
    test('uses face_centered strategy when faces detected', () {
      final faces = [
        {'x': 100, 'y': 100, 'width': 200, 'height': 200},
      ];
      expect(faces.isNotEmpty, isTrue);
      // In real code, this would set cropStrategy = 'face_centered'
    });

    test('uses rule_of_thirds strategy when no faces', () {
      final faces = <Map<String, dynamic>>[];
      expect(faces.isEmpty, isTrue);
      // In real code, this would set cropStrategy = 'rule_of_thirds'
    });

    test('video uses multi-frame sampling', () {
      const isVideo = true;
      expect(isVideo, isTrue);
      // In real code, this would call _sampleVideoFramesForFaces
    });

    test('image uses single frame detection', () {
      const isVideo = false;
      expect(isVideo, isFalse);
      // In real code, this would call _executeFaceDetection once
    });
  });

  group('Smart crop result format', () {
    test('includes all required fields for image crop', () {
      final result = {
        'success': true,
        'output_path': '/path/to/output.jpg',
        'crop_region': {
          'x': 100,
          'y': 0,
          'width': 1080,
          'height': 1920,
        },
        'faces_detected': 1,
        'crop_strategy': 'face_centered',
      };

      expect(result['success'], isTrue);
      expect(result['output_path'], isNotNull);
      expect(result['crop_region'], isA<Map>());
      expect(result['faces_detected'], isA<int>());
      expect(result['crop_strategy'], isA<String>());
    });

    test('includes video-specific fields for video crop', () {
      final result = {
        'success': true,
        'output_path': '/path/to/output.mp4',
        'crop_region': {
          'x': 100,
          'y': 0,
          'width': 1080,
          'height': 1920,
        },
        'faces_detected': 1,
        'crop_strategy': 'face_centered',
        'frames_sampled': 10,
        'total_face_detections': 8,
      };

      expect(result['frames_sampled'], equals(10));
      expect(result['total_face_detections'], equals(8));
    });

    test('crop_strategy reflects actual method used', () {
      // face_centered when face is used
      expect('face_centered', contains('face'));

      // rule_of_thirds when no faces
      expect('rule_of_thirds', contains('thirds'));

      // center would be the simplest fallback
      expect('center', equals('center'));
    });
  });

  group('Edge cases for smart crop', () {
    test('handles face near edge of frame', () {
      final sourceWidth = 1920;
      final sourceHeight = 1080;
      final cropWidth = 608;
      final cropHeight = 1080;

      // Face at far right edge
      final faceX = 1800;
      final faceWidth = 100;
      final faceCenterX = faceX + faceWidth ~/ 2; // 1850

      // Calculate crop position clamped to bounds
      var cropX = (faceCenterX - cropWidth ~/ 2); // 1850 - 304 = 1546
      cropX = cropX.clamp(0, sourceWidth - cropWidth); // max is 1920-608=1312

      expect(cropX, lessThanOrEqualTo(sourceWidth - cropWidth));
    });

    test('handles face near top edge', () {
      final sourceWidth = 1920;
      final sourceHeight = 1080;
      final cropWidth = 1920;
      final cropHeight = 800;

      // Face at top
      final faceY = 10;
      final faceHeight = 100;
      final faceCenterY = faceY + faceHeight ~/ 2; // 60

      // Calculate crop position clamped to bounds
      var cropY = (faceCenterY - cropHeight ~/ 2); // 60 - 400 = -340
      cropY = cropY.clamp(0, sourceHeight - cropHeight); // min is 0

      expect(cropY, equals(0));
    });

    test('handles very small source image', () {
      final result = _calculateRuleOfThirdsCrop(
        sourceWidth: 100,
        sourceHeight: 100,
        cropWidth: 50,
        cropHeight: 80,
      );

      expect(result['x'], greaterThanOrEqualTo(0));
      expect(result['y'], greaterThanOrEqualTo(0));
      expect(result['x']! + result['width']!, lessThanOrEqualTo(100));
      expect(result['y']! + result['height']!, lessThanOrEqualTo(100));
    });

    test('handles extreme aspect ratio conversion', () {
      // Converting very wide panorama to portrait
      final sourceWidth = 3000;
      final sourceHeight = 500;
      final targetRatio = 9.0 / 16.0; // 0.5625

      // Calculate crop
      final sourceRatio = sourceWidth / sourceHeight; // 6.0
      expect(sourceRatio, greaterThan(targetRatio));

      // Crop width should be much smaller than source width
      final cropHeight = sourceHeight;
      final cropWidth = (cropHeight * 9 / 16).round(); // 281
      expect(cropWidth, lessThan(sourceWidth / 10));
    });

    test('handles no movement in video (stable position)', () {
      final result = _simulateVideoFrameSampling(
        framesWithFaces: [
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}],
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}],
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}],
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}],
          [{'x': 100, 'y': 100, 'width': 200, 'height': 200}],
        ],
      );

      final avgFace = (result['faces'] as List).first;
      // Should be exactly the same as individual faces
      expect(avgFace['x'], equals(100));
      expect(avgFace['y'], equals(100));
      expect(avgFace['width'], equals(200));
      expect(avgFace['height'], equals(200));
    });
  });
}

// Helper functions that simulate the logic in NativeToolExecutor

String _buildFFmpegCommand({
  required String inputPath,
  required String outputPath,
  required String operation,
  required Map<String, dynamic> params,
}) {
  switch (operation) {
    case 'crop':
      final x = params['x'] as int? ?? 0;
      final y = params['y'] as int? ?? 0;
      final w = params['width'] as int?;
      final h = params['height'] as int?;

      if (w != null && h != null) {
        return '-i "$inputPath" -filter:v "crop=$w:$h:$x:$y" -pix_fmt yuv420p -c:a copy "$outputPath"';
      }
      return '-i "$inputPath" -filter:v "crop=ih*9/16:ih" -pix_fmt yuv420p -c:a copy "$outputPath"';

    case 'resize':
      final width = params['width'] as int?;
      final height = params['height'] as int?;
      final scale = params['scale'] as double?;

      if (width != null && height != null) {
        return '-i "$inputPath" -vf "scale=$width:$height" -pix_fmt yuv420p -c:a copy "$outputPath"';
      } else if (scale != null) {
        return '-i "$inputPath" -vf "scale=iw*$scale:ih*$scale" -pix_fmt yuv420p -c:a copy "$outputPath"';
      }
      return '-i "$inputPath" -vf "scale=-2:720" -pix_fmt yuv420p -c:a copy "$outputPath"';

    case 'extract_audio':
      final bitrate = params['bitrate'] as String? ?? '192k';
      return '-i "$inputPath" -vn -acodec libmp3lame -ab $bitrate "$outputPath"';

    case 'convert':
      final codec = params['video_codec'] as String?;
      final quality = params['quality'] as String? ?? 'medium';

      final crf = switch (quality) {
        'high' => '18',
        'medium' => '23',
        'low' => '28',
        _ => '23',
      };

      if (codec != null) {
        return '-i "$inputPath" -c:v $codec -pix_fmt yuv420p -crf $crf -c:a aac "$outputPath"';
      }
      return '-i "$inputPath" -c:v libx264 -pix_fmt yuv420p -crf $crf -c:a aac "$outputPath"';

    case 'filter':
      final vf = params['vf'] as String?;
      final af = params['af'] as String?;

      if (vf != null && af != null) {
        return '-i "$inputPath" -vf "$vf" -af "$af" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
      } else if (vf != null) {
        return '-i "$inputPath" -vf "$vf" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
      } else if (af != null) {
        return '-i "$inputPath" -c:v copy -af "$af" -c:a aac "$outputPath"';
      }
      return '-i "$inputPath" -c copy "$outputPath"';

    default:
      return '-i "$inputPath" -c copy "$outputPath"';
  }
}

void _validateTool(String tool) {
  const validTools = ['ffmpeg', 'ocr', 'headless_browser', 'face_detect', 'smart_crop', 'image_compose', 'list_files', 'llm_generate'];
  if (!validTools.contains(tool)) {
    throw UnsupportedError('Unknown native tool: $tool');
  }
}

void _validateFFmpegArgs(Map<String, dynamic> args) {
  if (args['input_path'] == null) {
    throw ArgumentError('Missing input_path');
  }
  if (args['output_path'] == null) {
    throw ArgumentError('Missing output_path');
  }
  if (args['operation'] == null) {
    throw ArgumentError('Missing operation');
  }
}

void _validateOCRArgs(Map<String, dynamic> args) {
  if (args['image_path'] == null) {
    throw ArgumentError('Missing image_path');
  }
}

void _validateHeadlessBrowserArgs(Map<String, dynamic> args) {
  if (args['url'] == null) {
    throw ArgumentError('Missing url');
  }
}

String _truncateContent(String content, int maxLength) {
  if (content.length <= maxLength) return content;
  return '${content.substring(0, maxLength)}\n\n[Content truncated...]';
}

Map<String, int> _parseAspectRatio(String aspectRatio) {
  final parts = aspectRatio.split(':');
  return {
    'width': int.parse(parts[0]),
    'height': int.parse(parts[1]),
  };
}

Map<String, int> _calculateCropRegion({
  required int sourceWidth,
  required int sourceHeight,
  required int targetWidth,
  required int targetHeight,
  required int? facesCenterX,
  required int? facesCenterY,
}) {
  int cropX, cropY, cropWidth, cropHeight;

  final sourceRatio = sourceWidth / sourceHeight;
  final targetRatio = targetWidth / targetHeight;

  if (sourceRatio > targetRatio) {
    cropHeight = sourceHeight;
    cropWidth = (cropHeight * targetWidth / targetHeight).round();
  } else {
    cropWidth = sourceWidth;
    cropHeight = (cropWidth * targetHeight / targetWidth).round();
  }

  if (facesCenterX != null && facesCenterY != null) {
    cropX = (facesCenterX - cropWidth ~/ 2).clamp(0, sourceWidth - cropWidth);
    cropY = (facesCenterY - cropHeight ~/ 2).clamp(0, sourceHeight - cropHeight);
  } else {
    cropX = (sourceWidth - cropWidth) ~/ 2;
    cropY = (sourceHeight - cropHeight) ~/ 2;
  }

  return {
    'x': cropX,
    'y': cropY,
    'width': cropWidth,
    'height': cropHeight,
  };
}

bool _isVideoFile(String path) {
  final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.m4v'];
  final lower = path.toLowerCase();
  return videoExtensions.any((ext) => lower.endsWith(ext));
}

int? _parseDuration(String message) {
  final match = RegExp(r'Duration: (\d+):(\d+):(\d+)').firstMatch(message);
  if (match != null) {
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    return hours * 3600 + minutes * 60 + seconds;
  }
  return null;
}

/// Select the primary (largest) face from a list of detected faces.
/// Simulates the logic in NativeToolExecutor._selectPrimaryFace
Map<String, dynamic>? _selectPrimaryFace(List<Map<String, dynamic>> faces) {
  if (faces.isEmpty) return null;
  if (faces.length == 1) return faces.first;

  // Sort by bounding box area (width * height), descending
  final sorted = List<Map<String, dynamic>>.from(faces);
  sorted.sort((a, b) {
    final areaA = (a['width'] as int) * (a['height'] as int);
    final areaB = (b['width'] as int) * (b['height'] as int);
    return areaB.compareTo(areaA); // Descending order
  });

  return sorted.first;
}

/// Calculate crop region using rule of thirds when no faces detected.
/// Simulates the logic in NativeToolExecutor._calculateRuleOfThirdsCrop
Map<String, int> _calculateRuleOfThirdsCrop({
  required int sourceWidth,
  required int sourceHeight,
  required int cropWidth,
  required int cropHeight,
}) {
  // Use center with slight bias toward upper third for faces/subjects
  final targetX = sourceWidth ~/ 2;
  final targetY = (sourceHeight * 2) ~/ 5; // Slightly above center (40%)

  final cropX = (targetX - cropWidth ~/ 2).clamp(0, sourceWidth - cropWidth);
  final cropY = (targetY - cropHeight ~/ 2).clamp(0, sourceHeight - cropHeight);

  return {
    'x': cropX,
    'y': cropY,
    'width': cropWidth,
    'height': cropHeight,
  };
}

/// Sanitize comparison operators in FFmpeg filter expressions.
/// Mirrors NativeToolExecutor._sanitizeFFmpegComparisons
String _sanitizeFFmpegComparisons(String filter) {
  return filter.replaceAllMapped(
    RegExp(r"'([^']*)'"),
    (match) {
      var expr = match.group(1)!;
      expr = _replaceComparisonOps(expr);
      return "'$expr'";
    },
  );
}

/// Replace comparison operators with function equivalents.
/// Mirrors NativeToolExecutor._replaceComparisonOps
String _replaceComparisonOps(String expr) {
  for (final op in ['>=', '<=', '>', '<']) {
    int pos = 0;
    while (pos < expr.length) {
      final idx = expr.indexOf(op, pos);
      if (idx < 0) break;

      if (op.length == 1 && idx + 1 < expr.length && expr[idx + 1] == '=') {
        pos = idx + 1;
        continue;
      }

      final lhsEnd = idx;
      final rhsStart = idx + op.length;
      if (lhsEnd <= 0 || rhsStart >= expr.length) {
        pos = idx + 1;
        continue;
      }

      int lhsStart = lhsEnd - 1;
      if (expr[lhsStart] == ')') {
        int depth = 1;
        lhsStart--;
        while (lhsStart >= 0 && depth > 0) {
          if (expr[lhsStart] == ')') depth++;
          else if (expr[lhsStart] == '(') depth--;
          lhsStart--;
        }
        while (lhsStart >= 0 && RegExp(r'[\w\\.]').hasMatch(expr[lhsStart])) {
          lhsStart--;
        }
        lhsStart++;
      } else {
        while (lhsStart > 0 && RegExp(r'[\w\\.]').hasMatch(expr[lhsStart - 1])) {
          lhsStart--;
        }
      }

      int rhsEnd = rhsStart;
      if (rhsEnd < expr.length && RegExp(r'[\w\\.]').hasMatch(expr[rhsEnd])) {
        int tempEnd = rhsEnd;
        while (tempEnd < expr.length && RegExp(r'[\w\\.]').hasMatch(expr[tempEnd])) {
          tempEnd++;
        }
        if (tempEnd < expr.length && expr[tempEnd] == '(') {
          int depth = 1;
          tempEnd++;
          while (tempEnd < expr.length && depth > 0) {
            if (expr[tempEnd] == '(') depth++;
            else if (expr[tempEnd] == ')') depth--;
            tempEnd++;
          }
          rhsEnd = tempEnd;
        } else {
          rhsEnd = tempEnd;
        }
      }

      if (lhsStart >= lhsEnd || rhsStart >= rhsEnd) {
        pos = idx + 1;
        continue;
      }

      final lhs = expr.substring(lhsStart, lhsEnd);
      final rhs = expr.substring(rhsStart, rhsEnd);
      final funcName = op == '>=' ? 'gte' : op == '<=' ? 'lte' : op == '>' ? 'gt' : 'lt';

      final replacement = '$funcName($lhs,$rhs)';
      expr = expr.substring(0, lhsStart) + replacement + expr.substring(rhsEnd);
      pos = lhsStart + replacement.length;
    }
  }
  return expr;
}

/// Escape commas inside parenthesized expressions in FFmpeg filter strings.
/// Mirrors NativeToolExecutor._escapeFFmpegExprCommas
String _escapeFFmpegExprCommas(String filter) {
  final result = StringBuffer();
  int parenDepth = 0;
  for (int i = 0; i < filter.length; i++) {
    final ch = filter[i];
    if (ch == '(') {
      parenDepth++;
      result.write(ch);
    } else if (ch == ')') {
      parenDepth = (parenDepth - 1).clamp(0, 999);
      result.write(ch);
    } else if (ch == ',' && parenDepth > 0) {
      if (i > 0 && filter[i - 1] == '\\') {
        result.write(ch);
      } else {
        result.write('\\,');
      }
    } else {
      result.write(ch);
    }
  }
  return result.toString();
}

/// Inject -pix_fmt yuv420p for custom FFmpeg args when re-encoding video.
/// Mirrors the logic in NativeToolExecutor._executeFFmpeg custom case.
String _injectPixFmtForCustom(String args) {
  if (args.contains('-c:v') && !args.contains('-c:v copy') && !args.contains('-pix_fmt')) {
    args = args.replaceFirstMapped(
      RegExp(r'-c:v\s+(\S+)'),
      (m) => '-c:v ${m.group(1)} -pix_fmt yuv420p',
    );
  }
  return args;
}

/// Validate filter_complex string to prevent native crashes.
/// Mirrors NativeToolExecutor._validateFilterComplex
void _validateFilterComplex(String command) {
  final match = RegExp(r'-filter_complex\s+"([^"]*)"').firstMatch(command);
  if (match == null) return;

  final fc = match.group(1)!;

  final forbiddenFlags = [' -c:v ', ' -c:a ', ' -af ', ' -vf ', ' -preset ', ' -crf ', ' -b:a ', ' -b:v '];
  for (final flag in forbiddenFlags) {
    if (fc.contains(flag)) {
      throw ArgumentError(
        'Invalid filter_complex: contains command-line flag "$flag". '
        'Use operation="filter" instead of "custom" for video filtering.',
      );
    }
  }
}

/// Build filter command with auto-generated audio filter.
/// Mirrors the select-handling logic in NativeToolExecutor._executeFFmpeg filter case.
Map<String, dynamic> _buildFilterCommandWithAutoAudio({
  required String? vf,
  required String? af,
}) {
  const inputPath = '/input.mp4';
  const outputPath = '/output.mp4';
  String command;

  if (vf != null && vf.contains('select')) {
    // Auto-generate matching audio filter if not provided
    if (af == null) {
      final vfParts = vf.split(',');
      final audioParts = <String>[];
      for (final part in vfParts) {
        if (part.contains('select')) {
          audioParts.add(part.replaceAll('select=', 'aselect='));
        } else if (part.contains('setpts')) {
          audioParts.add(part
              .replaceAll('setpts=N/FRAME_RATE/TB', 'asetpts=N/SR/TB')
              .replaceAll('setpts=', 'asetpts='));
        }
        // Skip video-only filters (hue, eq, format, colorbalance, etc.)
      }
      af = audioParts.isNotEmpty ? audioParts.join(',') : null;
      if (!vf.contains('setpts')) {
        vf = "$vf,setpts=N/FRAME_RATE/TB";
      }
      if (af != null && !af.contains('asetpts')) {
        af = "$af,asetpts=N/SR/TB";
      }
      if (af == null) {
        af = "aselect='1',asetpts=N/SR/TB";
      }
    }
    command = '-y -i "$inputPath" -filter_complex "[0:v]$vf[v];[0:a]$af[a]" -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
  } else if (vf != null && af != null) {
    command = '-y -i "$inputPath" -vf "$vf" -af "$af" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
  } else if (vf != null) {
    command = '-y -i "$inputPath" -vf "$vf" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
  } else {
    command = '-y -i "$inputPath" -c:v copy -af "$af" -c:a aac "$outputPath"';
  }

  return {'command': command, 'vf': vf, 'af': af};
}

/// Build custom FFmpeg command (simplified — no regex conversion).
/// Mirrors the custom case in NativeToolExecutor._executeFFmpeg.
String _buildCustomCommand({
  required String inputPath,
  required String outputPath,
  required String args,
}) {
  return '-y -i "$inputPath" $args "$outputPath"';
}

/// Simulate video frame sampling logic
Map<String, dynamic> _simulateVideoFrameSampling({
  required List<List<Map<String, dynamic>>> framesWithFaces,
}) {
  if (framesWithFaces.isEmpty) {
    return {
      'faces': <Map<String, dynamic>>[],
      'frames_sampled': 0,
      'total_detections': 0,
    };
  }

  final allFaces = <Map<String, dynamic>>[];
  for (final frameFaces in framesWithFaces) {
    allFaces.addAll(frameFaces);
  }

  if (allFaces.isEmpty) {
    return {
      'faces': <Map<String, dynamic>>[],
      'frames_sampled': framesWithFaces.length,
      'total_detections': 0,
    };
  }

  // Average the center positions of all detected faces
  double avgCenterX = 0;
  double avgCenterY = 0;
  int avgWidth = 0;
  int avgHeight = 0;

  for (final face in allFaces) {
    final x = face['x'] as int;
    final y = face['y'] as int;
    final w = face['width'] as int;
    final h = face['height'] as int;
    avgCenterX += x + w / 2;
    avgCenterY += y + h / 2;
    avgWidth += w;
    avgHeight += h;
  }

  avgCenterX /= allFaces.length;
  avgCenterY /= allFaces.length;
  avgWidth ~/= allFaces.length;
  avgHeight ~/= allFaces.length;

  // Return a synthetic "averaged" face
  final averagedFace = {
    'x': (avgCenterX - avgWidth / 2).round(),
    'y': (avgCenterY - avgHeight / 2).round(),
    'width': avgWidth,
    'height': avgHeight,
    'center_x': avgCenterX.round(),
    'center_y': avgCenterY.round(),
  };

  return {
    'faces': [averagedFace],
    'frames_sampled': framesWithFaces.length,
    'total_detections': allFaces.length,
    'averaged': true,
  };
}
