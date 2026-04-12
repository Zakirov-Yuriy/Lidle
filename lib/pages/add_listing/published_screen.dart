import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';

class PublishedScreen extends StatelessWidget {
  final UserAdvert? advert;

  const PublishedScreen({
    super.key,
    this.advert,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Лого ────────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(
                // left: 20,
                // top: 12,
                right: 20,
              ),
              child: const Header(),
            ),
            _buildSecondaryNav(context),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildPublishedCard(),
                    const SizedBox(height: 12),
                    _buildListingCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Назад / Отмена ──────────────────────────────────────────────────────
  Widget _buildSecondaryNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              // Гарантированный переход на MyListingsScreen и очистка стека
              Navigator.of(context).pushNamedAndRemoveUntil(
                MyListingsScreen.routeName,
                (route) => false,
              );
            },
            child: Row(
              children: const [
                Icon(
                  Icons.chevron_left,
                  color: Color(0xFF4FA3E3),
                  size: 22,
                ),
                SizedBox(width: 2),
                Text(
                  'Назад',
                  style: TextStyle(
                    color: Color(0xFF4FA3E3),
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // Гарантированный переход на MyListingsScreen и очистка стека
              Navigator.of(context).pushNamedAndRemoveUntil(
                MyListingsScreen.routeName,
                (route) => false,
              );
            },
            child: const Text(
              'Отмена',
              style: TextStyle(
                color: Color(0xFF4FA3E3),
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Карточка «Объявление опубликовано» ──────────────────────────────────
  Widget _buildPublishedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Ваше объявление опубликовано ЛИДЛЕ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Вы можете поделиться ссылкой на товар со своими '
            'друзьями или потенциальными покупателями, удобным '
            'для вас способом. Так быстрее произойдет сделка.',
            style: TextStyle(
              color: Color(0xFF8E8E9E),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Карточка объявления ─────────────────────────────────────────────────
  Widget _buildListingCard(BuildContext context) {
    if (advert == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'Объявление не найдено',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Форматируем цену
    final priceText = (advert!.price != null && advert!.price!.isNotEmpty)
        ? '${advert!.price} ₽'
        : 'Договорная';

    // Получаем основное описание (название)
    final title = advert!.name ?? 'Без названия';

    // Получаем изображение
    final imageUrl = advert!.thumbnail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Фото
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 100,
              height: 80,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2C3E50),
                                Color(0xFF3D5A6E),
                                Color(0xFF4A6C82),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2C3E50),
                            Color(0xFF3D5A6E),
                            Color(0xFF4A6C82),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 14),

          // Данные объявления
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // Конвертируем UserAdvert в Listing
                    final listing = Listing(
                      id: advert!.id.toString(),
                      slug: advert!.slug,
                      imagePath: advert!.thumbnail ?? '',
                      title: advert!.name ?? 'Без названия',
                      price: advert!.price ?? 'Договорная',
                      location: advert!.address ?? 'Адрес не указан',
                      date: advert!.createdAt ?? '',
                      images: advert!.thumbnail != null
                          ? [advert!.thumbnail!]
                          : [],
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MiniPropertyDetailsScreen(listing: listing),
                      ),
                    );
                  },
                  child: Row(
                    children: const [
                      Text(
                        'Перейти',
                        style: TextStyle(
                          color: Color(0xFF4FA3E3),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFF4FA3E3),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
