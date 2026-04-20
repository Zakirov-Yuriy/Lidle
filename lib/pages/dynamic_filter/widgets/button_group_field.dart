import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'choice_button_grid.dart';
import 'style_header.dart';

/// Поле-группа кнопок (style C/C1, `is_special_design = true`).
///
/// Рендерит:
///   * [StyleHeader] сверху (зарезервированное место под код стиля);
///   * метку с именем атрибута (если `isTitleHidden = false`) и
///     красной `*` для обязательных полей;
///   * адаптивную сетку [ChoiceButtonGrid] — 2/3/4/5+ кнопок;
///   * текст ошибки под сеткой при наличии [hasError].
///
/// В исходнике `_buildSpecialDesignField` в теме звёздочки был
/// мёртвый тернарник с двумя одинаковыми цветами:
/// `hasError ? 0xFFFF1744 : 0xFFFF1744` — очевидно, автор хотел
/// разные цвета, но передумал. Оставляем один цвет `#FF1744`.
///
/// Примеры использования: «Да/Нет», «Совместная/Продажа/Аренда».
class ButtonGroupField extends StatelessWidget {
  const ButtonGroupField({
    super.key,
    required this.attribute,
    required this.selectedValue,
    required this.onChanged,
    this.hasError = false,
    this.errorMessage,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final String? errorMessage;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        if (!attribute.isTitleHidden)
          Row(
            children: [
              Text(
                attribute.title,
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
              if (attribute.isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Color(0xFFFF1744),
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (attribute.values.isNotEmpty)
          ChoiceButtonGrid(
            buttons: attribute.values,
            selectedValue: selectedValue,
            onButtonPressed: onChanged,
          ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              errorMessage ?? 'Обязательное поле',
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
}
