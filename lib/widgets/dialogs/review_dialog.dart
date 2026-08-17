// ============================================================
//  "Диалог отзыва после звонка"
//  Показывается после того, как пользователь позвонил по объявлению.
//  Оценка (1..5 звёзд) + текст. Шлёт POST /advertisements/{id}/reviews.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/api_service.dart';

/// Показать диалог отзыва. Возвращает true, если отзыв успешно отправлен.
Future<bool?> showReviewDialog({
  required BuildContext context,
  required int advertId,
  required String title,
  String? token,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => ReviewDialog(
      advertId: advertId,
      title: title,
      token: token,
    ),
  );
}

class ReviewDialog extends StatefulWidget {
  /// Id объявления, к которому оставляем отзыв.
  final int advertId;

  /// Название продавца/компании для заголовка «Отзыв на …».
  final String title;

  /// Токен авторизации (отзыв требует регистрации).
  final String? token;

  const ReviewDialog({
    super.key,
    required this.advertId,
    required this.title,
    this.token,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 0;
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  static const _accent = Color(0xFF19D849);
  static const _star = Color(0xFFF5B301);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поставьте оценку')),
      );
      return;
    }

    setState(() => _submitting = true);

    final ok = await ApiService.submitAdvertReview(
      widget.advertId,
      rating: _rating,
      comment: _controller.text,
      token: widget.token,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Спасибо за отзыв!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить отзыв. Попробуйте позже.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Text(
              'Отзыв на ${widget.title}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),

            // Оценка
            const Text(
              'Оставить оценку',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;
                return GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _rating = value),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Icon(
                      value <= _rating ? Icons.star : Icons.star_border,
                      color: _star,
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),

            // Текст отзыва
            const Text(
              'Отзыв на звонок',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 2000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Напишите как прошёл звонок',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: formBackground,
                counterText: '',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Кнопки
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Отправить',
                          style: TextStyle(color: Colors.white),
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
