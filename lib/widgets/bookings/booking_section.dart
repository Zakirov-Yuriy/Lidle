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
    );

    if (!mounted) return;

    setState(() {
      _availability = data;
      _isLoading = false;
      _selectedDay = _firstDayWithFreeSlots(data);
      _selectedSlot = null;
      _firstNight = null;
      _lastNight = null;
    });
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
    if (data == null || !data.hasAnythingFree) return const SizedBox.shrink();

    return data.mode == BookingMode.daily
        ? _buildDaily(data)
        : _buildSlots(data);
  }

  /// Запись на услугу: полоса дней и плитки со временем.
  Widget _buildSlots(BookingAvailability data) {
    final days = data.days.where((d) => d.isWorking && d.hasFreeSlots).toList();
    if (days.isEmpty) return const SizedBox.shrink();

    return _shell(
      title: 'Записаться',
      children: [
        _buildDayStrip(days),
        const SizedBox(height: 14),
        _buildSlotGrid(),
        const SizedBox(height: 14),
        _buildActionButton(data),
      ],
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
              : 'Записаться на ${_time(slot.startsAt)}',
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
