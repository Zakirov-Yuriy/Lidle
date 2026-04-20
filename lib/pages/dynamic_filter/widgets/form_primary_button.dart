import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Широкая кнопка формы (full-width), используется для действий
/// на экранах подачи/редактирования объявления.
///
/// [isPrimary] = true — синяя заливка `activeIconColor`, белый текст,
/// без обводки. Используется для главного действия (обычно «Продолжить»
/// или «Опубликовать»).
///
/// [isPrimary] = false — фон `primaryBackground`, белая обводка,
/// белый текст. Для вторичных действий.
///
/// Высота фиксированная — 51px.
class FormPrimaryButton extends StatelessWidget {
  const FormPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? activeIconColor : primaryBackground,
          side: isPrimary ? null : const BorderSide(color: Colors.white),
          minimumSize: const Size.fromHeight(51),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(color: isPrimary ? Colors.white : textPrimary),
        ),
      ),
    );
  }
}
