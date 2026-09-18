// ============================================================
// "Экран: Ваш заказ"
// ============================================================
//
// Открывается из карусели покупок в кабинете (17.09.2026).
//
// Главное на экране это код получения: человек приходит в точку и называет его
// продавцу. Настоящего штрих-кода у нас пока нет, и рисовать полосатую картинку
// вместо него мы не стали: продавец попробовал бы её отсканировать, сканер
// промолчал бы, и оба решили бы, что сломалось приложение. Поэтому код показан
// крупно и читаемо, а картинка появится, когда появится сам штрих-код.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/products/order_courier_screen.dart';
import 'package:lidle/pages/products/order_details_screen.dart';
import 'package:lidle/pages/products/order_questions_screen.dart';
import 'package:lidle/pages/products/product_details_screen.dart';
import 'package:lidle/services/image_saver.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/cancel_order_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class YourOrderScreen extends StatefulWidget {
  static const String routeName = '/your-order';

  final OrderModel order;

  /// Позиция, с которой человек пришёл сюда из карусели. Экран открывается по
  /// конкретному товару, и показать надо в первую очередь его.
  final OrderLine? line;

  const YourOrderScreen({super.key, required this.order, this.line});

  @override
  State<YourOrderScreen> createState() => _YourOrderScreenState();
}

class _YourOrderScreenState extends State<YourOrderScreen> {
  /// Снимок карточки с кодом: по кнопке «Скачать код» сохраняем именно её.
  final GlobalKey _codeKey = GlobalKey();

  bool _saving = false;

  /// Идёт отмена. Пока идёт, кнопка «Отказаться» не нажимается: второе
  /// нажатие ушло бы вторым запросом, а заказ отменяется один раз.
  bool _cancelling = false;

  /// Заказ после отмены. Показываем его, не перезагружая экран: сервер
  /// возвращает изменённый заказ в ответе, и второй запрос за тем же самым
  /// был бы лишним.
  OrderModel? _cancelled;

  OrderModel get order => _cancelled ?? widget.order;
  OrderLine? get line => widget.line;

  bool get _isPickup => order.deliveryType != 'courier';

  /// Сохранить карточку с кодом в галерею.
  ///
  /// Настоящего штрих-кода у нас пока нет, поэтому сохраняем то, что человек и
  /// показывает продавцу: карточку с кодом. Снимок делаем с самого экрана, а
  /// не рисуем второй раз: так сохранится ровно то, что человек видит.
  Future<void> _saveCode() async {
    if (_saving) return;

    setState(() => _saving = true);

    final result = await ImageSaver.saveBoundary(
      _codeKey,
      'LIDLE_code_${order.number}.png',
    );

    if (!mounted) return;

    setState(() => _saving = false);

    switch (result) {
      case ImageSaveResult.saved:
        SnackBarHelper.showSuccess(context, 'Код сохранён в галерею');
        break;
      case ImageSaveResult.noPermission:
        SnackBarHelper.showWarning(
          context,
          'Нужно разрешение на сохранение файлов',
        );
        break;
      case ImageSaveResult.failed:
        SnackBarHelper.showError(context, 'Не удалось сохранить код');
        break;
    }
  }

  /// Спросить и отменить.
  ///
  /// Отказ необратим, поэтому подтверждение словом, а не «да/нет»: см.
  /// [CancelOrderDialog].
  void _askCancel() {
    showDialog<void>(
      context: context,
      builder: (_) => CancelOrderDialog(onConfirm: _cancel),
    );
  }

