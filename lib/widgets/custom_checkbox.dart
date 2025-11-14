/// Виджет кастомного чекбокса.
/// Предоставляет стилизованный чекбокс с анимацией состояния.
import 'package:flutter/material.dart';

/// `CustomCheckbox` - это StatelessWidget, который отображает
/// настраиваемый чекбокс.
class CustomCheckbox extends StatelessWidget {
  /// Текущее состояние чекбокса (отмечен или нет).
  final bool value;
  /// Callback-функция, вызываемая при изменении состояния чекбокса.
  final ValueChanged<bool>? onChanged;

  /// Конструктор для `CustomCheckbox`.
  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54, width: 2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? const Color(0xFF0EA5E9) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
