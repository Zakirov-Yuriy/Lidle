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

  /// Машинные значения интервала: дата в формате yyyy-MM-dd и время HH:mm.
  ///
  /// Отдельно от [onDateFromSelected], который отдаёт подпись для экрана
  /// («Пн, 20 апреля»): в ней нет года, и на сервер её не отправить. Время
  /// раньше не покидало виджет вовсе — выбранный час оставался внутри и
  /// терялся при публикации. Колбэк срабатывает и на смену даты, и на
  /// смену времени, и только после того, как дату действительно выбрали.
  final void Function(String date, String time)? onFromChanged;
  final void Function(String date, String time)? onToChanged;

  /// Сохранённая дата в машинном виде «yyyy-MM-dd». Нужна при открытии
  /// объявления на редактирование: подпись `dateFrom` года не содержит, и
  /// восстановить из неё настоящую дату нельзя — виджет отправил бы потом
  /// сегодняшнее число.
  final String? isoFrom;

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
    this.onFromChanged,
    this.onToChanged,
    this.isoFrom,
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

    // Дату берём из машинного значения, если оно пришло, иначе текущий день.
    _selectedDateFrom = DateTime.tryParse(widget.isoFrom ?? '') ?? DateTime.now();
    _selectedDateTo = _selectedDateFrom;

    // Если значение пришло сверху (открыли объявление на редактирование),
    // считаем дату выбранной — иначе смена одного лишь времени ничего бы
    // не отправила.
    _datePicked = widget.dateFrom != null || widget.isoFrom != null;
  }

  /// Значения объявления приезжают ПОЗЖЕ первого построения: форма рисуется,
  /// как только загружен список атрибутов категории, а сохранённые значения
  /// подставляются следующим шагом. К тому моменту initState уже отработал,
  /// и без этой синхронизации поля так и оставались бы пустыми.
  @override
  void didUpdateWidget(covariant KRentTimeWidget old) {
    super.didUpdateWidget(old);

    var changed = false;

    if (widget.dateFrom != old.dateFrom && widget.dateFrom != null) {
      _dateFrom = widget.dateFrom!;
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
        _selectedDateTo = parsed;
        _datePicked = true;
        changed = true;
      }
    }

    if (changed) setState(() {});
  }

  /// Дату действительно выбрали. Без этого флага виджет отдавал бы сегодняшнее
  /// число (им инициализируется `_selectedDateFrom`) у человека, который
  /// потрогал только время.
  bool _datePicked = false;

  /// У компактного календаря дата ОДНА, а «От» и «До» — это время в её
  /// пределах: запись к врачу 3 сентября с 14:00 до 14:30. Поэтому обе
  /// половины интервала отдаём с одной и той же датой. Метод выбора второй
  /// даты в файле есть, но к интерфейсу не подключён — в разметке на дату
  /// нажимается только верхняя строка.
  String get _isoDate => DateFormat('yyyy-MM-dd').format(_selectedDateFrom);

  void _emitFrom() {
    if (!_datePicked) return;

    widget.onFromChanged?.call(_isoDate, _timeFrom);
  }

  void _emitTo() {
    if (!_datePicked) return;

    widget.onToChanged?.call(_isoDate, _timeTo);
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
      _emitFrom();
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
      _emitTo();
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
      _datePicked = true;
      widget.onDateFromSelected?.call(formattedDate);
      // Дата одна на обе половины, поэтому отдаём и начало, и конец.
      _emitFrom();
      _emitTo();
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
      _datePicked = true;
      widget.onDateToSelected?.call(formattedDate);
      _emitTo();
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
