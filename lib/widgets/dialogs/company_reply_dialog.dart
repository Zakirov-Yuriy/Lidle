// ============================================================
//  "Диалог ответа продавца на отзыв о компании"
//  Виден только владельцу компании на экране CompanyReviewsScreen.
//  Небольшое окно: текст ответа + кнопка «Сохранить».
//  Шлёт POST /v1/company/reviews/{reviewId}/reply { comment }.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/api_service.dart';

/// Показать диалог ответа на отзыв о компании.
/// Возвращает тело ответа сервера (`{ reply, replied_at, ... }`) при успехе,
/// либо null (если отменили/ошибка).
/// [initialText] — текущий ответ (если редактируем существующий).
Future<Map<String, dynamic>?> showCompanyReplyDialog({
  required BuildContext context,
  required int reviewId,
  String? initialText,
  String? token,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => CompanyReplyDialog(
      reviewId: reviewId,
      initialText: initialText,
      token: token,
    ),
  );
}

class CompanyReplyDialog extends StatefulWidget {
  /// Id отзыва, на который отвечаем.
  final int reviewId;

  /// Текущий текст ответа (при редактировании), иначе null/пусто.
  final String? initialText;

  /// Токен авторизации (ответ доступен только владельцу компании).
  final String? token;

  const CompanyReplyDialog({
    super.key,
    required this.reviewId,
    this.initialText,
    this.token,
  });

  @override
  State<CompanyReplyDialog> createState() => _CompanyReplyDialogState();
}

class _CompanyReplyDialogState extends State<CompanyReplyDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText ?? '');
  bool _submitting = false;

  static const _accent = Color(0xFF19D849);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст ответа')),
      );
      return;
    }

    setState(() => _submitting = true);

    final res = await ApiService.replyCompanyReview(
      widget.reviewId,
      comment: text,
      token: widget.token,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res != null && res['success'] == true) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(res);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ответ сохранён'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить ответ. Попробуйте позже.'),
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
            const Text(
              'Ответить на отзыв',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ваш ответ',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              autofocus: true,
              maxLines: 4,
              maxLength: 2000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Например: спасибо за отзыв!',
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
                          'Сохранить',
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
