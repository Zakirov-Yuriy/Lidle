import 'package:flutter/material.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'required_label.dart';
import 'style_header.dart';

/// Булевый переключатель (style B1) для режима подачи объявления.
///
/// Внешне очень похож на [CheckboxField] (style B), но с двумя
/// важными отличиями:
///   * метка всегда берётся из `attribute.title` и рисуется через
///     [RequiredLabel] (fontSize 16pt, с красной `*` для обязательных);
///   * игнорируется `attribute.values[0].value` — в B1 список значений
///     не используется как источник текста.
///
/// Клик по всей строке (GestureDetector) и клик по самому чекбоксу
/// работают идентично — оба инвертируют значение через [onChanged].
///
/// Примеры: «Возможен торг», «Без комиссии», «Возможность обмена»
/// в режиме подачи.
class BooleanField extends StatelessWidget {
  const BooleanField({
    super.key,
    required this.attribute,
    required this.value,
    required this.onChanged,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              Expanded(
                child: RequiredLabel(
                  label: attribute.title,
                  isRequired: attribute.isRequired,
                ),
              ),
              const SizedBox(width: 12),
              CustomCheckbox(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
