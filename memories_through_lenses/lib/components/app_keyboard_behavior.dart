import 'package:flutter/material.dart';

/// Shared focus behavior for every route and overlay in the app.
class AppKeyboardBehavior extends StatelessWidget {
  const AppKeyboardBehavior({super.key, required this.child});

  final Widget child;

  /// Install above the Navigator using MaterialApp.builder.
  static Widget builder(BuildContext context, Widget? child) {
    return AppKeyboardBehavior(child: child ?? const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        // Flutter's text-field tap regions detect outside touches without
        // consuming the gesture. Buttons still activate on the same tap, and
        // field decorations (e.g. password visibility) remain inside the field.
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) {
            intent.focusNode.unfocus();
            return null;
          },
        ),
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        ),
        child: child,
      ),
    );
  }
}
