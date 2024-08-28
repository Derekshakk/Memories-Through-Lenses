import 'package:flutter/material.dart';

class ToggleRow extends StatefulWidget {
  const ToggleRow(
      {super.key,
      required this.title,
      this.onToggled,
      this.initialValue = false});

  final String title;
  final ValueChanged<bool>? onToggled;
  final bool initialValue;

  @override
  State<ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<ToggleRow> {
  bool isSwitched = false;

  @override
  Widget build(BuildContext context) {
    isSwitched = widget.initialValue;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.title),
        Switch(
          value: isSwitched,
          onChanged: (value) {
            setState(() {
              isSwitched = value;
            });
            if (widget.onToggled != null) {
              widget.onToggled!(value);
            }
          },
        )
      ],
    );
  }
}
