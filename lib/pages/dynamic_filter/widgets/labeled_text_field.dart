import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Текстовое поле с меткой сверху и сообщением об ошибке снизу.
///
/// Полностью stateless — принимает всё через параметры. Не знает про
/// глобальную мапу ошибок формы: вызывающая сторона сама вычисляет
/// [hasError] и [errorMessage] и передаёт их снаружи. Это позволяет
/// безопасно переиспользовать поле в будущем с BLoC/Cubit без правок.
///
/// Визуально и по поведению 1-в-1 соответствует оригинальному
/// `_buildTextField` из `DynamicFilter`:
///   * красная звёздочка — если `label` заканчивается на `*` либо
///     есть ошибка и звёздочки в label нет;
///   * фон поля подкрашивается в `0xFF381a1a` при ошибке;
///   * если ошибки нет, но задан `minLength`, под полем выводится
///     подсказка «Введите не менее N символов».
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.onChanged,
    this.errorMessage,
    this.hasError = false,
    this.maxLines = 1,
    this.minLength = 0,
    this.maxLength,
    this.keyboardType = TextInputType.text,
  });

  /// Текст метки над полем. Если заканчивается на `*`, звёздочка будет
  /// отрисована отдельно красным.
  final String label;

  /// Плейсхолдер внутри поля.
  final String hint;

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Текст ошибки, если поле заполнено неверно. При `null` и `hasError = false`
  /// ошибка не показывается.
  final String? errorMessage;

  /// Включает визуальную подсветку ошибки (красный фон, текст, звёздочка).
  final bool hasError;

  final int maxLines;
  final int minLength;
  final int? maxLength;

  /// Тип клавиатуры. В текущей реализации не передаётся во внутренний
  /// TextField — сохраняем исходное поведение (в `_buildTextField`
  /// внутри всегда использовался `TextInputType.multiline`, а параметр
  /// принимался, но игнорировался). Параметр оставлен, чтобы не ломать
  /// сигнатуру вызовов. При желании в будущем можно пробросить его
  /// в TextField — это будет отдельная задача, а не рефакторинг.
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final hasRedAsterisk = label.endsWith('*');
    final labelText =
        hasRedAsterisk ? label.substring(0, label.length - 1) : label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFF381a1a) : formBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            minLines: maxLines == 1 ? 1 : maxLines,
            maxLines: null,
            maxLength: maxLength,
            // В исходнике было идентично: keyboardType параметра
            // игнорировался, всегда multiline.
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: hasError
                  ? const Color(0xFFff7272)
                  : const Color.fromARGB(255, 255, 255, 255),
            ),
            onChanged: onChanged,
            expands: false,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: hasError ? const Color(0xFFff7272) : textSecondary,
                fontSize: 14,
              ),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: InputBorder.none,
              counterText: '',
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
          )
        else if (minLength > 0)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Введите не менее $minLength символов',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
