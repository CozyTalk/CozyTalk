import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/dialogs/report_dialog.dart';
import 'package:mobile/features/report/presentation/providers/report_provider.dart';

class _FakeReportNotifier extends ReportNotifier {
  int submitCount = 0;
  int resetCount = 0;
  final ReportState _initial;

  _FakeReportNotifier([this._initial = const ReportState()]);

  @override
  ReportState build() => _initial;

  @override
  void reset() => resetCount++;

  @override
  Future<void> submit({
    required String sessionId,
    required String reportedUserId,
  }) async {
    submitCount++;
  }
}

Future<_FakeReportNotifier> _openDialog(
  WidgetTester tester, [
  _FakeReportNotifier? notifier,
]) async {
  final fake = notifier ?? _FakeReportNotifier();
  // Use a tall viewport so dialog buttons are always in-bounds.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [reportNotifierProvider.overrideWith(() => fake)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => const ReportDialog(
                  sessionId: 'ses1',
                  reportedUserId: 'user2',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return fake;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<_FakeReportNotifier> _advanceToStep2(WidgetTester tester) async {
  final fake = await _openDialog(tester);
  await _tap(tester, find.text('Harassment or Bullying'));
  await _tap(tester, find.widgetWithText(ElevatedButton, 'Next'));
  await tester.pump(const Duration(milliseconds: 300));
  return fake;
}

void main() {
  group('ReportDialog — step 1', () {
    testWidgets('renders Report title and progress labels', (tester) async {
      await _openDialog(tester);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('renders all four checkbox options', (tester) async {
      await _openDialog(tester);
      expect(find.text('Harassment or Bullying'), findsOneWidget);
      expect(find.text('Spam & Scams'), findsOneWidget);
      expect(
        find.text('Exposing private identifying\ninformation'),
        findsOneWidget,
      );
      expect(find.text('Others'), findsOneWidget);
    });

    testWidgets('Next button is disabled when no option selected', (
      tester,
    ) async {
      await _openDialog(tester);
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Next button is enabled after selecting an option', (
      tester,
    ) async {
      await _openDialog(tester);
      await _tap(tester, find.text('Spam & Scams'));
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      await _openDialog(tester);
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsNothing);
    });
  });

  group('ReportDialog — step 2', () {
    testWidgets('shows step 2 content after tapping Next', (tester) async {
      await _advanceToStep2(tester);
      expect(find.text('Additional Context'), findsOneWidget);
      expect(find.text('Attach images'), findsOneWidget);
    });

    testWidgets('shows selection summary card with chosen reason', (
      tester,
    ) async {
      await _advanceToStep2(tester);
      expect(find.text('Selected reason'), findsOneWidget);
      // Chip label and checkbox option both render "Harassment or Bullying"
      // (one in the summary card, not visible in step 2 checkbox area)
      expect(find.text('Harassment or Bullying'), findsOneWidget);
    });

    testWidgets('step 1 progress dot shows checkmark on step 2', (
      tester,
    ) async {
      await _advanceToStep2(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Back button returns to step 1', (tester) async {
      await _advanceToStep2(tester);
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Back'));
      // Step 1 options are visible again
      expect(find.text('Spam & Scams'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);
    });

    testWidgets('Submit calls notifier.submit once', (tester) async {
      final fake = await _advanceToStep2(tester);
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Submit'));
      expect(fake.submitCount, 1);
    });

    testWidgets('shows error message when error is set', (tester) async {
      final fake = _FakeReportNotifier(
        const ReportState(error: 'Network error'),
      );
      await _openDialog(tester, fake);
      await _tap(tester, find.text('Spam & Scams'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Next'));
      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('shows loading indicator while submitting', (tester) async {
      final fake = _FakeReportNotifier(const ReportState(isSubmitting: true));
      await _openDialog(tester, fake);
      await _tap(tester, find.text('Spam & Scams'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Next'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Submit button is disabled while submitting', (tester) async {
      final fake = _FakeReportNotifier(const ReportState(isSubmitting: true));
      await _openDialog(tester, fake);
      await _tap(tester, find.text('Spam & Scams'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Next'));
      // When isLoading=true the button shows a spinner instead of 'Submit' text.
      // Find the ElevatedButton that contains the CircularProgressIndicator.
      final loadingBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(loadingBtn.onPressed, isNull);
    });
  });

  group('ReportDialog — step 3 (success)', () {
    testWidgets('shows thank you screen when isSuccess is true', (
      tester,
    ) async {
      final fake = _FakeReportNotifier(const ReportState(isSuccess: true));
      await _openDialog(tester, fake);
      await _tap(tester, find.text('Spam & Scams'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Next'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Thank you For Your Report'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Done button closes dialog', (tester) async {
      final fake = _FakeReportNotifier(const ReportState(isSuccess: true));
      await _openDialog(tester, fake);
      await _tap(tester, find.text('Spam & Scams'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Next'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pump(const Duration(milliseconds: 300));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.text('Thank you For Your Report'), findsNothing);
    });
  });
}
