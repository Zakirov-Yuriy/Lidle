import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/products/order_placed_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/user_service.dart';
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

  @override
  void initState() {
    super.initState();

    // Вошедшему пользователю контакты подставит сервер из профиля, если он их
    // не прислал: заставлять человека вводить своё же имя невежливо.
    final token = HiveService.getUserData('token');
    _isGuest = token == null || '$token'.isEmpty;

    if (!_isGuest) {
      _prefillFromProfile('$token');
    }
  }

  /// Prefill contact fields for a signed-in user, so the screen shows the
  /// same values the server would take from the profile anyway.
  /// Any failure here is silent: prefill is a convenience, the screen must
  /// keep working exactly as before.
  Future<void> _prefillFromProfile(String token) async {
    try {
      final profile = await UserService.getProfile(token: token);

      var phone = profile.phone ?? '';
      try {
        final phonesResponse = await ContactService.getPhones(token: token);
        if (phonesResponse.data.isNotEmpty) {
          phone = phonesResponse.data.first.phone;
        }
      } catch (_) {
        // Keep the scalar profile phone as a fallback.
      }

      if (!mounted) return;

      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.text = profile.name;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = phone;
        }
        if (_emailController.text.isEmpty) {
          _emailController.text = profile.email;
        }
      });
    } catch (_) {
      // Silent by design.
    }
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

    setState(() => _isSending = true);

    final result = await OrdersService.place(
      contactName: _nameController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      comment: _commentController.text.trim(),
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
            _isGuest
                ? 'Заполните все три поля: по почте придёт код получения.'
                : 'Проверьте данные — при необходимости измените для этого заказа.',
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
                onPressed: _isSending ? null : _submit,
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
