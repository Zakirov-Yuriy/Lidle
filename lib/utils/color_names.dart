// ============================================================
// Цвет по названию значения.
// ============================================================
//
// Цвет у нас приходит характеристикой раздела: администратор заводит
// «Цвет» со значениями словами — Чёрный, Синий, Красный. Кода цвета в
// справочнике характеристик нет, поэтому квадратик рисуем по названию.
//
// Незнакомое название (изумрудный, морская волна) осознанно возвращает
// пустоту: показать текстом честнее, чем угадать не тот оттенок.

import 'package:flutter/material.dart';

const Map<String, Color> _known = {
  'белый': Color(0xFFFFFFFF),
  'чёрный': Color(0xFF1A1A1A),
  'черный': Color(0xFF1A1A1A),
  'серый': Color(0xFF9E9E9E),
  'красный': Color(0xFFE53935),
  'оранжевый': Color(0xFFFB8C00),
  'жёлтый': Color(0xFFFDD835),
  'желтый': Color(0xFFFDD835),
  'зелёный': Color(0xFF43A047),
  'зеленый': Color(0xFF43A047),
  'голубой': Color(0xFF29B6F6),
  'синий': Color(0xFF1E88E5),
  'фиолетовый': Color(0xFF8E24AA),
  'сиреневый': Color(0xFFB39DDB),
  'розовый': Color(0xFFEC407A),
  'коричневый': Color(0xFF6D4C41),
  'бежевый': Color(0xFFD7CCC8),
  'золотой': Color(0xFFC9A227),
  'золотистый': Color(0xFFC9A227),
  'серебряный': Color(0xFFBDBDBD),
  'серебристый': Color(0xFFBDBDBD),
  'бирюзовый': Color(0xFF26A69A),
  'прозрачный': Color(0xFFECEFF1),
};

/// Цвет по названию значения. Пусто, если название незнакомое.
Color? colorByName(String? value) {
  final key = (value ?? '').trim().toLowerCase();

  if (key.isEmpty) return null;

  // Значение могло прийти с уточнением: «Синий (матовый)». Берём первое
  // слово — оно и есть цвет.
  return _known[key] ?? _known[key.split(RegExp(r'[\s(,/]')).first];
}

/// Это характеристика про цвет?
bool isColorAttribute(String? title) =>
    (title ?? '').toLowerCase().contains('цвет');

/// Квадратик цвета для списков и карточек.
Widget colorSwatch(Color color, {double size = 20}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),

      // Обводка обязательна: белый квадрат на светлой подложке и чёрный на
      // тёмной без неё просто исчезают.
      border: Border.all(color: const Color(0x66FFFFFF)),
    ),
  );
}
