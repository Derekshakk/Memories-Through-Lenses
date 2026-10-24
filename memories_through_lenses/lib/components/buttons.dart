import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  const MenuButton(
      {super.key, required this.text, this.style, this.onPressed, this.icon});
  final String text;
  final TextStyle? style;
  final Function()? onPressed;

  /// Optional leading icon so each drawer entry is recognisable at a glance.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 18, 135, 232),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      onPressed: onPressed,
      child: icon == null
          ? label
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: style?.color ?? Colors.white, size: 22),
                const SizedBox(width: 10),
                Flexible(child: label),
              ],
            ),
    );
  }
}
