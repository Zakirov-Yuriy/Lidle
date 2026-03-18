import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import 'month_year_picker.dart';

class KCustomDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? otherDate; // Вторая дата для отображения табло
  final String title;
  final String subtitle;
  final bool isSelectingDateTo; // true если выбираем "До", false если "От"
  final String fromTime;
  final String toTime;

  const KCustomDatePicker({
    super.key,
    this.initialDate,
    this.otherDate,
    this.title = 'Выберите время и дату',
    this.subtitle = 'Дата и время вашей аренды',
    this.isSelectingDateTo = false,
    this.fromTime = '00:00',
    this.toTime = '00:00',
  });

  @override
  State<KCustomDatePicker> createState() => _KCustomDatePickerState();
}

class _KCustomDatePickerState extends State<KCustomDatePicker> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  static const List<String> _monthsRu = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  static const List<String> _weekDaysRu = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  /// Получить список дней для отображения в календаре
  List<int?> _getDaysInMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // Первый день недели: 0=ПН, 6=ВС (в Flutter DateTime: 1=ПН, 7=ВС)
    final firstWeekday = firstDayOfMonth.weekday - 1; // Преобразуем в 0-6

    final days = <int?>[];

    // Добавляем пустые квадраты в начале
    for (int i = 0; i < firstWeekday; i++) {
      days.add(null);
    }

    // Добавляем дни месяца
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(i);
    }

    return days;
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
  }

  /// Показ диалога для выбора месяца и года
  Future<void> _selectMonthYear() async {
    final result = await showKCustomMonthYearPicker(
      context,
      initialDate: _displayedMonth,
      otherDate: widget.otherDate,
      isSelectingDateTo: widget.isSelectingDateTo,
      title: widget.title,
      subtitle: widget.subtitle,
      fromTime: widget.fromTime,
      toTime: widget.toTime,
    );

    if (result != null) {
      setState(() {
        _displayedMonth = DateTime(result.year, result.month, 1);
        _selectedDate = result; // Обновляем выбранную дату с новой датой из month_year picker
      });
    }
  }

  /// Форматировать дату в формат "Пн, 20 апреля"
  String _formatDate(DateTime date) {
    final formatted = DateFormat('EEE, d MMMM', 'ru_RU').format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Проверка, можно ли выбрать день
  bool _canSelectDay(int day) {
    final selectedDay = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    
    // Если выбираем дату "До", проверяем что она не меньше дня "От"
    if (widget.isSelectingDateTo && widget.otherDate != null) {
      return selectedDay.isAfter(widget.otherDate!) || 
             (selectedDay.year == widget.otherDate!.year && 
              selectedDay.month == widget.otherDate!.month && 
              selectedDay.day == widget.otherDate!.day);
    }
    
    // Если выбираем дату "От", то любая дата разрешена
    return true;
  }

  void _selectDay(int day) {
    final selectedDay = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    
    // Проверяем валидность выбора
    if (!_canSelectDay(day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дата "До" должна быть позже даты "От"'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _selectedDate = selectedDay;
    });
  }

  void _confirm() {
    // Преобразуем в нужный формат: "Пн, 20 апреля"
    final formatted = DateFormat('EEE, d MMMM', 'ru_RU').format(_selectedDate);
    final formattedDate = formatted[0].toUpperCase() + formatted.substring(1);
    // Возвращаем Map с DateTime и отформатированной строкой
    Navigator.of(context).pop({
      'date': _selectedDate,
      'formatted': formattedDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_displayedMonth);
    final monthName = _monthsRu[_displayedMonth.month - 1];
    final year = _displayedMonth.year;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF222E3A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
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
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Табло с датой и временем - новый компактный формат
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Вверху: дата которую выбираем
                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Горизонтальная линия
                  Container(height: 1, color: Colors.white24),
                  const SizedBox(height: 12),
                  // Внизу: От время и До время на одной линии
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'От',
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 52),
                          Text(
                            widget.fromTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          const Text(
                            'До',
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 52),
                          Text(
                            widget.toTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Месяц и год с навигацией
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: _previousMonth,
                  ),
                  GestureDetector(
                    onTap: _selectMonthYear,
                    child: Text(
                      '$monthName $year г.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Дни недели заголовки
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _weekDaysRu
                      .map((day) => SizedBox(
                            width: 35,
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  color: Color(0xFF999999),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Сетка дней
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];

                    if (day == null) {
                      return const SizedBox.shrink();
                    }

                    final isSelected =
                        day == _selectedDate.day && _displayedMonth.month == _selectedDate.month && _displayedMonth.year == _selectedDate.year;
                    final isToday = day == DateTime.now().day &&
                        _displayedMonth.month == DateTime.now().month &&
                        _displayedMonth.year == DateTime.now().year;
                    final isWeekend = (index % 7 == 5) || (index % 7 == 6); // СБ и ВС
                    final canSelect = _canSelectDay(day);

                    return GestureDetector(
                      onTap: canSelect ? () => _selectDay(day) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeIconColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                          border: isToday && canSelect
                              ? Border.all(color: Colors.grey, width: 1)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : !canSelect
                                      ? const Color(0xFF555555)
                                      : isWeekend
                                          ? const Color(0xFFFF4444)
                                          : Colors.white,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

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
                    side: const BorderSide(
                      color: activeIconColor,
                      width: 1,
                    ),
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
      ),
    );
  }
}

/// Показать кастомный календарь и вернуть выбранную дату
/// Возвращает Map с 'date' (DateTime) и 'formatted' (String в формате "Пн, 20 апреля")
Future<Map<String, dynamic>?> showKCustomDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? otherDate,
  bool isSelectingDateTo = false,
  String title = 'Выберите время и дату',
  String subtitle = 'Дата и время вашей аренды',
  String fromTime = '00:00',
  String toTime = '00:00',
}) {
  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (context) => KCustomDatePicker(
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

