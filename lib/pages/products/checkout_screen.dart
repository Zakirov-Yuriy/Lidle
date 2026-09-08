import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/products/order_placed_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Оформление заказа.
///
/// Оплаты здесь нет и не будет в этой версии: деньги покупатель отдаёт
/// продавцу напрямую, мы их не проводим. Поэтому оформление заканчивается не
/// платежом, а кодом получения.
///
/// Работает и без входа в аккаунт. Гостю имя, телефон и почта обязательны:
/// без них его нечем найти и некуда прислать код.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.cart});

  final CartSnapshot cart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isGuest = true;
  bool _isSending = false;

  /// Подставили ли мы контакты сами. Нужно только для подписи под заголовком:
  /// человек должен понимать, откуда взялся текст в полях, иначе заполненная
  /// форма выглядит подозрительно.
  bool _isPrefilled = false;

  /// Подтвердил ли человек, что платит продавцу напрямую.
  ///
  /// Требование заказчика от 08.09.2026: «главное написать уведомление, что
  /// деньги покупатель платит продавцу за товар напрямую, с галочкой
  /// подтверждения, что покупатель понял, куда отправил деньги».
  ///
  /// Заранее её НЕ ставим: галочка, проставленная за человека, ничего не
  /// подтверждает.
  bool _paymentAcknowledged = false;

  @override
  void initState() {
    super.initState();

    final token = HiveService.getUserData('token');
    _isGuest = token == null || '$token'.isEmpty;

    // Контакты приходят вместе с корзиной: то, чем этот покупатель оформлял в
    // прошлый раз, иначе профиль.
    //
    // Так было: поля всегда открывались пустыми, и человек на втором заказе
    // вводил своё же имя, телефон и почту заново. Нашлось при просмотре
    // записи экрана.
    //
    // Поля остаются обычными и редактируемыми: подстановка это подсказка, а
    // не решение за человека. Комментарий не подставляем никогда, он
    // относится к конкретному заказу.
    final contacts = widget.cart.contacts;

    _nameController.text = contacts.name ?? '';
    _phoneController.text = contacts.phone ?? '';
    _emailController.text = contacts.email ?? '';

    _isPrefilled = !contacts.isEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending) return;

    if (_isGuest) {
      final missing = _nameController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty;

      if (missing) {
        SnackBarHelper.showWarning(
          context,
          'Без регистрации нужны имя, телефон и почта: по почте придёт код получения',
        );
        return;
      }
    }

    if (_needsAcknowledgement && !_paymentAcknowledged) {
      SnackBarHelper.showWarning(
        context,
        'Подтвердите, что вы поняли, кому и куда отправляете деньги',
      );
      return;
    }

    setState(() => _isSending = true);

    final result = await OrdersService.place(
      contactName: _nameController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      comment: _commentController.text.trim(),
      paymentAcknowledged: _paymentAcknowledged,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    if (!result.isOk) {
      // Текст с сервера конкретный: «товар разобрали, пока вы оформляли».
      // Показываем как есть.
      SnackBarHelper.showError(context, result.error!);
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPlacedScreen(orders: result.orders),
      ),
    );

    if (mounted) Navigator.pop(context, true);
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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
      children: [
        const Text(
          'Оформление',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _buildPickupNotice(),
        const SizedBox(height: 12),
        _buildContacts(),
        const SizedBox(height: 12),
        _buildShops(),
        if (_needsAcknowledgement) ...[
          const SizedBox(height: 12),
          _buildPaymentNotice(),
        ],
      ],
    );
  }

  /// Требует ли сервер подтверждение оплаты.
  ///
  /// Старый сервер этого блока не присылает. Тогда галочки нет и оформление
  /// работает как раньше: ломать заказ из-за отсутствующего поля нельзя.
  bool get _needsAcknowledgement => widget.cart.payment.required;

  /// Предупреждение об оплате и галочка.
  ///
  /// Стоит последним блоком, прямо над кнопкой: человек читает его, когда уже
  /// видел, кому и сколько платит.
  Widget _buildPaymentNotice() {
    final payment = widget.cart.payment;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оплата',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            payment.notice,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(
              () => _paymentAcknowledged = !_paymentAcknowledged,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _paymentAcknowledged,
                  activeColor: activeIconColor,
                  onChanged: (value) => setState(
                    () => _paymentAcknowledged = value ?? false,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      payment.confirmLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Реквизиты точки: куда именно уходят деньги.
  ///
  /// Показываются рядом с её товарами, а не общим списком: точек в заказе
  /// может быть несколько, и счета у них разные.
  Widget _buildPaymentMethods(List<CartPaymentMethod> methods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Оплата продавцу',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        for (final method in methods) ...[
          const SizedBox(height: 4),
          Text(
            method.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final entry in method.fields.entries)
            Text(
              '${CartPaymentMethod.fieldTitle(entry.key)}: ${entry.value}',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
        ],
      ],
    );
  }

  Widget _buildPickupNotice() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Самовывоз по коду',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Доставки пока нет. После оформления вы получите код, назовёте его '
            'в точке и заберёте заказ. Оплата на месте, напрямую продавцу.',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          if (widget.cart.shops.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Точек ${widget.cart.shops.length}, значит и заказов будет '
              '${widget.cart.shops.length}: каждый со своим кодом.',
              style: const TextStyle(color: Color(0xFFE0A63C), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContacts() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isGuest ? 'Ваши контакты' : 'Контакты для этого заказа',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isPrefilled
                ? 'Подставили то, чем вы оформляли в прошлый раз. Поправьте, '
                    'если что-то изменилось.'
                : _isGuest
                    ? 'Заполните все три поля: по почте придёт код получения.'
                    : 'Можно не заполнять — возьмём из вашего профиля.',
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _field(_nameController, 'Имя', TextInputType.name),
          const SizedBox(height: 10),
          _field(_phoneController, 'Телефон', TextInputType.phone),
          const SizedBox(height: 10),
          _field(_emailController, 'Почта', TextInputType.emailAddress),
          const SizedBox(height: 10),
          _field(_commentController, 'Комментарий продавцу', TextInputType.text,
              lines: 3),
        ],
      ),
    );
  }

  Widget _buildShops() {
    return Column(
      children: widget.cart.shops.map((group) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _money(group.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
              const SizedBox(height: 8),
              ...group.items
                  .where((item) => item.isAvailable)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} × ${item.quantity}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 13),
                            ),
                          ),
                          Text(
                            _money(item.sum),
                            style: const TextStyle(
                                color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (group.paymentMethods.isNotEmpty)
                _buildPaymentMethods(group.paymentMethods),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('К оплате в точке',
                    style: TextStyle(color: textSecondary, fontSize: 15)),
                const Spacer(),
                Text(
                  _money(widget.cart.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
                onPressed: _isSending || (_needsAcknowledgement && !_paymentAcknowledged)
                    ? null
                    : _submit,
                child: Text(
                  _isSending ? 'Отправляем…' : 'Подтвердить заказ',
                  style: const TextStyle(
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

  Widget _field(
    TextEditingController controller,
    String hint,
    TextInputType type, {
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: lines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        filled: true,
        fillColor: secondaryBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
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
