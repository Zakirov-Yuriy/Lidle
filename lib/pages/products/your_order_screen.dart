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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

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

  OrderModel get order => widget.order;
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

    try {
      PermissionStatus status;

      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;

        status = info.version.sdkInt >= 33
            ? await Permission.photos.request()
            : await Permission.storage.request();
      } else if (Platform.isIOS) {
        status = await Permission.photos.request();
      } else {
        status = PermissionStatus.granted;
      }

      if (!status.isGranted) {
        if (mounted) {
          SnackBarHelper.showWarning(
            context,
            'Нужно разрешение на сохранение файлов',
          );
        }

        return;
      }

      final boundary = _codeKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) return;

      final bytes = data.buffer.asUint8List();
      final name = 'LIDLE_code_${order.number}.png';

      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/$name');
      await file.writeAsBytes(bytes);

      await _saveToGallery(file, name);

      if (await file.exists()) await file.delete();

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Код сохранён в галерею');
      }
    } catch (e) {
      log.d('Код не сохранился: $e');

      if (mounted) {
        SnackBarHelper.showError(context, 'Не удалось сохранить код');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Куда класть файл. Путь тот же, что у сохранения QR продавца: два разных
  /// места означали бы два разных ответа на вопрос «куда сохранилось».
  Future<void> _saveToGallery(File file, String name) async {
    if (Platform.isAndroid) {
      try {
        final directory = Directory('/storage/emulated/0/DCIM/Camera');

        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        await file.copy('${directory.path}/$name');

        return;
      } catch (e) {
        log.d('DCIM недоступен, кладём в папку приложения: $e');
      }
    }

    final documents = await getApplicationDocumentsDirectory();

    await file.copy('${documents.path}/$name');
  }

  @override
  Widget build(BuildContext context) {
    final current = line ?? (order.items.isEmpty ? null : order.items.first);

    return Scaffold(
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
                    _detailsCard(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _itemCard(OrderLine item) {
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
            if ((order.deliveryAddress ?? '').isNotEmpty)
              Text(
                'Куда: ${order.deliveryAddress}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            if ((order.deliveryComment ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  order.deliveryComment!,
                  style: const TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            if ((order.courierName ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Курьер: ${order.courierName}',
                  style: const TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Подробности заказа: то, что человеку нужно изредка, поэтому спрятано под
  /// раскрытие, а не занимает экран.
  Widget _detailsCard(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: textSecondary,
          collapsedIconColor: textSecondary,
          title: const Text(
            'Подробности заказа',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            _detailRow('Номер заказа', order.number),
            if (order.createdAt != null)
              _detailRow('Оформлен', _date(order.createdAt!)),
            for (final item in order.items)
              _detailRow(
                '${item.name} × ${item.quantity}',
                '${item.sum.toStringAsFixed(0)} ₽',
              ),
            if (!_isPickup && order.deliveryPrice.isNotEmpty)
              _detailRow('Доставка', '${order.deliveryPrice} ₽'),
            _detailRow('Итого', '${order.total} ₽'),
            if ((order.paymentMethodTitle ?? '').isNotEmpty)
              _detailRow('Оплата', order.paymentMethodTitle!),
            if ((order.contactPhone ?? '').isNotEmpty)
              _detailRow('Телефон', order.contactPhone!),
            if ((order.comment ?? '').isNotEmpty)
              _detailRow('Комментарий', order.comment!),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year}';
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
