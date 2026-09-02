import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/pages/bookings/booking_confirm_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/token_service.dart';
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
  /// На сколько вперёд просим календарь. Сервер сам обрежет до горизонта
  /// объявления, если тот меньше.
  static const int _horizonDays = 30;

  BookingAvailability? _availability;
  bool _isLoading = true;

  BookingDay? _selectedDay;
  BookingSlot? _selectedSlot;

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

    // Посуточное жильё вторым шагом: заказчик просил начать с записи на
    // услуги. Рисовать половину экрана для аренды хуже, чем не рисовать
    // ничего: человек решит, что забронировать можно, и упрётся в пустоту.
    if (data.mode == BookingMode.daily) return const SizedBox.shrink();

    final days = data.days.where((d) => d.isWorking && d.hasFreeSlots).toList();
    if (days.isEmpty) return const SizedBox.shrink();

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
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              'Записаться',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildDayStrip(days),
          const SizedBox(height: 14),
          _buildSlots(),
          const SizedBox(height: 14),
          _buildActionButton(data),
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

  Widget _buildSlots() {
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

  Future<void> _openConfirm(BookingAvailability data, BookingSlot slot) async {
    // Календарь публичный, а бронь требует входа. Проверяем здесь, чтобы
    // человек не заполнил форму и только потом узнал, что надо войти.
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
          startsAt: slot.startsAt,
          endsAt: slot.endsAt,
          startsAtRaw: slot.startsAtRaw,
          endsAtRaw: slot.endsAtRaw,
          needsConfirmation: data.needsConfirmation,
          maxGuests: data.maxGuests,
        ),
      ),
    );

    if (!mounted) return;

    // Перечитываем календарь в двух случаях: бронь создана (слот стал
    // занят) и время увели у нас из-под рук (экран вернул false после 409).
    if (created != null) {
      setState(() {
        _isLoading = true;
        _selectedSlot = null;
      });
      await _load();
    }
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
