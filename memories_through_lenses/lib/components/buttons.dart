import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.text, this.style, this.onPressed});
  final String text;
  final TextStyle? style;
  final Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 18, 135, 232),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      onPressed: onPressed,
      child: Text(text, style: style),
    );
  }
}
