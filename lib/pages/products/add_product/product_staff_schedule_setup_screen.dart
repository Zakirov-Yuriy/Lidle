// ============================================================
// График работы: настройка периода (макет 10.09.2026).
// ============================================================
//
// Открывается кнопкой «Настроить» с календаря. Три способа задать период, по
// карточке на каждый:
//
//  - «По неделям» — готовый набор: все дни, будни, чётные, нечётные;
//  - «Чередование рабочих дней» — столько-то рабочих, столько-то выходных;
//  - «Дни и часы» — дни отмечаются руками, там же часы и перерыв.
//
// Настроенная карточка раскрывается и показывает, что именно выбрано, с
// «Очистить» и «Изменить». Прятать выбор за нажатием нельзя: человек должен
// видеть свой график, не проваливаясь в него.
//
// Экран ничего не сохраняет на сервер: он возвращает график календарю, а тот
// уходит на сервер уже вместе с карточкой сотрудника. Иначе «Отмена» на
// карточке оставляла бы сохранённый график от несохранённого сотрудника.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/pages/products/add_product/product_staff_schedule_hours_screen.dart';
import 'package:lidle/pages/products/add_product/product_staff_schedule_rotation_screen.dart';
import 'package:lidle/pages/products/add_product/product_staff_schedule_weeks_screen.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScheduleSetupScreen extends StatefulWidget {
  const ProductStaffScheduleSetupScreen({super.key, required this.schedule});

  final StaffSchedule schedule;

  @override
  State<ProductStaffScheduleSetupScreen> createState() =>
      _ProductStaffScheduleSetupScreenState();
}

class _ProductStaffScheduleSetupScreenState
    extends State<ProductStaffScheduleSetupScreen> {
  late StaffSchedule _schedule = widget.schedule;

  // ── Действия ──────────────────────────────────────────────────────

  Future<void> _openWeeks() async {
    final preset = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScheduleWeeksScreen(
          preset: _schedule.weeksPreset,
        ),
      ),
    );

    if (preset == null || !mounted) return;

    setState(() {
      _schedule = _schedule.copyWith(
        mode: StaffScheduleMode.weeks,
        weeksPreset: preset,
      );
    });
  }

  /// Убрать настройку «По неделям».
  ///
  /// Отмеченные руками дни при этом остаются: человек их заводил отдельно, и
  /// уносить их вместе с правилом значит удалить не то, что просили.
  void _clearWeeks() {
    setState(() {
      _schedule = _schedule.copyWith(
        mode: StaffScheduleMode.days,
        clearWeeksPreset: true,
      );
    });
  }

  Future<void> _openRotation() async {
    final changed = await Navigator.push<StaffSchedule>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScheduleRotationScreen(
          schedule: _schedule,
        ),
      ),
    );

    if (changed != null && mounted) setState(() => _schedule = changed);
  }

  /// Убрать чередование: дни недели и период. Отмеченные руками дни остаются.
  void _clearRotation() {
    setState(() {
      _schedule = _schedule.copyWith(
        mode: StaffScheduleMode.days,
        weekdays: const [],
        clearRotationDates: true,
      );
    });
  }

  Future<void> _openHours() async {
    final changed = await Navigator.push<StaffSchedule>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScheduleHoursScreen(schedule: _schedule),
      ),
    );

    if (changed != null && mounted) setState(() => _schedule = changed);
  }

  /// Убрать «Дни и часы».
  void _clearHours() {
    setState(() {
      _schedule = _schedule.copyWith(
        mode: StaffScheduleMode.days,
        weekdayHours: const {},
      );
    });
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
                'Как это работает',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Выберите, как повторяется работа сотрудника, и дни отметятся '
                'в календаре сами.\n\n'
                'По неделям — все дни, только будни или по чётным и нечётным '
                'числам.\n\n'
                'Чередование — например два через два.\n\n'
                'Дни и часы — если расписания нет и дни проще отметить '
                'руками.',
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

  /// Что показывать в карточке чередования.
  ///
  /// Пусто, пока не выбраны и дни недели, и период: половина настройки в
  /// карточке выглядит как готовая, а рабочих дней от неё не появится.
  List<MapEntry<String, String>> get _rotationSummary {
    if (_schedule.mode != StaffScheduleMode.rotation) return const [];

    final from = _schedule.rotationFrom;
    final to = _schedule.rotationTo;

    if (from == null || _schedule.weekdays.isEmpty) return const [];

    final days = _schedule.weekdays
        .map((day) => StaffSchedule.weekdayShort[day - 1])
        .join(', ');

    final time = _schedule.time;

    return [
      MapEntry('Рабочие дни недели:', days),
      MapEntry(
        'Рабочие даты:',
        'с ${dayLabel(from)} - до ${dayLabel(to ?? from)}',
      ),
      MapEntry('Рабочие часы:', 'с ${time.start} - до ${time.end}'),
    ];
  }

  /// Что показывать в карточке «Дни и часы»: строка на каждый рабочий день.
  List<MapEntry<String, String>> get _hoursSummary {
    if (_schedule.mode != StaffScheduleMode.hours) return const [];

    final hours = _schedule.weekdayHours;

    if (hours.isEmpty) return const [];

    final weekdays = hours.keys.toList()..sort();

    return [
      for (final weekday in weekdays)
        MapEntry(
          '${StaffSchedule.weekdayShort[weekday - 1]}:',
          'с ${hours[weekday]?.start ?? '—'} - до ${hours[weekday]?.end ?? '—'}',
        ),
    ];
  }

  // ── Вёрстка ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final weeksSet = _schedule.mode == StaffScheduleMode.weeks &&
        _schedule.weeksPreset != null;

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
                  16,
                  defaultPadding,
                  16,
                ),
                children: [
                  _card(
                    icon: '📅',
                    title: 'По неделям',
                    hint: 'Тут вы можете настроить рабочие недели',
                    onTap: _openWeeks,
                    summary: weeksSet
                        ? [
                            MapEntry(
                              'Рабочие недели:',
                              StaffSchedule.weeksPresetTitle(
                                  _schedule.weeksPreset),
                            ),
                          ]
                        : const [],
                    onClear: _clearWeeks,
                    onChange: _openWeeks,
                  ),
                  const SizedBox(height: 14),
                  _card(
                    icon: '🗓',
                    title: 'Чередование рабочих дней',
                    hint: 'Тут вы можете настроить рабочие дни',
                    onTap: _openRotation,
                    summary: _rotationSummary,
                    onClear: _clearRotation,
                    onChange: _openRotation,
                  ),
                  const SizedBox(height: 14),
                  _card(
                    icon: '⏱',
                    title: 'Дни и часы',
                    hint: 'Тут вы можете настроить рабочие дни и часы',
                    onTap: _openHours,
                    summary: _hoursSummary,
                    onClear: _clearHours,
                    onChange: _openHours,
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
                onTap: () => Navigator.pop(context, _schedule),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeIconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Сохранить',
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
              'Настройка периода работы',
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

  /// Карточка способа. Настроенная раскрывается и показывает выбор.
  Widget _card({
    required String icon,
    required String title,
    required String hint,
    required VoidCallback onTap,
    List<MapEntry<String, String>> summary = const [],
    VoidCallback? onClear,
    VoidCallback? onChange,
  }) {
    final showsSummary = summary.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hint,
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showsSummary) ...[
            const Divider(color: Color(0xFF2A3744), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in summary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${line.key} ',
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: line.value,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onClear,
                        child: const Text(
                          'Очистить',
                          style: TextStyle(
                            color: Color(0xFFE05A5A),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onChange,
                        child: const Text(
                          'Изменить',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
