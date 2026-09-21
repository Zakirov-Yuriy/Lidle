// ============================================================
//  Диалог «Спасибо за заказ» (макет, 21.09.2026)
// ============================================================
//
// Показывается сразу после успешного оформления, до экрана с кодом
// получения. Кнопка «Далее» и крестик делают одно и то же: закрывают окно и
// пускают дальше. Отменить заказ отсюда нельзя, окно только благодарит.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Показать «Спасибо за заказ». Возвращается, когда окно закрыли.
Future<void> showThankYouOrderDialog(BuildContext context) {
  return showDialog<void>(
    context: context,

    // Мимо окна не закрываем: случайное касание фона не должно проскакивать
    // благодарность, закрывают её «Далее» или крестиком.
    barrierDismissible: false,
    builder: (_) => const _ThankYouOrderDialog(),
  );
}

class _ThankYouOrderDialog extends StatelessWidget {
  const _ThankYouOrderDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Спасибо за заказ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Спасибо за ваш заказ\nи за использование нашего '
                  'приложения.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: activeIconColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Далее',
                      style: TextStyle(color: activeIconColor, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
