import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../bridge/bridge.dart';
import '../bridge/messages.dart';
import 'analytics_service.dart';

/// Executor for native tools called from Python.
///
/// Handles FFmpeg, OCR, and other native operations that
/// must be performed on the Flutter/Android side.
class NativeToolExecutor {
  static final NativeToolExecutor instance = NativeToolExecutor._();

  NativeToolExecutor._();

  final _bridge = PythonBridge.instance;
  StreamSubscription? _subscription;

  /// Initialize and start listening for native tool requests
  void initialize() {
    _subscription = _bridge.nativeToolStream.listen(_handleToolRequest);
  }

  void _handleToolRequest(NativeToolRequest request) async {
    debugPrint('[NativeTool] Received request: ${request.tool} (id: ${request.id})');
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _executeTool(request.tool, request.args);
      stopwatch.stop();
      debugPrint('[NativeTool] Success: ${request.tool}');
      await _bridge.sendToolResult(id: request.id, result: result);
      debugPrint('[NativeTool] Result sent for: ${request.tool}');

      // Track successful tool execution
      await AnalyticsService.instance.toolExecuted(
        toolName: request.tool,
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('[NativeTool] Error in ${request.tool}: $e');
      debugPrint('[NativeTool] Stack: $stackTrace');
      await _bridge.sendToolError(
        id: request.id,
        code: -32000,
        message: e.toString(),
      );
      debugPrint('[NativeTool] Error sent for: ${request.tool}');

      // Track failed tool execution
      await AnalyticsService.instance.toolExecuted(
        toolName: request.tool,
        success: false,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<Map<String, dynamic>> _executeTool(
    String tool,
    Map<String, dynamic> args,
  ) async {
    switch (tool) {
      case 'ffmpeg':
        return _executeFFmpeg(args);
      case 'ocr':
        return _executeOCR(args);
      case 'headless_browser':
        return _executeHeadlessBrowser(args);
      case 'face_detect':
        return _executeFaceDetection(args);
      case 'smart_crop':
        return _executeSmartCrop(args);
      default:
        throw UnsupportedError('Unknown native tool: $tool');
    }
  }

  /// Sanitize comparison operators in FFmpeg filter expressions.
  /// FFmpegKit's native filter graph parser can crash (SIGSEGV) on `<` and `>`
  /// operators in filter_complex strings. Replace them with FFmpeg's function
  /// equivalents: lt(), gt(), lte(), gte() which are safer across builds.
  /// Only replaces operators inside single-quoted expression strings (e.g. select='...').
  String _sanitizeFFmpegComparisons(String filter) {
    // Replace operators inside single-quoted expression segments
    return filter.replaceAllMapped(
      RegExp(r"'([^']*)'"),
      (match) {
        var expr = match.group(1)!;
        expr = _replaceComparisonOps(expr);
        return "'$expr'";
      },
    );
  }

  /// Replace comparison operators (<, >, <=, >=) with function equivalents
  /// (lt, gt, lte, gte) in an FFmpeg expression string. Handles balanced
  /// parentheses so `floor(mod(t,4))<2` correctly becomes `lt(floor(mod(t,4)),2)`.
  String _replaceComparisonOps(String expr) {
    // Process operators in order: >= and <= first (to avoid partial matches with > and <)
    for (final op in ['>=', '<=', '>', '<']) {
      int pos = 0;
      while (pos < expr.length) {
        final idx = expr.indexOf(op, pos);
        if (idx < 0) break;

        // Skip if this is part of a longer operator already handled
        // e.g. if we're looking for '>' but it's part of '>='
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

        // Walk backward to find LHS start (handling balanced parens)
        int lhsStart = lhsEnd - 1;
        if (expr[lhsStart] == ')') {
          // Walk backward to find matching '('
          int depth = 1;
          lhsStart--;
          while (lhsStart >= 0 && depth > 0) {
            if (expr[lhsStart] == ')') depth++;
            else if (expr[lhsStart] == '(') depth--;
            lhsStart--;
          }
          // lhsStart is now one before the '(' — walk back over function name
          while (lhsStart >= 0 && RegExp(r'[\w\\.]').hasMatch(expr[lhsStart])) {
            lhsStart--;
          }
          lhsStart++; // Point to first char of LHS
        } else {
          // Simple value: walk back over word/dot/backslash characters
          while (lhsStart > 0 && RegExp(r'[\w\\.]').hasMatch(expr[lhsStart - 1])) {
            lhsStart--;
          }
        }

        // Walk forward to find RHS end
        int rhsEnd = rhsStart;
        if (rhsEnd < expr.length && RegExp(r'[\w\\.]').hasMatch(expr[rhsEnd])) {
          // Check if it's a function call (word chars followed by '(')
          int tempEnd = rhsEnd;
          while (tempEnd < expr.length && RegExp(r'[\w\\.]').hasMatch(expr[tempEnd])) {
            tempEnd++;
          }
          if (tempEnd < expr.length && expr[tempEnd] == '(') {
            // Function call: find matching ')'
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
  /// FFmpeg uses commas as filter chain separators, but inside expression
  /// functions like mod(x,y) or if(a,b,c), commas must be escaped as \,
  /// This only escapes commas where parenthesis depth > 0.
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
        // Comma inside parentheses — escape unless already escaped
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

  /// Validate that any -filter_complex string in the command is structurally
  /// sound. Catches garbage like command-line flags inside filter expressions
  /// (e.g. "-c:v libx264" inside filter_complex) which cause FFmpegKit to
  /// SIGSEGV in avfilter_inout_free / init_complex_filtergraph.
  void _validateFilterComplex(String command) {
    final match = RegExp(r'-filter_complex\s+"([^"]*)"').firstMatch(command);
    if (match == null) return; // No filter_complex — nothing to validate

    final fc = match.group(1)!;

    // Filter_complex must NOT contain command-line flags
    final forbiddenFlags = [' -c:v ', ' -c:a ', ' -af ', ' -vf ', ' -preset ', ' -crf ', ' -b:a ', ' -b:v '];
    for (final flag in forbiddenFlags) {
      if (fc.contains(flag)) {
        throw ArgumentError(
          'Invalid filter_complex: contains command-line flag "$flag". '
          'Use operation="filter" instead of "custom" for video filtering.',
        );
      }
    }

    // Stream labels [x] must be balanced — each chain ends with [label]
    final chains = fc.split(';');
    for (final chain in chains) {
      final trimmed = chain.trim();
      if (trimmed.isEmpty) continue;
      // Each chain should end with a stream label like [v] or [a]
      if (!RegExp(r'\[\w+\]\s*$').hasMatch(trimmed) &&
          !RegExp(r'^\[').hasMatch(trimmed) &&
          chains.length > 1) {
        // Multi-chain filter_complex where a chain doesn't end with [label]
        // is likely malformed — but don't block single-chain expressions
        debugPrint('[FFmpeg] Warning: filter chain may be malformed: $trimmed');
      }
    }
  }

  /// Execute FFmpeg operation
  Future<Map<String, dynamic>> _executeFFmpeg(Map<String, dynamic> args) async {
    final inputPath = args['input_path'] as String?;
    final outputPath = args['output_path'] as String?;
    final operation = args['operation'] as String?;
    final params = args['params'] as Map<String, dynamic>? ?? {};

    if (inputPath == null || outputPath == null || operation == null) {
      throw ArgumentError('Missing required parameters: input_path, output_path, operation');
    }

    // Verify input file exists
    if (!await File(inputPath).exists()) {
      throw ArgumentError('Input file does not exist: $inputPath');
    }

    // Build FFmpeg command based on operation
    // -y flag to auto-overwrite existing files
    String command;
    switch (operation) {
      case 'crop':
        final x = params['x'] ?? 0;
        final y = params['y'] ?? 0;
        final width = params['width'];
        final height = params['height'];
        if (width == null || height == null) {
          throw ArgumentError('Crop requires width and height parameters');
        }
        command = '-y -i "$inputPath" -vf "crop=$width:$height:$x:$y" -pix_fmt yuv420p -c:a copy "$outputPath"';
        break;

      case 'resize':
        final width = params['width'];
        final height = params['height'];
        if (width == null && height == null) {
          throw ArgumentError('Resize requires at least width or height parameter');
        }
        final scale = width != null && height != null
            ? 'scale=$width:$height'
            : width != null
                ? 'scale=$width:-2'
                : 'scale=-2:$height';
        command = '-y -i "$inputPath" -vf "$scale" -pix_fmt yuv420p -c:a copy "$outputPath"';
        break;

      case 'extract_audio':
        final format = params['format'] ?? 'mp3';
        final bitrate = params['bitrate'] ?? '192k';
        command = '-y -i "$inputPath" -vn -acodec libmp3lame -ab $bitrate "$outputPath"';
        break;

      case 'convert':
        final codec = params['codec'];
        final quality = params['quality'] ?? 23;
        // Ensure quality is a valid integer for CRF
        final crf = (quality is int) ? quality : int.tryParse(quality.toString()) ?? 23;
        if (codec != null) {
          command = '-y -i "$inputPath" -c:v $codec -pix_fmt yuv420p -crf $crf -c:a aac "$outputPath"';
        } else {
          command = '-y -i "$inputPath" -c:v libx264 -pix_fmt yuv420p -crf $crf -c:a aac "$outputPath"';
        }
        break;

      case 'extract_frame':
        final timestamp = params['timestamp'] ?? '00:00:00';
        command = '-y -i "$inputPath" -ss $timestamp -vframes 1 "$outputPath"';
        break;

      case 'trim':
        final start = params['start'] ?? '00:00:00';
        final duration = params['duration'];
        final end = params['end'];
        if (duration != null) {
          command = '-y -i "$inputPath" -ss $start -t $duration -c copy "$outputPath"';
        } else if (end != null) {
          command = '-y -i "$inputPath" -ss $start -to $end -c copy "$outputPath"';
        } else {
          throw ArgumentError('Trim requires duration or end parameter');
        }
        break;

      case 'filter':
        var vf = params['vf'] ?? params['video_filter'];
        var af = params['af'] ?? params['audio_filter'];
        if (vf == null && af == null) {
          throw ArgumentError('Filter requires vf (video filter) or af (audio filter) parameter');
        }
        // Sanitize comparison operators (< > <= >=) → lt() gt() lte() gte()
        // to prevent FFmpegKit native crash (SIGSEGV in avfilter_inout_free)
        if (vf != null) vf = _sanitizeFFmpegComparisons(vf.toString());
        if (af != null) af = _sanitizeFFmpegComparisons(af.toString());
        // Escape commas in expression functions (e.g. mod(x,y) -> mod(x\,y))
        if (vf != null) vf = _escapeFFmpegExprCommas(vf.toString());
        if (af != null) af = _escapeFFmpegExprCommas(af.toString());
        // When video uses select (time-based frame selection), use filter_complex
        // with explicit mapping to guarantee both A/V streams are filtered
        if (vf != null && vf.toString().contains('select')) {
          // Auto-generate matching audio filter if not provided
          if (af == null) {
            // Extract only select/setpts parts from vf for audio — strip
            // video-only filters (hue, eq, colorbalance, etc.)
            final vfParts = vf.toString().split(',');
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
            if (!vf.toString().contains('setpts')) {
              vf = "$vf,setpts=N/FRAME_RATE/TB";
            }
            if (af != null && !af.toString().contains('asetpts')) {
              af = "$af,asetpts=N/SR/TB";
            }
            if (af == null) {
              af = "aselect='1',asetpts=N/SR/TB";
            }
          }
          // Use filter_complex with explicit stream mapping
          command = '-y -i "$inputPath" -filter_complex "[0:v]$vf[v];[0:a]$af[a]" -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
        } else if (vf != null && af != null) {
          command = '-y -i "$inputPath" -vf "$vf" -af "$af" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
        } else if (vf != null) {
          command = '-y -i "$inputPath" -vf "$vf" -c:v libx264 -pix_fmt yuv420p -crf 23 -c:a aac "$outputPath"';
        } else {
          command = '-y -i "$inputPath" -c:v copy -af "$af" -c:a aac "$outputPath"';
        }
        break;

      case 'custom':
        // Raw FFmpeg args for complex operations (e.g. multi-filter chains)
        var args = params['args'] as String?;
        if (args == null || args.isEmpty) {
          throw ArgumentError('Custom requires args parameter with FFmpeg arguments');
        }
        // Sanitize comparison operators (< > <= >=) → lt() gt() lte() gte()
        args = _sanitizeFFmpegComparisons(args);
        // Escape commas in expression functions (e.g. mod(x,y) -> mod(x\,y))
        args = _escapeFFmpegExprCommas(args);
        // Inject -pix_fmt yuv420p for Android compatibility when re-encoding video
        // (prevents monochrome H.264 which Android hardware decoders can't play)
        if (args.contains('-c:v') && !args.contains('-c:v copy') && !args.contains('-pix_fmt')) {
          args = args.replaceFirstMapped(
            RegExp(r'-c:v\s+(\S+)'),
            (m) => '-c:v ${m.group(1)} -pix_fmt yuv420p',
          );
        }
        // Pass args through as-is — the agent should use operation="filter"
        // for filter chains, not "custom". Previous regex-based -vf/-af
        // extraction was fragile and produced mangled commands.
        command = '-y -i "$inputPath" $args "$outputPath"';
        break;

      default:
        throw ArgumentError('Unknown FFmpeg operation: $operation');
    }

    // Validate filter_complex strings before execution to prevent native crashes.
    // FFmpegKit's avfilter_inout_free SIGSEGV-crashes on malformed filter graphs.
    _validateFilterComplex(command);

    // Execute FFmpeg command
    debugPrint('[FFmpeg] Command: $command');
    final startTime = DateTime.now();
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    final duration = DateTime.now().difference(startTime);

    if (ReturnCode.isSuccess(returnCode)) {
      // Get output file info
      // If output path contains % (FFmpeg pattern like %03d), find actual generated files
      if (outputPath.contains('%')) {
        // Find generated segment files by globbing the directory
        final dir = Directory(outputPath.substring(0, outputPath.lastIndexOf('/')));
        final pattern = outputPath.substring(outputPath.lastIndexOf('/') + 1)
            .replaceAll(RegExp(r'%\d*d'), '*');
        final files = <String>[];
        int totalSize = 0;
        if (await dir.exists()) {
          await for (final entity in dir.list()) {
            if (entity is File) {
              final name = entity.path.substring(entity.path.lastIndexOf('/') + 1);
              if (RegExp('^${pattern.replaceAll('*', '.*')}\$').hasMatch(name)) {
                files.add(entity.path);
                totalSize += await entity.length();
              }
            }
          }
        }
        files.sort();
        return {
          'success': true,
          'output_paths': files,
          'file_count': files.length,
          'total_size_bytes': totalSize,
          'processing_time_ms': duration.inMilliseconds,
          'operation': operation,
        };
      }

      final outputFile = File(outputPath);
      final outputSize = await outputFile.length();

      // Probe output file for actual media duration
      double? mediaDuration;
      try {
        final probeSession = await FFprobeKit.getMediaInformation(outputPath);
        final probeInfo = probeSession.getMediaInformation();
        final durationStr = probeInfo?.getDuration();
        if (durationStr != null) {
          mediaDuration = double.tryParse(durationStr);
        }
      } catch (_) {
        // Probing may fail for non-media outputs (e.g., images) — that's fine
      }

      final result = {
        'success': true,
        'output_path': outputPath,
        'output_size_bytes': outputSize,
        'processing_time_ms': duration.inMilliseconds,
        'operation': operation,
      };
      if (mediaDuration != null) {
        result['media_duration_seconds'] = mediaDuration;
      }
      return result;
    } else {
      // Extract just the actual error lines, not the full FFmpeg banner
      final logs = await session.getAllLogsAsString() ?? '';
      final errorLines = logs
          .split('\n')
          .where((l) => l.contains('Error') || l.contains('error') || l.contains('Invalid') || l.contains('No such') || l.contains('not found') || l.contains('Overwrite'))
          .join('\n');
      final errorMsg = errorLines.isNotEmpty ? errorLines : 'FFmpeg failed (code ${returnCode?.getValue()})';
      throw Exception(errorMsg);
    }
  }

  /// Execute OCR using ML Kit
  Future<Map<String, dynamic>> _executeOCR(Map<String, dynamic> args) async {
    final imagePath = args['image_path'] as String?;

    if (imagePath == null) {
      throw ArgumentError('Missing image_path parameter');
    }

    // Verify file exists before attempting OCR
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw ArgumentError('Image file does not exist: $imagePath');
    }

    final textRecognizer = TextRecognizer();

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Extract text blocks with position info
      final blocks = <Map<String, dynamic>>[];
      for (final block in recognizedText.blocks) {
        final lines = <Map<String, dynamic>>[];
        for (final line in block.lines) {
          lines.add({
            'text': line.text,
            'confidence': line.confidence,
            'bounding_box': {
              'left': line.boundingBox.left,
              'top': line.boundingBox.top,
              'right': line.boundingBox.right,
              'bottom': line.boundingBox.bottom,
            },
          });
        }
        blocks.add({
          'text': block.text,
          'lines': lines,
          'bounding_box': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
        });
      }

      return {
        'success': true,
        'text': recognizedText.text,
        'blocks': blocks,
        'block_count': recognizedText.blocks.length,
      };
    } finally {
      textRecognizer.close();
    }
  }

  /// Execute headless browser using InAppWebView
  Future<Map<String, dynamic>> _executeHeadlessBrowser(
    Map<String, dynamic> args,
  ) async {
    final url = args['url'] as String?;
    final waitSeconds = args['wait_seconds'] as int? ?? 5;
    final extractSelector = args['extract_selector'] as String?;

    if (url == null) {
      throw ArgumentError('Missing url parameter');
    }

    final completer = Completer<Map<String, dynamic>>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          userAgent:
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        ),
        onLoadStop: (controller, loadedUrl) async {
          // Wait for JS to render
          await Future.delayed(Duration(seconds: waitSeconds));

          try {
            String? content;
            String? title;

            // Get page title
            title = await controller.getTitle();

            if (extractSelector != null && extractSelector.isNotEmpty) {
              // Extract specific element
              final result = await controller.evaluateJavascript(
                source: '''
                  (function() {
                    var el = document.querySelector('$extractSelector');
                    return el ? el.innerText : null;
                  })()
                ''',
              );
              content = result?.toString();
            } else {
              // Get full page text
              final result = await controller.evaluateJavascript(
                source: '''
                  (function() {
                    // Remove script, style, nav, footer, header elements
                    ['script', 'style', 'nav', 'footer', 'header'].forEach(function(tag) {
                      document.querySelectorAll(tag).forEach(function(el) {
                        el.remove();
                      });
                    });

                    // Try to find main content
                    var main = document.querySelector('main') ||
                               document.querySelector('article') ||
                               document.body;
                    return main ? main.innerText : document.body.innerText;
                  })()
                ''',
              );
              content = result?.toString();
            }

            // Clean up content
            if (content != null) {
              // Remove excessive whitespace
              content = content
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .join('\n');

              // Truncate if too long
              if (content.length > 50000) {
                content = '${content.substring(0, 50000)}\n\n[Content truncated...]';
              }
            }

            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'url': loadedUrl?.toString() ?? url,
                'title': title,
                'text': content ?? '',
              });
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(Exception('Failed to extract content: $e'));
            }
          }
        },
        onReceivedError: (controller, request, error) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Failed to load page: ${error.description}'),
            );
          }
        },
      );

      await headlessWebView.run();

      // Add timeout
      return await completer.future.timeout(
        Duration(seconds: waitSeconds + 30),
        onTimeout: () {
          throw TimeoutException('Headless browser timed out');
        },
      );
    } finally {
      await headlessWebView?.dispose();
    }
  }

  /// Execute face detection using ML Kit
  Future<Map<String, dynamic>> _executeFaceDetection(
    Map<String, dynamic> args,
  ) async {
    final imagePath = args['image_path'] as String?;

    if (imagePath == null) {
      throw ArgumentError('Missing image_path parameter');
    }

    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      enableClassification: false,
      performanceMode: FaceDetectorMode.accurate,
    );

    final faceDetector = FaceDetector(options: options);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await faceDetector.processImage(inputImage);

      // Extract face info
      final faceList = <Map<String, dynamic>>[];
      for (final face in faces) {
        final boundingBox = face.boundingBox;
        faceList.add({
          'x': boundingBox.left.round(),
          'y': boundingBox.top.round(),
          'width': boundingBox.width.round(),
          'height': boundingBox.height.round(),
          'center_x': (boundingBox.left + boundingBox.width / 2).round(),
          'center_y': (boundingBox.top + boundingBox.height / 2).round(),
          'head_euler_angle_y': face.headEulerAngleY,
          'head_euler_angle_z': face.headEulerAngleZ,
        });
      }

      return {
        'success': true,
        'faces': faceList,
        'face_count': faces.length,
      };
    } finally {
      faceDetector.close();
    }
  }

  /// Execute smart crop using face detection to center the crop
  Future<Map<String, dynamic>> _executeSmartCrop(
    Map<String, dynamic> args,
  ) async {
    final inputPath = args['input_path'] as String?;
    final outputPath = args['output_path'] as String?;
    final targetAspectRatio = args['aspect_ratio'] as String? ?? '9:16';

    if (inputPath == null || outputPath == null) {
      throw ArgumentError('Missing input_path or output_path parameter');
    }

    // Parse aspect ratio
    final parts = targetAspectRatio.split(':');
    final targetWidth = int.parse(parts[0]);
    final targetHeight = int.parse(parts[1]);

    // For video: extract first frame for face detection
    final isVideo = inputPath.toLowerCase().endsWith('.mp4') ||
        inputPath.toLowerCase().endsWith('.mov') ||
        inputPath.toLowerCase().endsWith('.webm');

    String framePathToAnalyze = inputPath;
    String? tempFramePath;
    bool usedMultiFrameSampling = false;
    int framesSampled = 1;
    int totalFaceDetections = 0;

    List<dynamic> faces;

    if (isVideo) {
      // For videos: sample multiple frames at 1fps for better face tracking
      final sampleResult = await _sampleVideoFramesForFaces(
        videoPath: inputPath,
        maxFrames: 10, // Sample up to 10 frames (10 seconds of video)
      );

      faces = sampleResult['faces'] as List<dynamic>;
      usedMultiFrameSampling = sampleResult['averaged'] == true;
      framesSampled = sampleResult['frames_sampled'] as int? ?? 1;
      totalFaceDetections = sampleResult['total_detections'] as int? ?? 0;
    } else {
      // For images: single frame detection
      final faceResult = await _executeFaceDetection({
        'image_path': framePathToAnalyze,
      });
      faces = faceResult['faces'] as List<dynamic>;
    }

    try {

      // Get image/video dimensions
      int sourceWidth, sourceHeight;
      if (isVideo) {
        // Use FFprobe to get actual video dimensions
        final probeSession = await FFprobeKit.getMediaInformation(inputPath);
        final info = probeSession.getMediaInformation();
        final streams = info?.getStreams();
        final videoStream = streams?.firstWhere(
          (s) => s.getType() == 'video',
          orElse: () => streams!.first,
        );
        sourceWidth = videoStream?.getWidth() ?? 1920;
        sourceHeight = videoStream?.getHeight() ?? 1080;
      } else {
        final imageFile = File(inputPath);
        final bytes = await imageFile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image == null) throw Exception('Failed to decode image');
        sourceWidth = image.width;
        sourceHeight = image.height;
      }

      // Calculate crop size maintaining aspect ratio
      int cropWidth, cropHeight;
      final sourceRatio = sourceWidth / sourceHeight;
      final targetRatio = targetWidth / targetHeight;

      if (sourceRatio > targetRatio) {
        // Source is wider - crop width
        cropHeight = sourceHeight;
        cropWidth = (cropHeight * targetWidth / targetHeight).round();
      } else {
        // Source is taller - crop height
        cropWidth = sourceWidth;
        cropHeight = (cropWidth * targetHeight / targetWidth).round();
      }

      // Calculate crop position
      int cropX, cropY;
      String cropStrategy;

      if (faces.isNotEmpty) {
        // Strategy 1: Face-centered crop (use primary/largest face)
        final primaryFace = _selectPrimaryFace(faces.cast<Map<String, dynamic>>());

        if (primaryFace != null) {
          final fx = (primaryFace['x'] as int);
          final fy = (primaryFace['y'] as int);
          final fw = (primaryFace['width'] as int);
          final fh = (primaryFace['height'] as int);

          // Center on the primary face
          final centerX = fx + fw ~/ 2;
          final centerY = fy + fh ~/ 2;

          cropX = (centerX - cropWidth ~/ 2).clamp(0, sourceWidth - cropWidth);
          cropY = (centerY - cropHeight ~/ 2).clamp(0, sourceHeight - cropHeight);
          cropStrategy = 'face_centered';
        } else {
          // Fallback if face selection fails
          cropX = (sourceWidth - cropWidth) ~/ 2;
          cropY = (sourceHeight - cropHeight) ~/ 2;
          cropStrategy = 'center';
        }
      } else {
        // Strategy 2: Rule of thirds (no faces detected)
        // Better composition than simple center crop
        final ruleOfThirds = _calculateRuleOfThirdsCrop(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          cropWidth: cropWidth,
          cropHeight: cropHeight,
        );
        cropX = ruleOfThirds['x']!;
        cropY = ruleOfThirds['y']!;
        cropStrategy = 'rule_of_thirds';
      }

      // Execute the crop
      if (isVideo) {
        final cropFilter = 'crop=$cropWidth:$cropHeight:$cropX:$cropY';
        return _executeFFmpeg({
          'input_path': inputPath,
          'output_path': outputPath,
          'operation': 'crop',
          'params': {
            'x': cropX,
            'y': cropY,
            'width': cropWidth,
            'height': cropHeight,
          },
        });
      } else {
        // Image crop using dart image package
        final imageFile = File(inputPath);
        final bytes = await imageFile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image == null) throw Exception('Failed to decode image');

        final cropped = img.copyCrop(
          image,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        );

        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(img.encodeJpg(cropped, quality: 90));

        return {
          'success': true,
          'output_path': outputPath,
          'crop_region': {
            'x': cropX,
            'y': cropY,
            'width': cropWidth,
            'height': cropHeight,
          },
          'faces_detected': faces.length,
          'crop_strategy': cropStrategy,
          if (isVideo) 'frames_sampled': framesSampled,
          if (isVideo && usedMultiFrameSampling)
            'total_face_detections': totalFaceDetections,
        };
      }
    } finally {
      // Cleanup temp frame (for images with temp processing)
      if (tempFramePath != null) {
        try {
          await File(tempFramePath).delete();
        } catch (_) {}
      }
    }
  }

  /// Sample video frames at 1fps and detect faces in each frame.
  ///
  /// Returns the average face center position across all sampled frames.
  /// This provides more stable face tracking for videos where subjects move.
  Future<Map<String, dynamic>> _sampleVideoFramesForFaces({
    required String videoPath,
    required int maxFrames,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final framesDir = Directory('${tempDir.path}/face_frames_${DateTime.now().millisecondsSinceEpoch}');
    await framesDir.create(recursive: true);

    try {
      // Get video duration using FFprobe
      final probeSession = await FFprobeKit.getMediaInformation(videoPath);
      final info = probeSession.getMediaInformation();
      final durationStr = info?.getDuration();
      final duration = durationStr != null ? double.tryParse(durationStr) ?? 10.0 : 10.0;

      // Calculate frame interval (sample at 1fps, max frames)
      final framesToExtract = duration.ceil().clamp(1, maxFrames);
      final interval = duration / framesToExtract;

      // Extract frames at 1fps
      final framePattern = '${framesDir.path}/frame_%03d.jpg';
      final extractCommand = '-i "$videoPath" -vf "fps=1/$interval" -frames:v $framesToExtract "$framePattern"';

      final extractSession = await FFmpegKit.execute(extractCommand);
      final extractCode = await extractSession.getReturnCode();

      if (!ReturnCode.isSuccess(extractCode)) {
        return {
          'faces': <Map<String, dynamic>>[],
          'frames_sampled': 0,
          'total_detections': 0,
          'error': 'Failed to extract video frames',
        };
      }

      // Detect faces in each frame
      final allFaces = <Map<String, dynamic>>[];
      int totalDetections = 0;
      int framesSampled = 0;

      final frameFiles = framesDir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final frameFile in frameFiles) {
        framesSampled++;
        try {
          final faceResult = await _executeFaceDetection({
            'image_path': frameFile.path,
          });
          final faces = faceResult['faces'] as List<dynamic>;
          totalDetections += faces.length;

          for (final face in faces) {
            allFaces.add(face as Map<String, dynamic>);
          }
        } catch (_) {
          // Continue with other frames if one fails
        }
      }

      // Average face positions if multiple detections
      if (allFaces.isEmpty) {
        return {
          'faces': <Map<String, dynamic>>[],
          'frames_sampled': framesSampled,
          'total_detections': 0,
          'averaged': false,
        };
      }

      // Calculate average face position
      double avgX = 0, avgY = 0, avgWidth = 0, avgHeight = 0;
      for (final face in allFaces) {
        avgX += (face['x'] as int).toDouble();
        avgY += (face['y'] as int).toDouble();
        avgWidth += (face['width'] as int).toDouble();
        avgHeight += (face['height'] as int).toDouble();
      }

      final count = allFaces.length;
      final averagedFace = {
        'x': (avgX / count).round(),
        'y': (avgY / count).round(),
        'width': (avgWidth / count).round(),
        'height': (avgHeight / count).round(),
        'center_x': ((avgX + avgWidth / 2) / count).round(),
        'center_y': ((avgY + avgHeight / 2) / count).round(),
      };

      return {
        'faces': [averagedFace],
        'frames_sampled': framesSampled,
        'total_detections': totalDetections,
        'averaged': true,
      };
    } finally {
      // Cleanup temp frames
      try {
        await framesDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Select the primary (largest) face from a list of detected faces.
  ///
  /// When multiple faces are detected, selects the one with the largest
  /// bounding box area (most prominent in frame).
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
  ///
  /// Centers the crop on the intersection of rule-of-thirds lines,
  /// providing better composition than simple center crop.
  Map<String, int> _calculateRuleOfThirdsCrop({
    required int sourceWidth,
    required int sourceHeight,
    required int cropWidth,
    required int cropHeight,
  }) {
    // Rule of thirds intersection points are at 1/3 and 2/3 of dimensions
    // Use the center intersection point (1/2, 1/2) with slight bias toward
    // upper third for faces/subjects (common in photography)
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

  void dispose() {
    _subscription?.cancel();
  }
}
