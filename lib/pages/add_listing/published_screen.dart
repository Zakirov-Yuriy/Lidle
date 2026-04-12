import 'package:flutter/material.dart';

class PublishedScreen extends StatelessWidget {
  const PublishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13131F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopNav(context),
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

  // ── Лого ────────────────────────────────────────────────────────────────
  Widget _buildTopNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        'LIDLE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
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
            onTap: () => Navigator.maybePop(context),
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
            onTap: () => Navigator.maybePop(context),
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
        color: const Color(0xFF1E1E2E),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
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
              // Замените на Image.network(...) или Image.asset(...)
              // когда будет реальное фото объявления:
              // child: Image.network(listingImageUrl, fit: BoxFit.cover),
              child: Container(
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
                const Text(
                  '3-к. квартира, 125,5 м², 5/17 эт.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '44 500 000 ₽',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '354 582 ₽ за м²',
                  style: TextStyle(
                    color: Color(0xFF6E6E7E),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // TODO: открыть объявление
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
