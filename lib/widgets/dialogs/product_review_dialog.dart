// ============================================================
//  Отзыв о товаре (15.09.2026)
//
//  Оценка от одной до пяти звёзд плюс текст. Диалог тот же по виду, что у
//  отзыва на объявление и на компанию: человек не должен привыкать к трём
//  разным окнам ради одного и того же действия.
//
//  Отзыв оставляет только тот, кто купил товар и забрал заказ. Проверяет это
//  сервер; экран, который открывает диалог, спрашивает у карточки признак
//  `can_review` и не показывает кнопку тому, кому она ответит отказом.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/services/products_service.dart';

/// Показать диалог отзыва о товаре. Возвращает true, если отзыв сохранён.
Future<bool?> showProductReviewDialog({
  required BuildContext context,
  required int productId,
  required String title,
  ProductReview? existing,
  int initialRating = 0,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => ProductReviewDialog(
      productId: productId,
      title: title,
      existing: existing,
      initialRating: initialRating,
    ),
  );
}

class ProductReviewDialog extends StatefulWidget {
  final int productId;

  /// Название товара для заголовка.
  final String title;

  /// Свой прежний отзыв: диалог открывается заполненным, и человек правит
  /// написанное, а не пишет заново.
  final ProductReview? existing;

  /// Оценка, выбранная звёздами до открытия диалога.
  final int initialRating;

  const ProductReviewDialog({
    super.key,
    required this.productId,
    required this.title,
    this.existing,
    this.initialRating = 0,
  });

  @override
  State<ProductReviewDialog> createState() => _ProductReviewDialogState();
}

class _ProductReviewDialogState extends State<ProductReviewDialog> {
  late int _rating =
      (widget.existing?.rating ?? widget.initialRating).clamp(0, 5);

  late final TextEditingController _controller =
      TextEditingController(text: widget.existing?.comment ?? '');

  bool _submitting = false;

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

    final error = await ProductsService.submitReview(
      widget.productId,
      rating: _rating,
      comment: _controller.text,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (error == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Спасибо за отзыв!'),
          backgroundColor: Colors.green,
        ),
      );

      return;
    }

    // Причину показываем целиком: чаще всего это «отзыв можно оставить после
    // того, как заберёте заказ», и человеку надо понять, чего он ждёт.
    // Диалог не закрываем, текст остаётся.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

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
            Text(
              isEdit ? 'Изменить отзыв' : 'Отзыв о товаре',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),

            const SizedBox(height: 18),

            const Text(
              'Ваша оценка',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;

                return GestureDetector(
                  onTap:
                      _submitting ? null : () => setState(() => _rating = value),
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

            const Text(
              'Что скажете о товаре',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              maxLines: 4,
              maxLength: 2000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Подошёл ли размер, совпало ли с описанием',
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

            const SizedBox(height: 4),
            const Text(
              'Оценки ниже четырёх звёзд видит только продавец.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeIconColor,
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
                      : Text(
                          isEdit ? 'Сохранить' : 'Отправить',
                          style: const TextStyle(color: Colors.white),
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
