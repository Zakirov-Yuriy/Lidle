// ============================================================
//  Оценка курьера (18.09.2026)
// ============================================================
//
// Звёзды плюс текст, как у отзыва о товаре: человек не должен привыкать к
// разным окнам ради одного и того же действия.
//
// Оценивают ДОСТАВКУ, а не человека вообще, поэтому оценка привязана к заказу,
// и поставить её можно только после получения. Признак приходит с сервера, а
// экран, который открывает диалог, не показывает звёзды тому, кому сервер
// ответит отказом.
//
// Свою оценку можно переписать: человек передумал, а не получил второй заказ.

import 'package:flutter/material.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/orders_service.dart';

/// Показать диалог оценки курьера. Возвращает true, если оценка сохранена.
Future<bool?> showCourierReviewDialog({
  required BuildContext context,
  required OrderModel order,
  int initialRating = 0,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => CourierReviewDialog(
      order: order,
      initialRating: initialRating,
    ),
  );
}

class CourierReviewDialog extends StatefulWidget {
  final OrderModel order;

  /// Оценка, выбранная звёздами до открытия диалога.
  final int initialRating;

  const CourierReviewDialog({
    super.key,
    required this.order,
    this.initialRating = 0,
  });

  @override
  State<CourierReviewDialog> createState() => _CourierReviewDialogState();
}

class _CourierReviewDialogState extends State<CourierReviewDialog> {
  late final TextEditingController _text;
  late int _rating;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final mine = widget.order.courier;

    _rating = widget.initialRating > 0
        ? widget.initialRating
        : (mine?.myRating ?? 0);

    _text = TextEditingController(text: mine?.myReviewText ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating < 1) {
      setState(() => _error = 'Поставьте оценку от одной до пяти звёзд');

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await OrdersService.reviewCourier(
      widget.order.id,
      rating: _rating,
      text: _text.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });

      return;
    }

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Спасибо, оценка сохранена')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courier = widget.order.courier;
    final name = (courier?.name.isNotEmpty ?? false)
        ? courier!.name
        : (widget.order.courierName ?? 'курьера');

    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      (courier?.myRating ?? 0) > 0
                          ? 'Изменить оценку'
                          : 'Оценить курьера',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  splashRadius: 20,
                ),
              ],
            ),
            Text(
              name,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(5, (index) {
                final value = index + 1;

                return GestureDetector(
                  onTap: () => setState(() {
                    _rating = value;
                    _error = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      _rating >= value ? Icons.star : Icons.star_border,
                      color: _rating >= value
                          ? const Color(0xFFFFB800)
                          : textMuted,
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 4,
              maxLength: 2000,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Как прошла доставка? Это необязательно',
                hintStyle: const TextStyle(color: textMuted, fontSize: 14),
                counterStyle: const TextStyle(color: textMuted, fontSize: 11),
                filled: true,
                fillColor: secondaryBackground,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFE05B5B),
                    fontSize: 13,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      inherit: false,
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                OutlinedButton(
                  onPressed: _saving ? null : _save,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: activeIconColor, width: 1.4),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Отправить',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                          ),
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

/// Строка «Рейтинг» со звёздами (18.09.2026).
///
/// Одна и та же на экране курьера и в подробностях заказа: это одно и то же
/// действие, и два разных вида читались бы как два разных смысла.
///
/// Звёзды показывают оценку курьера и одновременно служат кнопкой: нажал на
/// третью — диалог откроется с тремя. Так же сделано у отзывов о товаре.
///
/// Пока заказ не получен, звёзды не нажимаются, а под ними объяснение с
/// сервера: «Оценить курьера можно после получения заказа». Молча не отвечать
/// на нажатие нельзя, человек решит, что приложение сломалось.
Widget courierRatingRow(
  BuildContext context, {
  required OrderModel order,
  required Future<void> Function() onChanged,
  double size = 18,
}) {
  final courier = order.courier;
  final value = courier?.rating ?? 0;
  final canReview = courier?.canReview ?? false;

  Future<void> tap(int stars) async {
    if (!canReview) {
      final why = (courier?.reviewNotAllowed ?? '').trim();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            why.isEmpty ? 'Оценить курьера можно после получения заказа' : why,
          ),
        ),
      );

      return;
    }

    final saved = await showCourierReviewDialog(
      context: context,
      order: order,
      initialRating: stars,
    );

    if (saved == true) await onChanged();
  }

  // Подпись, оценка и звёзды стоят одной строкой (правка заказчика
  // 18.09.2026). Wrap, а не Row: на узком экране или при крупных звёздах
  // строка перенесётся, а не упрётся в край с жёлтой полосой переполнения.
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      const Text(
        'Рейтинг',
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
      if ((courier?.reviewsCount ?? 0) > 0)
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final stars = index + 1;

          // Своя оценка важнее средней: поставив четыре звезды, человек
          // должен видеть свои четыре, а не среднее по всем поездкам.
          final mine = courier?.myRating ?? 0;
          final shown = mine > 0 ? mine.toDouble() : value;
          final filled = shown >= stars - 0.5;

          return GestureDetector(
            onTap: () => tap(stars),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                filled ? Icons.star : Icons.star_border,
                color: filled ? const Color(0xFFFFB800) : textMuted,
                size: size,
              ),
            ),
          );
        }),
      ),
    ],
  );
}