  Future<void> _cancel() async {
    if (_cancelling) return;

    setState(() => _cancelling = true);

    final result = await OrdersService.cancel(order.id);

    if (!mounted) return;

    setState(() {
      _cancelling = false;

      if (result.isOk && result.order != null) _cancelled = result.order;
    });

    if (result.isOk) {
      SnackBarHelper.showSuccess(
        context,
        result.message.isEmpty ? 'Заказ отменён' : result.message,
      );

      // Кабинет обновит карусель покупок: отменённый заказ из неё уходит.
      Navigator.of(context).pop(true);

      return;
    }

    SnackBarHelper.showError(
      context,
      result.message.isEmpty ? 'Не удалось отменить заказ' : result.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = line ?? (order.items.isEmpty ? null : order.items.first);

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
                      const SizedBox(height: 6),
                      RepaintBoundary(key: _codeKey, child: _codeCard(context)),
                      const SizedBox(height: 10),
                      _downloadButton(),
                      const SizedBox(height: 16),
                      if (current != null) _itemCard(current),
                      const SizedBox(height: 12),
                      _deliveryCard(),
                      const SizedBox(height: 12),
                      _detailsRow(context),
                      const SizedBox(height: 12),
                      _actionButtons(context),
                      // Место под нижнее меню: экран под ним продолжается, и
                      // без запаса последняя кнопка пряталась бы за иконками.
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
                'Ваш заказ',
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

  /// Код получения крупно, на белом.
  ///
  /// Белая карточка не для красоты: человек показывает её продавцу в торговом
  /// зале, и тёмный экран при ярком свете читается хуже.
  Widget _codeCard(BuildContext context) {
    final code = (order.pickupCode ?? '').trim();

    return GestureDetector(
      onTap: code.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: code));
              SnackBarHelper.showSuccess(context, 'Код скопирован');
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              code.isEmpty ? 'Код появится после подтверждения' : code,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: code.isEmpty ? 16 : 40,
                fontWeight: FontWeight.w700,
                letterSpacing: code.isEmpty ? 0 : 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              code.isEmpty
                  ? 'Продавец ещё не принял заказ'
                  : 'Назовите код продавцу для получения товара',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7684), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// Кнопка «Скачать код».
  ///
  /// В макете она называется «Скачать штрих-код», но штрих-кода у нас пока нет,
  /// и обещать в подписи то, чего не сохранится, нельзя.
  Widget _downloadButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _saving ? null : _saveCode,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: activeIconColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Скачать код',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Купленный товар.
  ///
  /// Нажимается вся карточка целиком, а не картинка или название по
  /// отдельности: человек целится в товар, а не в его часть. Открывается
  /// карточка товара в виде «из заказа» (17.09.2026).
  ///
  /// У позиции без номера товара карточки нет: товар могли снять с витрины.
  /// Тогда карточка просто не нажимается, и это честнее, чем открыть пустой
  /// экран с крутилкой.
  Widget _itemCard(OrderLine item) {
    final productId = item.productId;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: productId == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(
                    productId: productId,
                    fromOrder: true,
                  ),
                ),
              ),
      child: _itemCardBody(item),
    );
  }

  Widget _itemCardBody(OrderLine item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.statusTitle,
            style: TextStyle(
              color: _statusColor(order.status),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(item.image),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    if ((item.sku ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Артикул: ${item.sku}',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (item.status == 'rejected') ...[
                      const SizedBox(height: 4),
                      Text(
                        (item.rejectReason ?? '').isEmpty
                            ? 'Продавец отклонил эту позицию'
                            : 'Отклонено: ${item.rejectReason}',
                        style: const TextStyle(
                          color: Color(0xFFE05B5B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumb(String? image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 54,
        height: 54,
        child: (image ?? '').isEmpty
            ? Container(
                color: primaryBackground,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: textMuted,
                  size: 20,
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
                    size: 20,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _deliveryCard() {
    final shop = order.shop;
    final hours = shop?.todayHours;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  _isPickup ? 'Самовывоз' : (order.deliveryTitle ?? 'Доставка'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hours != null)
                Text(
                  hours,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isPickup) ...[
            // Подпись серая, название магазина белое, адрес снова серый: белым
            // выделено то, что человек ищет глазами на месте.
            if ((shop?.name ?? '').isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Магазина: ',
                      style: TextStyle(color: textSecondary, fontSize: 15),
                    ),
                    TextSpan(
                      text: '«${shop!.name}»',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            if ((shop?.address ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  shop!.address!,
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ),
          ] else ...[
            // Курьерская доставка (18.09.2026): кто везёт, откуда забирает и
            // куда привезёт. Порядок с макета: сначала человек, потом места.
            _courierRow(),
            _placeBlock(
              title: 'Место забора',
              lines: [
                if ((shop?.name ?? '') .isNotEmpty)
                  _PlaceLine('Магазина: «${shop!.name}»', white: false),
                if ((shop?.address ?? '').isNotEmpty)
                  _PlaceLine(shop!.address!, white: true),
              ],
            ),
            _placeBlock(
              title: 'Место доставки',
              lines: [
                if ((order.deliveryAddress ?? '').isNotEmpty)
                  _PlaceLine('Ваш адрес: ${order.deliveryAddress}', white: true),

                // Подъезд, этаж и домофон человек пишет одной строкой при
                // оформлении: отдельных полей у заказа нет, и разбирать эту
                // строку на части значит гадать.
                if ((order.deliveryComment ?? '').isNotEmpty)
                  _PlaceLine(order.deliveryComment!, white: false),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Кто везёт: фото, имя, должность и две кнопки.
  ///
  /// «Написать» открывает экран курьера с его телефоном и мессенджерами, а не
  /// переписку: учётной записи у курьера нет, он в приложение не входит, и
  /// чата с ним быть не может (решение заказчика 18.09.2026).
  Widget _courierRow() {
    final man = order.courier;
    final name = (man?.name.isNotEmpty ?? false)
        ? man!.name
        : (order.courierName ?? '');

    // Курьера ещё не назначили: обещать человеку кнопки, которые ведут в
    // пустоту, нельзя.
    if (name.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Курьер пока не назначен',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openCourier(),
            child: Row(
              children: [
                _courierAvatar(man?.image, name),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showCourierComplaint(context, order),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: Color(0xFFE05B5B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Пожаловаться',
                    style: TextStyle(color: Color(0xFFE05B5B), fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _openCourier,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: activeIconColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Написать',
                    style: TextStyle(color: activeIconColor, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCourier() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderCourierScreen(order: order)),
    );
  }

  Widget _courierAvatar(String? image, String name) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);

    Widget fallback() => Container(
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 48,
        height: 48,
        child: (image ?? '').isEmpty
            ? fallback()
            : Image.network(
                image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              ),
      ),
    );
  }

  /// «Место забора» и «Место доставки»: заголовок и строки под ним.
  ///
  /// Карты в макете есть, но картографии в приложении нет вовсе, ни одного
  /// пакета. Ставить картинку вместо карты нельзя: человек будет её тянуть и
  /// решит, что приложение зависло.
  Widget _placeBlock({required String title, required List<_PlaceLine> lines}) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line.text,
                style: TextStyle(
                  color: line.white ? Colors.white : textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Строка «Подробности заказа»: подпись и стрелка отдельными полями.
  ///
  /// Раньше подробности раскрывались здесь же гармошкой, но в раскрытом виде
  /// они занимали весь экран и отодвигали код получения, ради которого экран и
  /// открывают. Теперь это отдельный экран, а здесь остаётся строка. Стрелка
  /// вынесена в своё поле по макету; нажимаются оба поля одинаково, потому что
  /// человек целится в строку, а не в стрелку.
  Widget _detailsRow(BuildContext context) {
    void open() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: open,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: secondaryBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Подробности заказа',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: open,
          child: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward_ios,
              color: textSecondary,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// «Отказаться» и «Задать вопрос».
  ///
  /// Отказ показываем только у живого заказа: отменить выданный или уже
  /// отменённый нельзя, и кнопка, которая всегда отвечает отказом сервера,
  /// хуже её отсутствия.
  Widget _actionButtons(BuildContext context) {
    final canCancel = order.isAlive;

    final question = OutlinedButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderQuestionsScreen(order: order)),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: const BorderSide(color: activeIconColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Задать вопрос',
        style: TextStyle(color: activeIconColor, fontSize: 15),
      ),
    );

    if (!canCancel) {
      return SizedBox(width: double.infinity, child: question);
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _cancelling ? null : _askCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFFE05B5B)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _cancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Отказаться',
                    style: TextStyle(color: Color(0xFFE05B5B), fontSize: 15),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: question),
      ],
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

/// Строка в блоках «Место забора» и «Место доставки».
///
/// Белым выделено то, что человек ищет глазами: адрес. Подпись и уточнения
/// серые, иначе белым становится весь блок и выделение перестаёт работать.
class _PlaceLine {
  final String text;
  final bool white;

  const _PlaceLine(this.text, {required this.white});
}
