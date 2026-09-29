// ============================================================
//  Календарь брони (29.09.2026)
// ============================================================
//
// Системный showDatePicker выглядел чужим: светлые кнопки, свои шрифты, своя
// разметка недели. Здесь календарь по макету заказчика — тёмное окно, месяцы
// стрелками, выходные красным, сегодня серым кружком, выбранный день синим,
// «Подтвердить» внизу.
//
// Неделя начинается с понедельника: в приложении всё русское, и неделя с
// воскресенья читалась бы как чужая.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

const List<String> _monthNames = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

const List<String> _weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Красный выходного: он же у цифр субботы и воскресенья.
const Color _weekend = Color(0xFFFF4D4D);

/// Серый кружок сегодняшнего дня.
const Color _today = Color(0xFF4A5764);

/// Показать календарь и вернуть выбранную дату. null — закрыли без выбора.
Future<DateTime?> showBookingDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Выберите дату',
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _BookingCalendarDialog(
      initial: initial,
      first: first,
      last: last,
      title: title,
    ),
  );
}

class _BookingCalendarDialog extends StatefulWidget {
  const _BookingCalendarDialog({
    required this.initial,
    required this.first,
    required this.last,
    required this.title,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_BookingCalendarDialog> createState() => _BookingCalendarDialogState();
}

class _BookingCalendarDialogState extends State<_BookingCalendarDialog> {
  late DateTime _picked = _day(widget.initial);
  late DateTime _month = DateTime(_picked.year, _picked.month);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: formBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const SizedBox(height: 10),
            _monthRow(),
            const SizedBox(height: 14),
            _weekdays(),
            const SizedBox(height: 6),
            _grid(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: activeIconColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(_picked),
                child: const Text(
                  'Подтвердить',
                  style: TextStyle(color: activeIconColor, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const SizedBox(width: 28),
        Expanded(
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, color: textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  /// «‹ Март   Апрель   Май ›»: соседние месяцы названы, чтобы стрелка не
  /// была загадкой.
  Widget _monthRow() {
    final previous = DateTime(_month.year, _month.month - 1);
    final next = DateTime(_month.year, _month.month + 1);

    final canBack = !_monthOf(previous).isBefore(_monthOf(widget.first));
    final canForward = !_monthOf(next).isAfter(_monthOf(widget.last));

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canBack ? () => setState(() => _month = previous) : null,
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 13,
                  color: canBack ? textPrimary : textMuted,
                ),
                Text(
                  _monthNames[previous.month - 1],
                  style: TextStyle(
                    color: canBack ? textPrimary : textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          _monthNames[_month.month - 1],
          style: const TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canForward ? () => setState(() => _month = next) : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _monthNames[next.month - 1],
                  style: TextStyle(
                    color: canForward ? textPrimary : textMuted,
                    fontSize: 14,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: canForward ? textPrimary : textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekdays() {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Text(
              _weekdayNames[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                // Воскресенье красным, как на макете: выходной виден до того,
                // как человек начнёт считать по столбцам.
                color: i == 6 ? _weekend : textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid() {
    final firstOfMonth = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    // Понедельник первый: weekday у Dart 1 = понедельник, 7 = воскресенье.
    final lead = firstOfMonth.weekday - 1;
    final cells = <Widget>[];

    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(_cell(DateTime(_month.year, _month.month, day)));
    }

    // Добиваем последнюю неделю, чтобы сетка не прыгала по высоте.
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final weeks = cells.length ~/ 7;

    return Column(
      children: [
        for (var row = 0; row < weeks; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: cells[row * 7 + column]),
            ],
          ),
      ],
    );
  }

  Widget _cell(DateTime date) {
    final available = !date.isBefore(_day(widget.first)) && !date.isAfter(_day(widget.last));
    final isPicked = date == _picked;
    final isToday = date == _day(DateTime.now());
    final isWeekend = date.weekday >= 6;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: available ? () => setState(() => _picked = date) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Выбранный день синим, сегодняшний серым: серый говорит «вы
              // здесь», синий — «это вы выбрали».
              color: isPicked
                  ? activeIconColor
                  : (isToday ? _today : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: !available
                    ? textMuted
                    : isPicked
                        ? Colors.white
                        : (isWeekend && !isToday ? _weekend : textPrimary),
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  static DateTime _monthOf(DateTime value) => DateTime(value.year, value.month);
}
