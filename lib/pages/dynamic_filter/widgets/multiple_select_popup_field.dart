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
    this.showSelectAll = false,
  });

  /// Строка «Все» в окне выбора (формы «Бронирования», 22.09.2026). Не
  /// рисуется, если «всё сразу» уже есть среди вариантов («Всю неделю»,
  /// «Круглый год»): две такие строки только путали бы.
  final bool showSelectAll;

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

    // Варианты выбора — с переносом. Заодно сразу запоминаем обратный
    // путь: перенесённый текст → исходное название.
    //
    // ПОЧЕМУ ПО ВСЕМ ВАРИАНТАМ, А НЕ ПО ВЫБРАННЫМ (07.10.2026).
    // Раньше обратный путь строился только из уже выбранных значений. Для
    // них возврат работал, а вот значение, выбранное в окне ВПЕРВЫЕ, в
    // этом списке отсутствовало, и наверх уходил текст С ПЕРЕНОСОМ внутри
    // («Сменный график\nработы» вместо «Сменный график работы»).
    //
    // Дальше в форме выбранное значение сопоставляется с его номером по
    // тексту. Перенос ломал сравнение, номер не находился, характеристика
    // до сервера не доезжала вовсе, и человек получал отказ «обязательный
    // атрибут не заполнен» при заполненном на вид поле. Нашли на деве при
    // подаче вакансии оператора ПК, поле «График работы».
    final wrappedToOriginal = <String, String>{};
    final processedOptions = attribute.values.map((v) {
      final wrapped = wrapLongText(v.value);
      if (wrapped != v.value) {
        wrappedToOriginal[wrapped] = v.value;
      }

      return wrapped;
    }).toList();

    // Текущие выбранные значения — с переносом, чтобы в окне выбора они
    // совпали с вариантами.
    final processedSelected = selectedValues.map((original) {
      final wrapped = wrapLongText(original);
      if (wrapped != original) {
        wrappedToOriginal[wrapped] = original;
      }

      return wrapped;
    }).toSet();

    // Hint в плашке — через запятую и БЕЗ переносов.
    //
    // Перенос нужен в окне выбора, где строки широкие. В плашке высота
    // фиксированная: вторая строка туда не помещается и обрезается
    // посередине, из-за чего поля «График работы» и «Образование»
    // выглядели иначе, чем соседние. Показываем исходные названия.
    final hint = selectedValues.isEmpty ? 'Выбрать' : selectedValues.join(', ');

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
                  showSelectAll: showSelectAll &&
                      attribute.isMultiple &&
                      !attribute.values.any(
                        (v) => const {'все', 'всю неделю', 'круглый год'}
                            .contains(v.value.trim().toLowerCase()),
                      ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
