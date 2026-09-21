// ============================================================
//  «Заказ не оплачен» (макет, 22.09.2026)
// ============================================================
//
// Открывается, когда онлайн-оплата не прошла. Сверху причина от банка
// («Недостаточно средств»), ниже выбор, как заплатить иначе:
//
//   Наличными      — заказ переводится на оплату при получении;
//   Оплата картой  — новая карта в форме SDK YooKassa прямо в приложении;
//   Оплата онлайн  — SberPay и СБП (форма SDK), T-Pay (страница оплаты,
//                    в SDK его нет) или сохранённая карта из «Ваши карты»
//                    (SDK спросит только CVC).
//
// Способы на этом экране заданы в приложении, а не приходят с сервера:
// это выбор «как доплатить за уже оформленный заказ», и он один для всех.
//
// «Отмена» отменяет заказ: товар возвращается продавцу. Перед этим
// переспрашиваем, случайно такое нажимать нельзя.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_payment.dart';
import 'package:lidle/pages/products/order_payment_flow.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:yookassa_payments_flutter/yookassa_payments_flutter.dart'
    show PaymentMethod;

const Color _errorRed = Color(0xFFFF3B30);

enum _Method { cash, card, online }

class OrderUnpaidScreen extends StatefulWidget {
  const OrderUnpaidScreen({super.key, required this.payment});

  final OrderPaymentInfo payment;

  @override
  State<OrderUnpaidScreen> createState() => _OrderUnpaidScreenState();
}

class _OrderUnpaidScreenState extends State<OrderUnpaidScreen> {
  late OrderPaymentInfo _payment = widget.payment;

  _Method _method = _Method.online;

  /// Выбранное внутри «Оплата онлайн»: банк или сохранённая карта.
  String? _channel;
  int? _cardId;

  bool _busy = false;

  @override
  void initState() {
    super.initState();

    // Есть сохранённая карта — предлагаем её первой, как на макете.
    if (_payment.cards.isNotEmpty) _cardId = _payment.cards.first.id;
  }

  bool get _canPay => switch (_method) {
    _Method.cash => true,
    _Method.card => true,
    _Method.online => _channel != null || _cardId != null,
  };

  String get _buttonText => switch (_method) {
    _Method.cash => 'Оплатить при получении',
    _ => 'Оплатить ${_money(_payment.amount)}',
  };

  // ── Действия ───────────────────────────────────────────────────────

  Future<void> _pay() async {
    if (_busy || !_canPay) return;

    setState(() => _busy = true);

    if (_method == _Method.cash) {
      final result = await OrdersService.payInCash(_payment.token);

      if (!mounted) return;
      setState(() => _busy = false);

      if (!result.isOk) {
        SnackBarHelper.showError(
          context,
          result.message ?? 'Не получилось сменить способ оплаты',
        );

        return;
      }

      Navigator.pop(
        context,
        OrderPaymentFlowResult(OrderPaymentOutcome.cash, orders: result.orders),
      );

      return;
    }

    // Форма SDK YooKassa (22.09.2026): карта, SberPay, СБП и сохранённые
    // карты. Отказ банка приходит сразу, и экран просто обновляет причину.
    // T-Pay в SDK нет, он идёт через страницу оплаты ниже.
    if (_payment.sdk != null && _channel != 'tinkoff_bank') {
      final outcome = await payOrderWithSdk(
        context,
        _payment,
        methods: switch ((_method, _channel)) {
          (_Method.online, 'sberbank') => const [PaymentMethod.sberbank],
          (_Method.online, 'sbp') => const [PaymentMethod.sbp],
          _ => const [PaymentMethod.bankCard],
        },
        card: _method == _Method.online && _channel == null
            ? _selectedCard
            : null,
      );

      if (!mounted) return;

      _finish(outcome);

      return;
    }

    final retry = await OrdersService.retryPayment(
      _payment.token,
      channel: _method == _Method.card ? 'bank_card' : _channel,
      cardId: _method == _Method.online && _channel == null ? _cardId : null,
    );

    if (!mounted) return;

    final next = retry.payment;

    if (next == null) {
      setState(() => _busy = false);
      SnackBarHelper.showError(
        context,
        retry.message ?? 'Не получилось начать оплату',
      );

      return;
    }

    final outcome = await payOrderOnce(context, next);

    if (!mounted) return;

    _finish(outcome);
  }

  SavedPaymentCard? get _selectedCard {
    for (final card in _payment.cards) {
      if (card.id == _cardId) return card;
    }

    return null;
  }

