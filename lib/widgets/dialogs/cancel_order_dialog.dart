// ============================================================
//  "Диалог отказа от заказа"
// ============================================================
//
// Открывается по кнопке «Отказаться» на экране заказа (17.09.2026).
//
// Отказ необратим: заказ отменяется целиком, товар возвращается продавцу на
// остаток, и передумать одной кнопкой уже нельзя. Поэтому здесь не просто
// «да/нет», а слово руками: случайное касание красной кнопки в кармане так не
// отменит покупку, а осознанное действие займёт три секунды.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class CancelOrderDialog extends StatefulWidget {
  /// Что человек должен напечатать, чтобы кнопка ожила.
  static const String word = 'Удалить';

  final VoidCallback onConfirm;

  const CancelOrderDialog({super.key, required this.onConfirm});

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  final TextEditingController _controller = TextEditingController();

  /// Слово сверяем без учёта регистра и пробелов по краям: человек печатает
  /// его с телефонной клавиатуры, и «удалить » с автозаглавной это то же
  /// самое согласие, что и «Удалить».
  bool get _matches =>
      _controller.text.trim().toLowerCase() ==
      CancelOrderDialog.word.toLowerCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Удалить товар',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text.rich(
              TextSpan(
                style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                children: [
                  TextSpan(
                    text: 'Внимание: ',
                    style: TextStyle(
                      color: Color(0xFFCCCC00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: 'если вы хотите\nудалить заказ!'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Введите слово: ${CancelOrderDialog.word}',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              // Перерисовываем на каждую букву: кнопка должна ожить ровно в
              // тот момент, когда слово совпало.
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Введите',
                hintStyle: const TextStyle(color: textMuted, fontSize: 15),
                filled: true,
                fillColor: secondaryBackground,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      inherit: false,
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                OutlinedButton(
                  // Пока слово не совпало, кнопка не нажимается: она и
                  // выглядит выключенной, чтобы человек искал причину в поле,
                  // а не в связи с сервером.
                  onPressed: _matches
                      ? () {
                          Navigator.of(context).pop();
                          widget.onConfirm();
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _matches ? activeIconColor : textMuted,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Подтвердить',
                    style: TextStyle(
                      color: _matches ? activeIconColor : textMuted,
                      fontSize: 16,
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
