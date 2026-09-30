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
///
/// Месяц на экране один, переключается стрелками (30.09.2026). Раньше все
/// месяцы горизонта шли лентой вниз, экран уезжал на три с лишним тысячи
/// точек, и календарь читался как список. Один месяц со стрелками привычен и
/// занимает ровно столько, сколько нужно.
class BookingNightsPicker extends StatefulWidget {
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
  State<BookingNightsPicker> createState() => _BookingNightsPickerState();
}

class _BookingNightsPickerState extends State<BookingNightsPicker> {
  /// Показанный месяц, первым числом.
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final nights = widget.availability.nights;

    if (nights.isEmpty) return const SizedBox.shrink();

    final months = _months(nights);

    if (months.isEmpty) return const SizedBox.shrink();

    // Открываемся на месяце заезда, если он выбран, иначе на месяце первой
    // СВОБОДНОЙ ночи (30.09.2026). Горизонт часто начинается с конца месяца,
    // и первый экран показывал сентябрь с единственным зачёркнутым числом:
    // человек решал, что свободного нет вовсе.
    final current = _clampToKnown(
      _month ??
          _monthOf(widget.firstNight?.date) ??
          _monthOf(_firstFree(nights)?.date) ??
          months.first,
      months,
    );

    final ofMonth = nights
        .where((n) => n.date.year == current.year && n.date.month == current.month)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _monthRow(current, months),
        const SizedBox(height: 10),
        _weekdayHeader(),
        const SizedBox(height: 6),
        _monthGrid(current, ofMonth),
      ],
    );
  }

  /// Первая свободная ночь горизонта. Нет ни одной — null, и тогда встаём
  /// на первый известный месяц.
  BookingNight? _firstFree(List<BookingNight> nights) {
    for (final night in nights) {
      if (night.isFree) return night;
    }

    return null;
  }

  /// Месяцы, в которых вообще есть ночи: по ним ходят стрелки.
  List<DateTime> _months(List<BookingNight> nights) {
    final seen = <String, DateTime>{};

    for (final night in nights) {
      final key = '${night.date.year}-${night.date.month}';

      seen.putIfAbsent(key, () => DateTime(night.date.year, night.date.month));
    }

    final list = seen.values.toList()..sort((a, b) => a.compareTo(b));

    return list;
  }

  DateTime? _monthOf(DateTime? date) =>
      date == null ? null : DateTime(date.year, date.month);

  /// Если сохранённый месяц оказался вне списка (календарь перечитали, и
  /// горизонт сдвинулся), встаём на ближайший известный.
  DateTime _clampToKnown(DateTime month, List<DateTime> months) {
    for (final known in months) {
      if (known.year == month.year && known.month == month.month) return known;
    }

    return months.first;
  }

  Widget _monthRow(DateTime current, List<DateTime> months) {
    final index = months.indexWhere(
      (m) => m.year == current.year && m.month == current.month,
    );

    final canBack = index > 0;
    final canForward = index >= 0 && index < months.length - 1;

    return Row(
      children: [
        _arrow(
          Icons.chevron_left,
          canBack ? () => setState(() => _month = months[index - 1]) : null,
        ),
        Expanded(
          child: Center(
            child: Text(
              _monthTitle(current),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _arrow(
          Icons.chevron_right,
          canForward ? () => setState(() => _month = months[index + 1]) : null,
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 36,
        child: Icon(
          icon,
          color: onTap == null ? textMuted : activeIconColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _weekdayHeader() {
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

  /// Сетка месяца целиком: числа стоят под своими днями недели, а дни, про
  /// которые сервер ничего не сказал, показываются погашенными. Без них в
  /// начале и конце горизонта месяц выглядел бы дырявым.
  Widget _monthGrid(DateTime month, List<BookingNight> nights) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month).weekday - 1;

    final byDay = <int, BookingNight>{
      for (final night in nights) night.date.day: night,
    };

    final cells = <Widget>[
      ...List.generate(leading, (_) => const SizedBox()),
      for (var day = 1; day <= daysInMonth; day++)
        byDay[day] == null
            ? _emptyCell(day)
            : _cell(byDay[day]!),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      // Свой нулевой отступ: вложенный список иначе забирает себе врезки
      // экрана из окружения и рисует зазор сверху и снизу.
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  /// День вне горизонта брони: виден, но не нажимается.
  Widget _emptyCell(int day) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: const TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }

  Widget _cell(BookingNight night) {
    final isFirst = widget.firstNight?.startsAtRaw == night.startsAtRaw;
    final isLast = widget.lastNight?.startsAtRaw == night.startsAtRaw;
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
      onTap: night.isFree ? () => widget.onNightTap(night) : null,
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
    final from = widget.firstNight;
    final to = widget.lastNight;

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
