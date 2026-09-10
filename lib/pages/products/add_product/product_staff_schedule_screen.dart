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

/// Отрезок дат: с какого по какое.
class DayRange {
  const DayRange(this.from, this.to);

  final DateTime from;
  final DateTime to;
}

class ProductStaffScheduleScreen extends StatefulWidget {
  const ProductStaffScheduleScreen({super.key, this.schedule})
      : pickRange = false,
        rangeFrom = null,
        rangeTo = null;

  /// Тот же календарь, но для выбора отрезка дат.
  ///
  /// Отдельным экраном его делать не стали: человек видит ровно ту же сетку
  /// месяцев, и два разных календаря в одном графике он воспримет как
  /// недоделку. Возвращает [DayRange].
  const ProductStaffScheduleScreen.range({
    super.key,
    DateTime? from,
    DateTime? to,
  })  : schedule = null,
        pickRange = true,
        rangeFrom = from,
        rangeTo = to;

  /// График, который уже задан. Пусто — заводим с нуля.
  final StaffSchedule? schedule;

  /// Выбираем отрезок дат, а не рабочие дни.
  final bool pickRange;

  final DateTime? rangeFrom;
  final DateTime? rangeTo;

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

  /// Края выбираемого отрезка. Работают только в режиме выбора дат.
  late DateTime? _from = widget.rangeFrom;
  late DateTime? _to = widget.rangeTo;

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
    if (widget.pickRange) {
      _pickEdge(day);

      return;
    }

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

  /// Первое нажатие ставит начало, второе конец.
  ///
  /// Нажатие раньше начала начинает выбор заново, а не двигает край:
  /// «хочу с другого числа» встречается чаще, чем «ошибся концом», и
  /// объяснять человеку разницу нечем.
  void _pickEdge(DateTime day) {
    setState(() {
      final start = _from;

      if (start == null || _to != null || day.isBefore(start)) {
        _from = day;
        _to = null;

        return;
      }

      _to = day;
    });
  }

  bool _inRange(DateTime day) {
    final start = _from;

    if (start == null) return false;

    final end = _to ?? start;

    return !day.isBefore(start) && !day.isAfter(end);
  }

  bool _isEdge(DateTime day) =>
      (_from != null && DateUtils.isSameDay(_from, day)) ||
      (_to != null && DateUtils.isSameDay(_to, day));

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
                    // При выборе дат её нет: настраивать отсюда нечего.
                    if (index == 0 && !widget.pickRange) ...[
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
              child: widget.pickRange ? _confirmButton() : _saveButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// «Сохранить» на своём графике: возвращаем весь график.
  Widget _saveButton() {
    return GestureDetector(
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
    );
  }

  /// «Подтвердить» при выборе дат: возвращаем отрезок.
  ///
  /// Пока начало не выбрано, кнопка приглушена: возвращать пустой отрезок
  /// значит показать на прошлом экране «с — до —» и заставить человека гадать,
  /// что пошло не так.
  Widget _confirmButton() {
    final start = _from;
    final ready = start != null;

    return GestureDetector(
      onTap: ready
          ? () => Navigator.pop(context, DayRange(start, _to ?? start))
          : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: ready ? activeIconColor : textMuted),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Подтвердить',
          style: TextStyle(
            color: ready ? activeIconColor : textMuted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
    final selected =
        widget.pickRange ? _inRange(day) : _schedule.isWorkingDay(day);

    final edge = widget.pickRange && _isEdge(day);

    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: Container(
        height: 42,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // В режиме выбора дат заливка приглушённая: отрезок это «с и по»,
          // а не список рабочих дней, и красить его тем же ярким синим
          // значит путать два разных смысла на одной сетке.
          color: selected
              ? (widget.pickRange
                  ? const Color(0xFF14384D)
                  : activeIconColor)
              : formBackground,
          borderRadius: BorderRadius.circular(6),
          border: edge ? Border.all(color: activeIconColor) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: selected && !widget.pickRange
                    ? Colors.white
                    : textPrimary,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),

            // Кружок с галочкой на краях отрезка: он показывает, откуда и
            // докуда, а не просто «этот день внутри».
            if (edge)
              const Positioned(
                top: 2,
                left: 4,
                child: Icon(Icons.check_circle,
                    color: activeIconColor, size: 13),
              ),
          ],
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
