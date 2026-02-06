import 'package:flutter/material.dart';

/// Accessibility utilities for the NavixMind app.
///
/// Provides helpers for respecting system accessibility settings
/// like "Reduce motion" and screen readers.
class AccessibilityUtils {
  AccessibilityUtils._();

  /// Check if the user has enabled "Reduce motion" in system settings.
  ///
  /// When true, animations should be disabled or minimized:
  /// - Use Duration.zero instead of animated durations
  /// - Show static indicators instead of spinners
  /// - Skip transition animations
  static bool reduceMotionEnabled(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get the appropriate animation duration respecting reduce motion.
  ///
  /// Returns [Duration.zero] if reduce motion is enabled,
  /// otherwise returns the provided duration.
  static Duration animationDuration(
    BuildContext context, {
    Duration normal = const Duration(milliseconds: 300),
  }) {
    return reduceMotionEnabled(context) ? Duration.zero : normal;
  }

  /// Get animation curve respecting reduce motion.
  ///
  /// Returns [Curves.linear] if reduce motion is enabled
  /// (for instant transitions), otherwise returns the provided curve.
  static Curve animationCurve(
    BuildContext context, {
    Curve normal = Curves.easeInOut,
  }) {
    return reduceMotionEnabled(context) ? Curves.linear : normal;
  }

  /// Check if the screen reader (TalkBack on Android) is active.
  static bool screenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Check if bold text is enabled in system settings.
  static bool boldTextEnabled(BuildContext context) {
    return MediaQuery.of(context).boldText;
  }

  /// Get the text scale factor from system settings.
  ///
  /// Clamped between 0.8 and 2.0 to prevent UI breaking.
  static double textScaleFactor(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1.0).clamp(0.8, 2.0);
  }
}

/// An animated container that respects "Reduce motion" setting.
///
/// When reduce motion is enabled, changes happen instantly.
/// Otherwise, uses the standard AnimatedContainer behavior.
class AccessibleAnimatedContainer extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Matrix4? transform;
  final Clip clipBehavior;

  const AccessibleAnimatedContainer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.constraints,
    this.transform,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AccessibilityUtils.animationDuration(context, normal: duration),
      curve: AccessibilityUtils.animationCurve(context, normal: curve),
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      width: width,
      height: height,
      constraints: constraints,
      transform: transform,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// An animated opacity widget that respects "Reduce motion" setting.
class AccessibleAnimatedOpacity extends StatelessWidget {
  final Widget child;
  final double opacity;
  final Duration duration;
  final Curve curve;

  const AccessibleAnimatedOpacity({
    super.key,
    required this.child,
    required this.opacity,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: AccessibilityUtils.animationDuration(context, normal: duration),
      curve: AccessibilityUtils.animationCurve(context, normal: curve),
      child: child,
    );
  }
}

/// A crossfade widget that respects "Reduce motion" setting.
class AccessibleAnimatedCrossFade extends StatelessWidget {
  final Widget firstChild;
  final Widget secondChild;
  final CrossFadeState crossFadeState;
  final Duration duration;

  const AccessibleAnimatedCrossFade({
    super.key,
    required this.firstChild,
    required this.secondChild,
    required this.crossFadeState,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDuration =
        AccessibilityUtils.animationDuration(context, normal: duration);

    // If reduce motion, just show the current child without animation
    if (effectiveDuration == Duration.zero) {
      return crossFadeState == CrossFadeState.showFirst
          ? firstChild
          : secondChild;
    }

    return AnimatedCrossFade(
      firstChild: firstChild,
      secondChild: secondChild,
      crossFadeState: crossFadeState,
      duration: effectiveDuration,
    );
  }
}

/// Helper extension for making widgets accessibility-aware.
extension AccessibilityExtension on Widget {
  /// Wrap with Semantics for screen reader support.
  ///
  /// Use for interactive elements that use Unicode icons
  /// which may not be announced correctly by screen readers.
  Widget withSemanticLabel(String label, {bool button = false}) {
    return Semantics(
      label: label,
      button: button,
      child: this,
    );
  }

  /// Exclude from semantics tree (for decorative elements).
  Widget excludeFromSemantics() {
    return ExcludeSemantics(child: this);
  }
}
