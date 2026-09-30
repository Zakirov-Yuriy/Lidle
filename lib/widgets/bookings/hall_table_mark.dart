// ============================================================
//  Метка места на схеме зала (30.09.2026)
// ============================================================
//
// ЗАЧЕМ. Раньше стол рисовался квадратом 44×44 с номером и числом мест
// ВНУТРИ рамки. План зала у каждого свой: белая схема, тёмная картинка,
// фотография. Мелкий цветной текст поверх такой картинки не читался, и
// квадрат одного размера не совпадал ни с одним настоящим столом: у кого-то
// длинный стол на восемь человек, у кого-то круглый на двоих, и стоят они
// под разными углами.
//
// РЕШЕНИЕ. Метка разделена на две части:
//
//   1. ОБЛАСТЬ — прямоугольник по размеру настоящего стола на картинке.
//      Продавец задаёт ширину, высоту и поворот, поэтому область ложится на
//      стол, а не рядом с ним. Она полупрозрачная: под ней видно сам стол, и
//      когда область красная или зелёная, кажется, что цвет меняет стол.
//
//   2. ПОДПИСЬ — непрозрачная тёмная таблетка с номером и числом мест.
//      Она НЕ вращается и НЕ меняет размер вместе с областью: буквы всегда
//      одного кегля и всегда на своём тёмном фоне. Поэтому подпись читается
//      одинаково на белой схеме, на тёмной и на фотографии.
//
// Закрасить сам стол на картинке нельзя: это растровое изображение, и где
// на нём кончается стол, программе неизвестно. Область по форме стола даёт
// тот же эффект и работает на любой схеме.
//
// Виджет общий для двух экранов: гость выбирает место (hall_booking_screen)
// и продавец расставляет столы (hall_tables_screen). Раньше метки на этих
// экранах выглядели по-разному, и продавец не понимал, что увидит гость.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lidle/models/hall_table.dart';

/// Состояние места на схеме.
enum TableMarkState {
  /// Время ещё не выбрано: занятость неизвестна.
  unknown,

  /// Свободно.
  free,

  /// Занято на выбранное время.
  busy,

  /// Это место человек выбрал.
  selected,
}

const Color _freeColor = Color(0xFFE9EFF5);
const Color _busyColor = Color(0xFFE05A6B);
const Color _pickedColor = Color(0xFF3ECF6E);
const Color _unknownColor = Color(0xFFA4B1BE);

/// Одно место на схеме: где стоит, как выглядит, в каком состоянии.
class TableSpot {
  final String key;
  final String number;
  final int seats;

  /// Середина стола долями ширины и высоты плана.
  final double x;
  final double y;

  /// Размер стола долями плана и поворот в градусах.
  final double width;
  final double height;
  final double angle;

  final TableMarkState state;

  /// Продавцу: за столом закреплён сотрудник.
  final bool hasStaff;

  const TableSpot({
    required this.key,
    required this.number,
    required this.seats,
    required this.x,
    required this.y,
    this.width = kTableMarkWidth,
    this.height = kTableMarkHeight,
    this.angle = 0,
    this.state = TableMarkState.free,
    this.hasStaff = false,
  });
}

/// Цвет состояния.
Color tableMarkColor(TableMarkState state) {
  switch (state) {
    case TableMarkState.selected:
      return _pickedColor;
    case TableMarkState.busy:
      return _busyColor;
    case TableMarkState.unknown:
      return _unknownColor;
    case TableMarkState.free:
      return _freeColor;
  }
}

