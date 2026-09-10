// ============================================================
// График работы сотрудника: календарь (макет 10.09.2026).
// ============================================================
//
// Открывается с карточки сотрудника. Показывает месяцы подряд и отмечает в
// них рабочие дни.
//
// Отмеченные дни считает приложение, а не сервер. Сервер график только
// хранит: правило («по будням», «два через два») живёт рядом с экраном,
// который его показывает, и вторая такая же арифметика на сервере однажды
// разойдётся с первой.
//
// Нажатие на день переводит график в ручной режим. Так честнее, чем молча
// править правило: человек ткнул в 14 декабря, потому что хочет ИМЕННО этот
// день, а не «каждую вторую субботу».

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/pages/products/add_product/product_staff_schedule_setup_screen.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScheduleScreen extends StatefulWidget {
  const ProductStaffScheduleScreen({super.key, this.schedule});

  /// График, который уже задан. Пусто — заводим с нуля.
  final StaffSchedule? schedule;

  @override
  State<ProductStaffScheduleScreen> createState() =>
      _ProductStaffScheduleScreenState();
}

class _ProductStaffScheduleScreenState
    extends State<ProductStaffScheduleScreen> {
  /// Сколько месяцев показываем вперёд. Год: дальше продавец сотрудника не
  /// планирует, а бесконечный список нечем закончить.
  static const int _monthsAhead = 12;

  late StaffSchedule _schedule = widget.schedule ?? const StaffSchedule();

  /// Свёрнутые месяцы. По умолчанию открыты все: человек пришёл смотреть
  /// календарь, а не искать, где его развернуть.
  final Set<String> _collapsed = {};

  late final DateTime _first = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  List<DateTime> get _months => List.generate(
        _monthsAhead,
        (index) => DateTime(_first.year, _first.month + index),
      );

  // ── Действия ──────────────────────────────────────────────────────

  /// Отметить или снять день.
  ///
  /// Правило при этом «раскрывается» в список дней: то, что было посчитано,
  /// становится тем, что выбрано. Иначе следующее открытие экрана пересчитало
  /// бы всё заново и стёрло правку.
  void _toggleDay(DateTime day) {
    final key = dayKey(day);

    final days = _schedule.mode == StaffScheduleMode.days
        ? [..._schedule.days]
        : _materialise();

    days.contains(key) ? days.remove(key) : days.add(key);

    setState(() {
      _schedule = _schedule.copyWith(
        mode: StaffScheduleMode.days,
        days: days..sort(),
      );
    });
  }

  /// Рабочие дни по правилу, посчитанные на весь показанный период.
  List<String> _materialise() {
    final days = <String>[];

    for (final month in _months) {
      final total = DateUtils.getDaysInMonth(month.year, month.month);

      for (var number = 1; number <= total; number++) {
        final day = DateTime(month.year, month.month, number);

        if (_schedule.isWorkingDay(day)) days.add(dayKey(day));
      }
    }

    return days;
  }

  Future<void> _openSetup() async {
    final changed = await Navigator.push<StaffSchedule>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScheduleSetupScreen(schedule: _schedule),
      ),
    );

    if (changed != null && mounted) setState(() => _schedule = changed);
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
                'Отмечайте рабочие дни прямо в календаре, нажимая на числа.\n\n'
                'Если график повторяется, нажмите «Настроить»: можно задать '
                'дни недели или чередование, например два через два, и дни '
                'отметятся сами.\n\n'
                'Там же задаётся рабочее время и перерыв. Оно одно на весь '
                'график.',
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
            const SizedBox(height: 4),
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
                  for (var index = 0; index < _months.length; index++) ...[
                    _month(_months[index]),

                    // «Настроить» стоит после первого месяца, как на макете:
                    // правило одно на весь график, и повторять кнопку у
                    // каждого месяца значило бы обещать помесячные настройки.
                    if (index == 0) ...[
                      const SizedBox(height: 16),
                      _setupButton(),
                    ],

                    const SizedBox(height: 20),
                  ],
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
              'График работы сотрудника',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // «Отмена» уходит без сохранения: возвращаем пусто, и карточка
          // оставляет тот график, который был.
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

  Widget _setupButton() {
    return GestureDetector(
      onTap: _openSetup,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: activeIconColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Настроить',
                style: TextStyle(color: activeIconColor, fontSize: 15)),
            SizedBox(width: 6),
            Icon(Icons.chevron_right, color: activeIconColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _month(DateTime month) {
    final key = '${month.year}-${month.month}';
    final isOpen = !_collapsed.contains(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _monthName(month.month),
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                isOpen ? _collapsed.add(key) : _collapsed.remove(key);
              }),
              child: Icon(
                isOpen ? Icons.unfold_less : Icons.unfold_more,
                color: textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isOpen) ...[
          _weekdayRow(),
          const SizedBox(height: 6),
          _grid(month),
        ],
      ],
    );
  }

  Widget _weekdayRow() {
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Row(
      children: [
        for (var index = 0; index < names.length; index++)
          Expanded(
            child: Container(
              height: 34,
              margin: const EdgeInsets.all(2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                names[index],
                style: TextStyle(
                  color: index >= 5 ? const Color(0xFFE05A5A) : textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(DateTime month) {
    final total = DateUtils.getDaysInMonth(month.year, month.month);

    // Сколько пустых клеток до первого числа: понедельник первый.
    final offset = DateTime(month.year, month.month, 1).weekday - 1;

    final cells = <Widget>[
      for (var index = 0; index < offset; index++) const Expanded(child: SizedBox()),
    ];

    final rows = <Widget>[];

    void flush() {
      while (cells.length < 7) {
        cells.add(const Expanded(child: SizedBox()));
      }

      rows.add(Row(children: List<Widget>.from(cells)));
      cells.clear();
    }

    for (var number = 1; number <= total; number++) {
      final day = DateTime(month.year, month.month, number);

      cells.add(Expanded(child: _dayCell(day)));

      if (cells.length == 7) flush();
    }

    if (cells.isNotEmpty) flush();

    return Column(children: rows);
  }

  Widget _dayCell(DateTime day) {
    final selected = _schedule.isWorkingDay(day);

    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: Container(
        height: 42,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? activeIconColor : formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: selected ? Colors.white : textPrimary,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];

    return names[(month - 1) % 12];
  }
}
