// ============================================================
// "Экран: Чек по заказу"
// ============================================================
//
// Открывается кнопкой «Ваш чек» в подробностях заказа (17.09.2026).
//
// ВАЖНО, чем это является и чем не является. Это ТОВАРНЫЙ чек: что человек
// купил, у кого, за сколько и чем платил. Это НЕ кассовый чек: кассовый чек
// печатает онлайн-касса продавца, он содержит фискальный признак, номер ФН,
// ФД, ФПД и проверяется на сайте ФНС. Ни кассы, ни связи с ОФД в проекте нет,
// и придумать эти номера нельзя: документ с выдуманным фискальным признаком
// это подделка кассового чека, а не «примерно чек». Поэтому внизу прямо
// написано, что документ не кассовый, а за кассовым надо к продавцу.
//
// Когда касса появится, чек будет приходить с неё, и этот экран станет её
// показывать; всё остальное в нём останется как есть.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/image_saver.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class OrderReceiptScreen extends StatefulWidget {
  static const String routeName = '/order-receipt';

  final OrderModel order;

  const OrderReceiptScreen({super.key, required this.order});

  @override
  State<OrderReceiptScreen> createState() => _OrderReceiptScreenState();
}

class _OrderReceiptScreenState extends State<OrderReceiptScreen> {
  /// Снимок листа чека: по кнопке сохраняем именно его, без кнопок и меню.
  final GlobalKey _sheetKey = GlobalKey();

  bool _saving = false;

  OrderModel get order => widget.order;

  bool get _isPickup => order.deliveryType != 'courier';

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    final result = await ImageSaver.saveBoundary(
      _sheetKey,
      'LIDLE_chek_${order.number}.png',
    );

    if (!mounted) return;

    setState(() => _saving = false);

    switch (result) {
      case ImageSaveResult.saved:
        SnackBarHelper.showSuccess(context, 'Чек сохранён в галерею');
        break;
      case ImageSaveResult.noPermission:
        SnackBarHelper.showWarning(
          context,
          'Нужно разрешение на сохранение файлов',
        );
        break;
      case ImageSaveResult.failed:
        SnackBarHelper.showError(context, 'Не удалось сохранить чек');
        break;
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
                      RepaintBoundary(key: _sheetKey, child: _sheet()),
                      const SizedBox(height: 12),
                      _saveButton(),
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
                'Ваш чек',
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

  /// Сам лист чека: белый, с чёрным текстом.
  ///
  /// Белый не ради вида: чек сохраняют и показывают, иногда печатают, и
  /// тёмная картинка в галерее среди фотографий читается хуже, а на бумаге
  /// заливает страницу.
  Widget _sheet() {
    final shop = order.shop;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Товарный чек № ${order.number}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (order.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  _dateTime(order.createdAt!),
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            ),
          if (shop != null && shop.name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  shop.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if ((shop?.address ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: Text(
                  shop!.address!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            ),
          if ((shop?.phone ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: Text(
                  shop!.phone!,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            ),
          const _DashedLine(),
          for (var i = 0; i < order.items.length; i++) _position(i),
          if (!_isPickup && _amount(order.deliveryPrice) > 0)
            _extraRow('Доставка', _amount(order.deliveryPrice)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 1.4, color: Colors.black),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'ИТОГО',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_money(_amount(order.total))} ₽',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if ((order.paymentMethodTitle ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Оплата: ${order.paymentMethodTitle}'
                '${order.paymentOnPickup ? ' при получении' : ''}',
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _isPickup ? 'Получение: самовывоз' : 'Получение: доставка курьером',
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          if ((order.contactName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Покупатель: ${order.contactName}',
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
            ),
          const _DashedLine(),
          // Прямая оговорка, а не мелкая сноска: человек должен понимать, что
          // этим документом налоговую не устроить и в суд с ним не пойти.
          const Text(
            'Документ не является кассовым чеком. Кассовый чек при оплате '
            'выдаёт продавец.',
            style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'lidle.io',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Позиция чека: название, артикул, «сколько × почём» и сумма.
  Widget _position(int index) {
    final item = order.items[index];

    // Отклонённую позицию оставляем в чеке зачёркнутой подписью, а не
    // выбрасываем: человек её заказывал, и молча исчезнувшая строка выглядит
    // как ошибка в документе. Сумма у неё ноль, платить за неё не придётся.
    final isRejected = item.status == 'rejected';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${item.name}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if ((item.sku ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                'Артикул: ${item.sku}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isRejected
                        ? 'Отклонено продавцом'
                        : '${item.quantity} × ${_money(_amount(item.price))}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${_money(item.sum)} ₽',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _extraRow(String title, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.black, fontSize: 13),
            ),
          ),
          Text(
            '${_money(value)} ₽',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _saving ? null : _save,
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
                'Скачать чек',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Сумма из строки сервера. Сервер отдаёт деньги строкой, и разбирать её
  /// надо в одном месте: запятая вместо точки и пробелы в тысячах встречаются
  /// в обоих написаниях.
  static double _amount(String value) {
    return double.tryParse(
          value.replaceAll(' ', '').replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  /// Деньги как их пишут в чеке: тысячи пробелом, копейки запятой.
  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');

      buffer.write(digits[i]);
    }

    return '$buffer,${parts[1]}';
  }

  static String _dateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

/// Пунктир, как на кассовой ленте. Рисуем сами: `Divider` умеет только
/// сплошную линию, а картинка ради пунктира весит больше кода.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dash = 5.0;
          const gap = 4.0;

          final count = (constraints.maxWidth / (dash + gap)).floor();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count < 1 ? 1 : count,
              (_) => Container(width: dash, height: 1, color: Colors.black38),
            ),
          );
        },
      ),
    );
  }
}
