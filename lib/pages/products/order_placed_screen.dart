import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/auth/register_screen.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/products/payment_link_block.dart';

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
                        : 'Приходите в точку и назовите код. Деньги вы '
                            'платите продавцу напрямую.',
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ...orders.map(_buildOrder),
                  _buildRegisterOffer(context),
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
              // Возвращаем признак успеха: экран корзины перечитывает себя
              // в любом случае, но признак пригодится другим экранам, с
              // которых сюда придут позже.
              onPressed: () => Navigator.pop(context, true),
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

  /// Мягкое предложение завести учётную запись. Только гостю (17.09.2026).
  ///
  /// Момент выбран намеренно: человек только что купил, и польза от учётной
  /// записи для него уже не абстрактная, а понятная — видеть свои заказы и не
  /// вводить контакты заново. До покупки то же предложение читается как
  /// препятствие, поэтому на оформлении мы ничего не просим.
  ///
  /// Это предложение, а не преграда: кнопка одна, отказаться можно просто
  /// нажав «Готово». Всплывающего окна тут быть не должно — человек в этот
  /// момент запоминает код получения.
  Widget _buildRegisterOffer(BuildContext context) {
    final token = TokenService.currentToken;

    if (token != null && token.isNotEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сохранить заказ за собой',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Заведите учётную запись, и этот заказ появится в разделе '
            '«Покупки». Там же видно, принял ли его продавец, и не нужно '
            'каждый раз вводить имя, телефон и почту.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, RegisterScreen.routeName),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: activeIconColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Зарегистрироваться',
                style: TextStyle(color: activeIconColor, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Код получения уже отправлен на вашу почту, так что заказ не '
            'потеряется в любом случае.',
            style: TextStyle(color: textMuted, fontSize: 12, height: 1.3),
          ),
        ],
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

          // Как заплатить продавцу (21.09.2026): реквизиты выбранного
          // способа и кнопка «Оплатить» с QR-кодом, если продавец дал
          // ссылку своего банка.
          if (order.paymentLink != null || order.paymentFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              order.paymentMethodTitle == null
                  ? 'Оплата'
                  : 'Оплата: ${order.paymentMethodTitle}',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            OrderPaymentDetails(order: order),
          ],
        ],
      ),
    );
  }
}
