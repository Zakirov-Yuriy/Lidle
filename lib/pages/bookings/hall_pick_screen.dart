import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/pages/bookings/hall_booking_screen.dart';
import 'package:lidle/widgets/components/header.dart';

/// Выбор зала перед бронью столика (29.09.2026).
///
/// Показывается, когда у заведения НЕСКОЛЬКО залов: основной, VIP, летняя
/// терраса. Если зал один, экран пропускается и сразу открывается схема:
/// выбор из одного пункта это лишнее нажатие.
///
/// Карточка зала показывает план, который загрузил продавец. У залов с PDF
/// вместо плана рисуется заглушка: PDF картинкой не показать, а пустая рамка
/// выглядит как поломка.
class HallPickScreen extends StatelessWidget {
  static const String routeName = '/booking-halls';

  const HallPickScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.halls,
    this.maxGuests,
  });

  final int advertId;
  final String advertTitle;
  final List<BookingHall> halls;

  /// Общий предел гостей объявления: нужен экрану зала.
  final int? maxGuests;

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
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      advertTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Выберите зал',
                style: TextStyle(
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
                itemCount: halls.length,
                itemBuilder: (_, index) => _HallCard(
                  hall: halls[index],
                  onTap: () => _open(context, halls[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, BookingHall hall) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HallBookingScreen(
          advertId: advertId,
          advertTitle: advertTitle,
          hall: hall,
          halls: halls,
          maxGuests: maxGuests,
        ),
      ),
    );
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
