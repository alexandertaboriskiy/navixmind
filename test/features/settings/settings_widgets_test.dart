import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/core/constants/defaults.dart';

// Test wrapper widgets that mirror the private widgets in settings_screen.dart
// We create exact copies of the private widgets for testing purposes since
// Dart's privacy model doesn't allow importing private classes from other files.

void main() {
  group('_SectionHeader', () {
    Widget createTestWidget(String title) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: _TestSectionHeader(title: title),
        ),
      );
    }

    testWidgets('displays title text', (tester) async {
      await tester.pumpWidget(createTestWidget('Test Section'));

      expect(find.text('Test Section'), findsOneWidget);
    });

    testWidgets('displays different titles correctly', (tester) async {
      await tester.pumpWidget(createTestWidget('API Configuration'));

      expect(find.text('API Configuration'), findsOneWidget);
    });

    testWidgets('uses correct text style with secondary color', (tester) async {
      await tester.pumpWidget(createTestWidget('Test Section'));

      final textWidget = tester.widget<Text>(find.text('Test Section'));
      expect(textWidget.style?.color, equals(NavixTheme.textSecondary));
    });

    testWidgets('has bottom padding', (tester) async {
      await tester.pumpWidget(createTestWidget('Test'));

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, equals(const EdgeInsets.only(bottom: 8)));
    });
  });

  group('_SettingsTile', () {
    Widget createTestWidget({
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: _TestSettingsTile(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('displays title', (tester) async {
      await tester.pumpWidget(createTestWidget(title: 'Claude API Key'));

      expect(find.text('Claude API Key'), findsOneWidget);
    });

    testWidgets('displays subtitle when provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'Claude API Key',
        subtitle: 'Configured',
      ));

      expect(find.text('Configured'), findsOneWidget);
    });

    testWidgets('does not display subtitle when not provided', (tester) async {
      await tester.pumpWidget(createTestWidget(title: 'Licenses'));

      // Find ListTile and check its subtitle
      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.subtitle, isNull);
    });

    testWidgets('shows trailing widget when provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'Test',
        trailing: const Icon(Icons.check),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows text trailing widget', (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'Test',
        trailing: Text(
          NavixTheme.iconCheck,
          style: TextStyle(color: NavixTheme.success),
        ),
      ));

      expect(find.text(NavixTheme.iconCheck), findsOneWidget);
    });

    testWidgets('onTap callback fires when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(createTestWidget(
        title: 'Tap Me',
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('Card structure is present', (tester) async {
      await tester.pumpWidget(createTestWidget(title: 'Test'));

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('ListTile is inside Card', (tester) async {
      await tester.pumpWidget(createTestWidget(title: 'Test'));

      final card = find.byType(Card);
      final listTile = find.descendant(of: card, matching: find.byType(ListTile));
      expect(listTile, findsOneWidget);
    });

    testWidgets('Card has bottom margin', (tester) async {
      await tester.pumpWidget(createTestWidget(title: 'Test'));

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, equals(const EdgeInsets.only(bottom: 8)));
    });
  });

  group('_SettingsTile System Prompt subtitle', () {
    Widget createTestWidget({
      required String title,
      String? subtitle,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: _TestSettingsTile(
            title: title,
            subtitle: subtitle,
          ),
        ),
      );
    }

    testWidgets('System Prompt tile shows Custom subtitle when custom prompt is set', (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'System Prompt',
        subtitle: 'Custom',
      ));

      expect(find.text('System Prompt'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('System Prompt tile shows Default subtitle when no custom prompt', (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'System Prompt',
        subtitle: 'Default',
      ));

      expect(find.text('System Prompt'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
    });
  });

  group('_SystemPromptEditor', () {
    Widget createTestWidget({
      String? initialCustomPrompt,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: _TestSystemPromptEditor(
          initialCustomPrompt: initialCustomPrompt,
        ),
      );
    }

    testWidgets('displays System Prompt title in app bar', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('System Prompt'), findsOneWidget);
    });

    testWidgets('shows default prompt text initially', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // The TextField should contain the default system prompt text
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals(defaultSystemPrompt));
    });

    testWidgets('shows character count', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(
        find.text('${defaultSystemPrompt.length} characters'),
        findsOneWidget,
      );
    });

    testWidgets('displays Default prompt label when using default', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Default prompt'), findsOneWidget);
    });

    testWidgets('displays Custom prompt label when using custom', (tester) async {
      await tester.pumpWidget(createTestWidget(
        initialCustomPrompt: 'You are a helpful assistant.',
      ));

      expect(find.text('Custom prompt'), findsOneWidget);
    });

    testWidgets('Save button is disabled when no changes made', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find the Save TextButton — it should have onPressed == null
      final saveButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Save button becomes enabled after text change', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Type something into the TextField to make it dirty
      await tester.enterText(find.byType(TextField), 'Modified prompt');
      await tester.pump();

      final saveButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('Reset button loads default prompt text', (tester) async {
      await tester.pumpWidget(createTestWidget(
        initialCustomPrompt: 'Some custom text',
      ));

      // Verify custom text is shown
      final textFieldBefore = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldBefore.controller?.text, equals('Some custom text'));

      // Tap reset
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pump();

      // Verify default text is now in the TextField
      final textFieldAfter = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldAfter.controller?.text, equals(defaultSystemPrompt));
    });

    testWidgets('Reset button sets isDirty so Save becomes enabled', (tester) async {
      await tester.pumpWidget(createTestWidget(
        initialCustomPrompt: 'Custom prompt here',
      ));

      // Save should be disabled initially (no changes yet)
      final saveButtonBefore = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(saveButtonBefore.onPressed, isNull);

      // Tap reset
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pump();

      // Save should now be enabled
      final saveButtonAfter = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(saveButtonAfter.onPressed, isNotNull);
    });

    testWidgets('character count updates when text changes', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initially shows default prompt length
      expect(
        find.text('${defaultSystemPrompt.length} characters'),
        findsOneWidget,
      );

      // Enter new text
      const newText = 'Hello world';
      await tester.enterText(find.byType(TextField), newText);
      await tester.pump();

      expect(find.text('${newText.length} characters'), findsOneWidget);
    });

    testWidgets('label switches from Default to Custom when text differs', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Default prompt'), findsOneWidget);
      expect(find.text('Custom prompt'), findsNothing);

      // Modify text to something different from default
      await tester.enterText(find.byType(TextField), 'A completely different prompt');
      await tester.pump();

      expect(find.text('Custom prompt'), findsOneWidget);
      expect(find.text('Default prompt'), findsNothing);
    });

    testWidgets('label stays Default when text is reset to default', (tester) async {
      await tester.pumpWidget(createTestWidget(
        initialCustomPrompt: 'Custom text',
      ));

      expect(find.text('Custom prompt'), findsOneWidget);

      // Tap reset to go back to default
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pump();

      expect(find.text('Default prompt'), findsOneWidget);
    });

    testWidgets('has multiline TextField with monospace font', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, isNull); // null for multiline with expands
      expect(textField.expands, isTrue);
      expect(textField.style?.fontFamily, equals('monospace'));
    });

    testWidgets('has Reset and Save buttons in AppBar', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    });

    testWidgets('empty text shows 0 characters', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('0 characters'), findsOneWidget);
    });
  });

  group('_UsageCard', () {
    Widget createTestWidget({
      required String title,
      required double used,
      required double limit,
      required bool enabled,
      VoidCallback? onEditLimit,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: _TestUsageCard(
              title: title,
              used: used,
              limit: limit,
              enabled: enabled,
              onEditLimit: onEditLimit ?? () {},
            ),
          ),
        ),
      );
    }

    group('Display', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('Today'), findsOneWidget);
      });

      testWidgets('displays This Month title', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'This Month',
          used: 5.0,
          limit: 10.0,
          enabled: true,
        ));

        expect(find.text('This Month'), findsOneWidget);
      });

      testWidgets('formats used amount with 4 decimals', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.1234,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('\$0.1234'), findsOneWidget);
      });

      testWidgets('formats limit amount with 2 decimals', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text(' / \$0.50'), findsOneWidget);
      });

      testWidgets('shows edit icon', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        // The pencil icon character
        expect(find.text('\u270e'), findsOneWidget);
      });
    });

    group('Progress bar', () {
      testWidgets('progress bar value is correct at 50%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.5));
      });

      testWidgets('progress bar value is correct at 80%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.40,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.8));
      });

      testWidgets('progress bar shows 0 when disabled', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: false,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.0));
      });

      testWidgets('progress bar clamped to 1.0 when over limit', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.75,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(1.0));
      });

      testWidgets('progress bar is 0 when limit is 0', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.0,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.0));
      });
    });

    group('Colors', () {
      testWidgets('primary color when below 80%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.39,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final animation = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
        expect(animation.value, equals(NavixTheme.primary));
      });

      testWidgets('warning color when above 80%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.41, // 82%
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final animation = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
        expect(animation.value, equals(NavixTheme.warning));
      });

      testWidgets('error color when at or above 100%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.50,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final animation = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
        expect(animation.value, equals(NavixTheme.error));
      });

      testWidgets('error color when over 100%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.75,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final animation = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
        expect(animation.value, equals(NavixTheme.error));
      });

      testWidgets('tertiary color when disabled', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.45,
          limit: 0.50,
          enabled: false,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final animation = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
        expect(animation.value, equals(NavixTheme.textTertiary));
      });
    });

    group('Warning messages', () {
      testWidgets('shows warning message at 81%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.405,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('Approaching limit (81%)'), findsOneWidget);
        expect(find.text(NavixTheme.iconWarning), findsOneWidget);
      });

      testWidgets('shows limit reached message at 100%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.50,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('Limit reached. Agent paused.'), findsOneWidget);
      });

      testWidgets('shows limit reached message when over 100%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.60,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('Limit reached. Agent paused.'), findsOneWidget);
      });

      testWidgets('no warning message below 80%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.40, // exactly 80%
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('Approaching limit'), findsNothing);
        expect(find.text('Limit reached'), findsNothing);
      });

      testWidgets('no warning message when disabled', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.45, // 90%
          limit: 0.50,
          enabled: false,
        ));

        expect(find.textContaining('Approaching limit'), findsNothing);
        expect(find.textContaining('Limit reached'), findsNothing);
      });

      testWidgets('no warning when disabled even at 100%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.50,
          limit: 0.50,
          enabled: false,
        ));

        expect(find.textContaining('Limit reached'), findsNothing);
      });
    });

    group('Edit limit interaction', () {
      testWidgets('onEditLimit called when tapped on amounts', (tester) async {
        var editLimitCalled = false;
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
          onEditLimit: () => editLimitCalled = true,
        ));

        // Tap on the GestureDetector area (amounts section)
        await tester.tap(find.byType(GestureDetector).first);
        expect(editLimitCalled, isTrue);
      });

      testWidgets('onEditLimit works when disabled', (tester) async {
        var editLimitCalled = false;
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: false,
          onEditLimit: () => editLimitCalled = true,
        ));

        await tester.tap(find.byType(GestureDetector).first);
        expect(editLimitCalled, isTrue);
      });
    });

    group('Edge cases', () {
      testWidgets('handles zero usage', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.0,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.text('\$0.0000'), findsOneWidget);
        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.0));
      });

      testWidgets('handles zero limit', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.0,
          enabled: true,
        ));

        expect(find.text(' / \$0.00'), findsOneWidget);
        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.0));
      });

      testWidgets('handles both zero usage and limit', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.0,
          limit: 0.0,
          enabled: true,
        ));

        expect(find.text('\$0.0000'), findsOneWidget);
        expect(find.text(' / \$0.00'), findsOneWidget);
      });

      testWidgets('handles very small amounts', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.0001,
          limit: 0.01,
          enabled: true,
        ));

        expect(find.text('\$0.0001'), findsOneWidget);
        expect(find.text(' / \$0.01'), findsOneWidget);
      });

      testWidgets('handles large amounts', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'This Month',
          used: 99.9999,
          limit: 100.00,
          enabled: true,
        ));

        expect(find.text('\$99.9999'), findsOneWidget);
        expect(find.text(' / \$100.00'), findsOneWidget);
      });

      testWidgets('warning at exactly 80.1%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.401,
          limit: 0.50,
          enabled: true,
        ));

        // 0.401 / 0.50 = 0.802 = 80.2% which is > 0.8
        expect(find.textContaining('Approaching limit'), findsOneWidget);
      });

      testWidgets('no warning at exactly 80%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.40,
          limit: 0.50,
          enabled: true,
        ));

        // 0.40 / 0.50 = 0.8 exactly, which is NOT > 0.8
        expect(find.textContaining('Approaching limit'), findsNothing);
      });

      testWidgets('limit reached at exactly 100%', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.50,
          limit: 0.50,
          enabled: true,
        ));

        // 0.50 / 0.50 = 1.0 = 100%, which is >= 1.0
        expect(find.text('Limit reached. Agent paused.'), findsOneWidget);
      });
    });

    group('Card structure', () {
      testWidgets('wrapped in Card widget', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.byType(Card), findsOneWidget);
      });

      testWidgets('Card has correct margin', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.margin, equals(const EdgeInsets.only(bottom: 8)));
      });

      testWidgets('has LinearProgressIndicator', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('progress bar has correct background color', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.backgroundColor, equals(NavixTheme.surfaceVariant));
      });

      testWidgets('progress bar has correct height', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Today',
          used: 0.25,
          limit: 0.50,
          enabled: true,
        ));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.minHeight, equals(8));
      });
    });
  });
}

