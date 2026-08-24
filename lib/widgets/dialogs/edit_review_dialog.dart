// ============================================================
//  "Диалог редактирования своего отзыва"
//  Оценка (1..5 звёзд) + текст. Шлёт PUT /v1/reviews/{id}.
//  Править может только автор — это проверяет бэк.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/api_service.dart';

/// Показать диалог редактирования отзыва.
/// Возвращает true, если изменения сохранены.
Future<bool?> showEditReviewDialog({
  required BuildContext context,
  required int reviewId,
  required int initialRating,
  String? initialComment,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => EditReviewDialog(
      reviewId: reviewId,
      initialRating: initialRating,
      initialComment: initialComment,
    ),
  );
}

class EditReviewDialog extends StatefulWidget {
  final int reviewId;
  final int initialRating;
  final String? initialComment;

  const EditReviewDialog({
    super.key,
    required this.reviewId,
    required this.initialRating,
    this.initialComment,
  });

  @override
  State<EditReviewDialog> createState() => _EditReviewDialogState();
}

class _EditReviewDialogState extends State<EditReviewDialog> {
  static const _star = Color(0xFFF5B301);

  late int _rating = widget.initialRating.clamp(0, 5);
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialComment ?? '');

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Поставьте оценку');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ApiService.updateAdvertReview(
      widget.reviewId,
      rating: _rating,
      comment: _controller.text,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _submitting = false;
        // Чаще всего это 422 из-за контактов в тексте — бэк запрещает
        // телефоны, почту и ссылки в отзыве.
        _error = 'Не удалось сохранить. Проверьте текст: '
            'телефоны, почта и ссылки в отзыве запрещены.';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Изменить отзыв',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Оценка',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (index) {
                final filled = index < _rating;
                return GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: _star,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              maxLines: 5,
              minLines: 3,
              maxLength: 400,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Текст отзыва',
                hintStyle: const TextStyle(color: Colors.white54),
                counterStyle: const TextStyle(color: Colors.white38),
                fillColor: Colors.white10,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF009EE2),
                          ),
                        )
                      : const Text(
                          'Сохранить',
                          style: TextStyle(color: Color(0xFF009EE2)),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
