// ============================================================
//  "Диалог: Заполните контактные данные"
// ============================================================
// Показывается при нажатии на «плюс» (создание объявления), если у
// пользователя не заполнены обязательные контактные данные компании.
// По кнопке «Заполнить» диалог закрывается с результатом true —
// вызывающий код ведёт пользователя на экран заполнения. Закрытие по
// крестику возвращает false/null (никакого перехода).

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class FillContactsDialog extends StatelessWidget {
  const FillContactsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Крестик закрытия (возврат без перехода).
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: textSecondary, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Заполните контактные данные',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Чтобы пользователи могли видеть ваши контактные данные, '
              'заполните информацию о себе в профиле.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: inactiveIconColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: activeIconColor,
                  side: const BorderSide(color: activeIconColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Заполнить',
                  style: TextStyle(
                    color: activeIconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
