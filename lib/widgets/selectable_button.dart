import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class SelectableButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;
  final double? width;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const SelectableButton({
    super.key,
    required this.text,
    required this.isActive,
    required this.onTap,
    this.width,
    this.maxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    this.borderRadius = 5.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: isActive ? activeIconColor : primaryBackground,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isActive ? activeIconColor : Colors.white,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );

    if (maxWidth != null) {
      button = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: button,
      );
    }

    return button;
  }
}
