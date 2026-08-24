// ============================================================
//  "Карточка отзыва"
//  Один вид на три вкладки экрана «Отзывы»: мои отзывы, отзывы на мои
//  объявления, отзывы о моей компании. Что можно делать с отзывом,
//  решает review.kind (см. ReviewModel).
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/common/user_avatar.dart';
import 'package:lidle/widgets/dialogs/edit_review_dialog.dart';
import 'package:lidle/widgets/dialogs/reply_review_dialog.dart';
import 'package:lidle/widgets/dialogs/review_complaint_dialog.dart';

class ReviewCard extends StatefulWidget {
  final ReviewModel review;

  /// Вызывается после удаления отзыва или отправки ответа, чтобы родитель
  /// обновил список.
  final VoidCallback? onChanged;

  const ReviewCard({
    super.key,
    required this.review,
    this.onChanged,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  /// Ответ раскрыт (по умолчанию свёрнут, как было).
  bool _isExpanded = false;

  /// Локальная копия ответа: после отправки показываем сразу, не дожидаясь
  /// перезагрузки списка.
  String? _localReply;
  String? _localReplyDate;

  String? get _reply => _localReply ?? widget.review.reply;
  String? get _replyDate => _localReplyDate ?? widget.review.replyDate;
  bool get _hasReply => (_reply ?? '').trim().isNotEmpty;

  /// Подтверждение и удаление собственного отзыва (DELETE /v1/reviews/{id}).
  Future<void> _confirmDeleteReview() async {
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

    final ok = await ApiService.deleteAdvertReview(
      reviewId: widget.review.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Отзыв удалён' : 'Не удалось удалить отзыв'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) widget.onChanged?.call();
  }

  /// Ответ на отзыв. Для отзыва о компании уходит на свой эндпоинт —
  /// разбирается внутри диалога по review.kind.
  Future<void> _openReplyDialog() async {
    final res = await showReplyReviewDialog(
      context: context,
      reviewId: widget.review.id,
      kind: widget.review.kind,
      initialText: _reply,
    );
    if (res == null || !mounted) return;

    setState(() {
      _localReply = res['reply']?.toString();
      _localReplyDate = _replyDate; // дату пересчитает бэк при перезагрузке
      _isExpanded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ответ сохранён'),
        backgroundColor: Colors.green,
      ),
    );
    widget.onChanged?.call();
  }

  /// Редактирование собственного отзыва (PUT /v1/reviews/{id}).
  Future<void> _openEditDialog() async {
    final saved = await showEditReviewDialog(
      context: context,
      reviewId: widget.review.id,
      initialRating: widget.review.rating.round(),
      initialComment: widget.review.text,
    );
    if (saved != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Отзыв изменён'),
        backgroundColor: Colors.green,
      ),
    );
    // Перечитываем список, чтобы показать новую оценку и текст.
    widget.onChanged?.call();
  }

  /// Жалоба на отзыв. Причины и адрес отличаются для объявления и компании.
  /// Для отзыва о компании бэку нужен company_id в пути — на этой вкладке
  /// компания моя, поэтому берём собственный id пользователя.
  void _openComplaintDialog() {
    final isCompany = widget.review.kind == ReviewKind.company;

    int? companyId;
    if (isCompany) {
      companyId = int.tryParse(
        UserService.getLocal('userId')?.toString().trim() ?? '',
      );
      if (companyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось определить компанию'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      builder: (_) => ReviewComplaintDialog(
        reviewId: widget.review.id,
        target: isCompany
            ? ReviewComplaintTarget.company
            : ReviewComplaintTarget.advert,
        companyId: companyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;

    return Card(
      margin: const EdgeInsets.only(right: 25, left: 25, top: 17, bottom: 20),
      color: formBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.only(
          right: 10.0,
          left: 10,
          top: 16,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Шапка: картинка, заголовок, дата, оценка ───
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumbnail(review),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.date,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          // Оценку показываем на всех вкладках: и на своих
                          // отзывах, и на полученных — как на сайте.
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
                                    index < review.rating
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

            // ─── Текст отзыва ───
            if (review.text.trim().isNotEmpty)
              Text(
                review.text,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              )
            else
              const Text(
                'Без комментария',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 14),

            const Divider(color: Color(0xFF474747), height: 0),

            // ─── Ответ на отзыв (сворачивается) ───
            if (_hasReply) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Row(
                  children: [
                    const Text(
                      '1 комментарий',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 26,
                    ),
                  ],
                ),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Ответ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if ((_replyDate ?? '').isNotEmpty)
                            Text(
                              _replyDate!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _reply!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // ─── Действия ───
            const SizedBox(height: 12),
            _actions(review),
          ],
        ),
      ),
    );
  }

  /// Превью объявления или аватар автора. Бэк отдаёт ссылку; если её нет
  /// или картинка не загрузилась — показываем прежнюю заглушку.
  Widget _thumbnail(ReviewModel review) {
    const double size = 67;
    final url = review.imageUrl;

    // Отзыв о компании — слева АВТОР отзыва, значит круглый аватар с общей
    // заглушкой проекта (default-photo.svg), а не превью объявления.
    if (review.kind == ReviewKind.company) {
      return UserAvatar(url: url, size: size);
    }

    final placeholder = Image.asset(
      'assets/reviews/reviews.png',
      width: 71,
      height: size,
      fit: BoxFit.cover,
    );

    if (url == null || !url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 71,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }

  /// Кнопки под отзывом. Набор зависит от вкладки:
  /// свой отзыв — только «Удалить» (редактирования нет на бэке);
  /// чужой отзыв на моё объявление или компанию — «Пожаловаться» и «Ответить».
  Widget _actions(ReviewModel review) {
    final buttons = <Widget>[];

    if (review.canReport) {
      buttons.add(
        Expanded(
          child: _actionButton(
            'Пожаловаться',
            Colors.red,
            _openComplaintDialog,
          ),
        ),
      );
    }

    if (review.canReply) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: _actionButton(
            _hasReply ? 'Изменить ответ' : 'Ответить',
            Colors.blue,
            _openReplyDialog,
          ),
        ),
      );
    }

    if (review.canDelete) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: _actionButton('Удалить', Colors.red, _confirmDeleteReview),
        ),
      );
      buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: _actionButton(
            'Редактировать',
            Colors.blue,
            _openEditDialog,
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(children: buttons);
  }

  Widget _actionButton(String text, Color color, VoidCallback onPressed) {
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