/// Слои схемы: сначала все области, потом все подписи.
///
/// Порядок важен: подписи соседних столов не должны уходить под область
/// следующего стола. Поэтому один проход рисует области, второй подписи.
List<Widget> tableMarkLayers({
  required Size plan,
  required List<TableSpot> spots,
  void Function(TableSpot spot)? onTap,

  /// Показывать подпись только у выбранного места (30.09.2026).
  ///
  /// У гостя таблички с номерами всех столов закрывали план, и зал было не
  /// разглядеть. Ему номер нужен ровно у того стола, который он выбрал.
  /// Продавцу наоборот: он расставляет столы и должен видеть все номера.
  bool badgesOnlyPicked = false,
}) {
  final areas = <Widget>[];
  final badges = <Widget>[];

  // Рамка не может стать совсем мелкой: в неё нужно попасть пальцем даже на
  // схеме с двадцатью столами. Порог считаем от плана, а не в точках: на
  // маленьком экране фиксированное число точек съело бы нижнюю половину
  // ползунка размера у продавца.
  final floor = math.min(26.0, plan.shortestSide * 0.055);

  for (final spot in spots) {
    final w = math.max(floor, spot.width * plan.width);
    final h = math.max(floor, spot.height * plan.height);
    final cx = spot.x * plan.width;
    final cy = spot.y * plan.height;

    areas.add(Positioned(
      left: cx - w / 2,
      top: cy - h / 2,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: spot.angle * math.pi / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null ? null : () => onTap(spot),
          child: _TableArea(state: spot.state),
        ),
      ),
    ));

    if (badgesOnlyPicked && spot.state != TableMarkState.selected) {
      continue;
    }

    // Подпись ставится серединой в середину стола. Размер её заранее
    // неизвестен (номер бывает «12» и «VIP-3»), поэтому сдвигаем на половину
    // собственного размера, а не считаем в точках.
    badges.add(Positioned(
      left: cx,
      top: cy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: onTap == null ? null : () => onTap(spot),
          child: _TableBadge(spot: spot),
        ),
      ),
    ));
  }

  return [...areas, ...badges];
}

/// Область стола: полупрозрачная заливка и обводка по состоянию.
class _TableArea extends StatelessWidget {
  const _TableArea({required this.state});

  final TableMarkState state;

  @override
  Widget build(BuildContext context) {
    final color = tableMarkColor(state);

    final Color fill;
    switch (state) {
      case TableMarkState.selected:
        fill = const Color(0x593ECF6E);
        break;
      case TableMarkState.busy:
        fill = const Color(0x4DE05A6B);
        break;
      case TableMarkState.unknown:
        fill = const Color(0x14FFFFFF);
        break;
      case TableMarkState.free:
        fill = const Color(0x1AFFFFFF);
        break;
    }

    // Три кольца: тёмное, цветное, тёмное. Тень здесь не годится — она
    // заливает весь прямоугольник и затемняет сам стол под рамкой, а рамка
    // должна оставаться прозрачной. Тёмные волоски снаружи и внутри делают
    // светлую обводку видимой и на белой схеме, и на пёстрой фотографии.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x66000000), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2.5),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0x4D000000), width: 1),
          ),
        ),
      ),
    );
  }
}

/// Подпись места: номер и сколько человек помещается.
class _TableBadge extends StatelessWidget {
  const _TableBadge({required this.spot});

  final TableSpot spot;

  @override
  Widget build(BuildContext context) {
    final color = tableMarkColor(spot.state);
    final busy = spot.state == TableMarkState.busy;
    final picked = spot.state == TableMarkState.selected;

    final number = spot.number.trim().isEmpty ? '?' : spot.number.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 7, 4),
      decoration: BoxDecoration(
        // Подложка почти непрозрачная: только так мелкий текст читается и
        // на белой схеме, и на тёмной фотографии.
        color: picked
            ? const Color(0xF01B3D29)
            : (busy ? const Color(0xF03B1D22) : const Color(0xF0101822)),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color, width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0x8C000000), blurRadius: 5),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (picked) ...[
            const Icon(Icons.check, size: 12, color: _pickedColor),
            const SizedBox(width: 3),
          ],
          if (busy) ...[
            const Icon(Icons.close, size: 12, color: _busyColor),
            const SizedBox(width: 3),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88),
            child: Text(
              '№ $number',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (spot.seats > 0) ...[
            const SizedBox(width: 5),
            const Icon(Icons.person, size: 11, color: Color(0xFFB9C5D1)),
            Text(
              '${spot.seats}',
              style: const TextStyle(
                color: Color(0xFFB9C5D1),
                fontSize: 11.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (spot.hasStaff) ...[
            const SizedBox(width: 4),
            const Icon(Icons.badge, size: 11, color: Color(0xFF2BD13F)),
          ],
        ],
      ),
    );
  }
}

/// Подсказка под схемой: что значит каждый цвет.
class TableMarkLegend extends StatelessWidget {
  const TableMarkLegend({
    super.key,
    required this.freeText,
    required this.busyText,
  });

  /// Готовые фразы из словаря заведения: «Свободный столик» и «Занят»,
  /// «Свободное кресло» и «Занято». Целиком, а не одно слово: род меняет
  /// всё предложение.
  final String freeText;
  final String busyText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _chip(_freeColor, freeText),
        _chip(_busyColor, busyText),
        _chip(_pickedColor, 'Вы выбрали'),
      ],
    );
  }

  Widget _chip(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1.6),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Color(0xFFA4B1BE), fontSize: 12.5),
          ),
        ],
      );
}
