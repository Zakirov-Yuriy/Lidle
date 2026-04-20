import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'labeled_dropdown.dart';

/// Выпадающий список с одиночным выбором (style D без `is_popup`
/// и без `is_multiple`).
///
/// Рендерит [LabeledDropdown], по тапу открывает [SelectionDialog]
/// с `allowMultipleSelection: false`. Виджет ничего не знает про
/// `_selectedValues` — работает через параметры [selectedValue] и
/// [onChanged]. При выборе пустой коллекции возвращает пустую строку.
///
/// Пример: «Санузел» (Раздельный / Смежный).
class SingleSelectDropdownField extends StatelessWidget {
  const SingleSelectDropdownField({
    super.key,
    required this.attribute,
    required this.selectedValue,
    required this.onChanged,
    this.errorMessage,
    this.hasError = false,
  });

  final Attribute attribute;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  final String? errorMessage;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final label = attribute.isTitleHidden
        ? ''
        : attribute.title + (attribute.isRequired ? '*' : '');

    return LabeledDropdown(
      label: label,
      hint: selectedValue.isEmpty ? 'Выбрать' : selectedValue,
      errorMessage: errorMessage,
      hasError: hasError,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textSecondary,
      ),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext dialogContext) {
            return SelectionDialog(
              title: attribute.title.isEmpty ? 'Выбор' : attribute.title,
              options: attribute.values.map((v) => v.value).toList(),
              selectedOptions: selectedValue.isEmpty ? <String>{} : {selectedValue},
              onSelectionChanged: (Set<String> newSelected) {
                onChanged(newSelected.isEmpty ? '' : newSelected.first);
              },
              allowMultipleSelection: false,
            );
          },
        );
      },
    );
  }
}
