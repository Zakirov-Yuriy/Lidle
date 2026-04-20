import 'package:flutter/material.dart';
import 'package:lidle/models/filter_models.dart';
import 'choice_button.dart';

/// Адаптивная сетка кнопок выбора ([ChoiceButton]). Расположение
/// зависит от количества вариантов:
///
/// * **0** вариантов → ничего не рисуется (`SizedBox.shrink`).
/// * **2** варианта → Row из двух кнопок по 50% ширины.
/// * **3** варианта → Row из трёх кнопок по 33% ширины.
/// * **4** варианта → сетка 2×2 (две строки по две кнопки).
/// * **5+** вариантов → [Wrap] с переносом, каждая кнопка обёрнута
///   во [Flexible] + [FittedBox] с `BoxFit.scaleDown`.
///
/// Отступ между кнопками — 10px по горизонтали и вертикали.
///
/// Виджет ничего не знает про state: принимает список [buttons],
/// текущее выбранное значение [selectedValue] и коллбэк
/// [onButtonPressed]. Возвращает в коллбэк `Value.value` нажатой
/// кнопки.
class ChoiceButtonGrid extends StatelessWidget {
  const ChoiceButtonGrid({
    super.key,
    required this.buttons,
    required this.selectedValue,
    required this.onButtonPressed,
  });

  final List<Value> buttons;
  final String selectedValue;
  final ValueChanged<String> onButtonPressed;

  static const double _spacing = 10.0;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    // 2 кнопки: ряд из двух равных (50/50).
    if (buttons.length == 2) {
      return Row(
        children: [
          Expanded(child: _button(buttons[0])),
          const SizedBox(width: _spacing),
          Expanded(child: _button(buttons[1])),
        ],
      );
    }

    // 3 кнопки: ряд из трёх равных (33/33/33).
    if (buttons.length == 3) {
      return Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            Expanded(child: _button(buttons[i])),
            if (i < buttons.length - 1) const SizedBox(width: _spacing),
          ],
        ],
      );
    }

    // Ровно 4 кнопки: сетка 2×2.
    if (buttons.length == 4) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _button(buttons[0])),
              const SizedBox(width: _spacing),
              Expanded(child: _button(buttons[1])),
            ],
          ),
          const SizedBox(height: _spacing),
          Row(
            children: [
              Expanded(child: _button(buttons[2])),
              const SizedBox(width: _spacing),
              Expanded(child: _button(buttons[3])),
            ],
          ),
        ],
      );
    }

    // 5+ кнопок: Wrap с гибкими размерами и переносом.
    return Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: [
        for (int i = 0; i < buttons.length; i++)
          Flexible(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _button(buttons[i]),
            ),
          ),
      ],
    );
  }

  Widget _button(Value btn) {
    return ChoiceButton(
      text: btn.value,
      isSelected: selectedValue == btn.value,
      onPressed: () => onButtonPressed(btn.value),
    );
  }
}
