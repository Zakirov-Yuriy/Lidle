// ============================================================
//  "Код +7 в пустом поле телефона"
// ============================================================

import 'package:flutter/material.dart';

/// Подставляет `+7`, когда человек встаёт в ПУСТОЕ поле телефона
/// (16.10.2026).
///
/// ЗАЧЕМ. Почти все номера у нас российские, и каждый раз набирать код руками
/// лишняя работа. Такое поведение уже было на регистрации и в оформлении
/// заказа, но каждый экран нёс свою копию обработчика. Теперь правило одно на
/// всё приложение.
///
/// ВАЖНО: код именно ПОДСТАВЛЯЕТСЯ, а не закрепляется. Его можно стереть и
/// набрать любой другой, хоть +90: поле обычное, никакой защиты от правки в
/// нём нет. Это осознанное решение, у нас есть продавцы не из России.
///
/// В поле, где уже что-то есть, ничего не меняется: человек вернулся
/// поправить номер, а не начать заново.
class PhonePrefix {
  const PhonePrefix._();

  /// Код, который подставляем.
  static const String code = '+7';

  /// Привязать правило к уже существующему узлу фокуса.
  static void bind(FocusNode node, TextEditingController controller) {
    node.addListener(() => _apply(node, controller));
  }

  /// Создать узел фокуса с этим правилом.
  ///
  /// Для полей, у которых своего узла не было: экран кладёт результат в своё
  /// поле, передаёт в `TextField(focusNode: ...)` и освобождает в `dispose`.
  static FocusNode node(TextEditingController controller) {
    final node = FocusNode();

    bind(node, controller);

    return node;
  }

  /// Применить правило прямо сейчас.
  ///
  /// Для экранов, где слушатель фокуса уже был заведён своим кодом: они
  /// зовут это из своего обработчика, а не вешают второй слушатель.
  static void applyTo(FocusNode node, TextEditingController controller) =>
      _apply(node, controller);

  static void _apply(FocusNode node, TextEditingController controller) {
    if (!node.hasFocus) return;

    // Пробелы считаем пустотой: человек мог стереть номер не до конца.
    if (controller.text.trim().isNotEmpty) return;

    controller.text = code;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: code.length),
    );
  }
}
