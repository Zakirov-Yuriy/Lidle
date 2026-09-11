// ============================================================
// "Экран: График работы" — время работы компании (макет 11.09.2026).
// ============================================================
//
// Открывается со строки «График работы» на экране контактных данных компании.
// Две строки: начало и конец рабочего дня. Нажатие на любую открывает диалог
// с двумя барабанами, часы и минуты.
//
// «Готово» возвращает на экран компании, оттуда время уходит на сервер.
//
// Минуты идут через пять: рабочий день назначают на «девять ровно» или
// «полдесятого», а не на 09:37. Шестьдесят значений в барабане пришлось бы
// пролистывать, и ради чего.
//
// «Без выходных» это не отдельное поле, а все семь дней разом. Отдельный
// признак рядом со списком дней дал бы два источника одной правды, и однажды
// нашлась бы компания «без выходных», работающая по вторникам.

import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

/// Что экран возвращает: рабочие дни, время и признак работы без перерыва.
class WorkScheduleChoice {
  const WorkScheduleChoice({
    this.days = const [],
    this.start,
    this.end,
    this.noBreak = false,
  });

  /// Номера дней недели, 1 — понедельник. Пусто — дни не отмечали.
  final List<int> days;

  final String? start;
  final String? end;
  final bool noBreak;
}

class CompanyWorkScheduleScreen extends StatefulWidget {
  const CompanyWorkScheduleScreen({
    super.key,
    this.days = const [],
    this.start,
    this.end,
    this.noBreak = false,
  });

  final List<int> days;
  final String? start;
  final String? end;
  final bool noBreak;

  @override
  State<CompanyWorkScheduleScreen> createState() =>
      _CompanyWorkScheduleScreenState();
}

