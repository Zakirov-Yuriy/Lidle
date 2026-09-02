import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_item.dart';
import 'package:lidle/models/bookings/booking_settings.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Настройка записи у своего объявления.
///
/// До этого бронь включалась только консольной командой, то есть владелец без
/// разработчика начать принимать записи не мог.
///
/// Экран намеренно короткий. Настроек на сервере больше, чем здесь, но
/// вываливать их все значит превратить включение записи в анкету. Показываем
/// то, что владелец действительно решает: принимать ли записи, в какие часы,
/// какой длины приём, надо ли подтверждать вручную и за сколько можно
/// отменить. Остальное живёт с разумными умолчаниями.
class BookingSettingsScreen extends StatefulWidget {
  final int advertId;
  final String advertTitle;

  const BookingSettingsScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
  });

  @override
  State<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<BookingSettingsScreen> {
  static const _weekdayNames = {
    1: 'Понедельник',
    2: 'Вторник',
    3: 'Среда',
    4: 'Четверг',
    5: 'Пятница',
    6: 'Суббота',
    7: 'Воскресенье',
  };

  BookingSettings? _settings;
  List<BookingItem> _blocks = const [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      final settings = await BookingsService.settings(widget.advertId);

      // Закрытые периоды имеют смысл, только когда бронь вообще включена.
      final blocks = settings.isEnabled
          ? await BookingsService.blocks(widget.advertId)
          : <BookingItem>[];

      if (!mounted) return;

      setState(() {
        _settings = settings;
        _blocks = blocks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _settings = BookingSettings.notConfigured(widget.advertId);
        _isLoading = false;
      });

      SnackBarHelper.showError(context, 'Не получилось загрузить настройки');
    }
  }

  /// Сохраняем сразу, без кнопки «Применить».
  ///
  /// Экран из переключателей и выборов, и кнопка внизу в таком экране это
  /// ловушка: человек меняет часы, уходит назад и обнаруживает, что ничего не
  /// сохранилось. Запрос частичный, поэтому шлём только изменённое.
  Future<void> _save(Map<String, dynamic> patch) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final result = await BookingsService.saveSettings(widget.advertId, patch);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (!result.isOk) {
      SnackBarHelper.showError(context, result.error!);
      // Возвращаем экран к тому, что реально на сервере: иначе переключатель
      // остался бы в положении, которого нет в базе.
      await _load();
      return;
    }

    setState(() => _settings = result.settings ?? _settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Назад',
                      style: TextStyle(
                        color: activeIconColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final settings = _settings!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 12, 25, 40),
      children: [
        const Text(
          'Запись на объявление',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.advertTitle,
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _buildEnableCard(settings),
        if (settings.isEnabled) ...[
          const SizedBox(height: 12),
          if (settings.resource?.isShared == true) _buildSharedNotice(settings),
          _buildSlotCard(settings),
          const SizedBox(height: 12),
          _buildConfirmationCard(settings),
          const SizedBox(height: 12),
          _buildCancelCard(settings),
          const SizedBox(height: 12),
          _buildWorkingHoursCard(settings),
          const SizedBox(height: 12),
          _buildBlocksCard(),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _buildEnableCard(BookingSettings settings) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title('Принимать записи')),
              Switch(
                value: settings.isEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: activeIconColor,
                onChanged: _isSaving
                    ? null
                    : (value) => _save({'is_enabled': value}),
              ),
            ],
          ),
          _hint(settings.isEnabled
              ? 'В карточке объявления появится календарь свободного времени и кнопка «Записаться».'
              : 'Пока выключено, календарь в карточке не показывается.'),
        ],
      ),
    );
  }

  /// Предупреждение о разделённом расписании.
  ///
  /// Это самая неочевидная вещь во всём бронировании: занятость считается по
  /// исполнителю, а не по объявлению. Владелец, у которого три услуги на одном
  /// расписании, увидит, что запись на одну закрыла время в остальных, и решит,
  /// что это ошибка. Поэтому говорим заранее.
  Widget _buildSharedNotice(BookingSettings settings) {
    final count = settings.resource!.sharedAdvertsCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE0A63C).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE0A63C).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          'Это расписание общее для $count ваших объявлений. '
          'Запись на одно из них закроет то же время в остальных.',
          style: const TextStyle(color: Color(0xFFE0A63C), fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSlotCard(BookingSettings settings) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Сколько длится приём'),
          const SizedBox(height: 10),
          _chips(
            values: const [30, 60, 90, 120],
            selected: settings.slotMinutes,
            label: _minutesLabel,
            onSelected: (value) => _save({'slot_minutes': value}),
          ),
          const SizedBox(height: 14),
          _title('Перерыв между записями'),
          const SizedBox(height: 10),
          _chips(
            values: const [0, 10, 15, 30],
            selected: settings.bufferMinutes,
            label: (value) => value == 0 ? 'Без перерыва' : _minutesLabel(value),
            onSelected: (value) => _save({'buffer_minutes': value}),
          ),
          _hint('Перерыв нужен, чтобы успеть между клиентами. Он не показывается как свободное время.'),
        ],
      ),
    );
  }

  Widget _buildConfirmationCard(BookingSettings settings) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title('Подтверждать записи вручную')),
              Switch(
                value: settings.needsConfirmation,
                activeThumbColor: Colors.white,
                activeTrackColor: activeIconColor,
                onChanged: _isSaving
                    ? null
                    : (value) => _save({'needs_confirmation': value}),
              ),
            ],
          ),
          _hint(settings.needsConfirmation
              ? 'Время держится за человеком, пока вы не ответите. Не ответите вовремя — заявка гаснет и время освобождается.'
              : 'Человек выбирает время и оно сразу занято, вы просто видите запись.'),
          if (settings.needsConfirmation) ...[
            const SizedBox(height: 14),
            _title('Сколько ждать вашего ответа'),
            const SizedBox(height: 10),
            _chips(
              values: const [10, 30, 60, 1440],
              selected: settings.confirmTtlMinutes,
              label: _minutesLabel,
              onSelected: (value) => _save({'confirm_ttl_minutes': value}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCancelCard(BookingSettings settings) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('За сколько можно отменить'),
          const SizedBox(height: 10),
          _chips(
            values: const [0, 2, 24, 72],
            selected: settings.cancelBeforeHours,
            label: (value) => value == 0 ? 'В любой момент' : _hoursLabel(value),
            onSelected: (value) => _save({'cancel_before_hours': value}),
          ),
          _hint('Ограничение действует на гостя. Вы можете отменить в любой момент.'),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard(BookingSettings settings) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Рабочие часы'),
          _hint('Выключенный день — выходной, записи в него не принимаются.'),
          const SizedBox(height: 8),
          ...List.generate(7, (index) {
            final weekday = index + 1;
            final hour = settings.workingHours
                .where((h) => h.weekday == weekday)
                .toList();

            return _buildWeekdayRow(settings, weekday, hour.isEmpty ? null : hour.first);
          }),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(
    BookingSettings settings,
    int weekday,
    BookingWorkingHour? hour,
  ) {
    final isWorking = hour != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Switch(
              value: isWorking,
              activeThumbColor: Colors.white,
              activeTrackColor: activeIconColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: _isSaving
                  ? null
                  : (value) => _toggleWeekday(settings, weekday, value),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              _weekdayNames[weekday]!,
              style: TextStyle(
                color: isWorking ? Colors.white : textMuted,
                fontSize: 15,
              ),
            ),
          ),
          if (isWorking) ...[
            _timeButton(hour.startsAt, () => _pickTime(settings, weekday, true)),
            const Text(' — ', style: TextStyle(color: textSecondary)),
            _timeButton(hour.endsAt, () => _pickTime(settings, weekday, false)),
          ] else
            const Text(
              'выходной',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _timeButton(String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isSaving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  void _toggleWeekday(BookingSettings settings, int weekday, bool isWorking) {
    final hours = settings.workingHours.where((h) => h.weekday != weekday).toList();

    if (isWorking) {
      hours.add(BookingWorkingHour(
        weekday: weekday,
        startsAt: '09:00',
        endsAt: '18:00',
      ));
    }

    // Расписание отправляем целиком: сервер заменяет неделю, а не дописывает.
    // Иначе выключить день было бы нечем.
    _save({'working_hours': hours.map((h) => h.toJson()).toList()});
  }

  Future<void> _pickTime(BookingSettings settings, int weekday, bool isStart) async {
    final current = settings.workingHours.firstWhere((h) => h.weekday == weekday);
    final source = isStart ? current.startsAt : current.endsAt;
    final parts = source.split(':');

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: activeIconColor),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    final updated = BookingWorkingHour(
      weekday: weekday,
      startsAt: isStart ? value : current.startsAt,
      endsAt: isStart ? current.endsAt : value,
    );

    // Начало позже конца сервер отклонит, но объяснить это лучше здесь: так
    // человек увидит причину сразу, а не после запроса.
    if (updated.endsAt.compareTo(updated.startsAt) <= 0) {
      SnackBarHelper.showWarning(
        context,
        'Конец рабочего дня должен быть позже начала',
      );
      return;
    }

    final hours = settings.workingHours.where((h) => h.weekday != weekday).toList()
      ..add(updated);

    await _save({'working_hours': hours.map((h) => h.toJson()).toList()});
  }

  Widget _buildBlocksCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title('Закрытые дни')),
              GestureDetector(
                onTap: _isSaving ? null : _addBlock,
                child: const Text(
                  'Закрыть время',
                  style: TextStyle(color: activeIconColor, fontSize: 14),
                ),
              ),
            ],
          ),
          _hint('Отпуск, ремонт, личные дела. В закрытое время записаться нельзя.'),
          const SizedBox(height: 8),
          if (_blocks.isEmpty)
            const Text(
              'Закрытых дней нет.',
              style: TextStyle(color: textMuted, fontSize: 14),
            )
          else
            ..._blocks.map(_buildBlockRow),
        ],
      ),
    );
  }

  Widget _buildBlockRow(BookingItem block) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_humanDate(block.startsAt)}, '
              '${_time(block.startsAt)} — ${_time(block.endsAt)}'
              '${block.comment == null ? '' : ' · ${block.comment}'}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => _removeBlock(block),
            child: const Icon(Icons.close, color: textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _addBlock() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: activeIconColor),
        ),
        child: child!,
      ),
    );

    if (date == null || !mounted) return;

    // Закрываем день целиком: закрытие по часам можно будет добавить, когда
    // станет понятно, что оно кому-то нужно. Пока «уехал на день» покрывает
    // все известные случаи, а лишние поля усложняют экран на пустом месте.
    final starts = DateTime(date.year, date.month, date.day, 0, 0);
    final ends = DateTime(date.year, date.month, date.day, 23, 59);

    final result = await BookingsService.block(
      widget.advertId,
      startsAt: _iso(starts),
      endsAt: _iso(ends),
      comment: null,
    );

    if (!mounted) return;

    if (result.isCreated) {
      SnackBarHelper.showSuccess(context, result.message);
    } else {
      SnackBarHelper.showError(context, result.message);
    }

    await _load();
  }

  Future<void> _removeBlock(BookingItem block) async {
    final result = await BookingsService.unblock(block.id);

    if (!mounted) return;

    if (result.isCreated) {
      SnackBarHelper.showSuccess(context, result.message);
    } else {
      SnackBarHelper.showError(context, result.message);
    }

    await _load();
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
          onTap: _isSaving || isSelected ? null : () => onSelected(value),
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
      return _hoursLabel(minutes ~/ 60);
    }
    return '$minutes мин';
  }

  String _hoursLabel(int hours) {
    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      return days == 1 ? 'Сутки' : '$days сут';
    }

    final last = hours % 10;
    final lastTwo = hours % 100;

    if (last == 1 && lastTwo != 11) return '$hours час';
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
      return '$hours часа';
    }
    return '$hours часов';
  }

  String _iso(DateTime value) => value.toIso8601String();

  String _time(DateTime? value) {
    if (value == null) return '--:--';
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _humanDate(DateTime? date) {
    if (date == null) return 'дата не указана';

    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]}';
  }
}
