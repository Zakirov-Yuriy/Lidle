import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'required_label.dart';
import 'style_header.dart';

/// Поле-диапазон (style E/E1 для целых, G для дробных).
///
/// Два числовых TextField в одном ряду с разделителем «Из» посередине,
/// общая ошибка под всем блоком. Вид клавиатуры выбирается по
/// `attribute.dataType` / `attribute.style`:
///   * `numeric` / style `G` / style `G1` → клавиатура с десятичной точкой;
///   * всё остальное → просто числовая клавиатура.
///
/// Контроллеры создаются и хранятся снаружи — это важно для
/// корректного сохранения ввода при ребилдах. Виджет ничего не
/// знает про `_selectedValues` / `_controllers` / `setState`,
/// но пробрасывает наверх отдельные коллбэки [onMinChanged]
/// и [onMaxChanged].
///
/// Ошибка валидации общая на пару полей — разные ошибки для min/max
/// не поддерживаются (так было в оригинале).
class RangeField extends StatelessWidget {
  const RangeField({
    super.key,
    required this.attribute,
    required this.controllerMin,
    required this.controllerMax,
    required this.onMinChanged,
    required this.onMaxChanged,
    this.hasError = false,
    this.errorMessage,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final TextEditingController controllerMin;
  final TextEditingController controllerMax;
  final ValueChanged<String> onMinChanged;
  final ValueChanged<String> onMaxChanged;
  final bool hasError;
  final String? errorMessage;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    // Выбор клавиатуры — 1-в-1 как в исходнике.
    final keyboardType =
        (attribute.dataType == 'numeric' ||
                attribute.style == 'G' ||
                attribute.style == 'G1')
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number;

    final hintColor = hasError ? const Color(0xFFff7272) : textSecondary;
    final textColor = hasError ? const Color(0xFFff7272) : textPrimary;
    final fieldBackground =
        hasError ? const Color(0xFF381a1a) : formBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        if (!attribute.isTitleHidden)
          RequiredLabel(
            label: attribute.title,
            isRequired: attribute.isRequired,
          ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _numberBox(
                controller: controllerMin,
                hint: 'От',
                keyboardType: keyboardType,
                hintColor: hintColor,
                textColor: textColor,
                background: fieldBackground,
                onChanged: onMinChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  'Из',
                  style: TextStyle(
                    color: hasError
                        ? const Color(0xFFff7272)
                        : textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _numberBox(
                controller: controllerMax,
                hint: 'До',
                keyboardType: keyboardType,
                hintColor: hintColor,
                textColor: textColor,
                background: fieldBackground,
                onChanged: onMaxChanged,
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              errorMessage ?? 'Заполните минимальное и максимальное значение',
              style: const TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// Одна из двух плашек «От» / «До» — вынесено в отдельный метод,
  /// чтобы не дублировать идентичную разметку два раза.
  Widget _numberBox({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required Color hintColor,
    required Color textColor,
    required Color background,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          border: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
