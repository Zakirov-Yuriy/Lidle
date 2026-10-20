import 'package:flutter/material.dart';
import 'package:lidle/models/filter_models.dart';
import 'labeled_text_field.dart';
import 'style_header.dart';

/// Универсальное текстовое поле — fallback для атрибутов, у которых не
/// задан специальный стиль. Тип клавиатуры и подсказка выбираются
/// по `attribute.dataType`:
///
///   * `integer` → цифровая клавиатура, подсказка «Цифрами»
///   * `numeric` → клавиатура с десятичной точкой, подсказка «Число»
///   * остальное → обычная клавиатура, подсказка «Текст»
///
/// Если у атрибута включён `isTitleHidden`, метка не показывается
/// (пустая строка передаётся в [LabeledTextField]).
///
/// В отличие от [NumericInputField] здесь ошибки не показываются по
/// умолчанию — в исходнике `_buildTextInputField` не пробрасывал
/// `fieldKey`. Параметры [errorMessage] и [hasError] оставлены на
/// будущее: передать при переходе на BLoC, если решим включить
/// показ ошибок и в универсальном поле.
class DynamicTextInputField extends StatelessWidget {
  const DynamicTextInputField({
    super.key,
    required this.attribute,
    required this.controller,
    required this.onChanged,
    this.errorMessage,
    this.hasError = false,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorMessage;
  final bool hasError;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    final TextInputType keyboardType;
    final String hint;

    // Ссылка на видео (стиль V, задача 10). Своя подсказка: человек должен
    // понимать, что сюда вставляют адрес ролика и что стереть его можно
    // здесь же, очистив поле (20.10.2026).
    if (attribute.style == 'V' || attribute.styleSingle == 'V1') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
          LabeledTextField(
            label: attribute.isTitleHidden
                ? ''
                : attribute.title + (attribute.isRequired ? '*' : ''),
            hint: 'Вставьте ссылку на ролик',
            controller: controller,
            keyboardType: TextInputType.url,
            errorMessage: errorMessage,
            hasError: hasError,
            onChanged: onChanged,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Ютуб, Рутуб, ВК и Одноклассники играют прямо в карточке, '
              'остальные откроются на своей площадке. Чтобы убрать видео, '
              'очистите поле и сохраните.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      );
    }

    switch (attribute.dataType) {
      case 'integer':
        keyboardType = TextInputType.number;
        hint = 'Цифрами';
        break;
      case 'numeric':
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
        hint = 'Число';
        break;
      default:
        keyboardType = TextInputType.text;
        hint = 'Текст';
    }

    final label = attribute.isTitleHidden
        ? ''
        : attribute.title + (attribute.isRequired ? '*' : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        LabeledTextField(
          label: label,
          hint: hint,
          controller: controller,
          keyboardType: keyboardType,
          errorMessage: errorMessage,
          hasError: hasError,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
