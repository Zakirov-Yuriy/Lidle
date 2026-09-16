// ============================================================
// "Подсветка незаполненных обязательных полей"
// ============================================================
//
// Экраны контактных данных длинные, и человек не видит, из-за чего именно
// форма не сохраняется: поле осталось пустым где-то выше, а внизу ничего об
// этом не говорит (16.09.2026).
//
// Здесь общая часть для таких экранов:
//   1. рядом с подписью обязательного поля ставится красная звёздочка;
//   2. после нажатия «Сохранить» пустые обязательные поля обводятся красным
//      и под ними появляется короткая подсказка;
//   3. экран прокручивается к САМОМУ ВЕРХНЕМУ незаполненному полю, чтобы не
//      искать его глазами;
//   4. как только поле заполнено, подсветка с него гаснет сама.
//
// Подсветка рисуется НАКЛАДКОЙ поверх готового поля, а не переделкой его
// внутренностей. Так один и тот же приём работает и для полей ввода, и для
// выпадающих списков области, города и прочего, каждый из которых собран
// по-своему.

import 'package:flutter/material.dart';

/// Обязательное поле: имя (для себя), человеческая подпись и признак
/// заполненности на момент проверки.
class RequiredField {
  const RequiredField({
    required this.name,
    required this.label,
    required this.filled,
  });

  final String name;
  final String label;
  final bool filled;
}

mixin RequiredFieldsMixin<T extends StatefulWidget> on State<T> {
  /// Якоря полей: по ним экран прокручивается к нужному месту.
  final Map<String, GlobalKey> _requiredKeys = {};

  /// Последнее известное состояние поля. Нужно только чтобы не перерисовывать
  /// экран на каждую букву, а только в момент, когда поле стало заполненным
  /// или снова опустело.
  final Map<String, bool> _requiredFilled = {};

  /// Проверку уже запускали. До первого нажатия «Сохранить» ничего красным не
  /// горит: подсвечивать поля человеку, который только открыл экран, значит
  /// ругаться на него раньше, чем он что-то сделал.
  bool _requiredChecked = false;

  bool get requiredChecked => _requiredChecked;

  GlobalKey requiredKey(String name) =>
      _requiredKeys.putIfAbsent(name, () => GlobalKey());

  /// Следит за полем ввода: подсветка гаснет, как только в поле появился текст.
  void watchRequired(TextEditingController controller, String name) {
    controller.addListener(() {
      if (!_requiredChecked) return;

      final filled = controller.text.trim().isNotEmpty;

      if (_requiredFilled[name] == filled) return;

      _requiredFilled[name] = filled;

      if (mounted) setState(() {});
    });
  }

  /// Оборачивает готовое поле: якорь для прокрутки, красная рамка и подсказка.
  ///
  /// [horizontal] повторяет боковые отступы поля, чтобы рамка легла ровно по
  /// его краям, а не по краям экрана.
  Widget requiredBox({
    required String name,
    required bool filled,
    required Widget child,
    double horizontal = 25,
    String message = 'Заполните это поле',
  }) {
    _requiredFilled[name] = filled;

    final invalid = _requiredChecked && !filled;

    return Column(
      key: requiredKey(name),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            child,
            if (invalid)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE5484D),
                          width: 1.4,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (invalid)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFE5484D),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  /// Включает подсветку, прокручивает к первому незаполненному полю и
  /// возвращает список незаполненных в том порядке, в каком они на экране.
  Future<List<RequiredField>> findMissingRequired(
    List<RequiredField> fields,
  ) async {
    setState(() {
      _requiredChecked = true;

      for (final field in fields) {
        _requiredFilled[field.name] = field.filled;
      }
    });

    final missing = fields.where((f) => !f.filled).toList();

    if (missing.isEmpty) return missing;

    // Ждём перерисовку: рамки и подсказки меняют высоту, и без этого прокрутка
    // уехала бы к старому положению поля.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return missing;

    final target = requiredKey(missing.first.name).currentContext;

    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    return missing;
  }

  /// Короткое сообщение под список незаполненных полей.
  String requiredMessage(List<RequiredField> missing) {
    if (missing.length == 1) {
      return 'Заполните поле «${missing.first.label}»';
    }

    return 'Заполните обязательные поля, они отмечены красным';
  }
}
