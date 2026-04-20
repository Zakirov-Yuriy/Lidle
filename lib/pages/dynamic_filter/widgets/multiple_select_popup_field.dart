import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'labeled_dropdown.dart';
import 'style_header.dart';

/// Максимум символов в одной строке для переноса текста.
const int _maxCharsPerLine = 20;

/// Интеллектуальный перенос длинного текста на две строки.
///
/// Правила:
///   * если длина не превышает [_maxCharsPerLine] — вернуть как есть;
///   * если в тексте нет пробелов — разрезать ровно пополам;
///   * иначе — набирать первую строку словами, пока умещается,
///     остальное перенести во вторую.
///
/// Вынесено на уровень файла (не метод класса), чтобы виджет оставался
/// чистым и функция была легко тестируемой.
String wrapLongText(String text) {
  if (text.length <= _maxCharsPerLine) {
    return text;
  }

  final words = text.split(' ');
  if (words.length == 1) {
    // Слово без пробелов — разбиваем в середине.
    final mid = text.length ~/ 2;
    return '${text.substring(0, mid)}\n${text.substring(mid)}';
  }

  // Ищем оптимальную точку разрыва.
  String line1 = '';
  String line2 = '';
  for (int i = 0; i < words.length; i++) {
    if (('$line1 ${words[i]}').length <= _maxCharsPerLine) {
      line1 += (line1.isEmpty ? '' : ' ') + words[i];
    } else {
      line2 = words.sublist(i).join(' ');
      break;
    }
  }

  return line2.isEmpty ? text : '$line1\n$line2';
}

/// Выпадающий список, открывающий попап с переносом длинного текста
/// (style F / style D с `is_popup = true`).
///
/// В отличие от [MultipleSelectDropdownField] здесь:
///   * заголовок диалога, варианты выбора и уже-выбранные значения
///     пропускаются через [wrapLongText];
///   * сохраняется маппинг «перенесённый текст → оригинальный»,
///     чтобы при изменении выбора в диалоге вернуть наверх
///     оригинальные строки (без `\n`). Это важно для последующей
///     сериализации в payload.
///
/// UI-подложка и правила `LabeledDropdown` идентичны обычному
/// мультиселекту.
class MultipleSelectPopupField extends StatelessWidget {
  const MultipleSelectPopupField({
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
    final displayLabel = attribute.isTitleHidden
        ? ''
        : attribute.title + (attribute.isRequired ? '*' : '');

    // Заголовок диалога — с переносом.
    final dialogTitle = wrapLongText(
      attribute.title.isEmpty ? 'Выбор' : attribute.title,
    );

    // Варианты выбора — с переносом.
    final processedOptions =
        attribute.values.map((v) => wrapLongText(v.value)).toList();

    // Текущие выбранные значения — с переносом. Сохраняем маппинг
    // обратно, чтобы потом в onChanged вернуть оригинальные строки.
    final wrappedToOriginal = <String, String>{};
    final processedSelected = selectedValues.map((original) {
      final wrapped = wrapLongText(original);
      if (wrapped != original) {
        wrappedToOriginal[wrapped] = original;
      }
      return wrapped;
    }).toSet();

    // Hint в плашке — через запятую, уже перенесённые.
    final hint = processedSelected.isEmpty
        ? 'Выбрать'
        : processedSelected.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyleHeader(attribute: attribute, isSubmissionMode: isSubmissionMode),
        LabeledDropdown(
          label: displayLabel,
          hint: hint,
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
                  title: dialogTitle,
                  options: processedOptions,
                  selectedOptions: processedSelected,
                  onSelectionChanged: (Set<String> newSelected) {
                    // Восстанавливаем оригинальные значения
                    // перед сохранением наружу.
                    final originalSelected = newSelected
                        .map((s) => wrappedToOriginal[s] ?? s)
                        .toSet();
                    onChanged(originalSelected);
                  },
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
