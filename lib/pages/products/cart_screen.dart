import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/pages/products/checkout_screen.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Корзина.
///
/// Разложена по точкам продавца, потому что товары разных точек станут РАЗНЫМИ
/// заказами: у каждого свой код получения и своя выдача. Человек должен
/// увидеть это до оформления, а не после.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  CartSnapshot? _cart;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final result = await CartService.show();

    if (!mounted) return;

    setState(() {
      _cart = result.cart ?? CartSnapshot.empty();
      _isLoading = false;
    });
  }

  /// Любое действие возвращает корзину целиком, поэтому местное состояние не
  /// пересчитываем, а заменяем: склеивать своё представление с ответом значит
  /// однажды разойтись с сервером в количестве.
  Future<void> _apply(Future<CartResult> Function() action) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    final result = await action();

    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (result.isOk) _cart = result.cart;
    });

    if (!result.isOk) SnackBarHelper.showError(context, result.error!);
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cart;

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : (cart == null || cart.isEmpty)
                      ? _buildEmpty()
                      : _buildList(cart),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          (cart == null || cart.isEmpty) ? null : _buildBottomBar(cart),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                SizedBox(width: 4),
                Text(
                  'Назад',
                  style: TextStyle(
                    color: activeIconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_cart != null && !_cart!.isEmpty)
            GestureDetector(
              onTap: () => _apply(CartService.clear),
              child: const Text(
                'Очистить',
                style: TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Корзина пуста.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textMuted, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildList(CartSnapshot cart) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
      children: [
        const Text(
          'Корзина',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (cart.shops.length > 1)
          const Text(
            'Товары из разных точек станут отдельными заказами: каждый забирают '
            'в своей точке и по своему коду.',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        const SizedBox(height: 12),
        ...cart.shops.map(_buildShopGroup),
      ],
    );
  }

  Widget _buildShopGroup(CartShopGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
                  group.shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _money(group.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (group.address != null && group.address!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              group.address!,
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
          if (!group.shopIsActive) ...[
            const SizedBox(height: 6),
            const Text(
              'Точка временно не принимает заказы.',
              style: TextStyle(color: Color(0xFFE0A63C), fontSize: 13),
            ),
          ],
          if (group.cookingTimeMinutes != null) ...[
            const SizedBox(height: 6),
            Text(
              'Готовят примерно ${group.cookingTimeMinutes} мин',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          ...group.items.map(_buildLine),
        ],
      ),
    );
  }

  Widget _buildLine(CartLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: line.image == null || line.image!.isEmpty
                  ? Container(
                      color: secondaryBackground,
                      child: const Icon(Icons.image_outlined,
                          color: textMuted, size: 20),
                    )
                  : Image.network(
                      line.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: secondaryBackground,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: textMuted, size: 20),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: line.isAvailable ? Colors.white : textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(line.sum),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Причину приходит готовой с сервера: «товара сегодня нет»,
                // «осталось только 2 шт.». Не переписываем её своими словами,
                // они будут менее точными.
                if (!line.isAvailable && line.unavailableReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    line.unavailableReason!,
                    style: const TextStyle(
                        color: Color(0xFFE0A63C), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                _buildStepper(line),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(CartLine line) {
    return Row(
      children: [
        _stepButton(
          Icons.remove,
          () => _apply(
            () => CartService.setQuantity(line.productId, line.quantity - 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '${line.quantity}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _stepButton(
          Icons.add,
          line.quantity < line.stockQuantity
              ? () => _apply(
                    () => CartService.setQuantity(
                        line.productId, line.quantity + 1),
                  )
              : null,
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _apply(() => CartService.remove(line.productId)),
          child: const Icon(Icons.delete_outline, color: textMuted, size: 20),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: onTap == null ? textMuted : Colors.white, size: 16),
      ),
    );
  }

  Widget _buildBottomBar(CartSnapshot cart) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Итого',
                  style: TextStyle(color: textSecondary, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  _money(cart.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (cart.hasUnavailable) ...[
              const SizedBox(height: 4),
              const Text(
                'Недоступные позиции в сумму не входят и в заказ не попадут.',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeIconColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isBusy ? null : _openCheckout,
                child: const Text(
                  'Оформить заказ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCheckout() async {
    final placed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(cart: _cart!)),
    );

    if (!mounted) return;

    // Заказ оформлен — корзина на сервере опустела, перечитываем.
    if (placed == true) {
      _load();
    }
  }

  String _money(double value) {
    final whole = value.truncate().toString();

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }
}
