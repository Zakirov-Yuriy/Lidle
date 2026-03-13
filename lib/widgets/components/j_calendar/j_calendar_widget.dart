// ============================================================
//  "J-Calendar Widget - Виджет выбора времени и даты для аренды"
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import 'date_picker.dart';
import 'time_picker.dart';

class RentTimeWidget extends StatefulWidget {
  final String? dateFrom;
  final String? timeFrom;
  final String? dateTo;
  final String? timeTo;
  final Function(String)? onDateFromSelected;
  final Function(String)? onDateToSelected;
  final VoidCallback? onEditFrom;
  final VoidCallback? onEditTo;

  const RentTimeWidget({
    super.key,
    this.dateFrom,
    this.timeFrom,
    this.dateTo,
    this.timeTo,
    this.onDateFromSelected,
    this.onDateToSelected,
    this.onEditFrom,
    this.onEditTo,
  });

  @override
  State<RentTimeWidget> createState() => _RentTimeWidgetState();
}

class _RentTimeWidgetState extends State<RentTimeWidget> {
  late String _dateFrom;
  late String _timeFrom;
  late String _dateTo;
  late String _timeTo;
  late DateTime _selectedDateFrom;
  late DateTime _selectedDateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.dateFrom ?? 'Выбрать дату';
    _timeFrom = widget.timeFrom ?? '00:00';
    _dateTo = widget.dateTo ?? 'Выбрать дату';
    _timeTo = widget.timeTo ?? '00:00';
    
    // Инициализируем даты с текущего дня
    _selectedDateFrom = DateTime.now();
    _selectedDateTo = DateTime.now();
  }

  /// Парсит дату из строки формата "ПН, 13 Марта"
  DateTime? _parseDateFromString(String dateStr) {
    if (dateStr == 'Выбрать дату') return null;
    try {
      // Пытаемся создать дату на основе текущего года
      // Это временное решение, так как формат не содержит года
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    } catch (e) {
      return null;
    }
  }

  /// Показ диалога для выбора времени "От"
  Future<void> _selectTimeFrom() async {
    final result = await showCustomTimePicker(
      context,
      initialTime: _timeFrom,
      title: 'Выберите время и дату',
      subtitle: 'Дата и время вашей аренды',
      fromDate: _selectedDateFrom,
      toDate: _selectedDateTo,
      isSelectingDateTo: false,
      fromTime: _timeFrom,
      toTime: _timeTo,
    );

    if (result != null) {
      setState(() {
        _timeFrom = result;
      });
    }
  }

  /// Показ диалога для выбора времени "До"
  Future<void> _selectTimeTo() async {
    final result = await showCustomTimePicker(
      context,
      initialTime: _timeTo,
      title: 'Выберите время и дату',
      subtitle: 'Дата и время вашей аренды',
      fromDate: _selectedDateFrom,
      toDate: _selectedDateTo,
      isSelectingDateTo: true,
      fromTime: _timeFrom,
      toTime: _timeTo,
    );

    if (result != null) {
      setState(() {
        _timeTo = result;
      });
    }
  }

  /// Показ диалога календаря с выбором даты
  Future<void> _selectDateFrom() async {
    final result = await showCustomDatePicker(
      context,
      initialDate: _selectedDateFrom,
      otherDate: _selectedDateTo,
      isSelectingDateTo: false,
      title: 'Выберите время и дату',
      subtitle: 'Дата и время вашей аренды',
      fromTime: _timeFrom,
      toTime: _timeTo,
    );

    if (result != null) {
      final selectedDateTime = result['date'] as DateTime;
      final formattedDate = result['formatted'] as String;
      setState(() {
        _selectedDateFrom = selectedDateTime;
        _dateFrom = formattedDate;
      });
      // Вызываем callback с выбранной датой
      widget.onDateFromSelected?.call(formattedDate);
      widget.onEditFrom?.call();
    }
  }

  /// Показ диалога календаря с выбором даты "До"
  Future<void> _selectDateTo() async {
    final result = await showCustomDatePicker(
      context,
      initialDate: _selectedDateTo,
      otherDate: _selectedDateFrom,
      isSelectingDateTo: true,
      title: 'Выберите время и дату',
      subtitle: 'Дата и время вашей аренды',
      fromTime: _timeFrom,
      toTime: _timeTo,
    );

    if (result != null) {
      final selectedDateTime = result['date'] as DateTime;
      final formattedDate = result['formatted'] as String;
      setState(() {
        _selectedDateTo = selectedDateTime;
        _dateTo = formattedDate;
      });
      // Вызываем callback с выбранной датой
      widget.onDateToSelected?.call(formattedDate);
      widget.onEditTo?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateFrom,
                  child: _TimeColumn(
                    label: 'От',
                    date: _dateFrom,
                    time: _timeFrom,
                    onTimePressed: _selectTimeFrom,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateTo,
                  child: _TimeColumn(
                    label: 'До',
                    date: _dateTo,
                    time: _timeTo,
                    onTimePressed: _selectTimeTo,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  final String label;
  final String date;
  final String time;
  final VoidCallback? onTimePressed;

  const _TimeColumn({
    required this.label,
    required this.date,
    required this.time,
    this.onTimePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.white24,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: GestureDetector(
                  onTap: onTimePressed,
                  child: Text(
                    time,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
            
          ),
          
        ),
      ],
    );
  }
}
