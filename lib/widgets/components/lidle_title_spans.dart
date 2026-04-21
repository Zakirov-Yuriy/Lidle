// ============================================================
// "Хелперы: TextSpan заголовки в стиле ЛИДЛ LIDLE"
// ============================================================
// Функции для создания фирменных заголовков где prefix
// отображается белым, а "LIDLE" — синим акцентным цветом.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Универсальная функция для заголовков в стиле "ТЕКСТ ЛИДЛ [LIDLE]".
///
/// [prefix] — текст перед LIDLE (например 'Поддержка ЛИДЛ ')
/// [fontSize] — размер шрифта prefix (по умолчанию 16)
/// [fontWeight] — вес шрифта (по умолчанию w400)
///
/// Пример:
/// ```dart
/// RichText(text: TextSpan(children: getLidleTitleSpans('Поддержка ЛИДЛ ')))
/// ```
List<TextSpan> getLidleTitleSpans(
  String prefix, {
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w400,
}) {
  return [
    TextSpan(
      text: prefix,
      style: TextStyle(
        color: textPrimary,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    ),
    TextSpan(
      text: 'LIDLE',
      style: TextStyle(
        color: activeIconColor,
        fontSize: 13,
        fontWeight: fontWeight,
      ),
    ),
  ];
}

// ── Обёртки для удобства ──────────────────────────────────────

List<TextSpan> getCapabilitiesTitleSpans() =>
    getLidleTitleSpans('Возможности ЛИДЛ ');

List<TextSpan> getAppTitleSpans() =>
    getLidleTitleSpans('ЛИДЛ ');

List<TextSpan> getSupportTitleSpans() =>
    getLidleTitleSpans('Поддержка ЛИДЛ ', fontSize: 18, fontWeight: FontWeight.w500);

List<TextSpan> getCategoriesTitleSpans() =>
    getLidleTitleSpans('Предложения на ЛИДЛ ');
