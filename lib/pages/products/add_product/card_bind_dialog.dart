// ============================================================
// Диалог «Привязать карту» (11.09.2026).
// ============================================================
//
// ГЛАВНОЕ ПРО ЭТОТ ФАЙЛ: полный номер карты никуда не уходит и нигде не
// сохраняется. Он живёт только в поле ввода, пока диалог открыт, а наружу
// возвращаются ПОСЛЕДНИЕ ЧЕТЫРЕ ЦИФРЫ. Их хватает, чтобы продавец узнал
// свою карту в списке, а хранение полного номера означало бы держать у себя
// платёжные данные со всеми требованиями к их защите. Так же устроены
// кабинеты крупных площадок: везде видно только хвост.
//
// Сама привязка, то есть согласие банка переводить деньги на эту карту,
// делается платёжным шлюзом. Его у нас пока нет, поэтому здесь только ввод
// и проверка номера.
//
// Номер проверяется алгоритмом Луна: он ловит опечатку в одной цифре и
// перестановку соседних, а это девять из десяти ошибок при наборе.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/constants.dart';

/// Показать диалог привязки карты. Возвращает последние четыре цифры.
Future<String?> showCardBindDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CardBindDialog(),
  );
}

class _CardBindDialog extends StatefulWidget {
  const _CardBindDialog();

  @override
  State<_CardBindDialog> createState() => _CardBindDialogState();
}

class _CardBindDialogState extends State<_CardBindDialog> {
  // Контроллер намеренно не освобождаем: диалог закрывается с анимацией, и
  // поле живёт ещё несколько кадров. Освобождение здесь оставляет живой
  // TextField с мёртвым контроллером — приложение намертво зависает.
  final _number = TextEditingController();

  String? _error;

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  /// Проверка номера алгоритмом Луна.
  bool _isValid(String digits) {
    if (digits.length < 16 || digits.length > 19) return false;

    var sum = 0;
    var double = false;

    for (var i = digits.length - 1; i >= 0; i--) {
      var value = int.parse(digits[i]);

      if (double) {
        value *= 2;

        if (value > 9) value -= 9;
      }

      sum += value;
      double = !double;
    }

    return sum % 10 == 0;
  }

  void _submit() {
    final digits = _digits;

    setState(() {
      _error = _isValid(digits)
          ? null
          : 'Проверьте номер карты: кажется, в нём опечатка';
    });

    if (_error != null) return;

    Navigator.pop(context, digits.substring(digits.length - 4));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Привязать карту',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: textPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Номер карты',
                style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _number,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberFormatter(),
                ],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  letterSpacing: 1.2,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0000 0000 0000 0000',
                  hintStyle: TextStyle(color: textMuted, fontSize: 17),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE05A5A), fontSize: 13),
              ),
            ],

            const SizedBox(height: 12),
            const Text(
              'Мы сохраним только последние четыре цифры, чтобы вы узнавали '
              'свою карту в списке. Полный номер нигде не хранится.',
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.35),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: activeIconColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Разбивает номер по четыре цифры: так его читают и так печатают на карте.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');

      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
