// ============================================================
//  "Виджет выбора времени и даты для аренды"
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

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
  late DateTime? _selectedDateFrom;
  late DateTime? _selectedDateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.dateFrom ?? 'Выбрать дату';
    _timeFrom = widget.timeFrom ?? '00:00';
    _dateTo = widget.dateTo ?? 'Выбрать дату';
    _timeTo = widget.timeTo ?? '00:00';
    _selectedDateFrom = null;
    _selectedDateTo = null;
  }

  /// Показ диалога календаря с выбором даты
  Future<void> _selectDateFrom() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
    );

    if (pickedDate != null) {
      final formatted = DateFormat('EEE, d MMMM', 'ru_RU').format(pickedDate);
      final formattedDate = formatted[0].toUpperCase() + formatted.substring(1);
      setState(() {
        _selectedDateFrom = pickedDate;
        _dateFrom = formattedDate;
      });
      // Вызываем callback с выбранной датой
      widget.onDateFromSelected?.call(formattedDate);
      widget.onEditFrom?.call();
    }
  }

  /// Показ диалога календаря с выбором даты "До"
  Future<void> _selectDateTo() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTo ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
    );

    if (pickedDate != null) {
      final formatted = DateFormat('EEE, d MMMM', 'ru_RU').format(pickedDate);
      final formattedDate = formatted[0].toUpperCase() + formatted.substring(1);
      setState(() {
        _selectedDateTo = pickedDate;
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

  const _TimeColumn({
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
          style: const TextStyle(
            color: textSecondary,
            fontSize: 14,
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
              const SizedBox(height: 4),
              Container(
                height: 1,
                color: Colors.white24,
              ),
              Text(
                time,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
