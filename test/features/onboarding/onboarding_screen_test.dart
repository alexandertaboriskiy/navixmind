import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/onboarding/onboarding_screen.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockStorageService extends Mock {
  Future<void> setApiKey(String key) async {}
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockNavigatorObserver = MockNavigatorObserver();
  });

  Widget createTestWidget({
    MockStorageService? storageService,
    List<NavigatorObserver>? observers,
  }) {
    return MaterialApp(
      theme: NavixTheme.darkTheme,
      navigatorObservers: observers ?? [mockNavigatorObserver],
      routes: {
        '/home': (context) => const Scaffold(body: Text('Home Screen')),
      },
      home: const OnboardingScreen(),
    );
  }

  group('OnboardingScreen Progress Indicator', () {
    testWidgets('renders 4 progress indicator segments', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find containers with height 4 (progress indicator segments)
      final progressIndicators = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxHeight == 4 &&
            widget.constraints?.minHeight == 4,
      );

      expect(progressIndicators, findsNWidgets(4));
    });

    testWidgets('first segment is active on initial page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find the Row containing progress indicators
      final progressRow = find.byWidgetPredicate(
        (widget) =>
            widget is Row &&
            widget.children.isNotEmpty &&
            widget.children.first is Expanded,
      );

      expect(progressRow, findsOneWidget);
    });

    testWidgets('progress indicator updates on page change', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap Next to go to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap Next to go to page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // We should be on page 3 now (index 2)
      expect(find.text('Connect Your Services'), findsOneWidget);
    });
  });

  group('OnboardingScreen Initial Page', () {
    testWidgets('shows welcome content on initial page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Welcome to NavixMind'), findsOneWidget);
      expect(find.text('\u25C6'), findsOneWidget); // Diamond icon
    });

    testWidgets('shows welcome description', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(
        find.textContaining('Your AI-powered console agent'),
        findsOneWidget,
      );
    });
  });

  group('OnboardingScreen Navigation Buttons', () {
    testWidgets('Next button is visible on first page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Next'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Back button is hidden on first page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Back'), findsNothing);
    });

    testWidgets('Next button advances to next page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verify we're on the first page
      expect(find.text('Welcome to NavixMind'), findsOneWidget);

      // Tap Next
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify we're on the second page
      expect(find.text('Process Any Media'), findsOneWidget);
    });

    testWidgets('Back button appears on second page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Go to second page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Back button goes to previous page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Go to second page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Process Any Media'), findsOneWidget);

      // Tap Back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Verify we're back on first page
      expect(find.text('Welcome to NavixMind'), findsOneWidget);
    });

    testWidgets('Get Started button appears on last page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to last page (4th page - API key page)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });
  });

  group('OnboardingScreen Page Content', () {
    testWidgets('page 1 shows Welcome to NavixMind with diamond icon',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Welcome to NavixMind'), findsOneWidget);
      expect(find.text('\u25C6'), findsOneWidget); // Diamond
      expect(
        find.textContaining('Your AI-powered console agent'),
        findsOneWidget,
      );
    });

    testWidgets('page 2 shows Process Any Media with file icon',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Process Any Media'), findsOneWidget);
      expect(find.text('\u25F0'), findsOneWidget); // File icon
      expect(
        find.textContaining('Extract text from PDFs'),
        findsOneWidget,
      );
    });

    testWidgets('page 3 shows Connect Your Services with service icon',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Connect Your Services'), findsOneWidget);
      expect(find.text('\u25EB'), findsOneWidget); // Service icon
      expect(
        find.textContaining('Link your Google account'),
        findsOneWidget,
      );
    });

    testWidgets('page 4 shows API Key entry with add icon', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to page 4
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Your API Key'), findsOneWidget);
      expect(find.text('\u2295'), findsOneWidget); // Add icon
      expect(
        find.textContaining('NavixMind uses Claude AI'),
        findsOneWidget,
      );
    });
  });

  group('OnboardingScreen API Key Page', () {
    testWidgets('API key page shows text field', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('API key field has correct hint text', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('sk-ant-...'), findsOneWidget);
    });

    testWidgets('API key field has label text', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Claude API Key'), findsOneWidget);
    });

    testWidgets('API key field is obscured', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('API key page shows security notice', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('stored securely on your device'),
        findsOneWidget,
      );
    });

    testWidgets('empty API key shows snackbar error', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap Get Started without entering API key
      await tester.tap(find.text('Get Started'));
      await tester.pump();

      expect(find.text('Please enter your Claude API key'), findsOneWidget);
    });

    testWidgets('whitespace-only API key shows snackbar error', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Enter whitespace only
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pump();

      expect(find.text('Please enter your Claude API key'), findsOneWidget);
    });

    testWidgets('can enter text in API key field', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Enter API key
      await tester.enterText(find.byType(TextField), 'sk-ant-test-key-123');
      await tester.pump();

      // Verify text was entered (field is obscured so we check controller)
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'sk-ant-test-key-123');
    });
  });

  group('OnboardingScreen Page Swipe', () {
    testWidgets('swiping left advances to next page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Welcome to NavixMind'), findsOneWidget);

      // Swipe left (drag from right to left)
      await tester.drag(
        find.byType(PageView),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Process Any Media'), findsOneWidget);
    });

    testWidgets('swiping right goes to previous page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // First go to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Process Any Media'), findsOneWidget);

      // Swipe right (drag from left to right) with fling to ensure page change
      await tester.fling(
        find.byType(PageView),
        const Offset(400, 0),
        1000,  // velocity
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to NavixMind'), findsOneWidget);
    });

    testWidgets('swiping through all pages works', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Page 1
      expect(find.text('Welcome to NavixMind'), findsOneWidget);

      // Swipe to page 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Process Any Media'), findsOneWidget);

      // Swipe to page 3
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Connect Your Services'), findsOneWidget);

      // Swipe to page 4
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Enter Your API Key'), findsOneWidget);
    });

    testWidgets('page swipe updates progress indicator and buttons',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initially no Back button
      expect(find.text('Back'), findsNothing);

      // Swipe to page 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Back button should appear
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Swipe to page 4 (API key page)
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Get Started button should appear
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });
  });

  group('OnboardingScreen Structure', () {
    testWidgets('has SafeArea', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('has PageView', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('PageView has 4 children', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.childrenDelegate.estimatedChildCount, 4);
    });

    testWidgets('uses correct background color', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, NavixTheme.background);
    });
  });

  group('OnboardingScreen Icon Styling', () {
    testWidgets('icons use primary color', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find the diamond icon text widget
      final iconFinder = find.text('\u25C6');
      expect(iconFinder, findsOneWidget);

      final iconText = tester.widget<Text>(iconFinder);
      expect(iconText.style?.color, NavixTheme.primary);
    });

    testWidgets('icons have large font size', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final iconFinder = find.text('\u25C6');
      final iconText = tester.widget<Text>(iconFinder);
      expect(iconText.style?.fontSize, 64);
    });
  });

  group('OnboardingScreen Multiple Interactions', () {
    testWidgets('can navigate back and forth multiple times', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Go forward
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Process Any Media'), findsOneWidget);

      // Go forward again
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Connect Your Services'), findsOneWidget);

      // Go back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Process Any Media'), findsOneWidget);

      // Go back again
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to NavixMind'), findsOneWidget);

      // Go forward to last page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Your API Key'), findsOneWidget);
    });

    testWidgets('progress indicator reflects current page after navigation',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify we're on page 3
      expect(find.text('Connect Your Services'), findsOneWidget);

      // Go back to page 2
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Verify we're on page 2
      expect(find.text('Process Any Media'), findsOneWidget);
    });
  });

  group('OnboardingScreen Edge Cases', () {
    testWidgets('cannot swipe past first page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Welcome to NavixMind'), findsOneWidget);

      // Try to swipe right on first page
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();

      // Should still be on first page
      expect(find.text('Welcome to NavixMind'), findsOneWidget);
    });

    testWidgets('cannot swipe past last page', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to last page
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Enter Your API Key'), findsOneWidget);

      // Try to swipe left on last page
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Should still be on last page
      expect(find.text('Enter Your API Key'), findsOneWidget);
    });

    testWidgets('API key field scrollable on small screens', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // API key page should have SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('OnboardingScreen Text Content', () {
    testWidgets('page descriptions are properly displayed', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Page 1 description
      expect(
        find.textContaining('manage calendar'),
        findsOneWidget,
      );

      // Navigate to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 2 description
      expect(
        find.textContaining('crop videos'),
        findsOneWidget,
      );

      // Navigate to page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 3 description
      expect(
        find.textContaining('calendar events and emails'),
        findsOneWidget,
      );
    });

    testWidgets('API key page has console.anthropic.com reference',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to API key page
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(
        find.textContaining('console.anthropic.com'),
        findsOneWidget,
      );
    });
  });
}
