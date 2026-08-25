// ============================================================
//  "Блок отзывов на карточке объявления"
//  Как в блоке оценки на экране продавца: звёзды «Оставить отзыв»
//  и ссылка «Все отзывы» на отдельный экран со списком.
//  Сам список здесь не показываем — карточка объявления и так длинная.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/full_category_screen/advert_reviews_screen.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/dialogs/review_dialog.dart';

class AdvertReviewsCard extends StatefulWidget {
  /// Объявление, к которому относится блок.
  final int advertId;

  /// Id владельца объявления — на своё объявление отзыв оставить нельзя.
  final String? ownerId;

  /// Название продавца — идёт в заголовок диалога отзыва («Отзыв на …»).
  final String sellerName;

  /// Название самого объявления — идёт в заголовок экрана «Все отзывы».
  /// Это разные вещи: на экране отзывов объявления имя продавца ни при чём.
  final String advertTitle;

  const AdvertReviewsCard({
    super.key,
    required this.advertId,
    required this.sellerName,
    this.advertTitle = '',
    this.ownerId,
  });

  @override
  State<AdvertReviewsCard> createState() => _AdvertReviewsCardState();
}

class _AdvertReviewsCardState extends State<AdvertReviewsCard> {
  /// Подсвеченная оценка: как у продавца, звезда остаётся закрашенной после
  /// тапа, пока открыт диалог.
  int _selectedStars = 0;

  /// Своё ли это объявление — бэк отзыв на своё отклонит (422),
  /// поэтому диалог не открываем и сразу объясняем причину.
  bool get _isOwnAdvert {
    final me = UserService.getLocal('userId')?.toString().trim();
    final owner = widget.ownerId?.trim();
    return me != null &&
        me.isNotEmpty &&
        owner != null &&
        owner.isNotEmpty &&
        me == owner;
  }

  Future<void> _onStarTap(int rating) async {
    if (_isOwnAdvert) {
      SnackBarHelper.showWarning(
        context,
        'Нельзя оставить отзыв на своё объявление',
      );
      return;
    }

    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы оставить отзыв',
      );
      return;
    }

    setState(() => _selectedStars = rating);

    final sent = await showReviewDialog(
      context: context,
      advertId: widget.advertId,
      title: widget.sellerName.trim().isNotEmpty
          ? widget.sellerName.trim()
          : 'объявление',
      token: token,
      initialRating: rating,
    );

    if (!mounted) return;

    // Отзыв ушёл — показываем список, чтобы человек увидел свой отзыв.
    if (sent == true) {
      _openAllReviews();
    } else {
      setState(() => _selectedStars = 0);
    }
  }

  void _openAllReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvertReviewsScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          // Владельцу объявления на экране показываем «Ответить»,
          // остальным — «Пожаловаться».
          ownerId: widget.ownerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Оставить отзыв',
              style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: List.generate(
                5,
                (index) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Тап по звезде открывает диалог отзыва с этой оценкой.
                  onTap: () => _onStarTap(index + 1),
                  child: Icon(
                    Icons.star,
                    color: index < _selectedStars ? Colors.amber : Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 0),
            // Ссылка «Все отзывы» → экран со списком отзывов объявления.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openAllReviews,
              child: const Text(
                'Все отзывы',
                style: TextStyle(
                  color: activeIconColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
