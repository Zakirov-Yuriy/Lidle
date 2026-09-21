import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/pages/products/order_placed_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/forms/phone_number_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Оформление заказа.
///
/// С 21.09.2026 экран собран по макету: сверху «Способ оплаты» и «Способ
/// получения», ниже «Ваши товары» по папкам, «Данные покупателя» и итог с
/// одной кнопкой «Оформить».
///
/// Магазин в заказе один — оба блока общие, как на макете. Магазинов
/// несколько — те же блоки идут по разу на каждый, с его названием: магазины
/// принимают разную оплату и возят не все, и общий выбор обещал бы то, чего
/// у кого-то из них нет (решение заказчика 21.09.2026).
///
/// Гость подтверждает почту кодом из письма (решение заказчика 21.09.2026):
/// туда уходят код получения и статус заказа, и опечатка в адресе оставила
/// бы его без них. Вошедшему код не нужен, его почта уже подтверждена.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.cart, this.productIds});

  final CartSnapshot cart;

  /// Номера отмеченных в корзине позиций (14.09.2026).
  ///
  /// Пусто — оформляется вся корзина, как было раньше. Список — только эти
  /// позиции, остальное останется лежать. `cart` при этом уже обрезан до
  /// выбранного, чтобы состав и сумма на экране совпадали с заказом.
  final List<int>? productIds;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  /// Пользовательское соглашение: та же ссылка, что при регистрации.
  static const _agreementUrl = 'https://lidle.ru/documents/user-agreement.pdf';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  /// Телефон пишется так же, как на регистрации: «+7 (925) 449 95 50».
  /// Фокус нужен, чтобы при первом касании пустого поля появился «+7».
  final _phoneFocus = FocusNode();
  final _emailController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isGuest = true;
  bool _isSending = false;

  /// Подтвердил ли человек, что платит продавцу напрямую.
  ///
  /// Требование заказчика от 08.09.2026. Заранее её НЕ ставим: галочка,
  /// проставленная за человека, ничего не подтверждает.
  bool _paymentAcknowledged = false;

  /// Чем человек платит в каждой точке: номер точки — ключ способа.
  final Map<int, String> _paymentMethods = {};

  /// Как человек получает заказ в каждой точке. Пусто значит самовывоз.
  final Map<int, CartDeliveryOption?> _delivery = {};

  /// Адрес и комментарий для курьера, по точке.
  final Map<int, TextEditingController> _addresses = {};
  final Map<int, TextEditingController> _addressComments = {};

  // ── Покупатель: физлицо или компания (21.09.2026) ──────────────────

  bool _isCompany = false;
  final _companyNameController = TextEditingController();
  final _innController = TextEditingController();

  // ── Код подтверждения почты гостя (21.09.2026) ─────────────────────

  final _codeController = TextEditingController();

  /// Код уже запрошен: показываем поле кода и таймер.
  bool _codeRequested = false;

  /// Идёт запрос кода или проверка.
  bool _codeBusy = false;

  /// Через сколько секунд можно просить новый код.
  int _resendLeft = 0;
  Timer? _resendTimer;

  /// Текст ошибки проверки: поле становится красным.
  String? _codeError;

  /// Токен подтверждённой почты и сама почта, для которой он выдан.
  String? _emailToken;
  String? _verifiedEmail;

  /// Свёрнутые блоки в «Ваших товарах»: ключ — номер папки, `null` — без папки.
  final Set<int?> _collapsed = {};

  @override
  void initState() {
    super.initState();

    for (final group in widget.cart.shops) {
      if (group.paymentMethods.isNotEmpty) {
        _paymentMethods[group.shopId] = group.paymentMethods.first.key;
      }
    }

    final token = HiveService.getUserData('token');
    _isGuest = token == null || '$token'.isEmpty;

    // Контакты приходят вместе с корзиной: то, чем этот покупатель оформлял
    // в прошлый раз, иначе профиль. Комментарий не подставляем никогда.
    final contacts = widget.cart.contacts;

    _nameController.text = contacts.name ?? '';
    _phoneController.text = formatPhoneForDisplay(contacts.phone ?? '');
    _emailController.text = contacts.email ?? '';

    _phoneFocus.addListener(_onPhoneFocus);

    // Почту поменяли после подтверждения — подтверждение больше не про неё.
    _emailController.addListener(_onEmailChanged);
  }

  void _onPhoneFocus() {
    if (!_phoneFocus.hasFocus || _phoneController.text.isNotEmpty) return;

    _phoneController.text = '+7';
    _phoneController.selection = TextSelection.fromPosition(
      TextPosition(offset: _phoneController.text.length),
    );
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim().toLowerCase();

    if (_verifiedEmail != null && email != _verifiedEmail) {
      setState(() {
        _emailToken = null;
        _verifiedEmail = null;
        _codeRequested = false;
        _codeError = null;
        _codeController.clear();
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _phoneFocus.removeListener(_onPhoneFocus);
    _phoneFocus.dispose();
    _phoneController.dispose();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _commentController.dispose();
    _companyNameController.dispose();
    _innController.dispose();
    _codeController.dispose();

    for (final controller in _addresses.values) {
      controller.dispose();
    }

    for (final controller in _addressComments.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ── Логика ─────────────────────────────────────────────────────────

  bool get _isVerified => !_isGuest || _emailToken != null;

  bool get _canSubmit =>
      !_isSending &&
      _isVerified &&
      !(_needsAcknowledgement && !_paymentAcknowledged);

  /// Требует ли оформление подтверждения перевода: решает выбранный способ.
  bool get _needsAcknowledgement {
    var sawMethods = false;

    for (final group in widget.cart.shops) {
      if (group.paymentMethods.isEmpty) continue;

      sawMethods = true;

      final chosen = _methodFor(group);

      if (chosen == null || chosen.needsAcknowledgement) return true;
    }

    return sawMethods ? false : widget.cart.payment.required;
  }

  CartPaymentMethod? _methodFor(CartShopGroup group) {
    final key = _paymentMethods[group.shopId];

    for (final method in group.paymentMethods) {
      if (method.key == key) return method;
    }

    return null;
  }

  /// Что отправляем серверу про получение. Цену доставки НЕ отправляем: её
  /// подставит сервер по номеру способа.
  Map<int, OrderDeliveryChoice> _deliveryChoices() {
    final result = <int, OrderDeliveryChoice>{};

    for (final group in widget.cart.shops) {
      final choice = _delivery[group.shopId];

      if (choice == null || !choice.isCourier) {
        result[group.shopId] = const OrderDeliveryChoice.pickup();

        continue;
      }

      result[group.shopId] = OrderDeliveryChoice.courier(
        optionId: choice.id,
        address: _addresses[group.shopId]?.text.trim(),
        comment: _addressComments[group.shopId]?.text.trim(),
      );
    }

    return result;
  }

  double _deliveryTotal() {
    var sum = 0.0;

    for (final shop in widget.cart.shops) {
      sum += _delivery[shop.shopId]?.price ?? 0;
    }

    return sum;
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      SnackBarHelper.showWarning(context, 'Укажите почту, на неё придёт код');

      return;
    }

    setState(() => _codeBusy = true);

    final result = await OrdersService.sendGuestCode(email);

    if (!mounted) return;

    setState(() => _codeBusy = false);

    if (!result.isOk) {
      SnackBarHelper.showError(context, result.error!);

      return;
    }

    setState(() {
      _codeRequested = true;
      _codeError = null;
      _codeController.clear();
    });

    _startTimer(result.resendIn ?? 60);
  }

  void _startTimer(int seconds) {
    _resendTimer?.cancel();

    setState(() => _resendLeft = seconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();

        return;
      }

      setState(() => _resendLeft = _resendLeft > 0 ? _resendLeft - 1 : 0);

      if (_resendLeft == 0) timer.cancel();
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _codeError = 'Введите код из письма');

      return;
    }

    setState(() => _codeBusy = true);

    final email = _emailController.text.trim();
    final result = await OrdersService.verifyGuestCode(email, code);

    if (!mounted) return;

    setState(() {
      _codeBusy = false;

      if (result.token != null) {
        _emailToken = result.token;
        _verifiedEmail = email.toLowerCase();
        _codeError = null;
        _resendTimer?.cancel();
        _resendLeft = 0;
      } else {
        _codeError = result.error ?? 'Код не подошёл';
      }
    });
  }

  Future<void> _submit() async {
    if (_isSending) return;

    final phoneDigits =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (phoneDigits.isNotEmpty && phoneDigits.length < 11) {
      SnackBarHelper.showWarning(
        context,
        'Телефон указан не полностью: нужно 10 цифр после +7',
      );

      return;
    }

    if (_isGuest) {
      final missing = _nameController.text.trim().isEmpty ||
          phoneDigits.isEmpty ||
          _emailController.text.trim().isEmpty;

      if (missing) {
        SnackBarHelper.showWarning(
          context,
          'Без регистрации нужны имя, телефон и почта: по почте придёт код получения',
        );

        return;
      }

      if (_emailToken == null) {
        SnackBarHelper.showWarning(
          context,
          'Подтвердите почту кодом из письма',
        );

        return;
      }
    }

    if (_isCompany) {
      final inn = _innController.text.replaceAll(RegExp(r'\D'), '');

      if (_companyNameController.text.trim().isEmpty ||
          !(inn.length == 10 || inn.length == 12)) {
        SnackBarHelper.showWarning(
          context,
          'Для юридического лица нужны название компании и ИНН: 10 или 12 цифр',
        );

        return;
      }
    }

    for (final group in widget.cart.shops) {
      final choice = _delivery[group.shopId];

      if (choice == null || !choice.isCourier) continue;

      if ((_addresses[group.shopId]?.text.trim() ?? '').isEmpty) {
        SnackBarHelper.showWarning(
          context,
          'Укажите адрес, куда везти заказ из магазина «${group.shopName}»',
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
      contactPhone: cleanPhone(_phoneController.text.trim()),
      contactEmail: _emailController.text.trim(),
      comment: _commentController.text.trim(),
      productIds: widget.productIds,
      paymentAcknowledged: _paymentAcknowledged,
      paymentMethods: _paymentMethods,
      deliveries: _deliveryChoices(),
      emailToken: _emailToken,
      buyerType: _isCompany ? 'company' : 'individual',
      companyName: _isCompany ? _companyNameController.text.trim() : null,
      companyInn:
          _isCompany ? _innController.text.replaceAll(RegExp(r'\D'), '') : null,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    if (!result.isOk) {
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

  // ── Экран ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _sectionTitle('Способ оплаты'),
                  ..._buildPaymentSection(),
                  const SizedBox(height: 16),
                  _sectionTitle('Способ получения'),
                  ..._buildDeliverySection(),
                  const SizedBox(height: 16),
                  _sectionTitle('Ваши товары'),
                  ..._buildItemsSection(),
                  const SizedBox(height: 16),
                  _sectionTitle('Данные покупателя'),
                  _buildBuyerSection(),
                  const SizedBox(height: 16),
                  _buildTotals(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            ),
          ),
          Expanded(
            child: Text(
              _isGuest ? 'Оформить без регистрации' : 'Оформление заказа',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
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

  // ── Способ оплаты ──────────────────────────────────────────────────

  List<Widget> _buildPaymentSection() {
    final shops = widget.cart.shops;
    final many = shops.length > 1;

    return [
      for (final group in shops)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (many) _shopCaption(group),
                ..._paymentOptions(group),
              ],
            ),
          ),
        ),
      if (_needsAcknowledgement) _buildAcknowledgement(),
    ];
  }

  List<Widget> _paymentOptions(CartShopGroup group) {
    final methods = group.paymentMethods;

    // Старый сервер без способов: расчёт при получении.
    if (methods.isEmpty) {
      return const [
        Text(
          'Оплата при получении',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
      ];
    }

    final chosen = _paymentMethods[group.shopId];

    return [
      for (final method in methods)
        _radioRow(
          selected: method.key == chosen,
          title: method.title,
          hint: method.hint,
          onTap: () => setState(() => _paymentMethods[group.shopId] = method.key),

          // Реквизиты только у выбранного: платить человек будет по ним.
          extra: method.key == chosen && method.fields.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final field in method.fields)
                      Text(
                        '${field.label}: ${field.value}',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                )
              : null,
        ),
    ];
  }

  Widget _buildAcknowledgement() {
    final payment = widget.cart.payment;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            payment.notice,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () =>
                setState(() => _paymentAcknowledged = !_paymentAcknowledged),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _paymentAcknowledged,
                  activeColor: activeIconColor,
                  onChanged: (value) =>
                      setState(() => _paymentAcknowledged = value ?? false),
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

  // ── Способ получения ───────────────────────────────────────────────

  List<Widget> _buildDeliverySection() {
    final shops = widget.cart.shops;

    // Один магазин: получатель и выбор в одной карточке, как на макете.
    if (shops.length == 1) {
      final group = shops.first;

      return [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._deliveryOptions(group),
              const SizedBox(height: 6),
              ..._recipientFields(),
              ..._deliveryDetails(group),
            ],
          ),
        ),
      ];
    }

    // Несколько: получатель один на все заказы, выбор по магазинам.
    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _recipientFields(),
        ),
      ),
      for (final group in shops)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shopCaption(group),
                ..._deliveryOptions(group),
                ..._deliveryDetails(group),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _deliveryOptions(CartShopGroup group) {
    var options = group.deliveryOptions;

    // Самовывоз есть всегда: у старого сервера списка может не быть вовсе.
    if (options.isEmpty) {
      options = const [
        CartDeliveryOption(type: 'pickup', name: 'Самовывоз'),
      ];
    }

    final chosen = _delivery[group.shopId];

    return [
      for (final option in options)
        _radioRow(
          selected: option.isCourier
              ? chosen?.id == option.id && chosen != null
              : chosen == null,
          // Курьерских способов у магазина бывает несколько («Доставка на
          // авто», «Пеший курьер»), поэтому у курьера название продавца, а
          // не одно на всех «Курьером».
          title: option.isCourier
              ? (option.name.trim().isEmpty ? 'Курьером' : option.name)
              : 'Самовывоз',
          hint: option.isCourier
              ? [
                  (option.description ?? '').isNotEmpty
                      ? option.description!
                      : 'Курьер привезёт заказ вам по адресу',
                  if (option.price > 0) _money(option.price),
                ].join(' · ')
              : 'Вы сами забираете заказ в магазине',
          onTap: () => setState(
            () => _delivery[group.shopId] = option.isCourier ? option : null,
          ),
        ),
    ];
  }

  List<Widget> _recipientFields() {
    return [
      _labeledField(
        'Имя и фамилия',
        _nameController,
        type: TextInputType.name,
      ),
      _labeledField(
        'Номер телефона',
        _phoneController,
        type: TextInputType.phone,
        focusNode: _phoneFocus,
        formatters: [PhoneNumberFormatter()],
      ),
    ];
  }

  /// Под выбором: адрес для курьера или магазин для самовывоза.
  List<Widget> _deliveryDetails(CartShopGroup group) {
    final chosen = _delivery[group.shopId];

    if (chosen != null && chosen.isCourier) {
      final address =
          _addresses.putIfAbsent(group.shopId, TextEditingController.new);
      final comment =
          _addressComments.putIfAbsent(group.shopId, TextEditingController.new);

      return [
        _labeledField('Адрес', address, hint: 'Улица, дом, квартира'),
        _labeledField(
          'Подъезд, этаж, домофон',
          comment,
          hint: 'Необязательно',
        ),
        const Text(
          'Перед доставкой с вами свяжется менеджер и уведомит о прибытии '
          'курьера',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
      ];
    }

    return [
      const SizedBox(height: 2),
      _infoLine('Магазин', group.shopName),
      if ((group.address ?? '').isNotEmpty) _infoLine('Адрес', group.address!),
    ];
  }

  // ── Ваши товары ────────────────────────────────────────────────────

  /// Товары по папкам, как они лежали в корзине.
  ///
  /// Внутри папки по магазинам: у каждого магазина свой заказ, своя
  /// доставка и своя цена за неё.
  List<Widget> _buildItemsSection() {
    final folders = <int?>[
      null,
      ...widget.cart.folders.map((f) => f.id),
    ];

    final names = <int?, String>{
      null: 'Без папки',
      for (final f in widget.cart.folders) f.id: f.name,
    };

    final blocks = <Widget>[];

    for (final folderId in folders) {
      final byShop = <CartShopGroup, List<CartLine>>{};

      for (final group in widget.cart.shops) {
        final lines = group.items
            .where((line) => line.isAvailable && line.folderId == folderId)
            .toList();

        if (lines.isNotEmpty) byShop[group] = lines;
      }

      if (byShop.isEmpty) continue;

      final collapsed = _collapsed.contains(folderId);

      blocks.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  collapsed
                      ? _collapsed.remove(folderId)
                      : _collapsed.add(folderId);
                }),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          names[folderId] ?? 'Без папки',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        collapsed ? Icons.expand_more : Icons.expand_less,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              if (!collapsed) ...[
                const Divider(color: Color(0xFF2E3A47), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in byShop.entries)
                        _shopItems(entry.key, entry.value),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return blocks;
  }

  Widget _shopItems(CartShopGroup group, List<CartLine> lines) {
    final choice = _delivery[group.shopId];
    final courier = choice != null && choice.isCourier;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoLine('Название магазина', '«${group.shopName}»'),
          if (courier && choice.price > 0)
            _infoLine('Цена доставки', _money(choice.price)),
          _infoLine('Доставка', courier ? 'Курьером' : 'Самовывоз'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final line in lines) _itemPhoto(line),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemPhoto(CartLine line) {
    final image = line.image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 72,
        height: 72,
        color: secondaryBackground,
        child: image == null || image.isEmpty
            ? const Icon(Icons.image_outlined, color: textMuted)
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image_not_supported_outlined,
                        color: textMuted),
              ),
      ),
    );
  }

  // ── Данные покупателя ──────────────────────────────────────────────

  Widget _buildBuyerSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _radioRow(
            selected: !_isCompany,
            title: 'Физическое лицо',
            hint: 'Покупаете для себя',
            onTap: () => setState(() => _isCompany = false),
          ),
          _radioRow(
            selected: _isCompany,
            title: 'Юридическое лицо',
            hint: 'Покупаете от компании: нужны название и ИНН для документов',
            onTap: () => setState(() => _isCompany = true),
          ),
          const SizedBox(height: 6),
          if (_isCompany) ...[
            _labeledField('Название компании', _companyNameController),
            _labeledField(
              'ИНН',
              _innController,
              type: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
            ),
          ],
          _labeledField(
            'Ваша почта',
            _emailController,
            type: TextInputType.emailAddress,

            // Подтверждённую почту не правим случайно: зелёная рамка
            // говорит, что всё в порядке. Поменять можно, но тогда код
            // придётся запросить заново.
            borderColor: _isGuest && _emailToken != null
                ? const Color(0xFF3BB273)
                : null,
          ),
          if (_isGuest) ..._buildCodeBlock(),
          _labeledField(
            'Комментарий продавцу',
            _commentController,
            hint: 'Необязательно',
            lines: 3,
          ),
          if (_isGuest) _buildSignInLink(),
        ],
      ),
    );
  }

  List<Widget> _buildCodeBlock() {
    // Почта подтверждена: ни поля, ни кнопок, только отметка.
    if (_emailToken != null) {
      return const [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF3BB273), size: 18),
              SizedBox(width: 6),
              Text(
                'Почта подтверждена',
                style: TextStyle(color: Color(0xFF3BB273), fontSize: 14),
              ),
            ],
          ),
        ),
      ];
    }

    if (!_codeRequested) {
      return [
        _outlinedButton(
          _codeBusy ? 'Отправляем…' : 'Получить код',
          _codeBusy ? null : _requestCode,
        ),
        const SizedBox(height: 12),
      ];
    }

    final hasError = _codeError != null;
    final canResend = _resendLeft == 0 && !_codeBusy;

    final timer =
        '${_resendLeft ~/ 60}:${(_resendLeft % 60).toString().padLeft(2, '0')}';

    return [
      _labeledField(
        'Код из письма',
        _codeController,
        type: TextInputType.number,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        borderColor: hasError ? const Color(0xFFE05B5B) : null,
        textColor: hasError ? const Color(0xFFE05B5B) : null,
        onChanged: (_) {
          if (_codeError != null) setState(() => _codeError = null);
        },
        bottomGap: 6,
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            _codeError!,
            style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 13),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, color: textSecondary, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _resendLeft > 0
                    ? 'Мы отправили код на почту. Получить новый код можно '
                        'через $timer'
                    : 'Не пришло письмо? Проверьте папку «Спам» или отправьте '
                        'новый код.',
                style: const TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),

      // После неверного кода кнопка просит новый код, как на макете. Как
      // только человек начал править код, она снова «Отправить».
      if (hasError)
        _outlinedButton(
          'Отправить новый код',
          canResend ? _requestCode : null,
        )
      else ...[
        _outlinedButton(
          _codeBusy ? 'Проверяем…' : 'Отправить',
          _codeBusy ? null : _verifyCode,
        ),
        if (canResend) ...[
          const SizedBox(height: 8),
          _outlinedButton('Отправить новый код', _requestCode),
        ],
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _buildSignInLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          text: 'Есть аккаунт? ',
          style: const TextStyle(color: textSecondary, fontSize: 14),
          children: [
            TextSpan(
              text: 'Войти',
              style: const TextStyle(color: activeIconColor, fontSize: 14),
              recognizer: TapGestureRecognizer()
                ..onTap = () =>
                    Navigator.of(context).pushNamed(SignInScreen.routeName),
            ),
          ],
        ),
      ),
    );
  }

  // ── Итог ───────────────────────────────────────────────────────────

  Widget _buildTotals() {
    final items = widget.cart.availableItemsCount;
    final delivery = _deliveryTotal();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Скидок на площадке пока нет: строка честно показывает ноль.
          _totalRow('Скидка', _money(0)),
          _totalRow('Товары ($items)', _money(widget.cart.total)),
          _totalRow('Доставка', _money(delivery)),
          const Divider(color: Color(0xFF2E3A47), height: 20),
          Row(
            children: [
              const Text(
                'Итог',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _money(widget.cart.total + delivery),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: activeIconColor,
                disabledBackgroundColor: const Color(0xFF1F4E6B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              // Гостю кнопка оживает после подтверждения почты. Погашенная
              // кнопка не объясняет почему, поэтому подсказка под ней.
              onPressed: _canSubmit ? _submit : null,
              child: Text(
                _isSending ? 'Отправляем…' : 'Оформить',
                style: TextStyle(
                  color: _canSubmit ? Colors.white : Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_isGuest && _emailToken == null) ...[
            const SizedBox(height: 6),
            const Text(
              'Чтобы оформить, подтвердите почту кодом из письма',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: 'Подтверждая заказ, я принимаю условия ',
              style: const TextStyle(color: textSecondary, fontSize: 13),
              children: [
                TextSpan(
                  text: 'пользовательского соглашения',
                  style: const TextStyle(color: activeIconColor, fontSize: 13),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                          Uri.parse(_agreementUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Общие кусочки ──────────────────────────────────────────────────

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _shopCaption(CartShopGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        group.shopName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Строка «Подпись: значение», подпись серая, значение белое.
  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioRow({
    required bool selected,
    required String title,
    String hint = '',
    required VoidCallback onTap,
    Widget? extra,
  }) {
    return InkWell(
      onTap: onTap,
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
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                  if (extra != null) ...[
                    const SizedBox(height: 4),
                    extra,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    String hint = 'Введите',
    TextInputType type = TextInputType.text,
    int lines = 1,
    FocusNode? focusNode,
    List<TextInputFormatter>? formatters,
    Color? borderColor,
    Color? textColor,
    ValueChanged<String>? onChanged,
    double bottomGap = 12,
  }) {
    final idle = borderColor ?? const Color(0xFF3A4654);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            focusNode: focusNode,
            inputFormatters: formatters,
            keyboardType: type,
            maxLines: lines,
            onChanged: onChanged,
            style: TextStyle(color: textColor ?? Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: textMuted, fontSize: 15),
              filled: true,
              fillColor: secondaryBackground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: idle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor ?? activeIconColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedButton(String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onTap == null ? textMuted : activeIconColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: onTap == null ? textMuted : activeIconColor,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
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
    final whole = value.truncate().toString();

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }
}
