import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'required_label.dart';

/// Бронирование в форме подачи объявления (стили L и M).
///
/// Особый атрибут: он ничего не хранит в объявлении. Заказчик вешает его на
/// категорию в супер-админке, и это значит «объявления этой категории можно
/// бронировать». Настройки уезжают отдельным блоком `booking` вместе с
/// объявлением и ложатся в свои таблицы, а не в значения атрибута.
///
/// Стиль атрибута задаёт режим по УМОЛЧАНИЮ: `L` это запись по часам (приём,
/// просмотр, занятие), `M` посуточно (жильё). Продавец может его поменять:
/// он мог ошибиться или передумать. Сервер разрешает смену, пока на
/// расписании нет живых броней, а дальше отказывает вслух.
///
/// Режим ровно один. Часы и ночи меряют одно и то же время: ночь на 24-е
/// занимает и 15:00 того же дня, поэтому два расписания у объявления либо
/// постоянно блокировали бы друг друга, либо врали о свободном времени.
///
/// Рабочие часы здесь одни на всю неделю. Полноценный недельный редактор с
/// выходными и обедом живёт на экране настройки записи: в форме подачи он
/// превратил бы создание объявления в анкету, а поправить расписание можно
/// сразу после публикации.
class BookingField extends StatefulWidget {
  const BookingField({
    super.key,
    required this.attribute,
    required this.mode,
    required this.onChanged,
    this.initial,
  });

  final Attribute attribute;

  /// Режим по умолчанию, `slots` или `daily`. Берётся из стиля атрибута,
  /// то есть из того, что заказчик задал категории. Продавец может его
  /// поменять: он мог ошибиться или передумать, и запрещать это неправильно.
  /// Сервер разрешает смену, пока на расписании нет живых броней.
  final String mode;

  /// Настройки для отправки. `null` означает «бронь не включали и включать не
  /// собираются»: тогда блок в запрос не попадает вовсе и на сервере не
  /// появляется лишнего расписания.
  final ValueChanged<Map<String, dynamic>?> onChanged;

  /// Что уже настроено у объявления. Приходит при редактировании.
  final Map<String, dynamic>? initial;

  @override
  State<BookingField> createState() => _BookingFieldState();
}

class _BookingFieldState extends State<BookingField> {
  late bool _enabled;

  /// Была ли бронь включена, когда экран открылся.
  ///
  /// Нужно, чтобы отличить «не включал» от «выключил». В первом случае блок
  /// не отправляем совсем, во втором обязаны отправить `is_enabled: false`,
  /// иначе выключение просто не доедет до сервера.
  late bool _wasEnabled;

  /// Выбранный режим. Начинается с умолчания категории.
  late String _mode;

  int _slotMinutes = 60;
  int _bufferMinutes = 0;
  bool _needsConfirmation = false;
  int _cancelBeforeHours = 24;

  String _workFrom = '09:00';
  String _workTo = '18:00';

  String _checkIn = '14:00';
  String _checkOut = '11:00';

  bool get _isDaily => _mode == 'daily';

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _wasEnabled = initial?['is_enabled'] == true;
    _enabled = _wasEnabled;

    // Порядок здесь важен: сначала СВОЙ режим объявления, потом расписание,
    // потом умолчание категории и только затем стиль атрибута.
    //
    // Именно тут была ошибка: сервер отдавал под именем `mode` режим
    // КАТЕГОРИИ, приложение читало его как режим объявления, и форма
    // редактирования возвращала владельца назад. Он переключал объявление на
    // посуточное, в карточке всё менялось, а при следующем открытии формы
    // снова стояли часы, потому что часы задавала категория.
    _mode = _firstMode([
      initial?['mode'],
      initial?['resource'] is Map ? (initial!['resource'] as Map)['mode'] : null,
      initial?['default_mode'],
      widget.mode,
    ]);

