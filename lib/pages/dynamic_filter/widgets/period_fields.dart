// ============================================================
//  Поля «с — до» для времени и дат (22.09.2026)
// ============================================================
//
// «Время работы зала: с 18:00 до 04:00» (стиль T) и «Выберите дату работы:
// С › До ›» на экране зала. Две плашки рядом, нажатие открывает системный
// выбор времени или даты.
//
// Время «до» может быть меньше «с»: заведение работает за полночь, это не
// ошибка.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/pages/dynamic_filter/widgets/required_label.dart';

class _PeriodBox extends StatelessWidget {
  const _PeriodBox({
    required this.prefix,
    required this.value,
    required this.onTap,
    this.chevron = false,
  });

  final String prefix;
  final String? value;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              prefix,
              style: TextStyle(
                color: textSecondary,
                fontSize: value == null ? 14 : 12,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value!,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            if (chevron)
              const Icon(Icons.chevron_right, color: textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

/// «18:00» ↔ TimeOfDay.
String formatTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

TimeOfDay? parseTime(String? s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s ?? '');
  if (m == null) return null;
  return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
}

/// «2026-09-22 …» ↔ DateTime, и показ «22.09.2026».
DateTime? parseDate(String? s) =>
    s == null || s.length < 10 ? null : DateTime.tryParse(s.substring(0, 10));

String showDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String serverDate(DateTime d, {bool end = false}) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${end ? '23:59' : '00:00'}';

/// Стиль T: «с 18:00» / «до 04:00».
class TimeRangeField extends StatelessWidget {
  const TimeRangeField({
    super.key,
    required this.attribute,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final Attribute attribute;
  final String? from;
  final String? to;
  final void Function(String? from, String? to) onChanged;

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final initial = parseTime(isFrom ? from : to) ??
        (isFrom ? const TimeOfDay(hour: 10, minute: 0) : const TimeOfDay(hour: 22, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null) return;

    isFrom ? onChanged(formatTime(picked), to) : onChanged(from, formatTime(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RequiredLabel(label: attribute.title, isRequired: attribute.isRequired),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _PeriodBox(prefix: 'с', value: from, onTap: () => _pick(context, true)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PeriodBox(prefix: 'до', value: to, onTap: () => _pick(context, false)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Даты «С › До ›» (стили J и K на экране блока).
class DateRangeBoxesField extends StatelessWidget {
  const DateRangeBoxesField({
    super.key,
    required this.attribute,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final Attribute attribute;
  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final now = DateTime.now();
    final first = isFrom ? DateTime(now.year - 1) : (from ?? DateTime(now.year - 1));
    final initial = (isFrom ? from : to) ?? (isFrom ? now : (from ?? now));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ru'),
    );

    if (picked == null) return;

    if (isFrom) {
      // Конец раньше начала сбрасываем: интервал наоборот сервер не примет.
      onChanged(picked, to != null && to!.isBefore(picked) ? null : to);
    } else {
      onChanged(from, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RequiredLabel(label: attribute.title, isRequired: attribute.isRequired),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _PeriodBox(
                prefix: from == null ? 'С' : 'с',
                value: from == null ? null : showDate(from!),
                chevron: true,
                onTap: () => _pick(context, true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PeriodBox(
                prefix: to == null ? 'До' : 'до',
                value: to == null ? null : showDate(to!),
                chevron: true,
                onTap: () => _pick(context, false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
