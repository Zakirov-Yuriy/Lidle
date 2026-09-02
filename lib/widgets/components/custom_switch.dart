// ============================================================
// "Пользовательский переключатель"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Цвет дорожки. По умолчанию тёмный, как было: на общем фоне экрана он
  /// читается. Параметр нужен там, где свич лежит на карточке того же цвета,
  /// иначе дорожка сливается с ней и остаётся один кружок.
  final Color? trackColor;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 37,
        height: 20,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor ?? const Color(0xFF17212B),
          borderRadius: BorderRadius.circular(30),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: value ? activeIconColor : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
