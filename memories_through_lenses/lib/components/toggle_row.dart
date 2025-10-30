import 'package:flutter/material.dart';

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    this.onToggled,
    this.value = false,
  });

  final String title;
  final ValueChanged<bool>? onToggled;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Switch(
          value: value,
          onChanged: onToggled,
        )
      ],
    );
  }
}
