// Regression tests for the Create Post screen upload UI state.
//
// These focus on the states that previously left users stuck: the Share Post
// button must be disabled until a photo and group are chosen, so an upload
// cannot start (and therefore cannot hang) without valid input.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:memories_through_lenses/screens/create_post.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<UserProvider>(
    create: (_) => UserProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Create Post renders with an idle Share Post button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const CreatePostScreen()));
    await tester.pump();

    // The screen renders its idle state, not a stuck "Uploading..." spinner.
    expect(find.text('Share Post'), findsOneWidget);
    expect(find.text('Uploading...'), findsNothing);
    expect(find.text('No Image Selected'), findsOneWidget);
  });

  testWidgets('Share Post button is disabled with no image or group selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const CreatePostScreen()));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Share Post'),
    );

    // A null onPressed means the button is disabled, so no upload can begin
    // until the user provides valid input.
    expect(button.onPressed, isNull);
  });
}