class _CompanyWorkScheduleScreenState extends State<CompanyWorkScheduleScreen> {
  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF17212B);
  static const accentColor = Color(0xFF00B7FF);

  /// Названия дней недели по порядку, 1 — понедельник.
  static const List<String> _weekdays = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  late final Set<int> _days = {...widget.days};

  late String? _start = widget.start;
  late String? _end = widget.end;
  late bool _noBreak = widget.noBreak;

  /// «Без выходных» это ровно «отмечены все семь дней».
  bool get _everyDay => _days.length == _weekdays.length;

  void _toggleEveryDay() {
    setState(() {
      if (_everyDay) {
        _days.clear();
      } else {
        _days
          ..clear()
          ..addAll(List.generate(_weekdays.length, (i) => i + 1));
      }
    });
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (_days.contains(weekday)) {
        _days.remove(weekday);
      } else {
        _days.add(weekday);
      }
    });
  }

  Future<void> _pickStart() async {
    final value = await showWorkTimeDialog(
      context,
      title: 'Начало рабочего дня',
      initial: _start,
    );

    if (value == null || !mounted) return;

    setState(() => _start = value);
  }

  Future<void> _pickEnd() async {
    final value = await showWorkTimeDialog(
      context,
      title: 'Конец рабочего дня',
      initial: _end,
    );

    if (value == null || !mounted) return;

    setState(() => _end = value);
  }

  void _done() {
    // Дни отдаём по порядку недели, а не по порядку нажатий: иначе в строке
    // на экране компании они каждый раз стояли бы по-новому.
    final days = (_days.toList()..sort());

    Navigator.pop(
      context,
      WorkScheduleChoice(
        days: days,
        start: _start,
        end: _end,
        noBreak: _noBreak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Стрелка назад и системная кнопка отдают то же самое, что «Готово»:
      // одно и то же действие двумя путями не должно давать разный итог.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 20, right: 23),
                child: Row(children: [Header()]),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _done,
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'График работы',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Выберите рабочие дни и установите время работы',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(25, 0, 25, 4),
                      child: Text(
                        'Рабочие дни',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    _checkRow('Без выходных', _everyDay, _toggleEveryDay),

                    for (var i = 0; i < _weekdays.length; i++)
                      _checkRow(
                        _weekdays[i],
                        _days.contains(i + 1),
                        () => _toggleDay(i + 1),
                      ),

                    const Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 14),
                      child: Divider(color: Colors.white12, height: 1),
                    ),

                    const Padding(
                      padding: EdgeInsets.fromLTRB(25, 0, 25, 12),
                      child: Text(
                        'Время работы',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    _label('Начало рабочего дня'),
                    _row(_start, _pickStart),

                    const SizedBox(height: 14),

                    _label('Конец рабочего дня'),
                    _row(_end, _pickEnd),

                    const SizedBox(height: 6),

                    _checkRow(
                      'Без перерыва',
                      _noBreak,
                      () => setState(() => _noBreak = !_noBreak),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: SizedBox(
                        width: double.infinity,
                        height: 47,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          onPressed: _done,
                          child: const Text(
                            'Готово',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строка с галочкой: подпись слева, квадратик справа.
  ///
  /// Нажатие работает по всей строке, а не только по квадратику: попасть
  /// пальцем в квадрат двадцать на двадцать точек труднее, чем кажется.
  Widget _checkRow(String title, bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            CustomCheckbox(value: value, onChanged: (_) => onTap()),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    );
  }

  Widget _row(String? value, VoidCallback onTap) {
    final filled = value != null && value.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filled ? value : 'Выбрать',
                  style: TextStyle(
                    color: filled ? Colors.white : Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Диалог выбора времени: два барабана, часы и минуты.
///
/// Возвращает «ЧЧ:ММ» или null, если человек передумал.
Future<String?> showWorkTimeDialog(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _WorkTimeDialog(title: title, initial: initial),
  );
}

class _WorkTimeDialog extends StatefulWidget {
  const _WorkTimeDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_WorkTimeDialog> createState() => _WorkTimeDialogState();
}

class _WorkTimeDialogState extends State<_WorkTimeDialog> {
  static const accentColor = Color(0xFF00B7FF);

  /// Минуты через пять: рабочий день назначают на ровные значения.
  static const int _minuteStep = 5;

  late int _hour;
  late int _minute;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();

    // Разбираем «ЧЧ:ММ». Мусор молча не подставляем: непонятное значение
    // лучше показать как девять утра, чем как случайное время.
    final parts = (widget.initial ?? '').split(':');

    _hour = parts.length == 2 ? (int.tryParse(parts[0]) ?? 9) : 9;
    _minute = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (_hour < 0 || _hour > 23) _hour = 9;

    // Округляем к ближайшему шагу вниз: иначе сохранённые раньше 09:37
    // встали бы на барабане между делениями.
    _minute = ((_minute ~/ _minuteStep) * _minuteStep).clamp(0, 55);

    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController =
        FixedExtentScrollController(initialItem: _minute ~/ _minuteStep);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String get _value =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2A38),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Часы и минуты',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 132,
              child: Stack(
                children: [
                  // Рамка выбранного значения. Стоит по центру, потому что
                  // барабан удерживает выбранное именно там. Рисуем её под
                  // барабанами, чтобы она не перехватывала нажатия.
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF4A4133)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _wheel(
                          controller: _hourController,
                          count: 24,
                          label: (index) => index.toString().padLeft(2, '0'),
                          onChanged: (index) =>
                              setState(() => _hour = index),
                        ),
                      ),

                      // Черта между барабанами, как на макете.
                      Container(width: 1, color: const Color(0xFF33404E)),

                      Expanded(
                        child: _wheel(
                          controller: _minuteController,
                          count: 60 ~/ _minuteStep,
                          label: (index) =>
                              (index * _minuteStep).toString().padLeft(2, '0'),
                          onChanged: (index) =>
                              setState(() => _minute = index * _minuteStep),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF33404E), height: 1),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, _value),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: accentColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(color: accentColor, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 44,
      // Барабан крутится только вверх: на макете выбранное значение стоит
      // первой строкой, а под ним следующие.
      offAxisFraction: 0,
      diameterRatio: 100,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => Center(
          child: Text(
            label(index),
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
      ),
    );
  }
}
