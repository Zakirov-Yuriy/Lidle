// ============================================================
// "Экран: Курьер"
// ============================================================
//
// Открывается с экрана заказа и из подробностей заказа (18.09.2026).
//
// Курьер это сотрудник продавца, а не пользователь приложения: учётной записи
// у него нет, войти он не может, переписки с ним в приложении тоже нет.
// Поэтому «связаться» здесь значит позвонить или написать в мессенджер, и
// контакты взяты из карточки сотрудника, которую ведёт продавец.
//
// Пустые поля здесь обычное дело: продавец заполняет карточку по мере того,
// как договаривается с человеком. Пустых строк не рисуем, показываем только
// то, что есть.
//
// Рейтинг курьера здесь же (18.09.2026): звёзды показывают оценку и служат
// кнопкой. Оценить можно только после получения заказа, потому что оценивают
// доставку, а пока её не было, оценивать нечего.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/dialogs/courier_review_dialog.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/report_courier_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class OrderCourierScreen extends StatefulWidget {
  static const String routeName = '/order-courier';

  final OrderModel order;

  const OrderCourierScreen({super.key, required this.order});

  @override
  State<OrderCourierScreen> createState() => _OrderCourierScreenState();
}

class _OrderCourierScreenState extends State<OrderCourierScreen> {
  /// Заказ, перечитанный после оценки: рейтинг считает сервер, и увидеть свою
  /// звезду человек должен сразу.
  OrderModel? _fresh;

  OrderModel get order => _fresh ?? widget.order;

  OrderCourier? get courier => order.courier;

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
                      _card(context),
                      const SizedBox(height: 12),
                      _complaintCard(context),
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
                'Курьер',
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

  Widget _card(BuildContext context) {
    final man = courier;
    final name = (man?.name.isNotEmpty ?? false)
        ? man!.name
        : (order.courierName ?? 'Курьер');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(man?.image, name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((man?.position ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          man!.position!,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),

                    // Рейтинг со звёздами (18.09.2026). Звёзды и показывают
                    // оценку, и служат кнопкой: нажал на третью — диалог
                    // откроется с тремя.
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: courierRatingRow(
                        context,
                        order: order,
                        onChanged: _reload,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Контакты. Каждая строка нажимается и делает то, чего от неё ждут:
          // номер звонит, мессенджер открывается в своём приложении.
          if (man != null && man.phones.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label('Номер'),
            for (final phone in man.phones)
              _contactRow(
                context,
                text: phone,
                onTap: () => _open(context, 'tel:${_digits(phone)}'),
                white: true,
              ),
          ],

          if ((man?.telegram ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _label('Телеграмм'),
            _contactRow(
              context,
              text: _handle(man!.telegram!),
              onTap: () => _open(
                context,
                'https://t.me/${_clean(man.telegram!)}',
              ),
            ),
          ],

          if ((man?.whatsapp ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _label('WhatsApp'),
            _contactRow(
              context,
              // Номер показываем номером, а не «@+7949…»: собачка уместна у
              // ника, а у телефона выглядит опечаткой (18.09.2026).
              text: _digits(man!.whatsapp!).length >= 10
                  ? man.whatsapp!
                  : _handle(man.whatsapp!),
              onTap: () => _open(
                context,
                // У WhatsApp адрес по номеру: если продавец вписал имя, а не
                // номер, открываем поиск по нему.
                _digits(man.whatsapp!).length >= 10
                    ? 'https://wa.me/${_digits(man.whatsapp!)}'
                    : 'https://wa.me/${_clean(man.whatsapp!)}',
              ),
            ),
          ],

          if ((man?.vk ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _label('VK'),
            _contactRow(
              context,
              text: _handle(man!.vk!),
              onTap: () => _open(context, 'https://vk.com/${_clean(man.vk!)}'),
            ),
          ],

          if ((man?.city ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF2C3A48)),
            const SizedBox(height: 12),
            _label('Город'),
            Text(
              man!.city!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          if (man == null || !man.hasContacts) ...[
            const SizedBox(height: 14),
            const Text(
              'Продавец не указал контакты курьера. Свяжитесь с магазином, '
              'если нужно уточнить доставку',
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required String text,
    required VoidCallback onTap,
    bool white = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // Долгое нажатие копирует: в шумном подъезде проще скопировать номер и
      // набрать его самому, чем ловить нажатие.
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        SnackBarHelper.showSuccess(context, 'Скопировано');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            color: white ? Colors.white : activeIconColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? image, String name) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        width: 64,
        height: 64,
        child: (image ?? '').isEmpty
            ? _avatarFallback(letter)
            : Image.network(
                image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(letter),
              ),
      ),
    );
  }

  Widget _avatarFallback(String letter) {
    return Container(
      color: primaryBackground,
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _complaintCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оставить жалобу на исполнителя',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // «правил» выделено синим, как на соседних экранах. Пока это только
          // выделение: экрана с правилами в приложении нет.
          const Text.rich(
            TextSpan(
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: 'Вы можете оставить жалобу на исполнителя в случае '
                      'нарушения им ',
                ),
                TextSpan(
                  text: 'правил',
                  style: TextStyle(color: activeIconColor),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => showCourierComplaint(context, order),
            behavior: HitTestBehavior.opaque,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Пожаловаться',
                  style: TextStyle(color: Color(0xFFE05B5B), fontSize: 15),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFE05B5B),
                  size: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!ok && context.mounted) {
        SnackBarHelper.showWarning(context, 'Не удалось открыть');
      }
    } catch (e) {
      log.d('Ссылка курьера не открылась ($url): $e');

      if (context.mounted) {
        SnackBarHelper.showWarning(context, 'Не удалось открыть');
      }
    }
  }

  /// Только цифры: телефон продавец пишет как привык, а набирать надо номер.
  static String _digits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  /// Ник без собачки и без адреса: продавец пишет и «@ivan», и
  /// «https://t.me/ivan», а ссылку мы собираем сами.
  static String _clean(String value) {
    var text = value.trim();

    for (final prefix in const [
      'https://',
      'http://',
      't.me/',
      'vk.com/',
      'wa.me/',
      'www.',
      '@',
    ]) {
      if (text.toLowerCase().startsWith(prefix)) {
        text = text.substring(prefix.length);
      }
    }

    // Хвост вида «?start=1» отрезаем: в ссылку он не нужен, а в подписи
    // выглядит мусором.
    return text.split('?').first.replaceAll('/', '');
  }

  static String _handle(String value) {
    final clean = _clean(value);

    return clean.isEmpty ? value : '@$clean';
  }
}

/// Диалог жалобы на курьера. Вынесен функцией: открывается и с этого экрана, и
/// кнопкой прямо на экране заказа.
Future<void> showCourierComplaint(BuildContext context, OrderModel order) {
  return showDialog<bool>(
    context: context,
    builder: (_) => ReportCourierDialog(
      orderId: order.id,
      courierName: order.courierName ?? '',
    ),
  ).then((_) {});
}
