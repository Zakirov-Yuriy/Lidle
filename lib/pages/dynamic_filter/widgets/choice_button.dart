import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Кнопка-«выбор» из группы (визуально как радиокнопка).
///
/// Активная — заливка `activeIconColor`, белый текст, без обводки.
/// Неактивная — прозрачный фон, белая обводка, белый текст.
/// Используется в группах выбора (1/2/3/4 варианта) внутри фильтров.
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onPressed,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? activeIconColor : Colors.transparent,
        side: isSelected ? null : const BorderSide(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : textPrimary,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
