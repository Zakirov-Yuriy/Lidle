// ============================================================
// Экран «Добавить оплату» (макет 11.09.2026).
// ============================================================
//
// Открывается с первого экрана публикации и со сводки. Продавец отмечает,
// какими способами у него можно заплатить.
//
// Список приходит С СЕРВЕРА (`GET /me/product-publications/payment-methods`).
// Вторая копия названий в приложении рано или поздно разъедется с первой, а
// за каждым пунктом стоит либо работающая интеграция, либо расчёт на месте:
// показать лишний способ значит получить покупателя, который его выбрал и не
// смог заплатить.
//
// Экран ничего не сохраняет сам: он возвращает выбор вызывающему экрану, а
// тот отправляет его вместе с публикацией. Иначе «Отмена» оставляла бы
// сохранённый выбор от несохранённой публикации.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPaymentScreen extends StatefulWidget {
  const ProductPaymentScreen({super.key, this.chosen = const []});

  /// Ключи способов, отмеченных сейчас.
  final List<String> chosen;

  @override
  State<ProductPaymentScreen> createState() => _ProductPaymentScreenState();
}

class _ProductPaymentScreenState extends State<ProductPaymentScreen> {
  /// Фирменные значки способов. Ключи те же, что у сервера.
  ///
  /// Лежат в приложении, а не приходят с сервера: это оформление, и гонять
  /// его по сети незачем.
  static const Map<String, String> _images = {
    'card': 'assets/payment/card.png',
    'yoomoney': 'assets/payment/yoomoney.png',
    'sberpay': 'assets/payment/sberpay.png',
    'sbp': 'assets/payment/sbp.png',
    'bank_transfer': 'assets/payment/bank_transfer.png',
  };

  /// Запасные значки: для способов без картинки и на случай, если файл не
  /// открылся. Пустое место в ряду хуже простого значка: строка разъезжается,
  /// и человек думает, что экран сломался.
  static const Map<String, IconData> _icons = {
    'card': Icons.credit_card,
    'yoomoney': Icons.account_balance_wallet_outlined,
    'sberpay': Icons.phone_iphone,
    'sbp': Icons.bolt,
    'cash': Icons.payments_outlined,
    'bank_transfer': Icons.account_balance_outlined,
  };

  late final Set<String> _chosen = {...widget.chosen};

  List<PaymentMethod> _methods = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await ProductsCabinetApi.paymentMethods();

      if (!mounted) return;

      setState(() {
        _methods = methods;
        _isLoading = false;
      });
    } catch (e) {
      log.e('Справочник оплаты не пришёл: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Не получилось загрузить способы оплаты. Проверьте связь.';
        _isLoading = false;
      });
    }
  }

  void _toggle(String key) {
    setState(() {
      _chosen.contains(key) ? _chosen.remove(key) : _chosen.add(key);
    });
  }

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: secondaryBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Как это работает',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Отметьте способы, которыми у вас можно заплатить. Покупатель '
                'увидит их при оформлении заказа.\n\n'
                'Реквизиты здесь не нужны: номер карты и телефон для перевода '
                'задаются отдельно, в настройках точки продаж.\n\n'
                'Отметить можно несколько способов сразу.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(color: activeIconColor, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            const SizedBox(height: 8),
            _titleRow(),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _explain,
                  child: const Text(
                    'Как это работает?',
                    style: TextStyle(color: activeIconColor, fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                16,
              ),
              child: GestureDetector(
                onTap: () => Navigator.pop(context, _chosen.toList()),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeIconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Выбрать',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: activeIconColor),
      );
    }

    final error = _error;

    if (error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textPrimary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });

              _load();
            },
            child: const Text(
              'Попробовать снова',
              style: TextStyle(color: activeIconColor),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        defaultPadding,
        14,
        defaultPadding,
        16,
      ),
      children: [
        const Text(
          'Способы оплаты',
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final method in _methods) _row(method),
      ],
    );
  }

  Widget _row(PaymentMethod method) {
    return GestureDetector(
      onTap: () => _toggle(method.key),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 26,
              child: Center(child: _badge(method.key)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method.title,
                style: const TextStyle(color: textPrimary, fontSize: 15),
              ),
            ),
            CustomCheckbox(
              value: _chosen.contains(method.key),
              onChanged: (_) => _toggle(method.key),
            ),
          ],
        ),
      ),
    );
  }

  /// Значок способа: фирменная картинка, если она есть, иначе значок.
  Widget _badge(String key) {
    final asset = _images[key];

    if (asset != null) {
      return Image.asset(
        asset,
        height: 22,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(key),
      );
    }

    return _fallback(key);
  }

  Widget _fallback(String key) => Container(
        width: 32,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _icons[key] ?? Icons.payment,
          color: activeIconColor,
          size: 15,
        ),
      );

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.chevron_left, color: textPrimary, size: 26),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Добавить оплату',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // «Отмена» уходит без сохранения: выбор остаётся прежним.
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
