import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';

/// Выбор ночей для посуточного жилья.
///
/// Почему календарь сеткой, а не полоса дней как у услуг. У записи к мастеру
/// человек выбирает одну точку во времени, и полосы хватает. У жилья он
/// выбирает промежуток, и ему нужно видеть месяц целиком: где выходные, где
/// занятые дни, влезет ли поездка между двумя чужими бронями. Полосой это не
/// показать.
///
/// Единица здесь — НОЧЬ, а не день. «С 5 по 12 сентября» это семь ночей:
/// заезд пятого, выезд двенадцатого. Поэтому подсвечиваем ночи с 5 по 11
/// включительно, а 12 показываем как день выезда.
class BookingNightsPicker extends StatelessWidget {
  final BookingAvailability availability;

  /// Первая выбранная ночь (заезд) и последняя (ночь перед выездом).
  final BookingNight? firstNight;
  final BookingNight? lastNight;

  final void Function(BookingNight night) onNightTap;

  const BookingNightsPicker({
    super.key,
    required this.availability,
    required this.firstNight,
    required this.lastNight,
    required this.onNightTap,
  });

  @override
  Widget build(BuildContext context) {
    final nights = availability.nights;
    if (nights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeekdayHeader(),
        const SizedBox(height: 6),
        ..._buildMonths(nights),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

    return Row(
      children: names
          .map((name) => Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Разбиваем ночи по месяцам: без заголовка месяца сетка из тридцати с
  /// лишним чисел читается как загадка.
  List<Widget> _buildMonths(List<BookingNight> nights) {
    final byMonth = <String, List<BookingNight>>{};

    for (final night in nights) {
      final key = '${night.date.year}-${night.date.month}';
      byMonth.putIfAbsent(key, () => []).add(night);
    }

    final widgets = <Widget>[];

    byMonth.forEach((_, monthNights) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          _monthTitle(monthNights.first.date),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));

      widgets.add(_buildMonthGrid(monthNights));
    });

    return widgets;
  }

  Widget _buildMonthGrid(List<BookingNight> monthNights) {
    final first = monthNights.first.date;

    // Пустые клетки до первого числа, чтобы числа встали под своими днями
    // недели. Без этого календарь врёт: человек ищет субботу и находит среду.
    final leading = first.weekday - 1;

    final cells = <Widget>[
      ...List.generate(leading, (_) => const SizedBox()),
      ...monthNights.map(_buildCell),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Widget _buildCell(BookingNight night) {
    final isFirst = firstNight?.startsAtRaw == night.startsAtRaw;
    final isLast = lastNight?.startsAtRaw == night.startsAtRaw;
    final inRange = _isInRange(night);

    final Color background;
    final Color textColor;

    if (isFirst || isLast) {
      background = activeIconColor;
      textColor = Colors.white;
    } else if (inRange) {
      background = activeIconColor.withValues(alpha: 0.28);
      textColor = Colors.white;
    } else if (night.isFree) {
      background = secondaryBackground;
      textColor = Colors.white;
    } else {
      background = primaryBackground;
      textColor = textMuted;
    }

    return GestureDetector(
      onTap: night.isFree ? () => onNightTap(night) : null,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          '${night.date.day}',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: (isFirst || isLast) ? FontWeight.w700 : FontWeight.w500,
            // Занятые ночи зачёркиваем, а не прячем: видно, что жильё вообще
            // сдаётся, просто эти даты разобрали.
            decoration:
                night.isFree ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }

  bool _isInRange(BookingNight night) {
    final from = firstNight;
    final to = lastNight;

    if (from == null || to == null) return false;

    return !night.date.isBefore(from.date) && !night.date.isAfter(to.date);
  }

  String _monthTitle(DateTime date) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.year}';
  }
}
