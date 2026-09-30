// ============================================================
//  Посуточная бронь: домик и даты (30.09.2026)
// ============================================================
//
// Тот же путь, что и у ресторана, только вместо часа и стола человек выбирает
// даты заезда и выезда, а единицу берёт целиком: дом на места не делится.
//
// Экран отдельный, а не блок внутри объявления: по макету бронь везде идёт
// своей дорогой — карточка из ленты ведёт сюда, отсюда к подтверждению, а
// само объявление с фотографиями и описанием открывается по названию сверху.
//
// Одна дата это одна ночь: заезд сегодня, выезд завтра. Второе касание по
// календарю ставит выезд, и промежуток должен быть свободен целиком: занятая
// ночь посередине не повод молча подрезать выбор.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/models/bookings/booking_labels.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/pages/bookings/booking_flow.dart';
import 'package:lidle/pages/bookings/table_booking_screen.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/bookings/booking_nights_picker.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

class DailyBookingScreen extends StatefulWidget {
  static const String routeName = '/booking-daily';

  const DailyBookingScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.hall,
    required this.halls,
    this.maxGuests,
    this.listing,
  });

  final int advertId;
  final String advertTitle;

  /// Выбранная единица: домик, комната, коттедж.
  final BookingHall hall;

  /// Все единицы объявления: по ним работает «Сменить».
  final List<BookingHall> halls;

  final int? maxGuests;

  /// Объявление, из карточки которого пришли: по названию сверху человек
  /// открывает его и смотрит фотографии, описание и отзывы.
  final Listing? listing;

  @override
  State<DailyBookingScreen> createState() => _DailyBookingScreenState();
}

class _DailyBookingScreenState extends State<DailyBookingScreen> {
  late BookingHall _hall = widget.hall;
  late List<BookingHall> _halls = widget.halls;

  BookingAvailability? _availability;

  BookingNight? _firstNight;
  BookingNight? _lastNight;

  int _guests = 1;

  bool _isLoading = true;

  /// Горизонт запроса. Дальше сервер всё равно обрежет по настройкам
  /// объявления, а календарь без края выглядит как обещание.
  static const int _horizonDays = 62;

  @override
  void initState() {
    super.initState();
    BookingsService.changed.addListener(_onBookingsChanged);
    _load();
  }

  @override
  void dispose() {
    BookingsService.changed.removeListener(_onBookingsChanged);
    super.dispose();
  }

  /// Где-то создали или отменили бронь: занятость изменилась.
  void _onBookingsChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();

    final data = await BookingsService.availability(
      widget.advertId,
      from: now,
      to: now.add(const Duration(days: _horizonDays)),
      hallId: _hall.id,
    );

    if (!mounted) return;

