// ============================================================
// График работы: «Дни и часы» (макет 10.09.2026).
// ============================================================
//
// Третий способ задать период. Отличается от чередования тем, что часы здесь
// СВОИ у каждого дня: в будни с девяти, в субботу с одиннадцати.
//
// Поэтому под каждым днём своя пара «с» и «до». Пока день не отмечен, поля
// приглушены: заполнять часы у выходного не нужно, и разрешать это значит
// собирать вопросы «я заполнил, а он не работает».

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScheduleHoursScreen extends StatefulWidget {
  const ProductStaffScheduleHoursScreen({super.key, required this.schedule});

  final StaffSchedule schedule;

  @override
  State<ProductStaffScheduleHoursScreen> createState() =>
      _ProductStaffScheduleHoursScreenState();
}

class _ProductStaffScheduleHoursScreenState
    extends State<ProductStaffScheduleHoursScreen> {
  late final Map<int, StaffDayHours> _hours = {
    ...widget.schedule.weekdayHours,
  };

  // ── Действия ──────────────────────────────────────────────────────

  void _toggle(int weekday) {
    setState(() {
      if (_hours.containsKey(weekday)) {
        _hours.remove(weekday);

        return;
      }

      // Часы предыдущего отмеченного дня: у большинства продавцов расписание
      // одинаковое, и перещёлкивать одно и то же семь раз незачем.
      final previous = _hours.values.isEmpty ? null : _hours.values.last;

      _hours[weekday] = StaffDayHours(
        weekday: weekday,
        start: previous?.start,
        end: previous?.end,
      );
    });
  }

  Future<void> _pick(int weekday, {required bool isStart}) async {
    if (!_hours.containsKey(weekday)) {
      _say('Сначала отметьте день');

      return;
    }

    final current = _hours[weekday]!;
    final text = (isStart ? current.start : current.end) ??
        (isStart ? '09:00' : '18:00');

    final parts = text.split(':');

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

    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      _hours[weekday] = StaffDayHours(
        weekday: weekday,
        start: isStart ? value : current.start,
        end: isStart ? current.end : value,
      );
    });
  }

  void _confirm() {
    if (_hours.isEmpty) {
      _say('Отметьте хотя бы один день');

      return;
    }

    // Часы, которые человек не тронул, заполняем обычным рабочим днём:
    // отмеченный день без часов на календаре выглядел бы рабочим, а в
    // карточке сотрудника показывал бы пустоту.
    final filled = <int, StaffDayHours>{};

    _hours.forEach((weekday, hours) {
      filled[weekday] = StaffDayHours(
        weekday: weekday,
        start: hours.start ?? '09:00',
        end: hours.end ?? '18:00',
      );
    });

    Navigator.pop(
      context,
      widget.schedule.copyWith(
        mode: StaffScheduleMode.hours,
        weekdayHours: filled,
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
                'Дни и часы',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Отметьте рабочие дни недели и укажите часы для каждого.\n\n'
                'Этот способ подходит, когда часы разные: в будни с девяти, '
                'в субботу с одиннадцати.\n\n'
                'Если часы одинаковые во все дни, проще выбрать «Чередование '
                'рабочих дней».',
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
                  for (var weekday = 1; weekday <= 7; weekday++)
                    _day(weekday),
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
              'Дни и часы',
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

  Widget _day(int weekday) {
    final chosen = _hours.containsKey(weekday);
    final hours = _hours[weekday];

    // Суббота и воскресенье красные, как в календаре и в чередовании.
    final isWeekend = weekday >= 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggle(weekday),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    StaffSchedule.weekdayFull[weekday - 1],
                    style: TextStyle(
                      color: isWeekend ? const Color(0xFFE05A5A) : textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CustomCheckbox(
                  value: chosen,
                  onChanged: (_) => _toggle(weekday),
                ),
              ],
            ),
          ),
        ),
        const Text('Часы работы',
            style: TextStyle(color: textMuted, fontSize: 14)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _field(
                hint: 'С',
                value: hours?.start,
                enabled: chosen,
                onTap: () => _pick(weekday, isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                hint: 'До',
                value: hours?.end,
                enabled: chosen,
                onTap: () => _pick(weekday, isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _field({
    required String hint,
    String? value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
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
      ),
    );
  }
}
