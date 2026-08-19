import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/dialogs/reply_review_dialog.dart';
import 'package:lidle/widgets/dialogs/review_complaint_dialog.dart';
import 'package:lidle/core/logger.dart';

class ReviewCard extends StatefulWidget {
  final ReviewModel review;
  final bool isMyListingsTab;

  /// Необязательный колбэк — вызывается после успешного удаления отзыва,
  /// чтобы родитель мог обновить список.
  final VoidCallback? onChanged;

  const ReviewCard({
    super.key,
    required this.review,
    required this.isMyListingsTab,
    this.onChanged,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();

  /// Подтверждение и удаление собственного отзыва (DELETE /v1/reviews/{id}).
  Future<void> _confirmDeleteReview(int reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: primaryBackground,
        title: const Text('Удалить отзыв?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Это действие нельзя отменить.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ApiService.deleteAdvertReview(reviewId: reviewId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Отзыв удалён' : 'Не удалось удалить отзыв'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) widget.onChanged?.call();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 25, left: 25, top: 17, bottom: 35),
      color: formBackground, // Darker background for the card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.only(
          right: 10.0,
          left: 10,
          top: 16,
          bottom: 26,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Info
            Row(
              children: [
                Image.asset(
                  'assets/reviews/reviews.png',
                  width: 71,
                  height: 67,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.review.productName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.review.reviewDate,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),

                          if (!widget.isMyListingsTab)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Оценка',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < widget.review.rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Текст отзыва
            GestureDetector(
              onTap: () {
                // TODO: Реализовать функционал нажатия на текст отзыва
                // log.d('Отзыв нажат');
              },
              child: Text(
                widget.review.reviewText,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 18),

            const Divider(color: Color(0xFF474747), height: 0),

            // Comments Section
            if (widget.review.commentCount > 0) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      '${widget.review.commentCount} комментарий',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,

                      color: Colors.white70,
                      size: 26,
                    ),
                  ],
                ),
              ),
              if (_isExpanded && widget.review.commentAuthor != null) ...[
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 23,
                          backgroundImage: AssetImage(
                            'assets/profile_dashboard/Ellipse.png',
                          ), // Заполнитель для аватара автора комментария
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Text(
                                      widget.review.commentAuthor!,
                                      style: const TextStyle(
                                        color: Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ), // Blue color
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'в ответ Эмилия Л.',
                                      style: const TextStyle(
                                        color: Colors.white70, // Gray color
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  if (widget.review.commentDate != null)
                                    Text(
                                      widget.review.commentDate!,
                                      style: const TextStyle(
                                        color: Colors.white70, // Gray color
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (widget.review.commentText != null)
                  Text(
                    widget.review.commentText!,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Сообщение',
                    hintStyle: const TextStyle(color: Colors.white54),
                    fillColor: Colors.white10,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Реализовать отправку комментария
                    },
                    child: const Text(
                      'Отправить',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
            // Action Buttons
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.review.canEdit)
                  Expanded(
                    child: _buildFullWidthActionButton(
                      widget.isMyListingsTab ? 'Ответить' : 'Редактировать',
                      Colors.blue,
                      () {
                        if (widget.isMyListingsTab) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return const ReplyReviewDialog();
                            },
                          );
                        } else {
                          // TODO: Реализовать функцию редактирования
                        }
                      },
                    ),
                  ),
                const SizedBox(width: 10),
                if (widget.review.canDelete)
                  Expanded(
                    child: _buildFullWidthActionButton(
                      widget.isMyListingsTab ? 'Пожаловаться' : 'Удалить',
                      Colors.red,
                      () {
                        final reviewId = int.tryParse(widget.review.id);
                        if (reviewId == null) return;
                        if (widget.isMyListingsTab) {
                          // Жалоба на отзыв к объявлению.
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ReviewComplaintDialog(
                                reviewId: reviewId,
                                target: ReviewComplaintTarget.advert,
                              );
                            },
                          );
                        } else {
                          // Удаление собственного отзыва.
                          _confirmDeleteReview(reviewId);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthActionButton(
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 36),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

