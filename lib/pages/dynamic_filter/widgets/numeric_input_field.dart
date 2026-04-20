import 'package:flutter/material.dart';
import 'package:lidle/models/filter_models.dart';
import 'labeled_text_field.dart';
import 'style_header.dart';

/// Числовое поле (style G1).
///
/// В отличие от [PriceInputField] не имеет значка валюты и использует
/// общий [LabeledTextField] как подложку. Примеры применения: «Общая
/// площадь», «Жилая площадь».
///
/// Поддерживает отображение ошибки валидации через [errorMessage]
/// и [hasError]. Метку собирает по стандартному правилу: если поле
/// обязательное, к [attribute.title] добавляется `*` — дальше
/// `LabeledTextField` сам обработает звёздочку красным.
class NumericInputField extends StatelessWidget {
  const NumericInputField({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        LabeledTextField(
          label: attribute.title + (attribute.isRequired ? '*' : ''),
          hint: 'Цифрами',
          controller: controller,
          keyboardType: TextInputType.number,
          errorMessage: errorMessage,
          hasError: hasError,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
