// ============================================================
//  "Кнопка «Поделиться» в нижнем ряду действий"
// ============================================================
//  Квадратная кнопка со значком отправки, стоит справа от
//  «Написать» на карточке объявления и на витрине продавца.
//  Нажатие открывает обычное окно «Поделиться» телефона,
//  где человек сам выбирает, куда отправить ссылку.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Кнопка «Поделиться» рядом с «Позвонить» и «Написать» (16.10.2026).
///
/// Отдельным виджетом, а не копией разметки на каждом экране: кнопка
/// появляется в двух местах и должна выглядеть одинаково, а главное
/// одинаково вести себя. Что именно отправлять, решает сам экран и передаёт
/// в [onTap]: карточка делится объявлением, витрина продавцом.
class ShareActionButton extends StatelessWidget {
  /// Что делать по нажатию. Обычно это метод экрана, который уже умеет
  /// делиться: он же считает статистику и собирает текст со ссылкой.
  final VoidCallback onTap;

  /// Цвет кнопки. По умолчанию тот же, что у соседней «Написать».
  final Color color;

  /// Высота, чтобы кнопка села ровно по соседям: на карточке объявления
  /// кнопки 43 точки, на витрине продавца выше за счёт своих отступов.
  final double size;

  const ShareActionButton({
    super.key,
    required this.onTap,
    this.color = Colors.blue,
    this.size = 43,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Нажатие ловим на всей площади, а не только на значке: попасть
      // пальцем в стрелку шириной двадцать точек трудно.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/chat_page/send-03.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
