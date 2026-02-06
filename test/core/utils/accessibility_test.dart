import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/utils/accessibility.dart';

void main() {
  group('AccessibilityUtils', () {
    group('reduceMotionEnabled', () {
      testWidgets('returns false when animations not disabled', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                expect(AccessibilityUtils.reduceMotionEnabled(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns true when animations disabled', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                expect(AccessibilityUtils.reduceMotionEnabled(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('animationDuration', () {
      testWidgets('returns normal duration when reduce motion disabled',
          (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                final duration = AccessibilityUtils.animationDuration(
                  context,
                  normal: const Duration(milliseconds: 500),
                );
                expect(duration, equals(const Duration(milliseconds: 500)));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns Duration.zero when reduce motion enabled',
          (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                final duration = AccessibilityUtils.animationDuration(
                  context,
                  normal: const Duration(milliseconds: 500),
                );
                expect(duration, equals(Duration.zero));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('uses default duration of 300ms', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                final duration = AccessibilityUtils.animationDuration(context);
                expect(duration, equals(const Duration(milliseconds: 300)));
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('animationCurve', () {
      testWidgets('returns normal curve when reduce motion disabled',
          (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                final curve = AccessibilityUtils.animationCurve(
                  context,
                  normal: Curves.bounceIn,
                );
                expect(curve, equals(Curves.bounceIn));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns Curves.linear when reduce motion enabled',
          (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                final curve = AccessibilityUtils.animationCurve(
                  context,
                  normal: Curves.bounceIn,
                );
                expect(curve, equals(Curves.linear));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('uses default curve of easeInOut', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                final curve = AccessibilityUtils.animationCurve(context);
                expect(curve, equals(Curves.easeInOut));
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('screenReaderEnabled', () {
      testWidgets('returns false when accessible navigation disabled',
          (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(accessibleNavigation: false),
            child: Builder(
              builder: (context) {
                expect(AccessibilityUtils.screenReaderEnabled(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns true when accessible navigation enabled',
          (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (context) {
                expect(AccessibilityUtils.screenReaderEnabled(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('boldTextEnabled', () {
      testWidgets('returns false when bold text disabled', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(boldText: false),
            child: Builder(
              builder: (context) {
                expect(AccessibilityUtils.boldTextEnabled(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns true when bold text enabled', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(boldText: true),
            child: Builder(
              builder: (context) {
                expect(AccessibilityUtils.boldTextEnabled(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('textScaleFactor', () {
      testWidgets('returns 1.0 for default scale', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
            child: Builder(
              builder: (context) {
                final scale = AccessibilityUtils.textScaleFactor(context);
                expect(scale, equals(1.0));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns scaled value within bounds', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Builder(
              builder: (context) {
                final scale = AccessibilityUtils.textScaleFactor(context);
                expect(scale, equals(1.5));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('clamps scale to minimum 0.8', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
            child: Builder(
              builder: (context) {
                final scale = AccessibilityUtils.textScaleFactor(context);
                expect(scale, equals(0.8));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('clamps scale to maximum 2.0', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: Builder(
              builder: (context) {
                final scale = AccessibilityUtils.textScaleFactor(context);
                expect(scale, equals(2.0));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('handles boundary values correctly', (tester) async {
        // Test exactly at min bound
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
            child: Builder(
              builder: (context) {
                final scale = AccessibilityUtils.textScaleFactor(context);
                expect(scale, equals(0.8));
                return const SizedBox();
              },
            ),
          ),
        );

        // Test exactly at max bound
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Builder(
              builder: (context) {
                final scale = AccessibilityUtils.textScaleFactor(context);
                expect(scale, equals(2.0));
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });
  });

  group('AccessibleAnimatedContainer', () {
    testWidgets('uses normal duration when reduce motion disabled',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedContainer(
              duration: Duration(milliseconds: 500),
              width: 100,
              height: 100,
              child: Text('Test'),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('uses Duration.zero when reduce motion enabled',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: AccessibleAnimatedContainer(
              duration: Duration(milliseconds: 500),
              width: 100,
              height: 100,
              child: Text('Test'),
            ),
          ),
        ),
      );

      final animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animatedContainer.duration, equals(Duration.zero));
    });

    testWidgets('passes all properties to AnimatedContainer', (tester) async {
      const testColor = Colors.red;
      const testPadding = EdgeInsets.all(16);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedContainer(
              width: 200,
              height: 150,
              color: testColor,
              padding: testPadding,
              child: Text('Test'),
            ),
          ),
        ),
      );

      final animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animatedContainer.constraints?.maxWidth, equals(200));
      expect(animatedContainer.constraints?.maxHeight, equals(150));
    });
  });

  group('AccessibleAnimatedOpacity', () {
    testWidgets('uses normal duration when reduce motion disabled',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedOpacity(
              opacity: 0.5,
              duration: Duration(milliseconds: 400),
              child: Text('Test'),
            ),
          ),
        ),
      );

      final animatedOpacity =
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.duration, equals(const Duration(milliseconds: 400)));
    });

    testWidgets('uses Duration.zero when reduce motion enabled',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: AccessibleAnimatedOpacity(
              opacity: 0.5,
              duration: Duration(milliseconds: 400),
              child: Text('Test'),
            ),
          ),
        ),
      );

      final animatedOpacity =
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.duration, equals(Duration.zero));
    });

    testWidgets('applies opacity correctly', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedOpacity(
              opacity: 0.7,
              child: Text('Test'),
            ),
          ),
        ),
      );

      final animatedOpacity =
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.opacity, equals(0.7));
    });
  });

  group('AccessibleAnimatedCrossFade', () {
    testWidgets('shows first child when CrossFadeState.showFirst',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedCrossFade(
              firstChild: Text('First'),
              secondChild: Text('Second'),
              crossFadeState: CrossFadeState.showFirst,
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
    });

    testWidgets('shows second child when CrossFadeState.showSecond',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedCrossFade(
              firstChild: Text('First'),
              secondChild: Text('Second'),
              crossFadeState: CrossFadeState.showSecond,
            ),
          ),
        ),
      );

      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('skips animation when reduce motion enabled', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: AccessibleAnimatedCrossFade(
              firstChild: Text('First'),
              secondChild: Text('Second'),
              crossFadeState: CrossFadeState.showFirst,
            ),
          ),
        ),
      );

      // Should show only the current child without AnimatedCrossFade
      expect(find.text('First'), findsOneWidget);
      expect(find.byType(AnimatedCrossFade), findsNothing);
    });

    testWidgets('uses AnimatedCrossFade when reduce motion disabled',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const MaterialApp(
            home: AccessibleAnimatedCrossFade(
              firstChild: Text('First'),
              secondChild: Text('Second'),
              crossFadeState: CrossFadeState.showFirst,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedCrossFade), findsOneWidget);
    });
  });

  group('AccessibilityExtension', () {
    testWidgets('withSemanticLabel adds Semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Text('Icon').withSemanticLabel('Close button'),
        ),
      );

      // Find the Semantics widget that is an ancestor of our Text widget
      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.text('Icon'),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(semantics.properties.label, equals('Close button'));
    });

    testWidgets('withSemanticLabel can mark as button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Text('Icon').withSemanticLabel(
            'Submit',
            button: true,
          ),
        ),
      );

      // Find the Semantics widget that is an ancestor of our Text widget
      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.text('Icon'),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(semantics.properties.label, equals('Submit'));
      expect(semantics.properties.button, isTrue);
    });

    testWidgets('excludeFromSemantics wraps with ExcludeSemantics',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Text('Decorative').excludeFromSemantics(),
        ),
      );

      // ExcludeSemantics should be an ancestor of the Text widget
      expect(
        find.ancestor(
          of: find.text('Decorative'),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('Accessibility combinations', () {
    testWidgets('handles multiple accessibility settings simultaneously',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            accessibleNavigation: true,
            boldText: true,
            textScaler: TextScaler.linear(1.5),
          ),
          child: Builder(
            builder: (context) {
              expect(AccessibilityUtils.reduceMotionEnabled(context), isTrue);
              expect(AccessibilityUtils.screenReaderEnabled(context), isTrue);
              expect(AccessibilityUtils.boldTextEnabled(context), isTrue);
              expect(AccessibilityUtils.textScaleFactor(context), equals(1.5));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('all accessible widgets work with screen reader',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: MaterialApp(
            home: Column(
              children: [
                const AccessibleAnimatedContainer(
                  child: Text('Container'),
                ),
                const AccessibleAnimatedOpacity(
                  opacity: 1.0,
                  child: Text('Opacity'),
                ),
                const AccessibleAnimatedCrossFade(
                  firstChild: Text('First'),
                  secondChild: Text('Second'),
                  crossFadeState: CrossFadeState.showFirst,
                ),
                const Text('Button').withSemanticLabel('Close', button: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Container'), findsOneWidget);
      expect(find.text('Opacity'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
    });
  });

  group('Edge cases', () {
    testWidgets('handles default MediaQuery', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(), // All defaults
          child: MaterialApp(
            home: _AccessibilityTestWidget(),
          ),
        ),
      );

      // Should not crash and return default values
      expect(find.byType(_AccessibilityTestWidget), findsOneWidget);
    });

    testWidgets('handles animated crossfade state changes', (tester) async {
      var showFirst = true;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return GestureDetector(
                  onTap: () => setState(() => showFirst = !showFirst),
                  child: AccessibleAnimatedCrossFade(
                    firstChild: const Text('First'),
                    secondChild: const Text('Second'),
                    crossFadeState: showFirst
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);

      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('handles rapid state changes with reduce motion',
        (tester) async {
      var showFirst = true;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return GestureDetector(
                  onTap: () => setState(() => showFirst = !showFirst),
                  child: AccessibleAnimatedCrossFade(
                    firstChild: const Text('First'),
                    secondChild: const Text('Second'),
                    crossFadeState: showFirst
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Rapid changes should be instant with reduce motion
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
      }

      // Should handle without crashing
      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });
}

/// Test widget that uses all accessibility utilities
class _AccessibilityTestWidget extends StatelessWidget {
  const _AccessibilityTestWidget();

  @override
  Widget build(BuildContext context) {
    // Access all utilities
    AccessibilityUtils.reduceMotionEnabled(context);
    AccessibilityUtils.screenReaderEnabled(context);
    AccessibilityUtils.boldTextEnabled(context);
    AccessibilityUtils.textScaleFactor(context);
    AccessibilityUtils.animationDuration(context);
    AccessibilityUtils.animationCurve(context);

    return const Text('Test');
  }
}
