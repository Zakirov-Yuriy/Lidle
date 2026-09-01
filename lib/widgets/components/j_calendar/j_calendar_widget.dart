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

  /// Машинные значения интервала: дата в формате yyyy-MM-dd и время HH:mm.
  ///
  /// Отдельно от [onDateFromSelected], который отдаёт подпись для экрана
  /// («Пн, 20 апреля»): в ней нет года, и на сервер её не отправить. Время
  /// раньше не покидало виджет вовсе — выбранный час оставался внутри и
  /// терялся при публикации. Колбэк срабатывает и на смену даты, и на
  /// смену времени, и только после того, как дату действительно выбрали.
  final void Function(String date, String time)? onFromChanged;
  final void Function(String date, String time)? onToChanged;

  /// Сохранённые даты в машинном виде «yyyy-MM-dd». Нужны при открытии
  /// объявления на редактирование: подписи `dateFrom`/`dateTo` года не
  /// содержат, и восстановить из них настоящую дату нельзя — виджет
  /// отправил бы потом сегодняшнее число.
  final String? isoFrom;
  final String? isoTo;

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
    this.onFromChanged,
    this.onToChanged,
    this.isoFrom,
    this.isoTo,
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
    
    // Даты берём из машинных значений, если они пришли, иначе с текущего дня.
    _selectedDateFrom = DateTime.tryParse(widget.isoFrom ?? '') ?? DateTime.now();
    _selectedDateTo = DateTime.tryParse(widget.isoTo ?? '') ?? DateTime.now();

    // Если значение пришло сверху (открыли объявление на редактирование),
    // считаем дату выбранной — иначе смена одного лишь времени ничего бы
    // не отправила.
    _dateFromPicked = widget.dateFrom != null || widget.isoFrom != null;
    _dateToPicked = widget.dateTo != null || widget.isoTo != null;
  }

  /// Значения объявления приезжают ПОЗЖЕ первого построения: форма рисуется,
  /// как только загружен список атрибутов категории, а сохранённые значения
  /// подставляются следующим шагом. К тому моменту initState уже отработал,
  /// и без этой синхронизации поля так и оставались бы пустыми.
  @override
  void didUpdateWidget(covariant RentTimeWidget old) {
    super.didUpdateWidget(old);

    var changed = false;

    if (widget.dateFrom != old.dateFrom && widget.dateFrom != null) {
      _dateFrom = widget.dateFrom!;
      changed = true;
    }
    if (widget.dateTo != old.dateTo && widget.dateTo != null) {
      _dateTo = widget.dateTo!;
      changed = true;
    }
    if (widget.timeFrom != old.timeFrom && widget.timeFrom != null) {
      _timeFrom = widget.timeFrom!;
      changed = true;
    }
    if (widget.timeTo != old.timeTo && widget.timeTo != null) {
      _timeTo = widget.timeTo!;
      changed = true;
    }
    if (widget.isoFrom != old.isoFrom) {
      final parsed = DateTime.tryParse(widget.isoFrom ?? '');
      if (parsed != null) {
        _selectedDateFrom = parsed;
        _dateFromPicked = true;
        changed = true;
      }
    }
    if (widget.isoTo != old.isoTo) {
      final parsed = DateTime.tryParse(widget.isoTo ?? '');
      if (parsed != null) {
        _selectedDateTo = parsed;
        _dateToPicked = true;
        changed = true;
      }
    }

    if (changed) setState(() {});
  }

  /// Дату действительно выбрали. Без этого флага виджет отдавал бы сегодняшнее
  /// число (им инициализируется `_selectedDateFrom`) у человека, который
  /// потрогал только время.
  bool _dateFromPicked = false;
  bool _dateToPicked = false;

  void _emitFrom() {
    if (!_dateFromPicked) return;

    widget.onFromChanged?.call(
      DateFormat('yyyy-MM-dd').format(_selectedDateFrom),
      _timeFrom,
    );
  }

  void _emitTo() {
    if (!_dateToPicked) return;

    widget.onToChanged?.call(
      DateFormat('yyyy-MM-dd').format(_selectedDateTo),
      _timeTo,
    );
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
      _emitFrom();
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
      _emitTo();
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
      _dateFromPicked = true;
      widget.onDateFromSelected?.call(formattedDate);
      _emitFrom();
      widget.onEditFrom?.call();
    }
  }

  /// Показ диалога календаря с выбором даты "До"
  Future<void> _selectDateTo() async {
    final result = await showCustomDatePicker(
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
      _dateToPicked = true;
      widget.onDateToSelected?.call(formattedDate);
      _emitTo();
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
