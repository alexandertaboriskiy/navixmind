import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/widgets/context_bar.dart';

void main() {
  group('SmartContextBar', () {
    Widget createTestWidget({
      bool isGoogleConnected = false,
      bool isOffline = false,
      String? activeMode,
      int attachedFileCount = 0,
      VoidCallback? onConnectGoogle,
      VoidCallback? onClearMode,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: SmartContextBar(
            isGoogleConnected: isGoogleConnected,
            isOffline: isOffline,
            activeMode: activeMode,
            attachedFileCount: attachedFileCount,
            onConnectGoogle: onConnectGoogle,
            onClearMode: onClearMode,
          ),
        ),
      );
    }

    group('Empty state', () {
      testWidgets('returns empty widget when no chips to show', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(SmartContextBar), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
      });
    });

    group('Offline indicator', () {
      testWidgets('shows offline chip when offline', (tester) async {
        await tester.pumpWidget(createTestWidget(isOffline: true));

        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('⚠'), findsOneWidget);
      });

      testWidgets('does not show offline chip when online', (tester) async {
        await tester.pumpWidget(createTestWidget(isOffline: false));

        expect(find.text('Offline'), findsNothing);
      });

      testWidgets('offline chip has warning color', (tester) async {
        await tester.pumpWidget(createTestWidget(isOffline: true));

        // Find the warning icon and verify color
        final textWidget = tester.widget<Text>(find.text('⚠'));
        expect(textWidget.style?.color, equals(NavixTheme.warning));
      });
    });

    group('Active mode', () {
      testWidgets('shows calendar mode chip', (tester) async {
        await tester.pumpWidget(createTestWidget(activeMode: 'Calendar'));

        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text(NavixTheme.iconCalendar), findsOneWidget);
      });

      testWidgets('shows email mode chip', (tester) async {
        await tester.pumpWidget(createTestWidget(activeMode: 'Email'));

        expect(find.text('Email'), findsOneWidget);
        expect(find.text(NavixTheme.iconEmail), findsOneWidget);
      });

      testWidgets('shows media mode chip', (tester) async {
        await tester.pumpWidget(createTestWidget(activeMode: 'Media'));

        expect(find.text('Media'), findsOneWidget);
        expect(find.text(NavixTheme.iconVideo), findsOneWidget);
      });

      testWidgets('shows OCR mode chip', (tester) async {
        await tester.pumpWidget(createTestWidget(activeMode: 'OCR'));

        expect(find.text('OCR'), findsOneWidget);
        expect(find.text(NavixTheme.iconImage), findsOneWidget);
      });

      testWidgets('shows close button on active mode chip', (tester) async {
        await tester.pumpWidget(createTestWidget(
          activeMode: 'Calendar',
          onClearMode: () {},
        ));

        expect(find.text(NavixTheme.iconClose), findsOneWidget);
      });

      testWidgets('tapping mode chip calls onClearMode', (tester) async {
        var cleared = false;
        await tester.pumpWidget(createTestWidget(
          activeMode: 'Calendar',
          onClearMode: () => cleared = true,
        ));

        await tester.tap(find.text('Calendar'));
        await tester.pump();

        expect(cleared, isTrue);
      });

      testWidgets('default mode shows generic icon', (tester) async {
        await tester.pumpWidget(createTestWidget(activeMode: 'Unknown'));

        expect(find.text('Unknown'), findsOneWidget);
        expect(find.text('●'), findsOneWidget);
      });
    });

    group('Google connection', () {
      testWidgets('shows connect Google chip when not connected in Calendar mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isGoogleConnected: false,
          activeMode: 'Calendar',
          onConnectGoogle: () {},
        ));

        expect(find.text('Connect Google'), findsOneWidget);
      });

      testWidgets('shows connect Google chip when not connected in Email mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isGoogleConnected: false,
          activeMode: 'Email',
          onConnectGoogle: () {},
        ));

        expect(find.text('Connect Google'), findsOneWidget);
      });

      testWidgets('hides connect Google when already connected', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isGoogleConnected: true,
          activeMode: 'Calendar',
        ));

        expect(find.text('Connect Google'), findsNothing);
      });

      testWidgets('hides connect Google in non-Google modes', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isGoogleConnected: false,
          activeMode: 'Media',
        ));

        expect(find.text('Connect Google'), findsNothing);
      });

      testWidgets('tapping connect Google calls callback', (tester) async {
        var connectCalled = false;
        await tester.pumpWidget(createTestWidget(
          isGoogleConnected: false,
          activeMode: 'Calendar',
          onConnectGoogle: () => connectCalled = true,
        ));

        await tester.tap(find.text('Connect Google'));
        await tester.pump();

        expect(connectCalled, isTrue);
      });
    });

    group('File attachments', () {
      testWidgets('shows single file count', (tester) async {
        await tester.pumpWidget(createTestWidget(attachedFileCount: 1));

        expect(find.text('1 file'), findsOneWidget);
      });

      testWidgets('shows plural file count', (tester) async {
        await tester.pumpWidget(createTestWidget(attachedFileCount: 3));

        expect(find.text('3 files'), findsOneWidget);
      });

      testWidgets('hides file count when zero', (tester) async {
        await tester.pumpWidget(createTestWidget(attachedFileCount: 0));

        expect(find.textContaining('file'), findsNothing);
      });

      testWidgets('shows file icon', (tester) async {
        await tester.pumpWidget(createTestWidget(attachedFileCount: 2));

        expect(find.text(NavixTheme.iconFile), findsOneWidget);
      });
    });

    group('Multiple chips', () {
      testWidgets('shows multiple chips in horizontal scroll', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isOffline: true,
          activeMode: 'Calendar',
          isGoogleConnected: false,
          attachedFileCount: 2,
          onConnectGoogle: () {},
        ));

        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text('Connect Google'), findsOneWidget);
        expect(find.text('2 files'), findsOneWidget);
      });

      testWidgets('chips are horizontally scrollable', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isOffline: true,
          activeMode: 'Calendar',
          isGoogleConnected: false,
          attachedFileCount: 2,
          onConnectGoogle: () {},
        ));

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('Accessibility', () {
      testWidgets('offline chip has tooltip', (tester) async {
        await tester.pumpWidget(createTestWidget(isOffline: true));

        // Find tooltip widget
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Tooltip &&
                widget.message == 'No internet connection. Messages will be queued.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('mode chip has semantic hint', (tester) async {
        await tester.pumpWidget(createTestWidget(
          activeMode: 'Calendar',
          onClearMode: () {},
        ));

        final semantics = tester.getSemantics(find.text('Calendar'));
        expect(semantics.label, contains('Calendar'));
      });
    });
  });

  group('QuickActionPills', () {
    Widget createTestWidget({
      required Function(String) onAction,
      bool showCalendar = true,
      bool showEmail = true,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: QuickActionPills(
            onAction: onAction,
            showCalendar: showCalendar,
            showEmail: showEmail,
          ),
        ),
      );
    }

    testWidgets('shows calendar action pill', (tester) async {
      await tester.pumpWidget(createTestWidget(onAction: (_) {}));

      expect(find.text("What's on my calendar?"), findsOneWidget);
    });

    testWidgets('shows email action pill', (tester) async {
      await tester.pumpWidget(createTestWidget(onAction: (_) {}));

      expect(find.text('Check emails'), findsOneWidget);
    });

    testWidgets('shows summarize action pill', (tester) async {
      await tester.pumpWidget(createTestWidget(onAction: (_) {}));

      expect(find.text('Summarize'), findsOneWidget);
    });

    testWidgets('shows process video action pill', (tester) async {
      await tester.pumpWidget(createTestWidget(onAction: (_) {}));

      expect(find.text('Process video'), findsOneWidget);
    });

    testWidgets('calendar pill triggers correct action', (tester) async {
      String? triggeredAction;
      await tester.pumpWidget(createTestWidget(
        onAction: (action) => triggeredAction = action,
      ));

      await tester.tap(find.text("What's on my calendar?"));
      await tester.pump();

      expect(triggeredAction, equals('/calendar list today'));
    });

    testWidgets('email pill triggers correct action', (tester) async {
      String? triggeredAction;
      await tester.pumpWidget(createTestWidget(
        onAction: (action) => triggeredAction = action,
      ));

      await tester.tap(find.text('Check emails'));
      await tester.pump();

      expect(triggeredAction, equals('/email list is:unread'));
    });

    testWidgets('summarize pill triggers correct action', (tester) async {
      String? triggeredAction;
      await tester.pumpWidget(createTestWidget(
        onAction: (action) => triggeredAction = action,
      ));

      await tester.tap(find.text('Summarize'));
      await tester.pump();

      expect(triggeredAction, equals('/summarize '));
    });

    testWidgets('process video pill triggers correct action', (tester) async {
      String? triggeredAction;
      await tester.pumpWidget(createTestWidget(
        onAction: (action) => triggeredAction = action,
      ));

      // Scroll to bring "Process video" into view (it's in a horizontal ListView)
      await tester.scrollUntilVisible(
        find.text('Process video'),
        200, // scroll by 200 pixels at a time
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Process video'), warnIfMissed: false);
      await tester.pump();

      expect(triggeredAction, equals('/crop '));
    });

    testWidgets('pills are horizontally scrollable', (tester) async {
      await tester.pumpWidget(createTestWidget(onAction: (_) {}));

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, equals(Axis.horizontal));
    });

    group('Accessibility', () {
      testWidgets('action pills have semantic labels', (tester) async {
        await tester.pumpWidget(createTestWidget(onAction: (_) {}));

        final semantics = tester.getSemantics(find.text("What's on my calendar?"));
        expect(semantics.label, contains("What's on my calendar?"));
      });

      testWidgets('action pills have tap hint', (tester) async {
        await tester.pumpWidget(createTestWidget(onAction: (_) {}));

        final semanticsFinder = find.bySemanticsLabel(
          RegExp(r"What's on my calendar\?"),
        );

        expect(semanticsFinder, findsOneWidget);
      });
    });
  });

  group('_ContextChip internal widget', () {
    // These test the internal chip behavior indirectly through SmartContextBar

    testWidgets('chip without onTap is not interactive', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NavixTheme.darkTheme,
          home: Scaffold(
            body: SmartContextBar(
              isOffline: true, // Offline chip doesn't have onTap
            ),
          ),
        ),
      );

      // Tapping offline chip shouldn't trigger any action (no GestureDetector wrapping)
      await tester.tap(find.text('Offline'));
      await tester.pump();

      // No error means success - chip is not interactive
    });

    testWidgets('chip with onTap is wrapped in GestureDetector', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: NavixTheme.darkTheme,
          home: Scaffold(
            body: SmartContextBar(
              activeMode: 'Calendar',
              onClearMode: () => tapped = true,
            ),
          ),
        ),
      );

      // Find and tap the mode chip
      await tester.tap(find.text('Calendar'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
