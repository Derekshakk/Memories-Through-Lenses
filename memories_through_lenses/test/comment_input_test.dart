import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/components/comment_input.dart';

void main() {
  late TextEditingController controller;
  late int submits;
  late int cancels;

  setUp(() {
    controller = TextEditingController();
    submits = 0;
    cancels = 0;
  });

  Widget screen({String? replyTo, String? replyText}) => MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Column(children: [
            Expanded(
              child: ListView(
                children: List.generate(
                    30, (i) => SizedBox(height: 60, child: Text('row $i'))),
              ),
            ),
            CommentInputBar(
              controller: controller,
              onSubmit: () => submits++,
              replyingToName: replyTo,
              replyingToText: replyText,
              onCancelReply: () => cancels++,
            ),
          ]),
        ),
      );

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('comment-submit')));

  testWidgets('Return inserts a line break; only Submit posts',
      (tester) async {
    await tester.pumpWidget(screen());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.maxLines, greaterThan(1));

    await tester.enterText(find.byType(TextField), 'line one\nline two');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(submits, 0);
    expect(controller.text, contains('\n'));

    await tester.tap(find.byKey(const Key('comment-submit')));
    expect(submits, 1);
  });

  testWidgets('Submit is disabled for blank input', (tester) async {
    await tester.pumpWidget(screen());
    expect(submitButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  \n ');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('reply preview and input stay above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        screen(replyTo: 'Jane Doe', replyText: 'Great photo!'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final keyboardTop = 800 - 300;
    final preview = find.byKey(const Key('reply-preview'));
    expect(find.text('Replying to Jane Doe'), findsOneWidget);
    expect(find.text('Great photo!'), findsOneWidget);
    expect(tester.getBottomLeft(preview).dy, lessThanOrEqualTo(keyboardTop));
    expect(tester.getBottomLeft(find.byType(TextField)).dy,
        lessThanOrEqualTo(keyboardTop));
    expect(tester.getTopLeft(preview).dy, greaterThanOrEqualTo(0));

    await tester.tap(find.byTooltip('Cancel reply'));
    expect(cancels, 1);
  });
}