// Test wrapper widgets that mirror the private widgets in settings_screen.dart
// These are exact copies of the private widgets for testing purposes

class _TestSectionHeader extends StatelessWidget {
  final String title;

  const _TestSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: NavixTheme.textSecondary,
        ),
      ),
    );
  }
}

class _TestSettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _TestSettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// Test mirror of `_SystemPromptEditor` from settings_screen.dart.
///
/// Accepts an optional initial custom prompt.  When `null` the editor starts
/// with [defaultSystemPrompt] (same behaviour as the production widget when
/// `StorageService.getSystemPrompt()` returns `null`).
class _TestSystemPromptEditor extends StatefulWidget {
  final String? initialCustomPrompt;

  const _TestSystemPromptEditor({this.initialCustomPrompt});

  @override
  State<_TestSystemPromptEditor> createState() =>
      _TestSystemPromptEditorState();
}

class _TestSystemPromptEditorState extends State<_TestSystemPromptEditor> {
  late TextEditingController _controller;
  bool _isDirty = false;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialCustomPrompt ?? defaultSystemPrompt,
    );
    _isCustom = widget.initialCustomPrompt != null;
  }

  void _resetToDefault() {
    _controller.text = defaultSystemPrompt;
    setState(() {
      _isDirty = true;
      _isCustom = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavixTheme.background,
      appBar: AppBar(
        backgroundColor: NavixTheme.background,
        title: const Text('System Prompt'),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: _isDirty ? () {} : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCustom ? 'Custom prompt' : 'Default prompt',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NavixTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_controller.text.length} characters',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NavixTheme.textTertiary,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                onChanged: (_) {
                  if (!_isDirty) {
                    setState(() => _isDirty = true);
                  }
                  setState(() {
                    _isCustom =
                        _controller.text.trim() != defaultSystemPrompt;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestUsageCard extends StatelessWidget {
  final String title;
  final double used;
  final double limit;
  final bool enabled;
  final VoidCallback onEditLimit;

  const _TestUsageCard({
    required this.title,
    required this.used,
    required this.limit,
    required this.enabled,
    required this.onEditLimit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final isWarning = progress > 0.8;
    final isOver = progress >= 1.0;

    final progressColor = isOver
        ? NavixTheme.error
        : isWarning
            ? NavixTheme.warning
            : NavixTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                GestureDetector(
                  onTap: onEditLimit,
                  child: Row(
                    children: [
                      Text(
                        '\$${used.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: progressColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        ' / \$${limit.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: NavixTheme.textTertiary,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\u270e',
                        style: TextStyle(
                          fontSize: 12,
                          color: NavixTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: enabled ? progress : 0,
                backgroundColor: NavixTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  enabled ? progressColor : NavixTheme.textTertiary,
                ),
                minHeight: 8,
              ),
            ),
            if (isWarning && enabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    NavixTheme.iconWarning,
                    style: TextStyle(
                      fontSize: 12,
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOver
                        ? 'Limit reached. Agent paused.'
                        : 'Approaching limit (${(progress * 100).toInt()}%)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: progressColor,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
