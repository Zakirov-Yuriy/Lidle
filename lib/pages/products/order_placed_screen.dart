import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/widgets/components/header.dart';

/// Экран после оформления: коды получения.
///
/// Отдельный экран, а не всплывающее сообщение, намеренно. Код получения это
/// единственное, что нужно человеку в точке, и показать его в исчезающей
/// плашке значит гарантированно его потерять. Заказов может быть несколько:
/// каждая точка выдаёт своё и по своему коду.
class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 16, 25, 24),
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF46BE78), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    orders.length > 1
                        ? 'Заказы оформлены'
                        : 'Заказ оформлен',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    orders.length > 1
                        ? 'Товары были из разных точек, поэтому заказов '
                            '${orders.length}. В каждой точке называйте её код.'
                        : 'Приходите в точку и назовите код. Оплата на месте, '
                            'напрямую продавцу.',
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ...orders.map(_buildOrder),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 8, 25, 12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: activeIconColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Готово',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrder(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.shop?.name ?? 'Точка выдачи',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '№ ${order.number}',
                style: const TextStyle(color: textMuted, fontSize: 13),
              ),
            ],
          ),
          if (order.shop?.address != null &&
              order.shop!.address!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              order.shop!.address!,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Код получения',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              order.pickupCode ?? '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
              ),
            ),
          ),
          if (order.cookingTimeMinutes != null) ...[
            const SizedBox(height: 10),
            Text(
              'Готовят примерно ${order.cookingTimeMinutes} мин',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
