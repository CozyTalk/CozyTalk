import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/report/domain/entities/report_type.dart';
import 'package:mobile/features/report/presentation/providers/report_provider.dart';
import 'package:mobile/features/report/presentation/screens/report_sheet.dart';

class _FakeReportNotifier extends ReportNotifier {
  int submitCount = 0;
  int resetCount = 0;
  final ReportState _initial;

  _FakeReportNotifier([this._initial = const ReportState()]);

  @override
  ReportState build() => _initial;

  @override
  void reset() {
    resetCount++;
    // Keep _initial state in fake — tests verify the specific state set via build()
  }

  @override
  Future<void> submit({
    required String sessionId,
    required String reportedUserId,
  }) async {
    submitCount++;
  }
}

// Shows the sheet via showModalBottomSheet so DraggableScrollableSheet gets
// the correct viewport constraints — matching how the sheet is used in prod.
Future<_FakeReportNotifier> _openSheet(
  WidgetTester tester, [
  _FakeReportNotifier? notifier,
]) async {
  final fake = notifier ?? _FakeReportNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reportNotifierProvider.overrideWith(() => fake)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const ReportSheet(
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
  await tester.pump(const Duration(milliseconds: 500));
  return fake;
}

// Brings a widget into view without waiting for settle (safe with ongoing animations).
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
}

void main() {
  group('ReportSheet', () {
    testWidgets('renders all report type chips', (tester) async {
      await _openSheet(tester);
      for (final type in ReportType.values) {
        expect(find.text(type.displayName), findsOneWidget);
      }
    });

    testWidgets('renders reason and context text fields', (tester) async {
      await _openSheet(tester);
      expect(find.text('Reason *'), findsOneWidget);
      expect(find.text('Additional context (optional)'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('submit button is disabled when no type selected', (
      tester,
    ) async {
      await _openSheet(tester);
      final submitFinder = find.byType(FilledButton);
      await _scrollTo(tester, submitFinder);
      final button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('submit button is disabled when reason is empty', (
      tester,
    ) async {
      final notifier = _FakeReportNotifier(
        const ReportState(selectedType: ReportType.spam, reason: ''),
      );
      await _openSheet(tester, notifier);
      final submitFinder = find.byType(FilledButton);
      await _scrollTo(tester, submitFinder);
      final button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('submit button is enabled when type and reason are set', (
      tester,
    ) async {
      final notifier = _FakeReportNotifier(
        const ReportState(
          selectedType: ReportType.spam,
          reason: 'Sending spam',
        ),
      );
      await _openSheet(tester, notifier);
      final submitFinder = find.byType(FilledButton);
      await _scrollTo(tester, submitFinder);
      final button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping submit calls notifier.submit', (tester) async {
      final notifier = _FakeReportNotifier(
        const ReportState(
          selectedType: ReportType.harassment,
          reason: 'Being rude',
        ),
      );
      await _openSheet(tester, notifier);
      final submitFinder = find.byType(FilledButton);
      await _scrollTo(tester, submitFinder);
      await tester.tap(submitFinder);
      await tester.pump();
      expect(notifier.submitCount, 1);
    });

    testWidgets('shows loading indicator while submitting', (tester) async {
      final notifier = _FakeReportNotifier(
        const ReportState(
          selectedType: ReportType.other,
          reason: 'Other issue',
          isSubmitting: true,
        ),
      );
      await _openSheet(tester, notifier);
      final submitFinder = find.byType(FilledButton);
      await _scrollTo(tester, submitFinder);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows error message when error is set', (tester) async {
      final notifier = _FakeReportNotifier(
        const ReportState(error: 'Something went wrong'),
      );
      await _openSheet(tester, notifier);
      final errorFinder = find.text('Something went wrong');
      await _scrollTo(tester, errorFinder);
      expect(errorFinder, findsOneWidget);
    });

    testWidgets('add screenshot button is visible when fewer than 5 images', (
      tester,
    ) async {
      await _openSheet(tester);
      final addFinder = find.text('Add');
      await _scrollTo(tester, addFinder);
      expect(addFinder, findsOneWidget);
    });

    testWidgets('add screenshot button is hidden when 5 images attached', (
      tester,
    ) async {
      final notifier = _FakeReportNotifier(
        const ReportState(contextImagePaths: ['a', 'b', 'c', 'd', 'e']),
      );
      await _openSheet(tester, notifier);
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('close button has accessible label', (tester) async {
      await _openSheet(tester);
      expect(find.bySemanticsLabel('Close report sheet'), findsOneWidget);
    });
  });
}
