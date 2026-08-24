// ============================================================
//  "Блок отзывов на карточке объявления"
//  Как на сайте: звёзды «Оставить отзыв» + список уже оставленных.
//  Данные: GET /v1/advertisements/{id}/reviews (публичный, пагинация).
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/pages/full_category_screen/advert_reviews_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/common/user_avatar.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/dialogs/review_dialog.dart';

class AdvertReviewsCard extends StatefulWidget {
  /// Объявление, к которому относится блок.
  final int advertId;

  /// Id владельца объявления — на своё объявление отзыв оставить нельзя.
  final String? ownerId;

  /// Название продавца для заголовка диалога отзыва.
  final String sellerName;

  const AdvertReviewsCard({
    super.key,
    required this.advertId,
    required this.sellerName,
    this.ownerId,
  });

  @override
  State<AdvertReviewsCard> createState() => _AdvertReviewsCardState();
}

class _AdvertReviewsCardState extends State<AdvertReviewsCard> {
  static const _star = Color(0xFFF5B301);

  /// Сколько отзывов показываем прямо в блоке; остальные — на отдельном экране.
  static const _previewCount = 3;

  List<ReviewModel> _reviews = const [];
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiService.getAdvertReviews(widget.advertId);
      if (!mounted) return;
      setState(() {
        _reviews = ReviewModel.listFromResponse(response, ReviewKind.received);
        _total = ReviewModel.totalFromResponse(response) ?? _reviews.length;
        _loading = false;
      });
    } catch (e) {
      log.d('Не удалось загрузить отзывы объявления: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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

    final sent = await showReviewDialog(
      context: context,
      advertId: widget.advertId,
      title: widget.sellerName.trim().isNotEmpty
          ? widget.sellerName.trim()
          : 'объявление',
      token: token,
      initialRating: rating,
    );

    if (sent == true && mounted) {
      // Перечитываем, чтобы новый отзыв сразу появился в блоке.
      setState(() => _loading = true);
      _load();
    }
  }

  void _openAllReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvertReviewsScreen(
          advertId: widget.advertId,
          advertTitle: widget.sellerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _reviews.take(_previewCount).toList();

    return Container(
      padding: const EdgeInsets.only(left: 9, right: 9, top: 8, bottom: 14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text(
            'Оставить отзыв',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final value = i + 1;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onStarTap(value),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.star, color: Colors.white38, size: 36),
                ),
              );
            }),
          ),

          if (_loading) ...[
            const SizedBox(height: 14),
            const Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (preview.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF474747), height: 0),
            const SizedBox(height: 12),
            Text(
              _total == 1 ? '1 отзыв' : '$_total ${_pluralReviews(_total)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...preview.map((r) => _reviewItem(r)),
            if (_total > preview.length) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _openAllReviews,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        'Все отзывы',
                        style: TextStyle(
                          color: Color(0xFF009EE2),
                          fontSize: 15,
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Color(0xFF009EE2), size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Компактный отзыв: аватар, имя, дата, звёзды, текст и ответ продавца.
  Widget _reviewItem(ReviewModel review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(url: review.imageUrl, size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            color: _star,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          review.date,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Ответ продавца',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if ((review.replyDate ?? '').isNotEmpty)
                        Text(
                          review.replyDate!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    review.reply!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _pluralReviews(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'отзыв';
    if ((count % 10 >= 2 && count % 10 <= 4) &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }
}
