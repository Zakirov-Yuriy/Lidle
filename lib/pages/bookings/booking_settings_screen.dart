import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_item.dart';
import 'package:lidle/models/bookings/booking_settings.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
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
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
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
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
      children: [
        Text(
          settings.isDaily ? 'Бронирование объявления' : 'Запись на объявление',
          style: const TextStyle(
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
          _buildModeCard(settings),
          const SizedBox(height: 12),
          // Длительность приёма и перерыв имеют смысл только у записи по
          // часам. У посуточной аренды единица это ночь, и вместо них нужны
          // часы заезда и выезда: именно они задают её границы.
          if (settings.isDaily)
            _buildStayCard(settings)
          else
            _buildSlotCard(settings),
          const SizedBox(height: 12),
          _buildConfirmationCard(settings),
          const SizedBox(height: 12),
          _buildCancelCard(settings),
          // Рабочие часы посуточная аренда не читает вовсе: ночь считается от
          // заезда до выезда независимо от дня недели. Показывать здесь
          // расписание значит предлагать настройку, которая ни на что не
          // влияет. Закрыть отдельные ночи можно ниже.
          if (!settings.isDaily) ...[
            const SizedBox(height: 12),
            _buildWorkingHoursCard(settings),
          ],
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
              Expanded(child: _title(
                settings.isDaily ? 'Принимать брони' : 'Принимать записи',
              )),
              CustomSwitch(
                value: settings.isEnabled,
                // Дорожка светлее карточки: на formBackground стандартный
                // тёмный цвет свича сливается с фоном.
                trackColor: primaryBackground,
                onChanged: (value) {
                  if (_isSaving) return;
                  _save({'is_enabled': value});
                },
              ),
            ],
          ),
          _hint(!settings.isEnabled
              ? 'Пока выключено, календарь в карточке не показывается.'
              : settings.isDaily
                  ? 'В карточке объявления появится календарь свободных ночей и кнопка «Забронировать».'
                  : 'В карточке объявления появится календарь свободного времени и кнопка «Записаться».'),
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

  /// Режим: запись по часам или посуточная аренда.
  ///
  /// Раньше этого выбора здесь не было вовсе, и режим задавался только
  /// консольной командой при первом включении. То есть владелец, сдающий
  /// квартиру, получал экран записи к мастеру и ничего не мог с этим сделать.
  ///
  /// Выбор из двух карточек, а не переключатель: слово «посуточно» само по
  /// себе ничего не объясняет, а разница между «клиент выбирает час» и «гость
  /// снимает на ночь» решает, каким объявление увидят люди.
  Widget _buildModeCard(BookingSettings settings) {
    final canChange = settings.resource?.canChangeMode ?? true;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Как бронируют'),
          const SizedBox(height: 10),
          _modeOption(
            settings: settings,
            mode: 'slots',
            title: 'По часам, запись',
            subtitle: 'Клиент выбирает день и время приёма. Стрижка, приём врача, занятие.',
            canChange: canChange,
          ),
          const SizedBox(height: 8),
          _modeOption(
            settings: settings,
            mode: 'daily',
            title: 'Посуточно, аренда',
            subtitle: 'Гость выбирает ночи. Заезд днём, выезд утром следующего дня.',
            canChange: canChange,
          ),
          if (!canChange)
            _hint('Режим уже нельзя поменять: на этом расписании есть брони. '
                'Отмените их или заведите объявление заново.'),
        ],
      ),
    );
  }

  Widget _modeOption({
    required BookingSettings settings,
    required String mode,
    required String title,
    required String subtitle,
    required bool canChange,
  }) {
    final isSelected = (settings.resource?.mode ?? 'slots') == mode;

    return GestureDetector(
      onTap: (!canChange || isSelected || _isSaving) ? null : () => _changeMode(mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? activeIconColor.withValues(alpha: 0.16) : secondaryBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeIconColor : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected
                  ? activeIconColor
                  : (canChange ? textSecondary : textMuted),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: canChange || isSelected ? Colors.white : textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Смена режима перечитывает экран целиком, а не только настройки.
  ///
  /// Закрытые периоды при этом меняют смысл: у записи закрывались календарные
  /// сутки, у аренды закрывается ночь. Оставить на экране прежний список
  /// значило бы показывать «закрытые ночи» там, где на самом деле лежат
  /// закрытые сутки.
  Future<void> _changeMode(String mode) async {
    await _save({'mode': mode});

    if (!mounted) return;

    await _load();
  }

  /// Часы заезда и выезда. Это не украшение: именно они задают границы ночи,
  /// и по ним же закрываются даты. При заезде 14:00 и выезде 11:00 ночь 24-го
  /// это промежуток с 24-го 14:00 до 25-го 11:00, поэтому гость, съехавший
  /// утром, не мешает следующему заехать в тот же день.
  Widget _buildStayCard(BookingSettings settings) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Заезд и выезд'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Заезд после',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
              _timeButton(
                settings.checkInTime ?? '14:00',
                () => _pickStayTime(settings, isCheckIn: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('Выезд до',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
              _timeButton(
                settings.checkOutTime ?? '11:00',
                () => _pickStayTime(settings, isCheckIn: false),
              ),
            ],
          ),
          _hint('Одна бронь это ночь: заезд в выбранный день, выезд утром следующего. '
              'Гость, съехавший утром, не мешает следующему заехать в тот же день.'),
        ],
      ),
    );
  }

  Future<void> _pickStayTime(
    BookingSettings settings, {
    required bool isCheckIn,
  }) async {
    final source = (isCheckIn ? settings.checkInTime : settings.checkOutTime) ??
        (isCheckIn ? '14:00' : '11:00');
    final parts = source.split(':');

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? (isCheckIn ? 14 : 11),
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
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

    // Ключ вычисляем заранее: условное выражение прямо в ключе литерала карты
    // читается двусмысленно из-за двоеточия.
    final field = isCheckIn ? 'check_in_time' : 'check_out_time';

    await _save({field: value});
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
              Expanded(child: _title(settings.isDaily
                  ? 'Подтверждать брони вручную'
                  : 'Подтверждать записи вручную')),
              CustomSwitch(
                value: settings.needsConfirmation,
                trackColor: primaryBackground,
                onChanged: (value) {
                  if (_isSaving) return;
                  _save({'needs_confirmation': value});
                },
              ),
            ],
          ),
          _hint(settings.needsConfirmation
              ? 'Время держится за человеком, пока вы не ответите. Не ответите вовремя — заявка гаснет и время освобождается.'
              : settings.isDaily
                  ? 'Гость выбирает ночи и они сразу заняты, вы просто видите бронь.'
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
          CustomSwitch(
            value: isWorking,
            trackColor: primaryBackground,
            onChanged: (value) {
              if (_isSaving) return;
              _toggleWeekday(settings, weekday, value);
            },
          ),
          const SizedBox(width: 12),
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
              Expanded(
                child: _title(_settings!.isDaily ? 'Закрытые ночи' : 'Закрытые дни'),
              ),
              GestureDetector(
                onTap: _isSaving ? null : _addBlock,
                child: Text(
                  _settings!.isDaily ? 'Закрыть ночь' : 'Закрыть день',
                  style: const TextStyle(color: activeIconColor, fontSize: 14),
                ),
              ),
            ],
          ),
          _hint(_settings!.isDaily
              ? 'Отпуск, ремонт, личные дела. Закрывается ночь: заезд в выбранный день, выезд на следующий.'
              : 'Отпуск, ремонт, личные дела. В закрытое время записаться нельзя.'),
          const SizedBox(height: 8),
          if (_blocks.isEmpty)
            Text(
              _settings!.isDaily ? 'Закрытых ночей нет.' : 'Закрытых дней нет.',
              style: const TextStyle(color: textMuted, fontSize: 14),
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
              _blockLabel(block),
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

    final settings = _settings!;

    // Что именно закрывать, зависит от режима, и это не мелочь.
    //
    // У записи к мастеру закрываем календарные сутки: «в этот день не
    // работаю».
    //
    // У жилья единица занятости не сутки, а НОЧЬ: ночь 24-го это заезд 24-го
    // в 14:00 и выезд 25-го в 11:00. Если у жилья закрыть сутки с 00:00 до
    // 23:59, промежуток заденет утро — то есть конец предыдущей ночи, — и
    // закрытыми окажутся ДВЕ ночи вместо одной. Именно так и вышло при первой
    // проверке: закрыли 25 сентября, а недоступными стали 24-е и 25-е.
    //
    // Поэтому для жилья закрываем ровно ночь, от часа заезда до часа выезда
    // следующего дня.
    final DateTime starts;
    final DateTime ends;

    if (settings.isDaily) {
      final checkIn = _parseTime(settings.checkInTime, fallbackHour: 14);
      final checkOut = _parseTime(settings.checkOutTime, fallbackHour: 11);
      final next = date.add(const Duration(days: 1));

      starts = DateTime(date.year, date.month, date.day, checkIn.$1, checkIn.$2);
      ends = DateTime(next.year, next.month, next.day, checkOut.$1, checkOut.$2);
    } else {
      starts = DateTime(date.year, date.month, date.day, 0, 0);
      ends = DateTime(date.year, date.month, date.day, 23, 59);
    }

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

  /// Разбирает `14:00` в часы и минуты. Запасное значение нужно на случай,
  /// когда владелец ещё не задавал часы заезда: без него мы бы закрыли
  /// полночь и снова задели соседнюю ночь.
  (int, int) _parseTime(String? value, {required int fallbackHour}) {
    final parts = (value ?? '').split(':');

    final hour = parts.isEmpty ? null : int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;

    return (hour ?? fallbackHour, minute ?? 0);
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

  /// Подпись закрытого промежутка.
  ///
  /// У жилья пишем «ночь на 26 сентября»: пара дат с часами читается как
  /// загадка, потому что заканчивается на следующий день.
  String _blockLabel(BookingItem block) {
    final comment = block.comment == null ? '' : ' · ${block.comment}';

    if (_settings!.isDaily && block.startsAt != null) {
      return 'Ночь ${_humanDate(block.startsAt)}, '
          'выезд ${_humanDate(block.endsAt)}$comment';
    }

    return '${_humanDate(block.startsAt)}, '
        '${_time(block.startsAt)} — ${_time(block.endsAt)}$comment';
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
