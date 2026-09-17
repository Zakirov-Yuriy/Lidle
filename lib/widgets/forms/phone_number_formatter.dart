// ============================================================
// "Ввод номера телефона: +7 (925) 449 95 50"
// ============================================================
//
// Форматирование жило внутри экрана регистрации, и из-за этого на оформлении
// заказа телефон вводился сплошной строкой цифр: одно и то же поле выглядело
// на двух экранах по-разному (17.09.2026). Вынесено сюда, чтобы любой экран
// с телефоном писал его одинаково.

import 'package:flutter/services.dart';

/// Форматер номера: показывает «+7 (925) 449 95 50», хранит только цифры.
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    // Извлекаем только цифры
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return newValue.copyWith(
        text: '+7',
        selection: const TextSelection.collapsed(offset: 2),
      );
    }

    // Ограничиваем до 11 цифр (7 + 10 цифр номера)
    final limitedDigits = digits.length > 11 ? digits.substring(0, 11) : digits;

    // Форматируем: +7 (925) 449 95 50
    String formatted;
    if (limitedDigits.length == 1 && limitedDigits[0] == '7') {
      formatted = '+7';
    } else if (limitedDigits.length <= 4) {
      final part = limitedDigits.startsWith('7')
          ? limitedDigits.substring(1)
          : limitedDigits;
      formatted = '+7 ($part';
    } else if (limitedDigits.length <= 7) {
      final areaCode = limitedDigits.substring(1, 4);
      final firstPart = limitedDigits.substring(4);
      formatted = '+7 ($areaCode) $firstPart';
    } else {
      final areaCode = limitedDigits.substring(1, 4);
      final firstPart = limitedDigits.substring(4, 7);
      final secondPart = limitedDigits.substring(7);
      formatted = '+7 ($areaCode) $firstPart $secondPart';
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Красивый вид номера, пришедшего с сервера.
///
/// Форматер работает только на ввод, а телефон в поле часто подставляется
/// готовым: из профиля или из прошлого заказа. Без этого человек видел бы
/// «+79254499550» в поле, которое само пишет «+7 (925) 449 95 50».
String formatPhoneForDisplay(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.isEmpty) return '';

  // Номер могли записать и с восьмёркой, и вовсе без кода страны.
  var national = digits;

  if (national.length == 11 && (national[0] == '7' || national[0] == '8')) {
    national = national.substring(1);
  }

  if (national.length != 10) {
    // Непонятный номер оставляем как есть: лучше показать как записано, чем
    // молча превратить во что-то другое.
    return raw;
  }

  final area = national.substring(0, 3);
  final first = national.substring(3, 6);
  final second = national.substring(6, 8);
  final third = national.substring(8);

  return '+7 ($area) $first $second $third';
}

/// Номер для отправки на сервер: только плюс и цифры.
String cleanPhone(String formatted) {
  return formatted.replaceAll(RegExp(r'[^0-9+]'), '');
}
