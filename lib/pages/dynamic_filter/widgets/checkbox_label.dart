import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Текст рядом с чекбоксом. Если [showAsterisk] — добавляется
/// красная `*` после текста. В отличие от [RequiredLabel] по умолчанию
/// шрифт 14pt и чуть другая структура (без обязательного Row при
/// отсутствии звёздочки — возвращается просто Text).
class CheckboxLabel extends StatelessWidget {
  const CheckboxLabel({
    super.key,
    required this.text,
    required this.showAsterisk,
    this.fontSize = 14,
  });

  final String text;
  final bool showAsterisk;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (showAsterisk) {
      return Row(
        children: [
          Text(
            text,
            style: TextStyle(color: textPrimary, fontSize: fontSize),
          ),
          Text(
            '*',
            style: TextStyle(
              color: const Color(0xFFFF1744),
              fontSize: fontSize,
            ),
          ),
        ],
      );
    }
    return Text(
      text,
      style: TextStyle(color: textPrimary, fontSize: fontSize),
    );
  }
}
