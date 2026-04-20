import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'labeled_dropdown.dart';
import 'style_header.dart';

/// Выпадающий список с множественным выбором (style D с `is_popup = false`).
///
/// Хинт собирается из выбранных значений через запятую. Если ничего
/// не выбрано — показывается placeholder «Выбрать».
///
/// При тапе открывается [SelectionDialog] с `allowMultipleSelection`,
/// взятым из [Attribute.isMultiple] (нестрогое множественное — диалог
/// сам обработает поведение по флагу).
///
/// В отличие от [SingleSelectDropdownField], здесь над полем
/// дополнительно рисуется [StyleHeader] — так было в исходнике
/// `_buildMultipleSelectDropdown`, сохраняем идентичность.
class MultipleSelectDropdownField extends StatelessWidget {
  const MultipleSelectDropdownField({
    super.key,
    required this.attribute,
    required this.selectedValues,
    required this.onChanged,
    this.errorMessage,
    this.hasError = false,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;
  final String? errorMessage;
  final bool hasError;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    final label = attribute.isTitleHidden
        ? ''
        : attribute.title + (attribute.isRequired ? '*' : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        LabeledDropdown(
          label: label,
          hint: selectedValues.isEmpty ? 'Выбрать' : selectedValues.join(', '),
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
                  selectedOptions: selectedValues,
                  onSelectionChanged: onChanged,
                  allowMultipleSelection: attribute.isMultiple,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
