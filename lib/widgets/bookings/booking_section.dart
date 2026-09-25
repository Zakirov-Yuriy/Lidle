import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/pages/bookings/booking_confirm_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/bookings/booking_nights_picker.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';

/// Блок записи в карточке объявления: выбор дня, свободные слоты и кнопка.
///
/// Показывается, только если у объявления подключена бронь и в ближайшем
/// месяце есть свободное время. Во всех остальных случаях виджет молча
/// возвращает пустоту: сломанный или отсутствующий календарь не повод
/// портить карточку.
///
/// Занятость НЕ считается здесь. Всё, что видно на экране, приходит с
/// сервера: он один знает про буферы, время «не раньше чем», выходные и про
/// брони соседних объявлений того же исполнителя. Клиентская проверка тут
/// была бы только подсказкой, и последнее слово всё равно за сервером,
/// который на попытку занять чужое время отвечает 409.
class BookingSection extends StatefulWidget {
  final int advertId;
  final String advertTitle;

  const BookingSection({
    super.key,
    required this.advertId,
    required this.advertTitle,
  });

  @override
  State<BookingSection> createState() => _BookingSectionState();
}

class _BookingSectionState extends State<BookingSection> {
  /// На сколько вперёд просим календарь.
  ///
  /// Шестьдесят два дня — это максимум, который отдаёт сервер за один запрос.
  /// Просим сразу его, а не месяц: жильё планируют за два-три месяца, и
  /// календарь, который заканчивается через тридцать дней, выглядит как
  /// «свободных дат больше нет». Для записи к мастеру лишние даты не мешают,
  /// а второй запрос ради них был бы дороже.
  ///
  /// Сервер сам обрежет промежуток до горизонта объявления, если владелец
  /// открыл бронь на меньший срок.
  static const int _horizonDays = 62;

  BookingAvailability? _availability;
  bool _isLoading = true;

  /// Ресторан с залами (22.09.2026): выбранный зал, число гостей и банкет.
  /// До первого ответа сервера пусто: зал и гостей по умолчанию выбирает он.
  int? _hallId;
  int? _guests;
  bool _wholeHall = false;

  /// Перечитываем время после смены зала, гостей или банкета. Блок при этом
  /// не прячем, только показываем полоску загрузки.
  bool _isReloading = false;

  BookingDay? _selectedDay;
  BookingSlot? _selectedSlot;

  /// Посуточный режим: первая выбранная ночь (заезд) и последняя (ночь перед
  /// выездом). Единица здесь ночь, а не день: «с 5 по 12» это семь ночей.
  BookingNight? _firstNight;
  BookingNight? _lastNight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();

    final data = await BookingsService.availability(
      widget.advertId,
      from: now,
      to: now.add(const Duration(days: _horizonDays)),
      hallId: _hallId,
      guests: _guests,
      wholeHall: _wholeHall,
    );

    if (!mounted) return;

    // День, который человек уже выбрал, сохраняем при смене зала или
    // гостей: он выбирает зал под дату, а не наоборот.
    final keepDay = _selectedDay;

