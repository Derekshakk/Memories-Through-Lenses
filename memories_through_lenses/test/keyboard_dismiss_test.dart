// Regression tests for the app-wide "tap outside to dismiss the keyboard"
// behavior.
//
// Use the production MaterialApp.builder without initializing Firebase.
// These tests lock in the required behavior:
//   * a user can type into a field,
//   * tapping a blank area drops focus (dismissing the keyboard),
//   * the entered text is NOT lost when focus is removed,
//   * tapping another field transfers focus,
//   * a button still fires on the FIRST tap while a field is focused.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/components/app_keyboard_behavior.dart';

const _mobilePlatforms = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

Widget _appWithDismissWrapper({required Widget home}) {
  return MaterialApp(
    builder: AppKeyboardBehavior.builder,
    home: home,
  );
}

void main() {
  testWidgets('typing works, tapping blank dismisses focus, text is preserved',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    final fieldFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(fieldFocus.dispose);

    await tester.pumpWidget(
      _appWithDismissWrapper(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller, focusNode: fieldFocus),
              const SizedBox(height: 40),
              const Text('blank area', key: Key('blank')),
            ],
          ),
        ),
      ),
    );

    // Focus + type.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();
    expect(controller.text, 'hello world');

    // Tap a blank, non-interactive area -> focus dropped (keyboard dismissed).
    await tester.tapAt(tester.getCenter(find.byKey(const Key('blank'))));
    await tester.pump();
    expect(fieldFocus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    // Text must survive losing focus.
    expect(controller.text, 'hello world');
  }, variant: _mobilePlatforms);

  testWidgets('button fires on the first tap while a field is focused',
      (WidgetTester tester) async {
    int taps = 0;
    final fieldFocus = FocusNode();
    addTearDown(fieldFocus.dispose);

    await tester.pumpWidget(
      _appWithDismissWrapper(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: fieldFocus),
              ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Press'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);

    // A single tap must activate the button (no "first tap only dismisses").
    await tester.tap(find.widgetWithText(ElevatedButton, 'Press'));
    await tester.pump();
    expect(taps, 1);
    expect(fieldFocus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  }, variant: _mobilePlatforms);

  testWidgets('tapping another field transfers focus normally',
      (WidgetTester tester) async {
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(
      _appWithDismissWrapper(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: a),
              TextField(focusNode: b),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(a.hasFocus, isTrue);
    expect(b.hasFocus, isFalse);

    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(a.hasFocus, isFalse);
    expect(b.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: _mobilePlatforms);

  testWidgets('form input retains text and validation when focus is dismissed',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(_appWithDismissWrapper(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: Column(children: [
            TextFormField(
              obscureText: true,
              validator: (value) => value == 'secret' ? null : 'Invalid',
            ),
            const SizedBox(height: 80, width: 200, key: Key('blank')),
          ]),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tapAt(tester.getCenter(find.byKey(const Key('blank'))));
    await tester.pump();
    final input = tester.widget<EditableText>(find.byType(EditableText));
    expect(input.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(input.controller.text, 'secret');
    expect(formKey.currentState!.validate(), isTrue);
  }, variant: _mobilePlatforms);

  testWidgets('tapping inside a field or its suffix keeps editing active',
      (tester) async {
    var suffixTaps = 0;
    await tester.pumpWidget(_appWithDismissWrapper(
      home: Scaffold(
        body: TextField(
          decoration: InputDecoration(
            suffixIcon: IconButton(
              onPressed: () => suffixTaps++,
              icon: const Icon(Icons.visibility),
            ),
          ),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'keep editing');
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(suffixTaps, 1);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'keep editing');
  }, variant: _mobilePlatforms);

  for (final useListView in [false, true]) {
    testWidgets(
        '${useListView ? 'ListView' : 'SingleChildScrollView'} drag dismisses and scrolls inside a text-field tap region',
        (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final children = [
        const TextField(),
        const SizedBox(height: 1500),
      ];
      await tester.pumpWidget(_appWithDismissWrapper(
        home: Scaffold(
          body: TextFieldTapRegion(
            child: useListView
                ? ListView(controller: scrollController, children: children)
                : SingleChildScrollView(
                    controller: scrollController,
                    child: Column(children: children),
                  ),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'scroll draft');
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(find.byType(EditableText));
      // The surrounding tap region bypasses outside-tap dismissal. This
      // specifically exercises drag dismissal without dragging the text caret.
      await tester.tapAt(const Offset(300, 300));
      await tester.pump();
      expect(input.focusNode.hasFocus, isTrue);
      await tester.dragFrom(const Offset(300, 300), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(scrollController.offset, greaterThan(0));
      expect(input.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(input.controller.text, 'scroll draft');
    }, variant: _mobilePlatforms);
  }

  testWidgets('dropdown opens on first tap and selection still works',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_appWithDismissWrapper(
      home: Scaffold(
        body: Column(children: [
          const TextField(),
          DropdownButton<String>(
            hint: const Text('Choose group'),
            items: const [
              DropdownMenuItem(value: 'group', child: Text('Photography')),
            ],
            onChanged: (value) => selected = value,
          ),
        ]),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.text('Photography').last);
    await tester.pumpAndSettle();
    expect(selected, 'group');
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'draft');
  }, variant: _mobilePlatforms);

  testWidgets('pushed routes and dialog fields inherit dismissal',
      (tester) async {
    await tester.pumpWidget(_appWithDismissWrapper(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Column(children: [
            const TextField(),
            ElevatedButton(
              child: const Text('Next'),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Next screen')),
                  body: Column(children: [
                    const TextField(),
                    const SizedBox(height: 80, key: Key('route blank')),
                    ElevatedButton(
                      child: const Text('Open dialog'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Dialog blank'),
                          content: TextFormField(),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              )),
            ),
          ]);
        }),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'first route');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Next screen'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'second route');
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byKey(const Key('route blank'))));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'dialog draft');
    await tester.pump();
    await tester.tap(find.text('Dialog blank'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        'dialog draft');
    await tester.tap(find.byType(TextFormField));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: _mobilePlatforms);
}