    if (initial != null) {
      _slotMinutes = _asInt(initial['slot_minutes']) ?? 60;
      _bufferMinutes = _asInt(initial['buffer_minutes']) ?? 0;
      _needsConfirmation = initial['needs_confirmation'] == true;
      _cancelBeforeHours = _asInt(initial['cancel_before_hours']) ?? 24;
      _checkIn = _asTime(initial['check_in_time']) ?? '14:00';
      _checkOut = _asTime(initial['check_out_time']) ?? '11:00';

      final hours = initial['working_hours'];
      if (hours is List && hours.isNotEmpty && hours.first is Map) {
        final first = hours.first as Map;
        _workFrom = _asTime(first['starts_at']) ?? '09:00';
        _workTo = _asTime(first['ends_at']) ?? '18:00';
      }
    }
  }

  /// Первый пригодный режим из списка. Пустые и незнакомые значения
  /// пропускаем: сервер может не прислать поле вовсе, и падать на этом
  /// форма подачи не должна.
  static String _firstMode(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate == 'daily' || candidate == 'slots') {
        return '$candidate';
      }
    }

    return 'slots';
  }

  /// Собираем то, что уедет на сервер, и отдаём наверх.
  ///
  /// Вызывается после каждой правки: форма может быть отправлена в любой
  /// момент, и держать «несохранённое» состояние внутри виджета значит
  /// однажды отправить объявление без настроек, которые человек задал.
  void _report() {
    if (!_enabled) {
      widget.onChanged(_wasEnabled ? {'is_enabled': false} : null);
      return;
    }

    final data = <String, dynamic>{
      'is_enabled': true,
      'mode': _mode,
      'needs_confirmation': _needsConfirmation,
      'cancel_before_hours': _cancelBeforeHours,
    };

    if (_needsConfirmation) {
      // Десять минут — решение заказчика: за это время слот не успевает
      // простоять запертым сколько-нибудь заметно.
      data['confirm_ttl_minutes'] = 10;
    }

    if (_isDaily) {
      data['check_in_time'] = _checkIn;
      data['check_out_time'] = _checkOut;
    } else {
      data['slot_minutes'] = _slotMinutes;
      data['buffer_minutes'] = _bufferMinutes;
      data['working_hours'] = [
        for (var weekday = 1; weekday <= 7; weekday++)
          {'weekday': weekday, 'starts_at': _workFrom, 'ends_at': _workTo},
      ];
    }

    widget.onChanged(data);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RequiredLabel(
                label: widget.attribute.title,
                isRequired: false,
              ),
            ),
            const SizedBox(width: 12),
            CustomSwitch(
              value: _enabled,
              onChanged: (value) {
                setState(() => _enabled = value);
                _report();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _enabled
              ? (_isDaily
                    ? 'В объявлении появится календарь свободных ночей и кнопка «Забронировать».'
                    : 'В объявлении появится календарь свободного времени и кнопка «Записаться».')
              : 'Включите, если хотите принимать заявки прямо из объявления.',
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
        if (_enabled) ...[
          const SizedBox(height: 12),
          _settingsCard(),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _settingsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Как бронируют'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _modeChip(
                  mode: 'slots',
                  title: 'По часам',
                  subtitle: 'Приём, просмотр, занятие',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeChip(
                  mode: 'daily',
                  title: 'Посуточно',
                  subtitle: 'Ночь: заезд и выезд',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isDaily) ..._dailyRows() else ..._slotRows(),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Подтверждать вручную',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              CustomSwitch(
                value: _needsConfirmation,
                trackColor: primaryBackground,
                onChanged: (value) {
                  setState(() => _needsConfirmation = value);
                  _report();
                },
              ),
            ],
          ),
          _hint(
            _needsConfirmation
                ? 'Время держится за человеком, пока вы не ответите. Не ответите за десять минут — заявка гаснет.'
                : 'Человек выбирает время и оно сразу занято, вы просто видите заявку.',
          ),
          const SizedBox(height: 14),
          _title('За сколько можно отменить'),
          const SizedBox(height: 8),
          _chips(
            values: const [0, 2, 24, 72],
            selected: _cancelBeforeHours,
            label: (value) => value == 0 ? 'В любой момент' : '$value ч',
            onSelected: (value) {
              setState(() => _cancelBeforeHours = value);
              _report();
            },
          ),
          _hint('Ограничение действует на гостя. Вы можете отменить в любой момент.'),
          const SizedBox(height: 10),
          _hint('Выходные, обед и закрытые дни настраиваются после публикации, '
              'кнопкой «Настройка записи» в вашем объявлении.'),
        ],
      ),
    );
  }

  /// Выбор режима. Два варианта, не переключатель: слово «посуточно» само по
  /// себе ничего не объясняет, а разница между «клиент выбирает час» и «гость
  /// снимает на ночь» решает, каким объявление увидят люди.
  Widget _modeChip({
    required String mode,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _mode == mode;

    return GestureDetector(
      onTap: isSelected
          ? null
          : () {
              setState(() => _mode = mode);
              _report();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeIconColor : secondaryBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white70 : textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _slotRows() {
    return [
      _title('Сколько длится приём'),
      const SizedBox(height: 8),
      _chips(
        values: const [30, 60, 90, 120],
        selected: _slotMinutes,
        label: _minutesLabel,
        onSelected: (value) {
          setState(() => _slotMinutes = value);
          _report();
        },
      ),
      const SizedBox(height: 14),
      _title('Перерыв между записями'),
      const SizedBox(height: 8),
      _chips(
        values: const [0, 10, 15, 30],
        selected: _bufferMinutes,
        label: (value) => value == 0 ? 'Без перерыва' : _minutesLabel(value),
        onSelected: (value) {
          setState(() => _bufferMinutes = value);
          _report();
        },
      ),
      const SizedBox(height: 14),
      _title('Рабочие часы'),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(
            child: Text('Каждый день с',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
          _timeButton(_workFrom, () => _pickTime(isStart: true)),
          const Text('  до  ', style: TextStyle(color: textSecondary)),
          _timeButton(_workTo, () => _pickTime(isStart: false)),
        ],
      ),
    ];
  }

  List<Widget> _dailyRows() {
    return [
      _title('Заезд и выезд'),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(
            child: Text('Заезд после',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
          _timeButton(_checkIn, () => _pickStayTime(isCheckIn: true)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(
            child: Text('Выезд до',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
          _timeButton(_checkOut, () => _pickStayTime(isCheckIn: false)),
        ],
      ),
      _hint('Одна бронь это ночь: заезд в выбранный день, выезд утром '
          'следующего. Гость, съехавший утром, не мешает следующему заехать '
          'в тот же день.'),
    ];
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await _showPicker(isStart ? _workFrom : _workTo);

    if (picked == null) return;

    // Конец рабочего дня должен быть позже начала: сервер это отклонит, но
    // объяснить лучше здесь, до отправки всей формы.
    final from = isStart ? picked : _workFrom;
    final to = isStart ? _workTo : picked;

    if (to.compareTo(from) <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Конец рабочего дня должен быть позже начала'),
        ),
      );
      return;
    }

    setState(() {
      _workFrom = from;
      _workTo = to;
    });
    _report();
  }

  Future<void> _pickStayTime({required bool isCheckIn}) async {
    final picked = await _showPicker(isCheckIn ? _checkIn : _checkOut);

    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
      } else {
        _checkOut = picked;
      }
    });
    _report();
  }

  Future<String?> _showPicker(String current) async {
    final parts = current.split(':');

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      ),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: activeIconColor),
        ),
        child: child!,
      ),
    );

    if (picked == null) return null;

    return '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
  }

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
      );

  Widget _timeButton(String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _chips({
    required List<int> values,
    required int selected,
    required String Function(int) label,
    required void Function(int) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = value == selected;

        return GestureDetector(
          onTap: isSelected ? null : () => onSelected(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? activeIconColor : secondaryBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label(value),
              style: TextStyle(
                color: isSelected ? Colors.white : textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _minutesLabel(int minutes) {
    if (minutes % 60 == 0 && minutes >= 60) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 час' : '$hours часа';
    }
    return '$minutes мин';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Сервер отдаёт `14:00:00`, полю нужны часы и минуты.
  static String? _asTime(dynamic value) {
    if (value == null) return null;

    final text = '$value'.trim();
    if (text.isEmpty) return null;

    return text.length >= 5 ? text.substring(0, 5) : text;
  }
}
