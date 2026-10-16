// ============================================================
//  "Подсказка у обязательной галочки"
// ============================================================

import 'package:flutter/material.dart';

/// Подсказка «Чтобы продолжить, установите этот флажок» (16.10.2026).
///
/// ЗАЧЕМ. Обязательные галочки согласия просто гасили кнопку: нажать нельзя,
/// а почему, не сказано. Человек жмёт в пустоту и уходит, решив, что
/// приложение сломалось. Теперь кнопка нажимается всегда, а при пропущенной
/// галочке под ней появляется это объяснение.
///
/// Так же ведёт себя браузер на обычной веб-форме, и подсказка намеренно
/// повторяет его слова: формулировка людям знакома.
class RequiredCheckHint extends StatelessWidget {
  /// Показывать ли подсказку. Экран ставит это в `true`, когда человек
  /// попытался продолжить без галочки.
  final bool visible;

  /// Текст. По умолчанию тот же, что в браузере.
  final String text;

  const RequiredCheckHint({
    super.key,
    required this.visible,
    this.text = 'Чтобы продолжить, установите этот флажок',
  });

  @override
  Widget build(BuildContext context) {
    // Появляется и исчезает плавно: подсказка возникает в ответ на нажатие,
    // и резкий скачок разметки читается как сбой.
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topLeft,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF6B6B),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
