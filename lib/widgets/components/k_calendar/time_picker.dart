import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';

class KCustomTimePicker extends StatefulWidget {
  final String? initialTime; // Формат "HH:mm"
  final String title;
  final String subtitle;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool isSelectingDateTo;
  final String? fromTime;
  final String? toTime;

  const KCustomTimePicker({
    super.key,
    this.initialTime,
    this.title = 'Выберите время',
    this.subtitle = 'Установите время',
    this.fromDate,
    this.toDate,
    this.isSelectingDateTo = false,
    this.fromTime,
    this.toTime,
  });

  @override
  State<KCustomTimePicker> createState() => _KCustomTimePickerState();
}

class _KCustomTimePickerState extends State<KCustomTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    
    // Инициализируем выбранную дату
    _selectedDate = widget.isSelectingDateTo 
        ? (widget.toDate ?? DateTime.now())
        : (widget.fromDate ?? DateTime.now());
    
    // Парсим initialTime или используем текущее время
    if (widget.initialTime != null && widget.initialTime!.contains(':')) {
      final parts = widget.initialTime!.split(':');
      _selectedHour = int.tryParse(parts[0]) ?? 0;
      _selectedMinute = int.tryParse(parts[1]) ?? 0;
    } else {
      final now = DateTime.now();
      _selectedHour = now.hour;
      _selectedMinute = now.minute;
    }

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _confirm() {
    final formattedTime = '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}';
    Navigator.of(context).pop(formattedTime);
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('EEE, d MMMM', 'ru_RU');
    final formatted = formatter.format(date);
    // Капитализируем первый символ дня недели
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
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
            // const SizedBox(height: 4),

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
                  widget.isSelectingDateTo && widget.toDate != null
                      ? _formatDate(widget.toDate!)
                      : (widget.fromDate != null 
                          ? _formatDate(widget.fromDate!)
                          : 'Выбрать дату'),
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
                          widget.fromTime ?? '00:00',
                          style: const TextStyle(
                            color: Colors.white70,
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
                          widget.toTime ?? '00:00',
                          style: const TextStyle(
                            color: Colors.white70,
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
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Часы с полосками
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ListWheelScrollView(
                          controller: _hourController,
                          itemExtent: 40,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedHour = index;
                            });
                          },
                          physics: const FixedExtentScrollPhysics(),
                          children: List<Widget>.generate(
                            24,
                            (index) => Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color: index == _selectedHour
                                      ? Colors.white
                                      : textSecondary,
                                  fontSize: 18,
                                  fontWeight: index == _selectedHour
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Полоски вверху и внизу для часов
                        Positioned(
                          top: 45,
                          child: SizedBox(
                            width: 56,
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
                  // Двоеточие без полосок
                  const SizedBox(
                    width: 0,
                    child: Center(
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Минуты с полосками
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ListWheelScrollView(
                          controller: _minuteController,
                          itemExtent: 45,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedMinute = index;
                            });
                          },
                          physics: const FixedExtentScrollPhysics(),
                          children: List<Widget>.generate(
                            60,
                            (index) => Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color: index == _selectedMinute
                                      ? Colors.white
                                      : textSecondary,
                                  fontSize: 18,
                                  fontWeight: index == _selectedMinute
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Полоски вверху и внизу для минут
                        Positioned(
                          top: 45,
                          child: SizedBox(
                            width: 56,
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
    );
  }
}

/// Показать кастомный time picker и вернуть выбранное время
/// Возвращает String в формате "HH:mm"
Future<String?> showKCustomTimePicker(
  BuildContext context, {
  String? initialTime,
  String title = 'Выберите время',
  String subtitle = 'Установите время',
  DateTime? fromDate,
  DateTime? toDate,
  bool isSelectingDateTo = false,
  String? fromTime,
  String? toTime,
}) {
  return showDialog<String?>(
    context: context,
    builder: (context) => KCustomTimePicker(
      initialTime: initialTime,
      title: title,
      subtitle: subtitle,
      fromDate: fromDate,
      toDate: toDate,
      isSelectingDateTo: isSelectingDateTo,
      fromTime: fromTime,
      toTime: toTime,
    ),
  );
}

