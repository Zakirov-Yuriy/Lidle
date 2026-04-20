import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'required_label.dart';
import 'style_header.dart';

/// Поле ввода цены (style A1).
///
/// Числовой TextField слева + отдельная квадратная плашка с символом `₽`
/// справа. Используется для полей типа «Цена», «Средний чек».
///
/// Не наследует общий [LabeledTextField] — у него нестандартная разметка
/// (Row с полем и плашкой валюты). Отображение ошибок отсутствует (как
/// и в исходнике — `_buildA1Field` не поддерживал fieldKey).
///
/// Контроллер и обработчик [onChanged] принимаются снаружи — хранение
/// состояния остаётся на вызывающей стороне (пока `DynamicFilter.State`,
/// позже — BLoC).
class PriceInputField extends StatelessWidget {
  const PriceInputField({
    super.key,
    required this.attribute,
    required this.controller,
    required this.onChanged,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        RequiredLabel(label: attribute.title, isRequired: attribute.isRequired),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: '1 000 000',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              width: 53,
              height: 48,
              alignment: Alignment.center,
              child: const Text(
                '₽',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
