import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Текстовая метка с опциональной красной звёздочкой.
/// По умолчанию размер — 16pt (размер меток над полями формы).
/// Для меток внутри чекбоксов см. [CheckboxLabel] (там 14pt).
class RequiredLabel extends StatelessWidget {
  const RequiredLabel({
    super.key,
    required this.label,
    required this.isRequired,
    this.fontSize = 16,
  });

  final String label;
  final bool isRequired;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: textPrimary, fontSize: fontSize),
        ),
        if (isRequired)
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
}
