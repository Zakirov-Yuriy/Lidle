// ============================================================
// "Экран: Принятие заказа (продавец)"
// ============================================================
//
// Здесь продавец решает судьбу заказа: принимает, назначает курьера, отмечает
// готовность и выдаёт по коду.
//
// Штрих-кода с макета тут нет намеренно (16.09.2026). У нас уже есть код
// получения из шести знаков, который покупатель называет вслух, и заводить
// вторую систему опознания ради картинки незачем. Кнопка «Печатать код»
// показывает код крупно: на телефоне печатать нечем, а показать кассиру или
// курьеру нужно.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

class OrderAcceptScreen extends StatefulWidget {
  final OrderModel order;

  const OrderAcceptScreen({super.key, required this.order});

  @override
  State<OrderAcceptScreen> createState() => _OrderAcceptScreenState();
}

class _OrderAcceptScreenState extends State<OrderAcceptScreen> {
  late OrderModel _order = widget.order;

  List<CourierBrief> _couriers = const [];

  bool _busy = false;

  /// Что-то поменяли: список на прошлом экране надо перечитать.
  bool _changed = false;

  @override
  void initState() {
    super.initState();

    if (_order.isCourier) _loadCouriers();
  }

  Future<void> _loadCouriers() async {
    final couriers = await OrdersService.couriers();

    if (!mounted) return;

    setState(() => _couriers = couriers);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(_changed),
                      // Нажатие на всю строку, а не только на стрелку: попасть пальцем
                      // в иконку шириной 16 точек трудно, а заголовок рядом читается
                      // как часть той же кнопки «назад».
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Принятие заказа',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 28),
                  children: [
                    _block(children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Заказ №${_order.number}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _order.statusTitle,
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._order.items.map(_item),

                      // Деньги по заказу целиком: этот экран про весь заказ, в
                      // отличие от списка, где карточка на каждый товар.
                      // Доставка отдельной строкой: она не входит в сумму
                      // товаров, потому что товар могут снять с заказа, а
                      // везти всё равно надо.
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 10),
                      _line('Товары:', _rub(_order.total)),
                      if (_order.isCourier) ...[
                        _line('Доставка:', _rub(_order.deliveryPrice)),
                        _line('К оплате:', _rub(_withDelivery())),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    _block(children: [
                      _line('Заказчик:', _order.contactName ?? '—'),
                      _line('Номер:', _order.contactPhone ?? '—'),
                      const SizedBox(height: 8),
                      _line('Доставка:', _order.deliveryTitle ?? 'Самовывоз'),
                      if (_order.isCourier)
                        _line('Адрес:', _order.deliveryAddress ?? '—'),
                      if (_order.isCourier &&
                          (_order.deliveryComment ?? '').isNotEmpty)
                        _line('Комментарий:', _order.deliveryComment!),
                      const SizedBox(height: 8),
                      _line('Оплата:', _order.paymentMethodTitle ?? '—'),
                      if ((_order.comment ?? '').isNotEmpty)
                        _line('От покупателя:', _order.comment!),
                    ]),
                    if (_order.isCourier) ...[
                      const SizedBox(height: 12),
                      _courierBlock(),
                    ],
                    const SizedBox(height: 12),
                    _codeBlock(),
                    const SizedBox(height: 18),
                    ..._actions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Выбор курьера.
  ///
  /// Курьер это сотрудник продавца с соответствующей должностью. Учётной
  /// записи у него нет, в приложение он не входит: назначение это пометка
  /// продавца самому себе, кто повёз заказ.
  Widget _courierBlock() {
    return _block(children: [
      const Text(
        'Выбор курьера',
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _couriers.isEmpty ? null : _pickCourier,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: secondaryBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _order.courierName ?? 'Выбрать',
                  style: TextStyle(
                    color: _order.courierName == null ? textMuted : Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: textSecondary),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 44,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _findCourier,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: activeIconColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Найти курьера',
            style: TextStyle(color: activeIconColor, fontSize: 15),
          ),
        ),
      ),
    ]);
  }

  Widget _codeBlock() {
    final code = _order.pickupCode ?? '—';

    return _block(children: [
      const Text(
        'Код заказа',
        style: TextStyle(color: textSecondary, fontSize: 14),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 44,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _showCodeBig(code),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: activeIconColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Показать код крупно',
            style: TextStyle(color: activeIconColor, fontSize: 15),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _actions() {
    if (!_order.isAlive) return const [];

    return [
      if (_order.status == 'new')
        _wide('Принять заказ', activeIconColor, () => _action(OrdersService.accept)),
      if (_order.status == 'new' || _order.status == 'accepted') ...[
        const SizedBox(height: 10),
        _wide('Готов к выдаче', activeIconColor, () => _action(OrdersService.ready)),
      ],
      if (_order.status == 'accepted' || _order.status == 'ready') ...[
        const SizedBox(height: 10),
        _wide('Выдать заказ', const Color(0xFF3BA55D), _complete),
      ],
      const SizedBox(height: 10),
      _wide('Отклонить', const Color(0xFFE5484D), _reject),
    ];
  }

  Widget _wide(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 15)),
      ),
    );
  }

  Widget _block({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _item(OrderLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: line.image == null
                ? Container(width: 64, height: 64, color: secondaryBackground)
                : Image.network(
                    line.image!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(width: 64, height: 64, color: secondaryBackground),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if ((line.sku ?? '').isNotEmpty)
                  Text(
                    'Артикул: ${line.sku}',
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                Text(
                  '${line.quantity} шт',
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _rub(line.sum),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Сумма заказа вместе с доставкой. В `total` доставка не входит намеренно:
  /// товар могут снять с заказа, и сумма товаров изменится, а везти всё равно
  /// надо. Складываем только для показа.
  String _withDelivery() {
    final total = double.tryParse(_order.total) ?? 0;
    final delivery = double.tryParse(_order.deliveryPrice) ?? 0;
    final sum = total + delivery;

    return sum == sum.roundToDouble()
        ? sum.toStringAsFixed(0)
        : sum.toStringAsFixed(2);
  }

  /// Деньги одним видом: «5 000 ₽», а не «5000.0 ₽». Сервер присылает числа
  /// как есть, и в интерфейс они попадали сырыми. Копейки показываем только
  /// когда они есть.
  String _rub(Object? value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse('${value ?? ''}') ?? 0;

    final whole = number.truncate().abs();
    final kopeks = ((number.abs() - whole) * 100).round();

    final digits = whole.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final sign = number < 0 ? '-' : '';
    final tail = kopeks == 0 ? '' : ',${kopeks.toString().padLeft(2, '0')}';

    return '$sign$buffer$tail ₽';
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCourier() async {
    // Диалог возвращает либо курьера, либо строку `clear`: «снять курьера».
    // Отдельный тип ради одного пункта заводить не стали.
    final chosen = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: formBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Выбор курьера',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        children: [
          for (final courier in _couriers)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(courier),
              child: Row(
                children: [
                  Icon(
                    _order.courierStaffId == courier.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: activeIconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      courier.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          // Курьер мог заболеть, а заказ передумали везти. Снять назначение
          // сервер умел с самого начала, а в приложении это было нечем
          // сделать: список предлагал только заменить одного другим.
          if (_order.courierStaffId != null)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('clear'),
              child: const Text(
                'Снять курьера',
                style: TextStyle(color: Color(0xFFE5484D), fontSize: 15),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена', style: TextStyle(color: textMuted)),
          ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _busy = true);

    final result = await OrdersService.assignCourier(
      _order.id,
      chosen is CourierBrief ? chosen.id : null,
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result.order != null) _order = result.order!;
      if (result.isOk) _changed = true;
    });

    if (result.isOk) {
      SnackBarHelper.showSuccess(context, result.message);

      return;
    }

    SnackBarHelper.showError(context, result.message);
  }

  /// «Найти курьера».
  ///
  /// Внешнего поиска курьеров у нас нет, и придумывать его на клиенте нечем.
  /// Если курьеров ещё не заводили, честно говорим, где они заводятся: в
  /// сотрудниках публикации, с должностью курьера. Иначе кнопка молчала бы.
  void _findCourier() {
    if (_couriers.isNotEmpty) {
      _pickCourier();

      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: formBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Курьеров пока нет',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'Курьер это ваш сотрудник с должностью курьера. Заведите его в '
          'разделе «Сотрудники» своей публикации товара, и он появится здесь '
          'в списке.',
          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Понятно', style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );
  }

  void _showCodeBig(String code) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: formBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Код заказа',
                style: TextStyle(color: textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              FittedBox(
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Закрыть', style: TextStyle(color: activeIconColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _action(Future<OrderActionResult> Function(int) call) async {
    setState(() => _busy = true);

    final result = await call(_order.id);

    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result.order != null) _order = result.order!;
      if (result.isOk) _changed = true;
    });

    if (result.isOk) {
      SnackBarHelper.showSuccess(context, result.message);

      return;
    }

    SnackBarHelper.showError(context, result.message);
  }

  /// Выдача с проверкой кода.
  ///
  /// Код можно оставить пустым: сервер это допускает. Но тогда выдача ничем не
  /// подтверждена, и в подсказке это сказано прямо.
  Future<void> _complete() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: formBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Код покупателя',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 3,
              ),
              decoration: const InputDecoration(
                hintText: 'ABC123',
                hintStyle: TextStyle(color: textMuted),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Спросите код у покупателя. Можно оставить пустым, но тогда '
              'выдача ничем не подтверждена.',
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена', style: TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Выдать', style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );

    // Поле живёт дольше окна: пока идёт анимация закрытия, оно ещё
    // нарисовано. Убираем его после кадра, а не сразу (урок 16.09.2026).
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (code == null || !mounted) return;

    setState(() => _busy = true);

    final result = await OrdersService.complete(_order.id, pickupCode: code);

    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result.order != null) _order = result.order!;
      if (result.isOk) _changed = true;
    });

    if (result.isOk) {
      SnackBarHelper.showSuccess(context, result.message);

      return;
    }

    SnackBarHelper.showError(context, result.message);
  }

  Future<void> _reject() async {
    // Диалог возвращает причину: пустая строка это «без причины», null это
    // отмена. Причина уходит покупателю, и без неё отказ выглядит молчаливым.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );

    if (reason == null || !mounted) return;

    await _action(
      (id) => OrdersService.cancel(id, reason: reason.isEmpty ? null : reason),
    );
  }
}

/// Диалог отказа от ЗАКАЗА целиком с полем причины.
///
/// Отдельным виджетом, чтобы контроллер поля принадлежал состоянию диалога и
/// умирал вместе с ним: контроллер, заведённый снаружи, переживает закрытие и
/// однажды роняет экран.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: formBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Отклонить заказ',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Отказ от всего заказа. Покупатель получит уведомление, товары '
            'вернутся на остаток. Отменить отказ будет нельзя.',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Причина, например «закрылись на учёт»',
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              counterText: '',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: activeIconColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Причину увидит покупатель. Можно оставить пустой.',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена', style: TextStyle(color: textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text(
            'Отклонить',
            style: TextStyle(color: Color(0xFFE5484D)),
          ),
        ),
      ],
    );
  }
}
