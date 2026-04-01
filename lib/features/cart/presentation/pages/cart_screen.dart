import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:lidle/features/cart/domain/entities/cart_item_entity.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  static const String routeName = '/cart';

  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);
  static const textSecondary = Colors.white54;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: CartScreen.bgColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───── Header ─────
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, right: 23),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [const Header()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Color.fromARGB(255, 255, 255, 255),
                          size: 16,
                        ),
                      ),
                      const Text(
                        'Корзина',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Назад',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ───── Select all / Delete ─────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      CustomCheckbox(
                        value: state.selectAll,
                        onChanged: (value) {
                          context.read<CartBloc>().add(
                            ToggleSelectAllEvent(value),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Выбрать все',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          context.read<CartBloc>().add(
                            RemoveSelectedItemsEvent(),
                          );
                        },
                        child: Text(
                          'Удалить',
                          style: TextStyle(
                            color: CartScreen.dangerColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24),

                const SizedBox(height: 10),

                // ───── Cart items with summary and checkout ─────
                Expanded(
                  child: state.items.isEmpty
                      ? const Center(
                          child: Text(
                            'Корзина пуста',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = state.items[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 25,
                                      vertical: 4,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.only(
                                        top: 22,
                                        bottom: 18,
                                        left: 10,
                                        right: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CartScreen.cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomCheckbox(
                                                value: item.isSelected,
                                                onChanged: (value) {
                                                  context.read<CartBloc>().add(
                                                    ToggleItemSelectionEvent(item.id),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 8),

                                              // image
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(
                                                  6,
                                                ),
                                                child: Image.asset(
                                                  item.imagePath,
                                                  width: 86,
                                                  height: 77,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),

                                              const SizedBox(width: 12),

                                              // info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text:
                                                                '${item.price} ₽   ',
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                '${item.oldPrice} ₽',
                                                            style: const TextStyle(
                                                              color: Colors.white54,
                                                              fontSize: 12,
                                                              decoration:
                                                                  TextDecoration
                                                                      .lineThrough,
                                                              decorationColor:
                                                                  Colors.white54,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    const SizedBox(height: 4),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          const TextSpan(
                                                            text: 'Цвет: ',
                                                            style: TextStyle(
                                                              color: CartScreen
                                                                  .textSecondary,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: item.color,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          const TextSpan(
                                                            text: 'Колл.шт: ',
                                                            style: TextStyle(
                                                              color: CartScreen
                                                                  .textSecondary,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: item.quantity
                                                                .toString(),
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 13),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 29.0,
                                            ),
                                            child: Row(
                                              children: [
                                                _QuantitySelector(
                                                  itemId: item.id,
                                                  quantity: item.quantity,
                                                ),
                                                const Spacer(),
                                                GestureDetector(
                                                  onTap: () {
                                                    context.read<CartBloc>().add(
                                                      RemoveFromCartEvent(item.id),
                                                    );
                                                  },
                                                  child: Text(
                                                    'Удалить',
                                                    style: TextStyle(
                                                      color: CartScreen.dangerColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                childCount: state.items.length,
                              ),
                            ),
                            // Summary and Checkout inside CustomScrollView
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 10),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 25,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.only(
                                        top: 18,
                                        bottom: 28,
                                        left: 9,
                                        right: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CartScreen.cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Сумма корзины',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _SummaryRow(
                                            'Товары (${state.items.length})',
                                            '${_calculateTotal(state.items)} ₽',
                                          ),
                                          const SizedBox(height: 6),
                                          _SummaryRow(
                                            'Скидка',
                                            'Нет',
                                            valueColor: CartScreen.dangerColor,
                                          ),
                                          const Divider(color: Colors.white24, height: 24),
                                          _SummaryRow(
                                            'К оплате:',
                                            '${_calculateTotal(state.items)} ₽',
                                            isTotal: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16,
                                      left: 25,
                                      right: 25,
                                      top: 20,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CartScreen.accentColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {},
                                        child: const Text(
                                          'Перейти к оформлению',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    'Доступные способы доставки можно будет выбрать при оформлении заказа',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  String _calculateTotal(List<CartItem> items) {
    int total = 0;
    for (var item in items) {
      total += int.parse(item.price.replaceAll(' ', '')) * item.quantity;
    }
    return total
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        )
        .trim();
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

class _QuantitySelector extends StatelessWidget {
  final String itemId;
  final int quantity;

  const _QuantitySelector({required this.itemId, required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: CartScreen.cardColor,
        border: Border.all(color: CartScreen.textSecondary, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (quantity > 1) {
                context.read<CartBloc>().add(DecrementQuantityEvent(itemId));
              }
            },
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove,
                color: quantity > 1 ? Colors.white : CartScreen.textSecondary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: Text(
              quantity.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.read<CartBloc>().add(IncrementQuantityEvent(itemId));
            },
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}



class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isTotal;
  final Color? valueColor;

  const _SummaryRow(
    this.title,
    this.value, {
    this.isTotal = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white54,
            fontSize: isTotal ? 16 : 16,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: isTotal ? 16 : 16,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