  void _finish(OrderPaymentInfo outcome) {
    if (outcome.paid) {
      Navigator.pop(
        context,
        const OrderPaymentFlowResult(OrderPaymentOutcome.paid),
      );

      return;
    }

    // Снова не прошло: показываем новую причину, выбор оставляем. Токен у
    // нового платежа свой, поэтому держим именно его.
    setState(() {
      _payment = outcome;
      _busy = false;
    });
  }

  Future<void> _cancel() async {
    if (_busy) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: formBackground,
        title: const Text(
          'Отменить заказ?',
          style: TextStyle(color: textPrimary, fontSize: 18),
        ),
        content: const Text(
          'Заказ не оплачен. Если его отменить, товары вернутся продавцу.',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Не отменять'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Отменить заказ',
              style: TextStyle(color: _errorRed),
            ),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    setState(() => _busy = true);

    final result = await OrdersService.cancelUnpaid(_payment.token);

    if (!mounted) return;

    setState(() => _busy = false);

    if (!result.isOk) {
      SnackBarHelper.showError(
        context,
        result.message ?? 'Не получилось отменить заказ',
      );

      return;
    }

    Navigator.pop(
      context,
      const OrderPaymentFlowResult(OrderPaymentOutcome.cancelled),
    );
  }

  // ── Экран ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,

      // Системное «назад» ведёт себя как «Отмена»: молча уйти с экрана
      // значит оставить заказ висеть неоплаченным.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(),
              _buildTopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _buildError(),
                    const SizedBox(height: 20),
                    const Text(
                      'Способ оплаты',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMethods(),
                  ],
                ),
              ),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Заказ не оплачен',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: _cancel,
            behavior: HitTestBehavior.opaque,
            child: const Text(
              'Отмена',
              style: TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return _card(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _errorRed, width: 2.5),
            ),
            child: const Icon(Icons.close, color: _errorRed, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            _payment.reasonTitle ?? 'Платёж не прошёл',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _payment.reasonHint ??
                'Выберите другую карту или другой способ оплаты',
            textAlign: TextAlign.center,
            style: const TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMethods() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _radioRow(
            method: _Method.cash,
            title: 'Наличными',
            hint: 'Оплата при получении заказа',
          ),
          _radioRow(
            method: _Method.card,
            title: 'Оплата картой',
            hint: 'Банковской картой',
          ),
          _radioRow(
            method: _Method.online,
            title: 'Оплата онлайн',
            hint: 'Через приложение банка или сохранённой картой',
          ),
          if (_method == _Method.online) ...[
            const SizedBox(height: 10),
            _buildBanks(),
            const SizedBox(height: 16),
            const Text(
              'Ваши карты',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildCards(),
          ],
        ],
      ),
    );
  }

  Widget _buildBanks() {
    return Row(
      children: [
        _bankTile(
          channel: 'sberbank',
          child: SvgPicture.asset('assets/payment/sberpay.svg', height: 26),
        ),
        const SizedBox(width: 10),
        _bankTile(
          channel: 'tinkoff_bank',
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDD2D),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Т',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _bankTile(
          channel: 'sbp',
          child: SvgPicture.asset('assets/payment/sbp.svg', height: 26),
        ),
      ],
    );
  }

  Widget _bankTile({required String channel, required Widget child}) {
    final selected = _channel == channel;

    return GestureDetector(
      onTap: () => setState(() {
        _channel = channel;
        _cardId = null;
      }),
      child: Container(
        width: 72,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeIconColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCards() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final card in _payment.cards) _cardTile(card),

        // «+» — новая карта, то же, что «Оплата картой».
        GestureDetector(
          onTap: () => setState(() => _method = _Method.card),
          child: Container(
            width: 72,
            height: 56,
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _cardTile(SavedPaymentCard card) {
    final selected = _channel == null && _cardId == card.id;

    return GestureDetector(
      onTap: () => setState(() {
        _cardId = card.id;
        _channel = null;
      }),
      child: Container(
        width: 110,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeIconColor : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          card.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _busy || !_canPay ? null : _pay,
          style: ElevatedButton.styleFrom(
            backgroundColor: activeIconColor,
            disabledBackgroundColor: activeIconColor.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _canPay ? _buttonText : 'Выберите банк или карту',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Мелочи ─────────────────────────────────────────────────────────

  Widget _radioRow({
    required _Method method,
    required String title,
    required String hint,
  }) {
    final selected = _method == method;

    return InkWell(
      onTap: () => setState(() => _method = method),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? activeIconColor : Colors.white70,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeIconColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  String _money(double value) {
    final whole = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }
}
