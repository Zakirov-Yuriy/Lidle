// ============================================================
//  Оплата по ссылке банка продавца (21.09.2026)
// ============================================================
//
// Решение Саши: LIDLE к деньгам отношения не имеет. Продавец вставляет в
// настройках способа оплаты ссылку, которую выдал его банк (Сбер Бизнес,
// Т-Бизнес и другие: платёжная ссылка или QR СБП). Покупатель видит здесь
// кнопку «Оплатить» и QR-код с этой ссылкой:
//
//   кнопка открывает приложение банка покупателя (или страницу банка);
//   QR-код для случая, когда платят с другого телефона: наводят камеру или
//   сканер в приложении банка.
//
// Деньги уходят продавцу напрямую, мы их не видим и об оплате не узнаём.
// Поэтому ниже подсказка: сумму сверить с заказом, если банк её не
// подставил сам (у «открытой» ссылки сумму вводит покупатель).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentLinkBlock extends StatelessWidget {
  const PaymentLinkBlock({super.key, required this.link, this.amount});

  final String link;

  /// Сумма к оплате готовой строкой, например «5 000 ₽».
  final String? amount;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(link);

    var opened = false;

    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не получилось открыть ссылку. Отсканируйте QR-код.'),
          backgroundColor: secondaryBackground,
        ),
      );
    }
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ссылка на оплату скопирована'),
        backgroundColor: secondaryBackground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () => _open(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: activeIconColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              amount == null ? 'Оплатить в банке' : 'Оплатить $amount в банке',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onLongPress: () => _copy(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 170,
                gapless: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Кнопка откроет приложение вашего банка. QR-код можно отсканировать '
          'камерой или в приложении банка на другом телефоне. Деньги придут '
          'продавцу напрямую. Если банк не подставил сумму, введите её сами.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}

/// Как платить по заказу: реквизиты выбранного способа и, если продавец дал
/// ссылку, кнопка «Оплатить» с QR-кодом. Ничего нет — ничего не рисуем.
class OrderPaymentDetails extends StatelessWidget {
  const OrderPaymentDetails({super.key, required this.order});

  final OrderModel order;

  /// «5 000 ₽»: товары плюс доставка.
  static String amountOf(OrderModel order) {
    final total = (double.tryParse(order.total) ?? 0) +
        (double.tryParse(order.deliveryPrice) ?? 0);
    final whole = total.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final link = order.paymentLink;

    if (order.paymentFields.isEmpty && link == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in order.paymentFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SelectableText.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${field.label}: ',
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  TextSpan(
                    text: field.value,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        if (link != null) ...[
          const SizedBox(height: 10),
          PaymentLinkBlock(link: link, amount: amountOf(order)),
        ],
      ],
    );
  }
}
