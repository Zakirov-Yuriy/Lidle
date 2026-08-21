import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants.dart';
import '../../services/api_service.dart';
import '../../widgets/components/header.dart';

/// Экран оплаты подписки на публикацию фида.
///
/// Внешне повторяет экран «Тариф публикации» (карточка «Тариф: … / Цена: …»),
/// но для фида показывает ПЛАТНЫЙ тариф (без «Бесплатно») и кнопку «Оплатить».
/// По кнопке создаёт платёж (POST /me/billing/pay) и открывает страницу оплаты
/// YooKassa в WebView. После возврата на return_url (или по кнопке «Проверить
/// оплату») перепроверяет подписку. Возвращает `true`, если подписка стала
/// активной (оплата прошла) — вызывающий код после этого повторяет публикацию.
class FeedPaymentScreen extends StatefulWidget {
  static const String routeName = '/feed-payment';

  const FeedPaymentScreen({super.key});

  @override
  State<FeedPaymentScreen> createState() => _FeedPaymentScreenState();
}

class _FeedPaymentScreenState extends State<FeedPaymentScreen> {
  // Куда YooKassa возвращает после оплаты (совпадает с BILLING_RETURN_URL на
  // бэке). При переходе на этот адрес считаем оплату завершённой и проверяем.
  static const String _returnUrl = 'https://lidle.io/cabinet/billing';

  bool _loading = true;
  String? _error;

  String _tariffTitle = '';
  int _priceRub = 0;

  bool _paying = false;
  bool _verifying = false;
  String? _verifyMessage;

  String? _webUrl;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getBillingSubscription();
      final data = (resp['data'] as Map?) ?? {};

      // Уже есть активная подписка — оплата не нужна, выходим с успехом.
      if (data['is_active'] == true) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final tariff = (data['suggested_tariff'] as Map?) ?? {};
      final priceKop = (tariff['price'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _tariffTitle = (tariff['title'] ?? 'Публикация фида').toString();
        _priceRub = (priceKop / 100).round();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить тариф';
      });
    }
  }

  Future<void> _onPay() async {
    setState(() => _paying = true);
    try {
      final resp = await ApiService.createBillingPayment();
      final url = ((resp['data'] as Map?)?['confirmation_url'] ?? '').toString();
      if (url.isEmpty) {
        throw Exception('empty confirmation_url');
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(_returnUrl)) {
              _onReturned();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadRequest(Uri.parse(url));

      if (!mounted) return;
      setState(() {
        _paying = false;
        _webUrl = url;
        _controller = controller;
        _verifyMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      _snack('Не удалось создать платёж, попробуйте ещё раз');
    }
  }

  /// YooKassa вернула пользователя на return_url — закрываем WebView и
  /// проверяем подписку.
  void _onReturned() {
    if (!mounted) return;
    setState(() {
      _webUrl = null;
      _controller = null;
    });
    _verify();
  }

  /// Перепроверить подписку после оплаты (вебхук + активация занимают секунду).
  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _verifyMessage = null;
    });
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final resp = await ApiService.getBillingSubscription();
        final active = ((resp['data'] as Map?)?['is_active']) == true;
        if (active) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verifyMessage =
          'Оплата ещё не подтверждена. Если вы оплатили, подождите немного и нажмите «Проверить оплату».';
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    // Режим WebView (страница оплаты YooKassa).
    if (_webUrl != null && _controller != null) {
      return Scaffold(
        backgroundColor: primaryBackground,
        appBar: AppBar(
          backgroundColor: formBackground,
          foregroundColor: textPrimary,
          title: const Text('Оплата'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _webUrl = null;
              _controller = null;
            }),
          ),
          actions: [
            TextButton(
              onPressed: _onReturned,
              child: const Text('Проверить оплату',
                  style: TextStyle(color: Color(0xFF009EE2))),
            ),
          ],
        ),
        body: WebViewWidget(controller: _controller!),
      );
    }

    // Экран выбора тарифа. Назад запрещён (как на экране тарифа публикации):
    // выйти можно только кнопкой «Отмена».
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Header(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 19,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Тариф публикации',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _paying
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: defaultPadding),
                  child: Column(
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        _errorView()
                      else
                        _buildTariffCard(),
                      const SizedBox(height: 79),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text(_error!, style: const TextStyle(color: textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadInfo, child: const Text('Повторить')),
        ],
      ),
    );
  }

  // Карточка тарифа фида — тот же вид, что на экране «Тариф публикации».
  Widget _buildTariffCard() {
    final features = <String>[
      'Публикация всех объявлений из фида',
      'Подписка на 30 дней',
    ];

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 20, top: 19),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              children: [
                const TextSpan(
                  text: 'Тариф: ',
                  style: TextStyle(color: textSecondary),
                ),
                TextSpan(
                  text: _tariffTitle,
                  style: const TextStyle(color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/publication_tariff/check.svg',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/publication_tariff/icon.svg',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Без подписки объявления из фида не публикуются.',
                    style: TextStyle(color: textPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Divider(color: textMuted),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Цена: ',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: '$_priceRub ₽ / мес',
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_verifyMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _verifyMessage!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: formBackground,
                side: const BorderSide(color: Color(0xFF009EE2)),
                minimumSize: const Size.fromHeight(43),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: (_paying || _verifying) ? null : _onPay,
              child: (_paying || _verifying)
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF009EE2),
                      ),
                    )
                  : const Text(
                      'Оплатить',
                      style: TextStyle(color: Color(0xFF009EE2), fontSize: 16),
                    ),
            ),
          ),
          if (_verifyMessage != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _verifying ? null : _verify,
                child: const Text('Проверить оплату',
                    style: TextStyle(color: Color(0xFF009EE2))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
