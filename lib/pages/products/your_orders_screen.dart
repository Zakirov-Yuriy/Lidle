// ============================================================
// "Экран: Ваши заказы"
// ============================================================
//
// Открывается с полоски «Покажите штрих-код продавцу» в кабинете
// (17.09.2026). В карусели рядом лежат только живые покупки и только столько,
// сколько влезло в прокрутку; здесь список целиком.
//
// Карточка на каждый купленный товар, а не на заказ: человек помнит, что он
// купил куртку, а не что у него заказ №1112312. По той же причине карточка
// ведёт на экран заказа именно с этим товаром.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/products/your_order_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

/// Заказ и одна его позиция: карточка показывает товар, а открывает заказ.
class _OrderEntry {
  final OrderModel order;
  final OrderLine line;

  const _OrderEntry({required this.order, required this.line});
}

class YourOrdersScreen extends StatefulWidget {
  static const String routeName = '/your-orders';

  const YourOrdersScreen({super.key});

  @override
  State<YourOrdersScreen> createState() => _YourOrdersScreenState();
}

class _YourOrdersScreenState extends State<YourOrdersScreen> {
  List<_OrderEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    try {
      // `all: true`: экран обещает все заказы, а не только живые.
      final orders = await OrdersService.myOrders(all: true);

      // Живые сверху: за ними человек сюда и заходит. Внутри каждой половины
      // сначала свежие.
      orders.sort((a, b) {
        if (a.isAlive != b.isAlive) return a.isAlive ? -1 : 1;

        final left = a.createdAt;
        final right = b.createdAt;

        if (left == null || right == null) return 0;

        return right.compareTo(left);
      });

      final entries = <_OrderEntry>[];

      for (final order in orders) {
        for (final line in order.items) {
          entries.add(_OrderEntry(order: order, line: line));
        }
      }

      if (!mounted) return;

      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      log.d('Заказы покупателя не загрузились: $e');

      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToAddListing ||
            state is NavigationToMyPurchases ||
            state is NavigationToMessages ||
            state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, left: 8),
                child: Header(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _titleRow(context),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Text(
                  'На этой странице собраны все ваши заказы',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            if (index == 3) {
              context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
            } else {
              context
                  .read<NavigationBloc>()
                  .add(SelectNavigationIndexEvent(index));
            }
          },
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Заказов пока нет',
          style: TextStyle(color: textSecondary, fontSize: 15),
        ),
      );
    }

    // Потянуть вниз и обновить: статус меняет продавец, и человек проверяет
    // именно этим движением, не закрывая экран.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _card(_entries[index]),
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Ваши заказы',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Назад',
            style: TextStyle(color: activeIconColor, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _card(_OrderEntry entry) {
    final order = entry.order;
    final line = entry.line;

    // У отклонённой позиции свой статус, а не статус заказа: заказ может быть
    // готов к выдаче, а этого товара в нём уже не будет, и общая подпись
    // обещала бы человеку то, чего он не получит.
    final isRejected = line.status == 'rejected';
    final statusTitle = isRejected ? 'Отклонён продавцом' : order.statusTitle;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => YourOrderScreen(order: order, line: line),
          ),
        );

        // Там могли отказаться от заказа: перечитываем список.
        if (changed == true && mounted) _load();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      color: isRejected
                          ? const Color(0xFFE05B5B)
                          : _statusColor(order.status),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  order.isCourier ? 'Курьер' : 'Самовывоз',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(line.image),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      if ((line.sku ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Артикул: ${line.sku}',
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String? image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 72,
        height: 72,
        child: (image ?? '').isEmpty
            ? Container(
                color: primaryBackground,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: textMuted,
                  size: 22,
                ),
              )
            : Image.network(
                image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: primaryBackground,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: textMuted,
                    size: 22,
                  ),
                ),
              ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'ready':
        return const Color(0xFF4CD964);
      case 'completed':
        return textSecondary;
      case 'cancelled_by_buyer':
      case 'cancelled_by_seller':
        return const Color(0xFFE05B5B);
      default:
        return const Color(0xFFFFB800);
    }
  }
}
