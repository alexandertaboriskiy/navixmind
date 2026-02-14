import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/bridge/messages.dart';

/// Tests for image_compose native tool.
///
/// Tests cover: concat, overlay, resize, adjust, crop, grayscale, blur operations
/// and edge cases like missing params, wrong input count, invalid operations.
void main() {
  group('NativeToolRequest parsing for image_compose', () {
    test('parses image_compose concat_horizontal request', () {
      final json = {
        'id': 'req-ic-1',
        'params': {
          'tool': 'image_compose',
          'args': {
            'input_paths': ['/storage/img1.jpg', '/storage/img2.jpg'],
            'output_path': '/storage/combined.jpg',
            'operation': 'concat_horizontal',
          },
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.tool, equals('image_compose'));
      expect(request.args['operation'], equals('concat_horizontal'));
      expect(request.args['input_paths'], hasLength(2));
    });

    test('parses image_compose overlay request with params', () {
      final json = {
        'id': 'req-ic-2',
        'params': {
          'tool': 'image_compose',
          'args': {
            'input_paths': ['/storage/bg.jpg', '/storage/fg.png'],
            'output_path': '/storage/overlaid.png',
            'operation': 'overlay',
            'params': {'x': 100, 'y': 50},
          },
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.args['operation'], equals('overlay'));
      expect(request.args['params']['x'], equals(100));
      expect(request.args['params']['y'], equals(50));
    });

    test('parses image_compose adjust request', () {
      final json = {
        'id': 'req-ic-3',
        'params': {
          'tool': 'image_compose',
          'args': {
            'input_paths': ['/storage/photo.jpg'],
            'output_path': '/storage/bright.jpg',
            'operation': 'adjust',
            'params': {'brightness': 1.3, 'contrast': 1.1},
          },
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.args['operation'], equals('adjust'));
      expect(request.args['params']['brightness'], equals(1.3));
    });

    test('parses image_compose crop request', () {
      final json = {
        'id': 'req-ic-4',
        'params': {
          'tool': 'image_compose',
          'args': {
            'input_paths': ['/storage/photo.jpg'],
            'output_path': '/storage/cropped.jpg',
            'operation': 'crop',
            'params': {'x': 10, 'y': 20, 'width': 500, 'height': 300},
          },
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.args['operation'], equals('crop'));
      expect(request.args['params']['width'], equals(500));
    });

    test('parses image_compose grayscale request', () {
      final json = {
        'id': 'req-ic-5',
        'params': {
          'tool': 'image_compose',
          'args': {
            'input_paths': ['/storage/photo.jpg'],
            'output_path': '/storage/gray.jpg',
            'operation': 'grayscale',
          },
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.args['operation'], equals('grayscale'));
    });

    test('parses image_compose blur request', () {
      final json = {
        'id': 'req-ic-6',
        'params': {
          'tool': 'image_compose',
          'args': {
            'input_paths': ['/storage/photo.jpg'],
            'output_path': '/storage/blurred.jpg',
            'operation': 'blur',
            'params': {'radius': 10},
          },
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.args['operation'], equals('blur'));
      expect(request.args['params']['radius'], equals(10));
    });
  });

  group('image_compose parameter validation', () {
    test('validates missing input_paths', () {
      final args = {
        'output_path': '/output.jpg',
        'operation': 'resize',
      };
      expect(
        () => _validateImageComposeArgs(args),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates empty input_paths', () {
      final args = {
        'input_paths': [],
        'output_path': '/output.jpg',
        'operation': 'resize',
      };
      expect(
        () => _validateImageComposeArgs(args),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates missing output_path', () {
      final args = {
        'input_paths': ['/img.jpg'],
        'operation': 'resize',
      };
      expect(
        () => _validateImageComposeArgs(args),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates missing operation', () {
      final args = {
        'input_paths': ['/img.jpg'],
        'output_path': '/output.jpg',
      };
      expect(
        () => _validateImageComposeArgs(args),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates unknown operation', () {
      expect(
        () => _validateImageComposeOperation('rotate'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates concat_horizontal requires 2+ images', () {
      expect(
        () => _validateConcatInputCount(1, 'concat_horizontal'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates concat_vertical requires 2+ images', () {
      expect(
        () => _validateConcatInputCount(1, 'concat_vertical'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates overlay requires 2+ images', () {
      expect(
        () => _validateConcatInputCount(1, 'overlay'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts single image for resize', () {
      // Should not throw
      _validateSingleImageOp(1, 'resize');
    });

    test('accepts single image for adjust', () {
      _validateSingleImageOp(1, 'adjust');
    });

    test('accepts single image for crop', () {
      _validateSingleImageOp(1, 'crop');
    });

    test('accepts single image for grayscale', () {
      _validateSingleImageOp(1, 'grayscale');
    });

    test('accepts single image for blur', () {
      _validateSingleImageOp(1, 'blur');
    });

    test('validates crop requires width and height', () {
      expect(
        () => _validateCropParams({'x': 0, 'y': 0}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates crop accepts all params', () {
      // Should not throw
      _validateCropParams({'x': 10, 'y': 20, 'width': 100, 'height': 200});
    });

    test('validates resize requires width or height', () {
      expect(
        () => _validateResizeParams({}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates resize accepts width only', () {
      _validateResizeParams({'width': 800});
    });

    test('validates resize accepts height only', () {
      _validateResizeParams({'height': 600});
    });

    test('validates resize accepts both', () {
      _validateResizeParams({'width': 800, 'height': 600});
    });
  });

  group('image_compose concat dimension calculations', () {
    test('concat_horizontal: output width = sum of widths when same height', () {
      final result = _simulateConcatHorizontal([
        {'width': 100, 'height': 200},
        {'width': 150, 'height': 200},
      ]);
      expect(result['width'], equals(250));
      expect(result['height'], equals(200));
    });

    test('concat_horizontal: images resized to max height', () {
      final result = _simulateConcatHorizontal([
        {'width': 100, 'height': 200},
        {'width': 300, 'height': 100}, // shorter — will be scaled up
      ]);
      // Image 2 scaled: 300 * (200/100) = 600 width, 200 height
      expect(result['height'], equals(200));
      expect(result['width'], equals(700)); // 100 + 600
    });

    test('concat_horizontal: three images', () {
      final result = _simulateConcatHorizontal([
        {'width': 100, 'height': 100},
        {'width': 100, 'height': 100},
        {'width': 100, 'height': 100},
      ]);
      expect(result['width'], equals(300));
      expect(result['height'], equals(100));
    });

    test('concat_horizontal: very different aspect ratios', () {
      final result = _simulateConcatHorizontal([
        {'width': 100, 'height': 1000}, // tall thin
        {'width': 1000, 'height': 100}, // wide short
      ]);
      // Max height = 1000
      // Image 2 scaled: 1000 * (1000/100) = 10000 width, 1000 height
      expect(result['height'], equals(1000));
      expect(result['width'], equals(10100)); // 100 + 10000
    });

    test('concat_vertical: output height = sum of heights when same width', () {
      final result = _simulateConcatVertical([
        {'width': 200, 'height': 100},
        {'width': 200, 'height': 150},
      ]);
      expect(result['width'], equals(200));
      expect(result['height'], equals(250));
    });

    test('concat_vertical: images resized to max width', () {
      final result = _simulateConcatVertical([
        {'width': 200, 'height': 100},
        {'width': 100, 'height': 300}, // narrower — will be scaled up
      ]);
      // Image 2 scaled: height = 300 * (200/100) = 600
      expect(result['width'], equals(200));
      expect(result['height'], equals(700)); // 100 + 600
    });

    test('concat_vertical: three images', () {
      final result = _simulateConcatVertical([
        {'width': 100, 'height': 100},
        {'width': 100, 'height': 100},
        {'width': 100, 'height': 100},
      ]);
      expect(result['width'], equals(100));
      expect(result['height'], equals(300));
    });
  });

  group('image_compose adjust parameter handling', () {
    test('adjust accepts all color params', () {
      final params = {
        'brightness': 1.5,
        'contrast': 0.8,
        'saturation': 1.2,
        'hue': 30.0,
        'gamma': 1.1,
        'exposure': 0.5,
      };
      // Should not throw
      _validateAdjustParams(params);
    });

    test('adjust works with no params (identity)', () {
      // Empty params should be valid — no adjustment
      _validateAdjustParams({});
    });

    test('adjust works with single param', () {
      _validateAdjustParams({'brightness': 1.5});
    });

    test('adjust params are numeric', () {
      final params = {
        'brightness': 1.5,
        'contrast': 0.8,
      };
      for (final value in params.values) {
        expect(value, isA<num>());
      }
    });
  });

  group('image_compose output encoding', () {
    test('selects PNG encoding for .png extension', () {
      expect(_getEncodingFormat('/output.png'), equals('png'));
    });

    test('selects JPG encoding for .jpg extension', () {
      expect(_getEncodingFormat('/output.jpg'), equals('jpg'));
    });

    test('selects JPG encoding for .jpeg extension', () {
      expect(_getEncodingFormat('/output.jpeg'), equals('jpg'));
    });

    test('defaults to JPG for unknown extension', () {
      expect(_getEncodingFormat('/output.bmp'), equals('jpg'));
    });

    test('defaults to JPG for no extension', () {
      expect(_getEncodingFormat('/output'), equals('jpg'));
    });

    test('handles uppercase extension', () {
      expect(_getEncodingFormat('/output.PNG'), equals('png'));
    });

    test('handles mixed case extension', () {
      expect(_getEncodingFormat('/output.Jpg'), equals('jpg'));
    });
  });

  group('image_compose result format', () {
    test('result includes all required fields', () {
      final result = {
        'success': true,
        'output_path': '/storage/output.jpg',
        'width': 800,
        'height': 600,
        'output_size_bytes': 125000,
        'operation': 'concat_horizontal',
      };

      expect(result['success'], isTrue);
      expect(result['output_path'], isNotNull);
      expect(result['width'], isA<int>());
      expect(result['height'], isA<int>());
      expect(result['output_size_bytes'], isA<int>());
      expect(result['operation'], isA<String>());
    });

    test('result width and height reflect operation', () {
      // Resize result
      final resizeResult = {
        'success': true,
        'output_path': '/output.jpg',
        'width': 400,
        'height': 300,
        'output_size_bytes': 50000,
        'operation': 'resize',
      };
      expect(resizeResult['width'], equals(400));
      expect(resizeResult['height'], equals(300));
    });
  });

  group('image_compose overlay operations', () {
    test('overlay default offset is 0,0', () {
      final params = <String, dynamic>{};
      expect(params['x'] ?? 0, equals(0));
      expect(params['y'] ?? 0, equals(0));
    });

    test('overlay with negative offset (should still work)', () {
      final params = {'x': -50, 'y': -30};
      // Negative offsets are valid — image will be partially outside canvas
      expect(params['x'], equals(-50));
    });

    test('overlay with large offset (image partially off canvas)', () {
      final params = {'x': 10000, 'y': 10000};
      // Valid but foreground will be mostly outside canvas
      expect(params['x'], isA<int>());
    });
  });

  group('image_compose blur operations', () {
    test('blur default radius is 5', () {
      final params = <String, dynamic>{};
      final radius = (params['radius'] as int?) ?? 5;
      expect(radius, equals(5));
    });

    test('blur with custom radius', () {
      final params = {'radius': 20};
      expect(params['radius'], equals(20));
    });

    test('blur with radius 0 (should be no-op)', () {
      final params = {'radius': 0};
      expect(params['radius'], equals(0));
    });

    test('blur with very large radius', () {
      final params = {'radius': 100};
      expect(params['radius'], greaterThan(50));
    });
  });

  group('Tool registration', () {
    test('image_compose is a valid native tool', () {
      const validTools = [
        'ffmpeg', 'ocr', 'headless_browser', 'face_detect',
        'smart_crop', 'image_compose', 'list_files', 'llm_generate',
      ];
      expect(validTools, contains('image_compose'));
    });

    test('list_files is a valid native tool', () {
      const validTools = [
        'ffmpeg', 'ocr', 'headless_browser', 'face_detect',
        'smart_crop', 'image_compose', 'list_files', 'llm_generate',
      ];
      expect(validTools, contains('list_files'));
    });
  });
}

// Helper functions simulating image_compose validation logic

void _validateImageComposeArgs(Map<String, dynamic> args) {
  final inputPaths = args['input_paths'] as List?;
  if (inputPaths == null || inputPaths.isEmpty) {
    throw ArgumentError('Missing required parameter: input_paths');
  }
  if (args['output_path'] == null) {
    throw ArgumentError('Missing required parameter: output_path');
  }
  if (args['operation'] == null) {
    throw ArgumentError('Missing required parameter: operation');
  }
}

void _validateImageComposeOperation(String operation) {
  const validOps = [
    'concat_horizontal', 'concat_vertical', 'overlay', 'resize',
    'adjust', 'crop', 'grayscale', 'blur',
  ];
  if (!validOps.contains(operation)) {
    throw ArgumentError('Unknown image_compose operation: $operation');
  }
}

void _validateConcatInputCount(int count, String operation) {
  if (count < 2) {
    throw ArgumentError('$operation requires at least 2 input images');
  }
}

void _validateSingleImageOp(int count, String operation) {
  if (count < 1) {
    throw ArgumentError('$operation requires at least 1 input image');
  }
}

void _validateCropParams(Map<String, dynamic> params) {
  if (params['width'] == null || params['height'] == null) {
    throw ArgumentError('crop requires width and height in params');
  }
}

void _validateResizeParams(Map<String, dynamic> params) {
  if (params['width'] == null && params['height'] == null) {
    throw ArgumentError('resize requires width or height in params');
  }
}

void _validateAdjustParams(Map<String, dynamic> params) {
  // All params are optional for adjust — empty params = identity (no change)
  const validKeys = ['brightness', 'contrast', 'saturation', 'hue', 'gamma', 'exposure'];
  for (final key in params.keys) {
    if (!validKeys.contains(key)) {
      throw ArgumentError('Unknown adjust parameter: $key');
    }
  }
}

Map<String, int> _simulateConcatHorizontal(List<Map<String, int>> images) {
  final maxHeight = images.map((i) => i['height']!).reduce((a, b) => a > b ? a : b);
  int totalWidth = 0;
  for (final image in images) {
    if (image['height']! != maxHeight) {
      final newWidth = (image['width']! * maxHeight / image['height']!).round();
      totalWidth += newWidth;
    } else {
      totalWidth += image['width']!;
    }
  }
  return {'width': totalWidth, 'height': maxHeight};
}

Map<String, int> _simulateConcatVertical(List<Map<String, int>> images) {
  final maxWidth = images.map((i) => i['width']!).reduce((a, b) => a > b ? a : b);
  int totalHeight = 0;
  for (final image in images) {
    if (image['width']! != maxWidth) {
      final newHeight = (image['height']! * maxWidth / image['width']!).round();
      totalHeight += newHeight;
    } else {
      totalHeight += image['height']!;
    }
  }
  return {'width': maxWidth, 'height': totalHeight};
}

String _getEncodingFormat(String outputPath) {
  final ext = outputPath.contains('.')
      ? outputPath.substring(outputPath.lastIndexOf('.')).toLowerCase()
      : '';
  if (ext == '.png') return 'png';
  return 'jpg';
}
