// ============================================================
//  "K-Calendar Widget - Виджет выбора времени и даты для аренды (Style K)"
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import 'date_picker.dart';
import 'time_picker.dart';

class KRentTimeWidget extends StatefulWidget {
  final String? dateFrom;
  final String? timeFrom;
  final String? dateTo;
  final String? timeTo;
  final Function(String)? onDateFromSelected;
  final Function(String)? onDateToSelected;
  final VoidCallback? onEditFrom;
  final VoidCallback? onEditTo;

  const KRentTimeWidget({
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
  State<KRentTimeWidget> createState() => _KRentTimeWidgetState();
}

class _KRentTimeWidgetState extends State<KRentTimeWidget> {
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
    final result = await showKCustomTimePicker(
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
    final result = await showKCustomTimePicker(
      context,
      initialTime: _timeFrom, // По умолчанию устанавливаем время "От"
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
    final result = await showKCustomDatePicker(
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
    final result = await showKCustomDatePicker(
      context,
      initialDate: _selectedDateFrom, // По умолчанию устанавливаем дату "От"
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Вверху: одна дата (От)
          GestureDetector(
            onTap: _selectDateFrom,
            child: Text(
              _dateFrom,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Горизонтальная линия
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 12),
          // Внизу: От время и До время на одной линии
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _selectTimeFrom,
                    child: Text(
                      'От',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                  GestureDetector(
                    onTap: _selectTimeFrom,
                    child: Text(
                      _timeFrom,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 24),
              Row(
                children: [
                  GestureDetector(
                    onTap: _selectTimeTo,
                    child: Text(
                      'До',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                  GestureDetector(
                    onTap: _selectTimeTo,
                    child: Text(
                      _timeTo,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
