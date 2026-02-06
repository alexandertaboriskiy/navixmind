import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Braille pattern spinner animation
class BrailleSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const BrailleSpinner({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  State<BrailleSpinner> createState() => _BrailleSpinnerState();
}

class _BrailleSpinnerState extends State<BrailleSpinner> {
  int _frameIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _frameIndex = (_frameIndex + 1) % NavixTheme.spinnerFrames.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduce motion setting
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Text(
          reduceMotion ? '●' : NavixTheme.spinnerFrames[_frameIndex],
          style: TextStyle(
            fontSize: widget.size * 0.9,
            height: 1.0,
            color: widget.color ?? NavixTheme.primary,
          ),
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Voice waveform visualization
class VoiceWaveform extends StatefulWidget {
  final bool isRecording;
  final double level; // 0.0 to 1.0

  const VoiceWaveform({
    super.key,
    required this.isRecording,
    this.level = 0.0,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) {
      return Text(
        NavixTheme.iconVoiceIdle,
        style: TextStyle(
          fontSize: 24,
          color: NavixTheme.textSecondary,
        ),
      );
    }

    // Generate waveform based on level
    final waveform = _generateWaveform(widget.level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          NavixTheme.iconVoiceRecording,
          style: TextStyle(
            fontSize: 16,
            color: NavixTheme.error,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          waveform,
          style: TextStyle(
            fontSize: 16,
            color: NavixTheme.primary,
            fontFamily: NavixTheme.fontFamilyMono,
          ),
        ),
      ],
    );
  }

  String _generateWaveform(double level) {
    final chars = NavixTheme.waveformChars;
    final buffer = StringBuffer();

    // Generate 8 bars based on level with some variation
    for (var i = 0; i < 8; i++) {
      final variation = (i % 2 == 0 ? 0.2 : -0.1);
      final adjustedLevel = (level + variation).clamp(0.0, 1.0);
      final charIndex = (adjustedLevel * (chars.length - 1)).round();
      buffer.write(chars[charIndex]);
    }

    return buffer.toString();
  }
}

/// Pulsing indicator for initialization
class PulsingIndicator extends StatefulWidget {
  final String label;

  const PulsingIndicator({
    super.key,
    required this.label,
  });

  @override
  State<PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (reduceMotion) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '●',
            style: TextStyle(
              fontSize: 12,
              color: NavixTheme.accentCyan,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavixTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: _animation.value,
              child: Text(
                '●',
                style: TextStyle(
                  fontSize: 12,
                  color: NavixTheme.accentCyan,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NavixTheme.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
