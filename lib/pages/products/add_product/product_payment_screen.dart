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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_payment_setup_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

/// Что человек выбрал в оплате: способы и их настройки.
class PaymentChoice {
  const PaymentChoice({required this.methods, required this.settings});

  final List<String> methods;

  /// Ключ способа → куда приходят деньги.
  final Map<String, String> settings;
}

class ProductPaymentScreen extends StatefulWidget {
  const ProductPaymentScreen({
    super.key,
    this.chosen = const [],
    this.settings = const {},
  });

  /// Ключи способов, отмеченных сейчас.
  final List<String> chosen;

  /// Настройки способов, заданные раньше.
  final Map<String, String> settings;

  /// Фирменные значки способов. Ключи те же, что у сервера.
  ///
  /// Лежат в приложении, а не приходят с сервера: это оформление, и гонять
  /// его по сети незачем. Отсюда же их берёт экран настройки: два разных
  /// набора значков для одного и того же человек воспримет как разные вещи.
  ///
  /// Векторные рисуются одинаково чётко на любом экране.
  static const Map<String, String> vectors = {
    'card': 'assets/payment/card.svg',
    'yoomoney': 'assets/payment/yoomoney.svg',
    'sberpay': 'assets/payment/sberpay.svg',
    'sbp': 'assets/payment/sbp.svg',
    'cash': 'assets/payment/cash.svg',
  };

  /// Растровые.
  ///
  /// «Безналичный перевод» только здесь: в его SVG вклеена растровая
  /// картинка, а такие flutter_svg не рисует и оставляет пустоту. Рисунок
  /// тот же, просто в другом виде.
  static const Map<String, String> images = {
    'bank_transfer': 'assets/payment/bank_transfer.png',
  };

  static String? vectorFor(String key) => vectors[key];

  static String? imageFor(String key) => images[key];

  @override
  State<ProductPaymentScreen> createState() => _ProductPaymentScreenState();
}

class _ProductPaymentScreenState extends State<ProductPaymentScreen> {

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

  late final Map<String, String> _settings = {...widget.settings};

  PaymentDictionary _dictionary = const PaymentDictionary();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    try {
      final dictionary = await ProductsCabinetApi.paymentMethods();

      if (!mounted) return;

      setState(() {
        _dictionary = dictionary;
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

  /// «Выбрать» ведёт на настройку выбранного, а не закрывает экран.
  ///
  /// Выбор возвращается публикации только после «Сохранить» на втором шаге:
  /// человек ещё может вернуться и поправить отметки, и запоминать
  /// промежуточное состояние значит сохранить то, чего он не подтверждал.
  Future<void> _openSetup() async {
    if (_chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отметьте хотя бы один способ оплаты'),
          backgroundColor: secondaryBackground,
        ),
      );

      return;
    }

    final saved = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPaymentSetupScreen(
          chosen: _chosen.toList(),
          dictionary: _dictionary,
          settings: _settings,
        ),
      ),
    );

    if (saved == null || !mounted) return;

    Navigator.pop(
      context,
      PaymentChoice(methods: _chosen.toList(), settings: saved),
    );
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
                onTap: _openSetup,
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
        for (final method in _dictionary.methods) _row(method),
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
    final vector = ProductPaymentScreen.vectors[key];

    if (vector != null) {
      return SvgPicture.asset(
        vector,
        height: 22,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(width: 32, height: 22),
      );
    }

    final image = ProductPaymentScreen.images[key];

    if (image != null) {
      return Image.asset(
        image,
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
