import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Поле-«выпадающий список» с меткой сверху.
///
/// Визуально выглядит как плашка на которую можно нажать (обработчик
/// [onTap]). В отличие от настоящего `DropdownButton`, сам список
/// выбора этот виджет не открывает — это делает вызывающая сторона
/// (обычно показывает диалог и пишет результат в контроллер формы).
///
/// 1-в-1 соответствует оригинальному `_buildDropdown`:
///   * высота плашки 60px если есть [subtitle], иначе 45px;
///   * цвет подсказки: серый для «Выбрать»/пустой строки, белый иначе;
///   * при ошибке фон становится `0xFF381a1a`, подсказка краснеет;
///   * звёздочка по тем же правилам, что и в `LabeledTextField`.
class LabeledDropdown extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.hint,
    this.onTap,
    this.errorMessage,
    this.hasError = false,
    this.subtitle,
    this.icon,
    this.showChangeText = false,
  });

  final String label;
  final String hint;
  final VoidCallback? onTap;
  final String? errorMessage;
  final bool hasError;

  /// Если задано — под [hint] рисуется вторая строка-подпись.
  /// В этом режиме высота плашки становится 60 (вместо 45).
  final String? subtitle;

  /// Виджет справа от текста (обычно иконка-стрелка).
  final Widget? icon;

  /// Показать слева от иконки надпись «Изменить» синим.
  final bool showChangeText;

  /// Подсказка в одну строку (07.10.2026).
  ///
  /// В названиях значений характеристик встречается мусор: перенос строки,
  /// табуляция, двойной или неразрывный пробел. Из-за переноса плашка
  /// рисовала текст в две строки и он налезал на край, тогда как соседние
  /// поля помещались в одну (видно было на «Графике работы» и
  /// «Образовании»). Высота плашки фиксированная, поэтому вторая строка
  /// просто обрезалась посередине.
  ///
  /// Сами названия чинит команда `attributes:tidy-values` на сервере, но
  /// поле не должно разъезжаться даже если мусор где-то остался.
  String get _oneLineHint {
    return hint
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final hasRedAsterisk = label.endsWith('*');
    final labelText =
        hasRedAsterisk ? label.substring(0, label.length - 1) : label;

    // Цвет подсказки зависит от того, выбрано ли значение.
    // Пустая строка или «Выбрать» = placeholder → серый.
    final cleanHint = _oneLineHint;
    final hintIsPlaceholder = cleanHint == 'Выбрать' || cleanHint.isEmpty;
    final hintColor = hasError
        ? const Color(0xFFff7272)
        : (hintIsPlaceholder
            ? const Color(0xFF7A7A7A)
            : const Color.fromARGB(255, 255, 255, 255));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // В оригинале GestureDetector был и на label, и на контейнере
        // (два независимых хита). Сохраняем эту странность — тап по самой
        // метке тоже открывает диалог.
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                labelText,
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
              if (hasRedAsterisk)
                const Text(
                  '*',
                  style: TextStyle(color: Color(0xFFFF1744), fontSize: 16),
                ),
              if (hasError && !hasRedAsterisk)
                const Text(
                  ' *',
                  style: TextStyle(color: Color(0xFFFF1744), fontSize: 16),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: subtitle != null ? 60 : 45,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: hasError ? const Color(0xFF381a1a) : formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: subtitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _oneLineHint,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hintColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                color: Color(0xFF7A7A7A),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _oneLineHint,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hintColor,
                            fontSize: 14,
                          ),
                        ),
                ),
                if (showChangeText)
                  const Text(
                    'Изменить',
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                if (icon != null) icon!,
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              errorMessage ?? 'Ошибка заполнения',
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
