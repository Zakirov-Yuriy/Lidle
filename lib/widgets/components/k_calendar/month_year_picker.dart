import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';

/// Диалог для выбора дня, месяца и года (Style K)
class KCustomMonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? otherDate;
  final bool isSelectingDateTo;
  final String title;
  final String subtitle;
  final String fromTime;
  final String toTime;

  const KCustomMonthYearPicker({
    required this.initialDate,
    this.otherDate,
    this.isSelectingDateTo = false,
    this.title = 'Выберите время и дату',
    this.subtitle = 'Дата и время вашей аренды',
    this.fromTime = '00:00',
    this.toTime = '00:00',
  });

  @override
  State<KCustomMonthYearPicker> createState() => _KCustomMonthYearPickerState();
}

class _KCustomMonthYearPickerState extends State<KCustomMonthYearPicker> {
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;
  late DateTime _selectedDate;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  static const List<String> _monthsRu = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedDay = widget.initialDate.day;
    _selectedMonth = widget.initialDate.month - 1;
    _selectedYear = widget.initialDate.year;

    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth);
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - 2020,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  /// Получить количество дней в месяце
  int _getDaysInMonth(int month, int year) {
    if (month == 2) {
      return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    }
    return [31, 31, 30, 31, 30, 31, 31, 31, 30, 31, 30, 31][month - 1];
  }

  /// Форматировать дату в формат "Пн, 20 апреля"
  String _formatDate(DateTime date) {
    final formatted = DateFormat('EEE, d MMMM', 'ru_RU').format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  void _confirm() {
    _selectedDate = DateTime(_selectedYear, _selectedMonth + 1, _selectedDay);
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_selectedMonth + 1, _selectedYear);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF222E3A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Закрыть кнопку X
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(height: 16),

            // Заголовок
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // Подтекст
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Табло с датами "От" и "До"
            Row(
              children: [
                Expanded(
                  child: _TimeDisplayColumn(
                    label: 'От',
                    date: widget.isSelectingDateTo
                        ? (widget.otherDate != null
                              ? _formatDate(widget.otherDate!)
                              : 'Выбрать дату')
                        : _formatDate(_selectedDate),
                    time: widget.fromTime,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _TimeDisplayColumn(
                    label: 'До',
                    date: widget.isSelectingDateTo
                        ? _formatDate(_selectedDate)
                        : (widget.otherDate != null
                              ? _formatDate(widget.otherDate!)
                              : 'Выбрать дату'),
                    time: widget.toTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Отображение выбранного месяца и года
            Text(
              '${_monthsRu[_selectedMonth]} $_selectedYear г.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Селектор дня, месяца, года
            SizedBox(
              height: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // День
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ListWheelScrollView(
                          controller: _dayController,
                          itemExtent: 40,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedDay = index + 1;
                              _selectedDate = DateTime(
                                _selectedYear,
                                _selectedMonth + 1,
                                _selectedDay,
                              );
                            });
                          },
                          physics: const FixedExtentScrollPhysics(),
                          children: List<Widget>.generate(
                            daysInMonth,
                            (index) => Center(
                              child: Text(
                                (index + 1).toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color: index + 1 == _selectedDay
                                      ? Colors.white
                                      : textSecondary,
                                  fontSize: 18,
                                  fontWeight: index + 1 == _selectedDay
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Полоски
                        Positioned(
                          top: 45,
                          child: SizedBox(
                            width: 50,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: textSecondary,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: textSecondary,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Месяц
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ListWheelScrollView(
                          controller: _monthController,
                          itemExtent: 40,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedMonth = index;
                              _selectedDate = DateTime(
                                _selectedYear,
                                _selectedMonth + 1,
                                _selectedDay,
                              );
                            });
                          },
                          physics: const FixedExtentScrollPhysics(),
                          children: List<Widget>.generate(
                            12,
                            (index) => Center(
                              child: Text(
                                _monthsRu[index],
                                style: TextStyle(
                                  color: index == _selectedMonth
                                      ? Colors.white
                                      : textSecondary,
                                  fontSize: 14,
                                  fontWeight: index == _selectedMonth
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Полоски
                        Positioned(
                          top: 45,
                          child: SizedBox(
                            width: 100,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: textSecondary,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: textSecondary,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Год
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ListWheelScrollView(
                          controller: _yearController,
                          itemExtent: 40,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedYear = 2020 + index;
                              _selectedDate = DateTime(
                                _selectedYear,
                                _selectedMonth + 1,
                                _selectedDay,
                              );
                            });
                          },
                          physics: const FixedExtentScrollPhysics(),
                          children: List<Widget>.generate(
                            30,
                            (index) => Center(
                              child: Text(
                                (2020 + index).toString(),
                                style: TextStyle(
                                  color: 2020 + index == _selectedYear
                                      ? Colors.white
                                      : textSecondary,
                                  fontSize: 14,
                                  fontWeight: 2020 + index == _selectedYear
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Полоски
                        Positioned(
                          top: 45,
                          child: SizedBox(
                            width: 70,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: textSecondary,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: textSecondary,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Кнопка подтверждения
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: activeIconColor, width: 1),
                ),
                onPressed: _confirm,
                child: const Text(
                  'Подтвердить',
                  style: TextStyle(
                    color: activeIconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Показать диалог выбора месяца и года (Style K)
Future<DateTime?> showKCustomMonthYearPicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? otherDate,
  bool isSelectingDateTo = false,
  String title = 'Выберите время и дату',
  String subtitle = 'Дата и время вашей аренды',
  String fromTime = '00:00',
  String toTime = '00:00',
}) {
  return showDialog<DateTime?>(
    context: context,
    builder: (context) => KCustomMonthYearPicker(
      initialDate: initialDate,
      otherDate: otherDate,
      isSelectingDateTo: isSelectingDateTo,
      title: title,
      subtitle: subtitle,
      fromTime: fromTime,
      toTime: toTime,
    ),
  );
}

/// Компонент для отображения колонки с датой и временем
class _TimeDisplayColumn extends StatelessWidget {
  final String label;
  final String date;
  final String time;

  const _TimeDisplayColumn({
    required this.label,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF999999), fontSize: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(color: Color(0xFF999999), fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
