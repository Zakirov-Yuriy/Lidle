import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'checkbox_label.dart';
import 'style_header.dart';

/// Чекбокс-поле (style B).
///
/// Используется для простых флагов вроде «Возможен торг», «Без комиссии».
/// Лейбл берётся из [Attribute.values] (первый элемент), если он есть;
/// иначе — из `attribute.title` через [CheckboxLabel].
///
/// Тап по всей строке и тап по самому чекбоксу одинаково переключают
/// значение. Значение передаётся наверх через [onChanged].
///
/// Примечание: в исходнике тут были неиспользуемые вычисления
/// `isBargainCheckbox` и `offerPriceAttrId` — остатки от ранее
/// существовавшей связки чекбокса «Возможен торг» с атрибутом
/// «Вам предложат цену». Сейчас эти поля независимы (судя по
/// комментариям в коде), поэтому удалено — поведение не изменилось.
class CheckboxField extends StatelessWidget {
  const CheckboxField({
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
          // Тап по строке — переключить значение.
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              Expanded(
                child: attribute.values.isNotEmpty
                    ? Text(
                        attribute.values[0].value,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                        ),
                      )
                    : CheckboxLabel(
                        text: attribute.title,
                        showAsterisk: attribute.isRequired,
                        fontSize: 14,
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
