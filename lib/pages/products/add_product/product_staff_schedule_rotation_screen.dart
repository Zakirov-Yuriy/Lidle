// ============================================================
// График работы: «Чередование рабочих дней» (макет 10.09.2026).
// ============================================================
//
// Открывается карточкой на экране настройки периода. Здесь три вещи:
//
//  - какие дни недели рабочие (галочки, их бывает несколько);
//  - в какой период это действует (даты выбираются в календаре);
//  - в какие часы.
//
// Даты выбираются тем же календарём, что и весь график: человек видит
// привычную сетку месяцев, а не второй, незнакомый ему календарь.
//
// «Подтвердить» возвращает настройку экрану периода, и уже он показывает её
// в карточке. Ничего на сервер отсюда не уходит.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/pages/products/add_product/product_staff_schedule_screen.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScheduleRotationScreen extends StatefulWidget {
  const ProductStaffScheduleRotationScreen({super.key, required this.schedule});

  final StaffSchedule schedule;

  @override
  State<ProductStaffScheduleRotationScreen> createState() =>
      _ProductStaffScheduleRotationScreenState();
}

class _ProductStaffScheduleRotationScreenState
    extends State<ProductStaffScheduleRotationScreen> {
  late final List<int> _weekdays = [...widget.schedule.weekdays];

  late DateTime? _from = widget.schedule.rotationFrom;
  late DateTime? _to = widget.schedule.rotationTo;

  late String? _start = widget.schedule.time.start;
  late String? _end = widget.schedule.time.end;

  // ── Действия ──────────────────────────────────────────────────────

  void _toggle(int weekday) {
    setState(() {
      _weekdays.contains(weekday)
          ? _weekdays.remove(weekday)
          : _weekdays.add(weekday);

      _weekdays.sort();
    });
  }

  /// Выбрать период в календаре.
  ///
  /// Оба поля, «С» и «До», ведут в один и тот же календарь: отрезок выбирают
  /// целиком, двумя нажатиями, и открывать ради каждого края свой экран
  /// значит заставить человека ходить туда дважды.
  Future<void> _pickDates() async {
    final range = await Navigator.push<DayRange>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScheduleScreen.range(
          from: _from,
          to: _to,
        ),
      ),
    );

    if (range == null || !mounted) return;

    setState(() {
      _from = range.from;
      _to = range.to;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = (isStart ? _start : _end) ?? (isStart ? '09:00' : '18:00');
    final parts = current.split(':');

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: activeIconColor,
            surface: secondaryBackground,
          ),
        ),
        child: child ?? const SizedBox(),
      ),
    );

    if (picked == null || !mounted) return;

    final text = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() => isStart ? _start = text : _end = text);
  }

  void _confirm() {
    final from = _from;

    if (_weekdays.isEmpty) {
      _say('Отметьте хотя бы один день недели');

      return;
    }

    if (from == null) {
      _say('Выберите период работы в календаре');

      return;
    }

    final time = widget.schedule.time.copyWith(
      start: _start ?? '09:00',
      end: _end ?? '18:00',
    );

    Navigator.pop(
      context,
      widget.schedule.copyWith(
        mode: StaffScheduleMode.rotation,
        weekdays: _weekdays,
        rotationFrom: from,
        rotationTo: _to ?? from,
        time: time,
      ),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: secondaryBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Чередование рабочих дней',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Отметьте дни недели, в которые сотрудник работает, и период, '
                'в котором это действует.\n\n'
                'Например: понедельник, вторник и четверг с 13 декабря по '
                '4 января. В календаре отметятся все такие дни внутри этого '
                'периода.\n\n'
                'Время работы одно на все отмеченные дни.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(color: activeIconColor, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Вёрстка ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            const SizedBox(height: 8),
            _titleRow(),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _explain,
                  child: const Text(
                    'Как это работает?',
                    style: TextStyle(color: activeIconColor, fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  12,
                  defaultPadding,
                  16,
                ),
                children: [
                  for (var index = 0; index < 7; index++) _weekdayRow(index + 1),

                  const SizedBox(height: 16),
                  const Text('Выберите даты работы',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          hint: 'С',
                          value: _from == null ? null : dayLabel(_from!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(
                          hint: 'До',
                          value: _to == null ? null : dayLabel(_to!),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text('Введите время работы',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _timeField(
                          hint: 'С',
                          value: _start,
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _timeField(
                          hint: 'До',
                          value: _end,
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                16,
              ),
              child: GestureDetector(
                onTap: _confirm,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeIconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Подтвердить',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.chevron_left, color: textPrimary, size: 26),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Чередование рабочих дней',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekdayRow(int weekday) {
    // Суббота и воскресенье красные, как в календаре: человек ищет их
    // глазами по цвету, и в двух списках он должен быть одинаковым.
    final isWeekend = weekday >= 6;

    return GestureDetector(
      onTap: () => _toggle(weekday),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                StaffSchedule.weekdayFull[weekday - 1],
                style: TextStyle(
                  color: isWeekend ? const Color(0xFFE05A5A) : textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            CustomCheckbox(
              value: _weekdays.contains(weekday),
              onChanged: (_) => _toggle(weekday),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({required String hint, String? value}) {
    return GestureDetector(
      onTap: _pickDates,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null ? textMuted : textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _timeField({
    required String hint,
    String? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value ?? hint,
          style: TextStyle(
            color: value == null ? textMuted : textPrimary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
