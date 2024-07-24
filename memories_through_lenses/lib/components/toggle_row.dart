import 'package:flutter/material.dart';

class ToggleRow extends StatefulWidget {
  const ToggleRow({super.key, required this.title});

  final String title;

  @override
  State<ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<ToggleRow> {
  bool isSwitched = false;

  @override
  Widget build(BuildContext context) {
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
          },
        )
      ],
    );
  }
}
