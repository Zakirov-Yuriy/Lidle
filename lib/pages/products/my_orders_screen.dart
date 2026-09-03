import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Мои покупки и заказы в моих точках.
///
/// Два списка на одном экране, вкладками: это одна и та же сущность с двух
/// сторон, и разводить их по разным экранам значит заставлять продавца,
/// который сам что-то покупал, помнить, где что лежит.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, this.startWithIncoming = false});

  final bool startWithIncoming;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late bool _incoming;
  bool _showAll = false;
  bool _isLoading = true;

  List<OrderModel> _orders = const [];

  @override
  void initState() {
    super.initState();
    _incoming = widget.startWithIncoming;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final orders = _incoming
        ? await OrdersService.incoming(all: _showAll)
        : await OrdersService.myOrders(all: _showAll);

    if (!mounted) return;

    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              child: GestureDetector(
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
            ),
            _buildTabs(),
            _buildScopeRow(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : _orders.isEmpty
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _incoming
                                  ? 'Заказов в ваших точках пока нет.'
                                  : 'Покупок пока нет.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: textMuted, fontSize: 15),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: activeIconColor,
                          onRefresh: _load,
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(25, 4, 25, 24),
                            children: _orders.map(_buildOrder).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 8),
      child: Row(
        children: [
          _tab('Мои покупки', !_incoming, () {
            setState(() => _incoming = false);
            _load();
          }),
          const SizedBox(width: 18),
          _tab('Заказы ко мне', _incoming, () {
            setState(() => _incoming = true);
            _load();
          }),
        ],
      ),
    );
  }

  Widget _tab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : textMuted,
              fontSize: 17,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 90,
            color: isSelected ? activeIconColor : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildScopeRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 8),
      child: Row(
        children: [
          // По умолчанию показываем живые заказы: разбирают обычно то, что ещё
          // не закончилось. Прошлое достаётся отдельно.
          GestureDetector(
            onTap: () {
              setState(() => _showAll = !_showAll);
              _load();
            },
            child: Row(
              children: [
                Icon(
                  _showAll ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _showAll ? activeIconColor : textMuted,
                  size: 20,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Показывать завершённые',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrder(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  order.shop?.name ?? 'Точка выдачи',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusChip(order),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '№ ${order.number}',
            style: const TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.name} × ${line.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Итого',
                  style: TextStyle(color: textSecondary, fontSize: 14)),
              const Spacer(),
              Text(
                '${order.total} ₽',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // Код показываем, только пока заказ живой: у выданного и отменённого
          // он уже ничего не открывает, а на экране только мешает.
          if (order.isAlive && order.pickupCode != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Код получения',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
                const Spacer(),
                Text(
                  order.pickupCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ],
          if (order.cancelReason != null && order.cancelReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Причина: ${order.cancelReason}',
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
          if (_actionsFor(order).isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _actionsFor(order)),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(OrderModel order) {
    Color color = textMuted;

    if (order.status == 'new') color = activeIconColor;
    if (order.status == 'ready') color = const Color(0xFF46BE78);
    if (order.isCancelled) color = const Color(0xFFE0A63C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.statusTitle,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Кнопки зависят от роли и состояния.
  ///
  /// Продавец ведёт заказ по пути «принял, собрал, выдал», покупатель может
  /// только отменить, пока заказ жив.
  List<Widget> _actionsFor(OrderModel order) {
    if (!order.isAlive) return const [];

    final actions = <Widget>[];

    if (_incoming) {
      if (order.status == 'new') {
        actions.add(_action('Принять', () => OrdersService.accept(order.id)));
      }
      if (order.status == 'new' || order.status == 'accepted') {
        actions.add(_action('Готов к выдаче', () => OrdersService.ready(order.id)));
      }
      if (order.status == 'accepted' || order.status == 'ready') {
        actions.add(_action('Выдать', () => _completeWithCode(order)));
      }
    }

    actions.add(
      _action('Отменить', () => OrdersService.cancel(order.id), muted: true),
    );

    return actions;
  }

  Widget _action(
    String label,
    Future<OrderActionResult> Function() run, {
    bool muted = false,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await run();

        if (!mounted) return;

        if (result.isOk) {
          SnackBarHelper.showSuccess(context, result.message);
        } else {
          SnackBarHelper.showError(context, result.message);
        }

        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: muted ? Colors.transparent : activeIconColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: muted ? textMuted : activeIconColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Выдача со сверкой кода.
  ///
  /// Код спрашиваем, а не проставляем сами: это единственное место, где сверка
  /// что-то проверяет. Пустое поле сервер примет, но тогда продавец отмечает
  /// выдачу на свой страх, о чём и написано в подсказке.
  Future<OrderActionResult> _completeWithCode(OrderModel order) async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: formBackground,
        title: const Text('Код покупателя',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, letterSpacing: 3),
              decoration: const InputDecoration(
                hintText: 'ABC123',
                hintStyle: TextStyle(color: textMuted),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Спросите код у покупателя. Можно оставить пустым, но тогда '
              'выдача ничем не подтверждена.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Выдать',
                style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );

    if (code == null) {
      return const OrderActionResult(isOk: true, message: '');
    }

    return OrdersService.complete(order.id, pickupCode: code);
  }
}
