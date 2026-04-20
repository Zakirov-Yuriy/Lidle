import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'style_header.dart';

/// «Скрытый» чекбокс (style I).
///
/// Используется для атрибутов с `is_title_hidden = true`: текст берётся
/// из `attribute.values[0].value` (если есть), иначе — из `attribute.title`
/// при условии, что заголовок не скрыт. Если лейбла собрать не удалось,
/// виджет вообще ничего не рисует (возвращает `SizedBox.shrink`) —
/// это то же поведение, что в исходнике.
///
/// В отличие от [CheckboxField] здесь нет отдельного [CheckboxLabel]
/// с красной звёздочкой — лейбл всегда идёт обычным Text (такова была
/// логика в оригинале).
class HiddenCheckboxField extends StatelessWidget {
  const HiddenCheckboxField({
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
    // Порядок выбора лейбла 1-в-1 как в исходнике:
    //   values[0].value → attribute.title (если не скрыт) → пусто
    String checkboxLabel = '';
    if (attribute.values.isNotEmpty) {
      checkboxLabel = attribute.values[0].value;
    } else if (attribute.title.isNotEmpty && !attribute.isTitleHidden) {
      checkboxLabel = attribute.title;
    }

    if (checkboxLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  checkboxLabel,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
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
