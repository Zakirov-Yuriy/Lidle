import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/bookings/booking_flow.dart';
import 'package:lidle/pages/bookings/daily_booking_screen.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/models/bookings/booking_labels.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/pages/bookings/hall_booking_screen.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/widgets/components/header.dart';

/// Выбор зала (29.09.2026).
///
/// У заведения с залами карточка в выдаче ведёт сюда, а не в объявление:
/// человек пришёл забронировать стол, а не читать описание. Само объявление
/// открывается отсюда по названию сверху.
///
/// Один зал — экран не показывается вовсе, сразу открывается схема: выбор из
/// одного пункта это лишнее нажатие. Залов не оказалось (продавец убрал их,
/// пока человек листал выдачу) — открываем объявление, как раньше.
class HallPickScreen extends StatefulWidget {
  static const String routeName = '/booking-halls';

  const HallPickScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    this.listing,
  });

  final int advertId;
  final String advertTitle;

  /// Объявление, из карточки которого пришли: по нему открывается экран
  /// объявления по названию сверху.
  final Listing? listing;

  @override
  State<HallPickScreen> createState() => _HallPickScreenState();
}

class _HallPickScreenState extends State<HallPickScreen> {
  List<BookingHall> _halls = const [];

  /// Слова по роду заведения (29.09.2026): в ресторане зал со столиками, в
  /// барбершопе зал с креслами.
  BookingLabels _labels = BookingLabels.standard;
  int? _maxGuests;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Посуточный режим: единицу выбирают вместе с датами, а не с часом.
  bool _daily = false;

  Future<void> _load() async {
    final now = DateTime.now();

    final data = await BookingsService.availability(
      widget.advertId,
      from: now,
      to: now,
    );

    if (!mounted) return;

    final halls = data?.halls ?? const <BookingHall>[];

    // Залов нет (или бронь выключили): человеку нужно объявление.
    if (halls.isEmpty) {
      _openAdvert(replace: true);

      return;
    }

    // Посуточная бронь идёт своим экраном: там календарь ночей вместо часов
    // и единица берётся целиком (30.09.2026).
    _daily = data?.mode == BookingMode.daily;

    if (halls.length == 1) {
      _openHall(halls.first, halls, data?.maxGuests, replace: true);

      return;
    }

    setState(() {
      _halls = halls;
      _maxGuests = data?.maxGuests;
      _labels = data?.labels ?? BookingLabels.standard;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: activeIconColor))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Header(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openAdvert(),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.advertTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: textSecondary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Назад',
                            style: TextStyle(color: activeIconColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      _labels.unitPick,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _halls.length,
                      itemBuilder: (_, index) => _HallCard(
                        hall: _halls[index],
                        onTap: () => _openHall(_halls[index], _halls, _maxGuests),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openHall(
    BookingHall hall,
    List<BookingHall> halls,
    int? maxGuests, {
    bool replace = false,
  }) {
    final route = MaterialPageRoute<bool>(
      settings: const RouteSettings(name: kBookingStepRoute),
      builder: (_) => _daily
          ? DailyBookingScreen(
              advertId: widget.advertId,
              advertTitle: widget.advertTitle,
              hall: hall,
              halls: halls,
              maxGuests: maxGuests,
              listing: widget.listing,
            )
          : HallBookingScreen(
              advertId: widget.advertId,
              advertTitle: widget.advertTitle,
              hall: hall,
              halls: halls,
              maxGuests: maxGuests,
              listing: widget.listing,
            ),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);

      return;
    }

    Navigator.push(context, route);
  }

  /// Открыть само объявление. Без данных карточки открыть нечего: тогда
  /// просто уходим назад, в выдачу, откуда человек и пришёл.
  void _openAdvert({bool replace = false}) {
    final listing = widget.listing;

    if (listing == null) {
      if (replace) Navigator.of(context).pop();

      return;
    }

    // Карточка, открытая ИЗ пути брони, тоже его шаг (30.09.2026): иначе
    // после брони под ней остались бы экраны выбора зала с устаревшей схемой.
    final route = MaterialPageRoute(
      settings: const RouteSettings(name: kBookingStepRoute),
      builder: (_) => MiniPropertyDetailsScreen(listing: listing),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);

      return;
    }

    Navigator.push(context, route);
  }
}

class _HallCard extends StatelessWidget {
  const _HallCard({required this.hall, required this.onTap});

  final BookingHall hall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plan = hall.planImageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: plan != null
                  ? Image.network(
                      plan,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _NoPlan(),
                    )
                  : const _NoPlan(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hall.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: textPrimary, fontSize: 15),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: activeIconColor),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onTap,
            child: const Text(
              'Перейти',
              style: TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

/// Заглушка вместо плана: у зала его либо нет, либо он в PDF.
class _NoPlan extends StatelessWidget {
  const _NoPlan();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: secondaryBackground,
      alignment: Alignment.center,
      child: const Icon(Icons.map_outlined, color: textMuted, size: 32),
    );
  }
}