    setState(() {
      _availability = data;

      if (data != null && data.halls.isNotEmpty) {
        _halls = data.halls;
        _hall = data.selectedHall ?? _hall;
      }

      // Выбранные ночи держим, только если они свободны и в этой единице:
      // при смене домика занятость другая.
      if (_firstNight != null && !_stillFree(_firstNight!)) {
        _firstNight = null;
        _lastNight = null;
      } else if (_lastNight != null && !_stillFree(_lastNight!)) {
        _lastNight = null;
      }

      _isLoading = false;
    });
  }

  bool _stillFree(BookingNight night) {
    final nights = _availability?.nights ?? const <BookingNight>[];

    for (final n in nights) {
      if (n.date == night.date) return n.isFree;
    }

    return false;
  }

  BookingLabels get _labels => _availability?.labels ?? BookingLabels.standard;

  /// Сколько гостей помещается: вместимость единицы, а если её не задали —
  /// общий предел объявления.
  int get _maxGuests {
    if (_hall.capacity > 0) return _hall.capacity;

    return _availability?.maxGuests ?? widget.maxGuests ?? 500;
  }

  /// Сколько ночей выбрано. Одна дата это одна ночь.
  int get _nightsCount {
    final first = _firstNight;

    if (first == null) return 0;

    final last = _lastNight ?? first;

    return last.date.difference(first.date).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final data = _availability;

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            _backRow(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 30),
                      children: [
                        _titleRow(),
                        const SizedBox(height: 12),
                        _hallRow(),
                        const SizedBox(height: 10),
                        for (final line in _hall.lines) _line(line),
                        const SizedBox(height: 12),
                        _guestsRow(),
                        const SizedBox(height: 16),
                        if (data == null)
                          const Text(
                            'Свободных дат сейчас нет. Загляните позже.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          )
                        else ...[
                          BookingNightsPicker(
                            availability: data,
                            firstNight: _firstNight,
                            lastNight: _lastNight,
                            onNightTap: (night) => _onNightTap(data, night),
                          ),
                          const SizedBox(height: 16),
                          _summary(data),
                        ],
                      ],
                    ),
            ),
            if (!_isLoading && data != null) _bookButton(data),
          ],
        ),
      ),
    );
  }

  Widget _backRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new, color: activeIconColor, size: 16),
            SizedBox(width: 4),
            Text('Назад', style: TextStyle(color: activeIconColor, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// Название ведёт в само объявление: фотографии, описание и отзывы живут
  /// там, а не здесь.
  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openAdvert,
        child: Row(
          children: [
            Flexible(
              child: Text(
                widget.advertTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.listing != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, color: textSecondary, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  void _openAdvert() {
    final listing = widget.listing;

    if (listing == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBookingStepRoute),
        builder: (_) => MiniPropertyDetailsScreen(listing: listing),
      ),
    );
  }

  /// Название единицы и «Сменить»: второе показываем, только если единиц
  /// правда несколько.
  Widget _hallRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _hall.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_halls.length > 1)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _changeHall,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Сменить', style: TextStyle(color: activeIconColor, fontSize: 15)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios, color: activeIconColor, size: 13),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _changeHall() async {
    final picked = await showModalBottomSheet<BookingHall>(
      context: context,
      backgroundColor: formBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _labels.unitPick,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final hall in _halls)
              ListTile(
                title: Text(
                  hall.name,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
                subtitle: hall.capacity > 0
                    ? Text(
                        'До ${hall.capacity} гостей',
                        style: const TextStyle(color: textSecondary, fontSize: 13),
                      )
                    : null,
                trailing: hall.id == _hall.id
                    ? const Icon(Icons.check, color: activeIconColor)
                    : null,
                onTap: () => Navigator.of(sheet).pop(hall),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked.id == _hall.id || !mounted) return;

    setState(() {
      _hall = picked;
      _firstNight = null;
      _lastNight = null;
      _guests = _guests.clamp(1, picked.capacity > 0 ? picked.capacity : 500);
    });

    await _load();
  }

  Widget _line(BookingHallLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${line.title}: ',
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            TextSpan(
              text: line.value,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guestsRow() {
    final max = _maxGuests;

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Сколько гостей',
            style: TextStyle(color: textPrimary, fontSize: 15),
          ),
        ),
        _step(Icons.remove, _guests > 1 ? () => setState(() => _guests--) : null),
        SizedBox(
          width: 44,
          child: Text(
            '$_guests',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _step(Icons.add, _guests < max ? () => setState(() => _guests++) : null),
      ],
    );
  }

  Widget _step(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: onTap == null ? textMuted : textPrimary, size: 20),
        ),
      );

  void _onNightTap(BookingAvailability data, BookingNight night) {
    final first = _firstNight;

    if (first == null || _lastNight != null || night.date.isBefore(first.date)) {
      setState(() {
        _firstNight = night;
        _lastNight = null;
      });

      return;
    }

    // Промежуток должен быть свободен целиком: человек хотел неделю, а
    // получил бы три дня и не заметил.
    final between = data.nights.where(
      (n) => !n.date.isBefore(first.date) && !n.date.isAfter(night.date),
    );

    if (between.any((n) => !n.isFree)) {
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

  Widget _summary(BookingAvailability data) {
    final first = _firstNight;

    if (first == null) {
      return const Text(
        'Выберите дату заезда',
        style: TextStyle(color: textSecondary, fontSize: 14),
      );
    }

    final last = _lastNight ?? first;
    final checkOut = last.date.add(const Duration(days: 1));

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
          'Выезд ${_humanDate(checkOut)}'
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: activeIconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: textPrimary, fontSize: 14, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _bookButton(BookingAvailability data) {
    final ready = _firstNight != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 4, 25, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: ready ? const Color(0xFF3ECF6E) : textMuted),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: ready ? () => _goToBooking(data) : null,
          child: Text(
            _labels.bookingGo,
            style: TextStyle(
              color: ready ? const Color(0xFF3ECF6E) : textMuted,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _goToBooking(BookingAvailability data) async {
    final first = _firstNight;

    if (first == null) return;

    // Бронь требует входа: без этой проверки человек прошёл бы карточку и
    // форму и упёрся в отказ только на отправке (30.09.2026).
    final token = await TokenService.getCurrentToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы забронировать',
      );

      return;
    }

    final last = _lastNight ?? first;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBookingStepRoute),
        builder: (_) => TableBookingScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          hall: _hall,
          wholeUnit: true,
          labels: _labels,
          photos: widget.listing?.images ?? const [],
          startsAt: first.startsAt,
          endsAt: last.endsAt,
          startsAtRaw: first.startsAtRaw,
          endsAtRaw: last.endsAtRaw,
          needsConfirmation: data.needsConfirmation,
          maxGuests: _maxGuests,
          guests: _guests,
          nights: _nightsCount,
          checkInTime: data.checkInTime,
          checkOutTime: data.checkOutTime,
        ),
      ),
    );

    if (!mounted) return;

    // Даты заняли, пока человек заполнял форму: перечитываем календарь.
    if (result == false) await _load();
  }

  String _humanDate(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  String _nightsLabel(int count) {
    final tail = count % 10;
    final hundred = count % 100;

    if (tail == 1 && hundred != 11) return '$count ночь';

    if (tail >= 2 && tail <= 4 && (hundred < 12 || hundred > 14)) {
      return '$count ночи';
    }

    return '$count ночей';
  }
}
