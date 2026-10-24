import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/components/report_dialog.dart';

void main() {
  late List<(String, String)> submitted;
  late int blocks;
  late Future<ReportOutcome?>? result;

  setUp(() {
    submitted = [];
    blocks = 0;
    result = null;
  });

  Future<void> open(
    WidgetTester tester, {
    Future<void> Function(String, String)? onSubmit,
    bool withBlock = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              result = showDialog<ReportOutcome>(
                context: context,
                builder: (_) => ReportDialog(
                  title: 'Report Post',
                  subject: 'post',
                  timeout: timeout,
                  onSubmit: onSubmit ??
                      (reason, details) async =>
                          submitted.add((reason, details)),
                  onBlock: withBlock ? () async => blocks++ : null,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers every reason and requires one', (tester) async {
    await open(tester);
    for (final reason in kReportReasons) {
      expect(find.text(reason), findsOneWidget);
    }
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Please choose a reason.'), findsOneWidget);
    expect(submitted, isEmpty);
  });

  testWidgets('submits the chosen reason and details, then closes',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Harassment or bullying'));
    await tester.enterText(find.byType(TextField), 'mean comments');
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(submitted, [('Harassment or bullying', 'mean comments')]);
    expect(find.byType(ReportDialog), findsNothing);
    expect(await result, ReportOutcome.reported);
  });

  testWidgets('a failed submission keeps the dialog open with an error',
      (tester) async {
    await open(tester, onSubmit: (_, __) async => throw StateError('denied'));
    await tester.tap(find.text('Spam or misleading'));
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportDialog), findsOneWidget);
    expect(find.textContaining('Could not submit'), findsOneWidget);
    // Retry is possible.
    final report = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Report'));
    expect(report.onPressed, isNotNull);
  });

  testWidgets('a stalled submission times out instead of spinning forever',
      (tester) async {
    await open(tester,
        onSubmit: (_, __) => Completer<void>().future,
        timeout: const Duration(seconds: 2));
    await tester.tap(find.text('Other'));
    await tester.tap(find.text('Report'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('taking too long'), findsOneWidget);
  });

  testWidgets('blocking only blocks — it never files a report',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not report'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(blocks, 1);
    expect(submitted, isEmpty);
    expect(await result, ReportOutcome.blocked);
  });

  testWidgets('comment reports use the same reasons without a block action',
      (tester) async {
    await open(tester, withBlock: false);
    expect(find.text('Block user'), findsNothing);
    expect(find.text(kReportReasons.first), findsOneWidget);
  });
}
