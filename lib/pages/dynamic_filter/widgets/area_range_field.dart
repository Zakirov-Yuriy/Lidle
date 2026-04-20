import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Простое числовое поле без метки и статуса ошибки.
///
/// В исходнике `_buildAreaRangeField` помечен `unused_element`, но
/// сохраняем его ради идентичности рефакторинга. Если в будущем
/// выяснится, что поле действительно нигде не используется, можно
/// удалить и виджет, и соответствующий адаптер в `DynamicFilter`.
///
/// Отличается от [LabeledTextField] тем, что не имеет метки и блока
/// сообщения об ошибке — просто контейнер с числовым TextField внутри.
class AreaRangeField extends StatelessWidget {
  const AreaRangeField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: textPrimary),
        decoration: const InputDecoration(
          hintText: 'Введите',
          hintStyle: TextStyle(color: textSecondary, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