    setState(() {
      _availability = data;
      _isLoading = false;
      _isReloading = false;

      final selection = data?.selection;
      if (selection != null) {
        _hallId = selection.hallId;
        _guests = selection.guests;
        _wholeHall = selection.wholeHall;
      }

      _selectedDay = _sameDayIn(data, keepDay) ?? _firstDayWithFreeSlots(data);
      _selectedSlot = null;
      _firstNight = null;
      _lastNight = null;
    });
  }

  BookingDay? _sameDayIn(BookingAvailability? data, BookingDay? day) {
    if (data == null || day == null) return null;

    for (final d in data.days) {
      if (_isSameDate(d.date, day.date) && d.isWorking && d.hasFreeSlots) return d;
    }
    return null;
  }

  /// Сменить зал, гостей или банкет и перечитать свободное время.
  void _choose({int? hallId, int? guests, bool? wholeHall}) {
    setState(() {
      if (hallId != null && hallId != _hallId) {
        _hallId = hallId;
        // В новом зале банкет может быть запрещён: сервер сам поправит.
        _wholeHall = false;
      }
      if (guests != null) _guests = guests;
      if (wholeHall != null) _wholeHall = wholeHall;
      _selectedSlot = null;
      _isReloading = true;
    });

    _load();
  }

  BookingDay? _firstDayWithFreeSlots(BookingAvailability? data) {
    if (data == null) return null;

    for (final day in data.days) {
      if (day.isWorking && day.hasFreeSlots) return day;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Пока грузим, места не занимаем: у большинства объявлений брони нет, и
    // мигать заглушкой в каждой карточке незачем.
    if (_isLoading) return const SizedBox.shrink();

    final data = _availability;
    if (data == null) return const SizedBox.shrink();

    // Ресторан с залами: блок виден всегда, даже если в выбранном зале нет
    // свободного времени, иначе вместе с ним пропал бы и выбор зала.
    if (data.hasHalls) return _buildHalls(data);

    if (!data.hasAnythingFree) return const SizedBox.shrink();

    return data.mode == BookingMode.daily
        ? _buildDaily(data)
        : _buildSlots(data);
  }

  /// Запись на услугу: полоса дней и плитки со временем.
  Widget _buildSlots(BookingAvailability data) {
    final days = data.days.where((d) => d.isWorking && d.hasFreeSlots).toList();
    if (days.isEmpty) return const SizedBox.shrink();

    return _shell(
      title: data.labels.bookTitle,
      children: [
        _buildDayStrip(days),
        const SizedBox(height: 14),
        _buildSlotGrid(),
        const SizedBox(height: 14),
        _buildActionButton(data),
      ],
    );
  }

  /// Ресторан с залами (22.09.2026): зал, гости, столик или банкет, потом
  /// день и время.
  Widget _buildHalls(BookingAvailability data) {
    final hall = data.selectedHall!;
    final guests = _guests ?? 2;
    final days = data.days.where((d) => d.isWorking && d.hasFreeSlots).toList();

    // Сколько гостей можно выбрать: за столик не больше самого большого
    // столика, целиком — не больше вместимости, если она задана (25.09.2026).
    // Ноль значит «ограничения нет», тогда разумный предел 500.
    final maxGuests = _wholeHall
        ? (hall.capacity > 0 ? hall.capacity : 500)
        : (hall.maxTable > 0 ? hall.maxTable : 500);
    final minGuests = _wholeHall ? hall.banquetMinGuests : 1;

    return _shell(
      title: data.labels.bookTitle,
      children: [
        _label('Зал'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in data.halls)
              _chip(
                text: h.name,
                selected: h.id == hall.id,
                onTap: () => _choose(hallId: h.id),
              ),
          ],
        ),
        if (hall.hasTables && hall.banquetEnabled) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _chip(
                  text: 'Столик',
                  selected: !_wholeHall,
                  expand: true,
                  // За столик не больше мест самого большого столика.
                  onTap: () => _choose(
                    wholeHall: false,
                    guests: guests > hall.maxTable ? hall.maxTable : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  text: 'Весь зал (банкет)',
                  selected: _wholeHall,
                  expand: true,
                  onTap: () => _choose(wholeHall: true),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _label('Сколько гостей')),
            _stepButton(
              Icons.remove,
              guests > minGuests ? () => _choose(guests: guests - 1) : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$guests',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _stepButton(
              Icons.add,
              guests < maxGuests ? () => _choose(guests: guests + 1) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _hallHint(hall, guests),
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (_isReloading) ...[
          const LinearProgressIndicator(minHeight: 2, color: activeIconColor),
          const SizedBox(height: 12),
        ],
        if (days.isEmpty)
          const Text(
            'В этом зале на ближайшие дни свободного времени нет. '
            'Попробуйте другой зал или другое число гостей.',
            style: TextStyle(color: textSecondary, fontSize: 14),
          )
        else ...[
          _buildDayStrip(days),
          const SizedBox(height: 14),
          _buildSlotGrid(),
          const SizedBox(height: 14),
          _buildActionButton(data),
        ],
      ],
    );
  }

  String _hallHint(BookingHall hall, int guests) {
    if (_wholeHall) {
      // Часы и вместимость показываем, только если их задали: у ресторанного
      // банкета длительность жёсткая, у переговорной её нет (25.09.2026).
      final parts = <String>[
        if (hall.banquetHours > 0) 'на ${hall.banquetHours} ч',
        if (hall.banquetMinGuests > 1) 'от ${hall.banquetMinGuests} гостей',
        if (hall.capacity > 0) 'до ${hall.capacity} гостей',
      ];

      final about = parts.isEmpty ? '' : ' ${parts.join(', ')}';

      return 'Бронируете целиком$about. Владелец подтвердит бронь.';
    }

    final tables = hall.tables
        .map((t) => 'на ${t.seats}: ${t.count}')
        .join(', ');

    final more = hall.banquetEnabled && guests >= hall.maxTable
        ? ' Для большой компании выберите «Весь зал».'
        : '';

    return 'Столик подберём под число гостей. Столики $tables.$more';
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      );

  Widget _chip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    bool expand = false,
  }) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? activeIconColor : secondaryBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : textSecondary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: _isReloading ? null : onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: onTap == null ? textMuted : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Посуточное жильё: календарь ночей и кнопка.
  Widget _buildDaily(BookingAvailability data) {
    return _shell(
      title: 'Забронировать',
      children: [
        BookingNightsPicker(
          availability: data,
          firstNight: _firstNight,
          lastNight: _lastNight,
          onNightTap: (night) => _onNightTap(data, night),
        ),
        const SizedBox(height: 14),
        _buildDailySummary(data),
        const SizedBox(height: 12),
        _buildDailyButton(data),
      ],
    );
  }

  Widget _shell({required String title, required List<Widget> children}) {
    return Container(
      // Отступ снизу держим внутри блока, а не в карточке: когда бронь не
      // подключена, виджет исчезает целиком и лишнего пробела не остаётся.
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(left: 9, right: 9, top: 8, bottom: 14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDayStrip(List<BookingDay> days) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _selectedDay != null &&
              _isSameDate(day.date, _selectedDay!.date);

          return GestureDetector(
            onTap: () => setState(() {
              _selectedDay = day;
              // Слот от прошлого дня к новому дню не относится.
              _selectedSlot = null;
            }),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? activeIconColor : secondaryBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayShort(day.date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.date.day}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    _monthShort(day.date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid() {
    final day = _selectedDay;
    if (day == null) {
      return const Text(
        'Выберите день',
        style: TextStyle(color: textSecondary, fontSize: 14),
      );
    }

    // Занятые слоты показываем зачёркнутыми, а не прячем: так видно, что
    // время у мастера вообще есть, просто разобрано.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: day.slots.map((slot) {
        // Сравниваем по исходной строке сервера: она уникальна и не зависит
        // от того, как мы разобрали время.
        final isSelected =
            _selectedSlot != null && _selectedSlot!.startsAtRaw == slot.startsAtRaw;

        return GestureDetector(
          onTap: slot.isFree
              ? () => setState(() => _selectedSlot = slot)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeIconColor
                  : (slot.isFree ? secondaryBackground : primaryBackground),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? activeIconColor : Colors.transparent,
              ),
            ),
            child: Text(
              _time(slot.startsAt),
              style: TextStyle(
                color: slot.isFree ? Colors.white : textMuted,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                decoration:
                    slot.isFree ? TextDecoration.none : TextDecoration.lineThrough,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(BookingAvailability data) {
    final slot = _selectedSlot;

    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: slot == null ? secondaryBackground : activeIconColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: slot == null ? null : () => _openConfirm(data, slot),
        child: Text(
          slot == null
              ? 'Выберите время'
              : data.labels.button(_time(slot.startsAt)),
          style: TextStyle(
            color: slot == null ? textSecondary : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Нажатие по ночи в календаре.
  ///
  /// Первое касание задаёт заезд, второе выезд. Касание раньше заезда
  /// начинает выбор заново: человек чаще уточняет начало, чем хочет
  /// «расширить промежуток назад».
  void _onNightTap(BookingAvailability data, BookingNight night) {
    final first = _firstNight;

    if (first == null || _lastNight != null || night.date.isBefore(first.date)) {
      setState(() {
        _firstNight = night;
        _lastNight = null;
      });
      return;
    }

    // Промежуток должен быть свободен ЦЕЛИКОМ. Занятая ночь посередине не
    // повод молча подрезать выбор: человек хотел неделю, а получил бы три дня
    // и не заметил. Честнее сказать и начать заново с этой даты.
    final between = data.nights.where((n) =>
        !n.date.isBefore(first.date) && !n.date.isAfter(night.date));

    final busy = between.where((n) => !n.isFree).toList();

    if (busy.isNotEmpty) {
      SnackBarHelper.showWarning(
        context,
        'В этом промежутке есть занятые ночи. Выберите другие даты.',
      );

      setState(() {
        _firstNight = night;
        _lastNight = null;
      });
      return;
    }

    setState(() => _lastNight = night);
  }

  /// Сколько ночей выбрано. Одна выбранная дата это одна ночь: заезд сегодня,
  /// выезд завтра.
  int get _nightsCount {
    final first = _firstNight;
    if (first == null) return 0;

    final last = _lastNight ?? first;

    return last.date.difference(first.date).inDays + 1;
  }

  Widget _buildDailySummary(BookingAvailability data) {
    final first = _firstNight;

    if (first == null) {
      return const Text(
        'Выберите дату заезда',
        style: TextStyle(color: textSecondary, fontSize: 14),
      );
    }

    final last = _lastNight ?? first;
    final checkOutDate = last.date.add(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow(
          Icons.login,
          'Заезд ${_humanDate(first.date)}'
          '${data.checkInTime == null ? '' : ', с ${data.checkInTime}'}',
        ),
        const SizedBox(height: 6),
        _summaryRow(
          Icons.logout,
          'Выезд ${_humanDate(checkOutDate)}'
          '${data.checkOutTime == null ? '' : ', до ${data.checkOutTime}'}',
        ),
        const SizedBox(height: 6),
        _summaryRow(Icons.nightlight_round, _nightsLabel(_nightsCount)),
        if (_lastNight == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Выберите дату выезда или бронируйте одну ночь.',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: activeIconColor, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyButton(BookingAvailability data) {
    final first = _firstNight;

    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: first == null ? secondaryBackground : activeIconColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: first == null ? null : () => _openDailyConfirm(data),
        child: Text(
          first == null
              ? 'Выберите даты'
              : 'Забронировать, ${_nightsLabel(_nightsCount)}',
          style: TextStyle(
            color: first == null ? textSecondary : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _openDailyConfirm(BookingAvailability data) async {
    final first = _firstNight;
    if (first == null) return;

    final last = _lastNight ?? first;

    // Границы берём из крайних ночей: начало первой это заезд, конец
    // последней это выезд. Строки отправляем как есть, без пересчёта поясов.
    await _openConfirmScreen(
      data: data,
      startsAt: first.startsAt,
      endsAt: last.endsAt,
      startsAtRaw: first.startsAtRaw,
      endsAtRaw: last.endsAtRaw,
    );
  }

  Future<void> _openConfirm(BookingAvailability data, BookingSlot slot) async {
    // Календарь публичный, а бронь требует входа. Проверку делает общий
    // метод ниже: она нужна обоим режимам.
    await _openConfirmScreen(
      data: data,
      startsAt: slot.startsAt,
      endsAt: slot.endsAt,
      startsAtRaw: slot.startsAtRaw,
      endsAtRaw: slot.endsAtRaw,
    );
  }

  /// Экран подтверждения, общий для обоих режимов.
  Future<void> _openConfirmScreen({
    required BookingAvailability data,
    required DateTime startsAt,
    required DateTime endsAt,
    required String startsAtRaw,
    required String endsAtRaw,
  }) async {
    final token = await TokenService.getCurrentToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы забронировать время',
      );
      return;
    }

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          startsAt: startsAt,
          endsAt: endsAt,
          startsAtRaw: startsAtRaw,
          endsAtRaw: endsAtRaw,
          needsConfirmation: data.needsConfirmation,
          maxGuests: data.maxGuests,
          title: data.labels.confirmTitle,
          hallId: data.hasHalls ? _hallId : null,
          wholeHall: _wholeHall,
          fixedGuests: data.hasHalls ? _guests : null,
          place: data.hasHalls
              ? '${data.selectedHall!.name}, ${_wholeHall ? 'весь зал' : 'столик'}'
              : null,
        ),
      ),
    );

    if (!mounted) return;

    // Перечитываем календарь в двух случаях: бронь создана (время стало
    // занято) и его увели у нас из-под рук (экран вернул false после 409).
    if (created != null) {
      setState(() {
        _isLoading = true;
        _selectedSlot = null;
      });
      await _load();
    }
  }

  String _nightsLabel(int nights) {
    final last = nights % 10;
    final lastTwo = nights % 100;

    if (last == 1 && lastTwo != 11) return '$nights ночь';
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
      return '$nights ночи';
    }
    return '$nights ночей';
  }

  String _humanDate(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]}';
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _weekdayShort(DateTime date) {
    const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return names[(date.weekday - 1).clamp(0, 6)];
  }

  String _monthShort(DateTime date) {
    const names = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return names[(date.month - 1).clamp(0, 11)];
  }
}
