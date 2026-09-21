// ============================================================
// "Экран: Подробности заказа"
// ============================================================
//
// Открывается с экрана «Ваш заказ» по строке «Подробности заказа»
// (17.09.2026). Раньше подробности раскрывались прямо там гармошкой, но в
// раскрытом виде они занимали весь экран и отодвигали код получения, ради
// которого экран и открывают. Теперь это отдельный экран, а на заказе
// остаётся одна строка.
//
// Всё на экране относится к ОДНОМУ заказу и берётся из него же: способ
// получения, точка, номер, код, способ оплаты. Ничего не досчитываем и не
// подставляем «как обычно»: заказ хранит снимок того, о чём договаривались,
// и показывать надо именно его.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lidle/widgets/products/payment_link_block.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';
import 'package:lidle/pages/products/order_courier_screen.dart';
import 'package:lidle/pages/products/order_receipt_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/dialogs/courier_review_dialog.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class OrderDetailsScreen extends StatefulWidget {
  static const String routeName = '/order-details';

  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  /// Заказ, перечитанный с сервера после оценки курьера (18.09.2026).
  ///
  /// Экран стал с состоянием ради одной вещи: поставив звёзды, человек должен
  /// увидеть их тут же, а рейтинг считает сервер. Пока оценки не было,
  /// показываем то, с чем экран открыли.
  OrderModel? _fresh;

  OrderModel get order => _fresh ?? widget.order;

  bool get _isPickup => order.deliveryType != 'courier';

  Future<void> _reload() async {
    final fresh = await OrdersService.details(order.id);

    if (fresh != null && mounted) setState(() => _fresh = fresh);
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0, left: 8),
                  child: Header(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleRow(context),
                      const SizedBox(height: 10),
                      _deliveryCard(),
                      const SizedBox(height: 10),
                      _shopCard(context),
                      if (!_isPickup) ...[
                        const SizedBox(height: 10),
                        _courierCard(context),
                        const SizedBox(height: 10),
                        _deliveryAddressCard(),
                      ],
                      const SizedBox(height: 10),
                      _receiveCard(),
                      const SizedBox(height: 10),
                      _numberCard(context),
                      const SizedBox(height: 10),
                      _codeCard(context),
                      const SizedBox(height: 10),
                      _paymentCard(),
                      const SizedBox(height: 10),
                      _sumCard(),
                      const SizedBox(height: 16),
                      _receiptButton(context),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ],
            ),
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
                'Подробности заказа',
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

  /// Как человек получает заказ.
  ///
  /// Показываем оба способа, а не один выбранный: человек смотрит сюда, чтобы
  /// убедиться, что заказ именно на самовывоз, и вторая строка рядом отвечает
  /// на этот вопрос быстрее, чем одна строка без сравнения.
  Widget _deliveryCard() {
    return _card(
      title: 'Доставка',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _choiceRow(
            title: 'Самовывоз',
            hint: 'Забор товара из магазина осуществляет покупатель',
            selected: _isPickup,
          ),
          const SizedBox(height: 12),
          _choiceRow(
            title: 'Курьером',
            hint: 'Доставку товара осуществляет курьер на указанный адрес',
            selected: !_isPickup,
          ),
        ],
      ),
    );
  }

  /// Адрес доставки отдельной карточкой (18.09.2026).
  ///
  /// Только у курьерского заказа и рядом с магазином, а не вместо него: при
  /// доставке человеку важны оба адреса, откуда везут и куда.
  Widget _deliveryAddressCard() {
    final address = (order.deliveryAddress ?? '').trim();
    final comment = (order.deliveryComment ?? '').trim();

    if (address.isEmpty && comment.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Адрес доставки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address.isNotEmpty)
            Text(
              'Ваш адрес: $address',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),

          // Подъезд, этаж и домофон человек пишет одной строкой при
          // оформлении: отдельных полей у заказа нет, и разбирать эту строку
          // на части значит гадать.
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                comment,
                style: const TextStyle(color: textSecondary, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  /// Магазин заказа. Нажатие открывает страницу продавца (18.09.2026).
  ///
  /// Страница знает ЧЕЛОВЕКА, а не точку, поэтому нужен её владелец. Старый
  /// сервер его в заказе не присылает, и тогда блок не нажимается: лучше так,
  /// чем пустой экран после нажатия.
  Widget _shopCard(BuildContext context) {
    final shop = order.shop;

    if (shop == null) return const SizedBox.shrink();

    final userId = shop.userId;

    void open() {
      if (userId == null) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SellerProfileScreen(
            sellerName: shop.name,
            sellerAvatar:
                const AssetImage('assets/profile_dashboard/default-photo.svg'),
            sellerAvatarUrl: shop.image,
            userId: '$userId',
          ),
        ),
      );
    }

    return _card(
      title: 'Магазин',
      child: GestureDetector(
        onTap: userId == null ? null : open,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shop.name.isNotEmpty)
              Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Магазина: ',
                            style: TextStyle(color: textSecondary, fontSize: 15),
                          ),
                          TextSpan(
                            text: '«${shop.name}»',
                            style:
                                const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (userId != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(Icons.chevron_right,
                          color: activeIconColor, size: 18),
                    ),
                ],
              ),
            if ((shop.address ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  shop.address!,
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Кто везёт (18.09.2026). Нажатие открывает экран курьера с его
  /// контактами: телефон и мессенджеры, переписки с ним в приложении нет.
  Widget _courierCard(BuildContext context) {
    final man = order.courier;
    final name = (man?.name.isNotEmpty ?? false)
        ? man!.name
        : (order.courierName ?? '');

    if (name.isEmpty) {
      return _card(
        title: 'Курьер',
        child: const Text(
          'Курьер пока не назначен',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
      );
    }

    return _card(
      title: 'Курьер',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderCourierScreen(order: order)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 48,
                height: 48,
                child: (man?.image ?? '').isEmpty
                    ? _courierFallback(name)
                    : Image.network(
                        man!.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _courierFallback(name),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((man?.position ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        man!.position!,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Рейтинг со звёздами (18.09.2026). Нажатие открывает
                  // оценку, если заказ уже получен: оценивают доставку, а
                  // пока её не было, оценивать нечего.
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: courierRatingRow(
                      context,
                      order: order,
                      onChanged: _reload,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: textSecondary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _courierFallback(String name) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);

    return Container(
      color: primaryBackground,
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Кто может забрать заказ.
  ///
  /// Вопрос живой: человек на работе, а за товаром идёт кто-то другой.
  /// Отвечаем прямо, потому что выдача действительно идёт по коду, а не по
  /// паспорту.
  Widget _receiveCard() {
    if (!_isPickup) {
      return _card(
        title: 'Получение',
        child: const Text(
          'Курьер привезёт заказ по указанному адресу. Код получения назовите '
          'курьеру при передаче товара',
          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        ),
      );
    }

    return _card(
      title: 'Получать',
      child: const Text(
        'Ваш заказ может забрать любой человек, назвав продавцу код получения',
        style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _numberCard(BuildContext context) {
    return _card(
      title: 'Номер заказа',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.number,
            style: const TextStyle(color: textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: order.number));
              SnackBarHelper.showSuccess(context, 'Номер заказа скопирован');
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Скопировать',
                style: TextStyle(color: activeIconColor, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Код получения.
  ///
  /// В макете здесь штрих-код, но штрих-кода у нас пока нет, и рисовать
  /// полосы, которые не считает ни один сканер, нельзя: продавец попробовал бы
  /// их отсканировать и решил бы, что сломалось приложение. Показываем тот же
  /// код, что и на экране заказа, тем же белым полем: при ярком свете в зале
  /// тёмный экран читается хуже.
  Widget _codeCard(BuildContext context) {
    final code = (order.pickupCode ?? '').trim();

    return _card(
      title: 'Код получения',
      child: GestureDetector(
        onTap: code.isEmpty
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: code));
                SnackBarHelper.showSuccess(context, 'Код скопирован');
              },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                code.isEmpty ? 'Код появится после подтверждения' : code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: code.isEmpty ? 15 : 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: code.isEmpty ? 0 : 5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                code.isEmpty
                    ? 'Продавец ещё не принял заказ'
                    : 'Нажмите, чтобы скопировать',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7684), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Чем платят по этому заказу.
  ///
  /// Выбранный способ отмечен, остальные показаны бледными. Список берём из
  /// заказа: это те способы, которые точка принимала в момент оформления, и
  /// дописывать к ним «обычные» значило бы показать человеку выбор, которого
  /// у него не было.
  Widget _paymentCard() {
    final chosen = (order.paymentMethod ?? '').trim();
    final keys = <String>[];

    if (chosen.isNotEmpty) keys.add(chosen);

    for (final type in order.paymentTypes) {
      final key = _normalize(type);

      if (key.isNotEmpty && !keys.contains(key)) keys.add(key);
    }

    if (keys.isEmpty) {
      final title = (order.paymentMethodTitle ?? '').trim();

      if (title.isEmpty) return const SizedBox.shrink();

      return _card(
        title: 'Оплата',
        child: _choiceRow(title: title, selected: true),
      );
    }

    return _card(
      title: 'Оплата',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _choiceRow(
              // Для выбранного способа берём название из заказа: оно хранится
              // копией и переживёт переименование в справочнике.
              title: keys[i] == chosen && (order.paymentMethodTitle ?? '').isNotEmpty
                  ? order.paymentMethodTitle!
                  : _paymentTitle(keys[i]),
              hint: _paymentHint(keys[i]),
              selected: keys[i] == chosen,
            ),
          ],
          // Заказ без записанного способа оплаты: так оформлялись заказы до
          // 15.09.2026, когда выбора ещё не было, и так приходят заказы от
          // клиента, который про выбор не знает. Сервер в этом случае
          // намеренно не подставляет ничего: записать «наличные» за человека
          // значило бы записать в заказ то, чего он не выбирал.
          //
          // Но ряд одинаково серых кружков читается как «всё сломалось»,
          // поэтому объясняем прямо, а не оставляем человека гадать
          // (17.09.2026).
          // Как заплатить продавцу (21.09.2026): реквизиты выбранного
          // способа и кнопка «Оплатить» с QR-кодом, если продавец дал ссылку
          // своего банка. Деньги идут продавцу напрямую.
          if (order.paymentLink != null || order.paymentFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            OrderPaymentDetails(order: order),
          ],
          if (chosen.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Способ оплаты в этом заказе не записан: он оформлен до того, '
                'как появился выбор. Рассчитайтесь с продавцом при получении.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sumCard() {
    return _card(
      title: 'Сумма',
      child: Column(
        children: [
          for (final item in order.items)
            _sumRow(
              '${item.name} × ${item.quantity}',
              '${item.sum.toStringAsFixed(0)} ₽',
            ),
          if (!_isPickup && order.deliveryPrice.isNotEmpty)
            _sumRow('Доставка', '${order.deliveryPrice} ₽'),
          const Divider(height: 18, color: Color(0xFF2C3A48)),
          _sumRow('Итого', '${order.total} ₽', bold: true),
        ],
      ),
    );
  }

  Widget _sumRow(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: bold ? Colors.white : textSecondary,
                fontSize: 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// Строка выбора: галочка и подпись у выбранного, бледный кружок у
  /// остальных. Невыбранное не прячем: рядом видно, из чего выбирали.
  Widget _choiceRow({
    required String title,
    String? hint,
    required bool selected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: selected
              ? const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF4CD964),
                  size: 20,
                )
              : const Icon(
                  Icons.circle_outlined,
                  color: textMuted,
                  size: 20,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if ((hint ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    hint!,
                    style: TextStyle(
                      color: selected ? textSecondary : textMuted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// «Ваш чек».
  ///
  /// Открывает товарный чек по этому заказу, его можно сохранить на телефон.
  /// Кассовым он не является: кассу печатает продавец, см.
  /// [OrderReceiptScreen].
  Widget _receiptButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderReceiptScreen(order: order)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: activeIconColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Ваш чек',
          style: TextStyle(color: activeIconColor, fontSize: 15),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  /// Старые названия типов реквизитов и их место в нынешнем справочнике.
  /// `account` это перевод по реквизитам счёта, то есть нынешний
  /// `bank_transfer`.
  static String _normalize(String type) {
    switch (type.trim()) {
      case 'account':
        return 'bank_transfer';
      default:
        return type.trim();
    }
  }

  static String _paymentTitle(String key) {
    switch (key) {
      case 'cash':
        return 'Наличными';
      case 'card':
        return 'Картой';
      case 'sbp':
        return 'Система быстрых платежей';
      case 'bank_transfer':
        return 'Переводом';
      default:
        return key;
    }
  }

  static String? _paymentHint(String key) {
    switch (key) {
      case 'cash':
      case 'card':
        return 'При получении товара';
      case 'sbp':
      case 'bank_transfer':
        return 'Перевести деньги онлайн';
      default:
        return null;
    }
  }
}
