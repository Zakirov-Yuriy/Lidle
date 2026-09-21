// ============================================================
//  "Диалог ответа на отзыв"
//  Один диалог на три случая: ответ владельца ОБЪЯВЛЕНИЯ на отзыв
//  (POST /v1/reviews/{id}/reply), ответ владельца КОМПАНИИ
//  (POST /v1/company/reviews/{id}/reply) и ответ ПРОДАВЦА на отзыв о товаре
//  (POST /v1/product-reviews/{id}/reply, с 21.09.2026). Куда слать, решают
//  kind и isProductReview.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/products_service.dart';

/// Показать диалог ответа на отзыв.
/// Возвращает тело ответа сервера (`{ reply, replied_at, ... }`) при успехе,
/// либо null, если отменили или не удалось отправить.
Future<Map<String, dynamic>?> showReplyReviewDialog({
  required BuildContext context,
  required int reviewId,
  required ReviewKind kind,
  String? initialText,
  bool isProductReview = false,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => ReplyReviewDialog(
      reviewId: reviewId,
      kind: kind,
      initialText: initialText,
      isProductReview: isProductReview,
    ),
  );
}

class ReplyReviewDialog extends StatefulWidget {
  /// Id отзыва, на который отвечаем.
  final int reviewId;

  /// Отзыв на объявление или на компанию — от этого зависит эндпоинт.
  final ReviewKind kind;

  /// Текущий текст ответа (если ответ уже был — перезапишем).
  final String? initialText;

  /// Отзыв о товаре: ответ уходит на ручку товаров (21.09.2026).
  final bool isProductReview;

  const ReplyReviewDialog({
    super.key,
    required this.reviewId,
    required this.kind,
    this.initialText,
    this.isProductReview = false,
  });

  @override
  State<ReplyReviewDialog> createState() => _ReplyReviewDialogState();
}

class _ReplyReviewDialogState extends State<ReplyReviewDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText ?? '');

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Напишите ответ');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Отзыв о компании отвечается своим эндпоинтом (компания определяется
    // по токену), отзыв на объявление — своим.
    final Map<String, dynamic>? res;

    if (widget.isProductReview) {
      res = await ProductsService.replyReview(widget.reviewId, comment: text);
    } else if (widget.kind == ReviewKind.company) {
      res = await ApiService.replyCompanyReview(widget.reviewId, comment: text);
    } else {
      res = await ApiService.replyAdvertReview(widget.reviewId, comment: text);
    }

    if (!mounted) return;

    if (res == null) {
      setState(() {
        _submitting = false;
        _error = 'Не удалось отправить ответ. Попробуйте ещё раз.';
      });
      return;
    }

    Navigator.of(context).pop(res);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = (widget.initialText ?? '').trim().isNotEmpty;

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
                Expanded(
                  child: Text(
                    isEditing ? 'Изменить ответ' : 'Ответить на отзыв',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              maxLines: 5,
              minLines: 3,
              maxLength: 2000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ваш ответ',
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
                          'Отправить',
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
