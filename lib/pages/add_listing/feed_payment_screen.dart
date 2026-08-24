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
  // Возврат после оплаты ловим по ПУТИ, а не по полному адресу: у прода
  // несколько доменов (lidle.ru, lidle.io, lidle.xn--p1ai), и BILLING_RETURN_URL
  // на бэке может смениться без пересборки приложения.
  static const String _returnPath = '/cabinet/billing';

  bool _loading = true;
  String? _error;

  String _tariffTitle = '';
  int _priceRub = 0;

  bool _paying = false;
  bool _verifying = false;
  String? _verifyMessage;

  // Платёж уже создавался в этой сессии экрана. Пока флаг взведён, главной
  // кнопкой становится «Проверить оплату», а повторная оплата уезжает во
  // второстепенную ссылку: иначе пользователь, не дождавшись вебхука, жмёт
  // привычную синюю кнопку и создаёт ВТОРОЙ платёж (бэк не видит активной
  // подписки и заводит ещё одну pending) — то есть платит дважды.
  bool _paymentStarted = false;

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
            final uri = Uri.tryParse(request.url);
            if (uri != null && uri.path.startsWith(_returnPath)) {
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
        _paymentStarted = true;
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

  /// Закрыть WebView, не проверяя оплату (крестик в шапке). Платёж при этом
  /// уже создан, поэтому на карточке останется «Проверить оплату».
  void _closeWebView() {
    if (!mounted) return;
    setState(() {
      _webUrl = null;
      _controller = null;
    });
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
          'Оплата ещё не подтверждена. Если вы оплатили, подождите немного и нажмите «Проверить оплату». Повторно платить не нужно.';
    });
  }

  /// Повторная оплата — только по явному подтверждению: создаёт НОВЫЙ платёж.
  Future<void> _onPayAgain() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: formBackground,
        title: const Text('Оплатить заново?',
            style: TextStyle(color: textPrimary, fontSize: 18)),
        content: const Text(
          'Будет создан новый платёж. Если предыдущая оплата уже прошла, '
          'деньги спишутся второй раз. Сначала попробуйте «Проверить оплату».',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Создать платёж',
                style: TextStyle(color: Color(0xFF009EE2))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _onPay();
    }
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
            onPressed: _closeWebView,
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

  /// Синяя кнопка во всю ширину — единый стиль для «Оплатить» и «Проверить оплату».
  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool busy,
  }) {
    return SizedBox(
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
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF009EE2),
                ),
              )
            : Text(
                label,
                style: const TextStyle(color: Color(0xFF009EE2), fontSize: 16),
              ),
      ),
    );
  }

  // Карточка тарифа фида — тот же вид, что на экране «Тариф публикации».
  Widget _buildTariffCard() {
    final features = <String>[
      'Публикация всех объявлений из фида',
      'Подписка на 30 дней',
    ];

    final busy = _paying || _verifying;

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

          // Платёж ещё не создавался — обычная кнопка «Оплатить».
          if (!_paymentStarted)
            _primaryButton(
              label: 'Оплатить',
              onPressed: _onPay,
              busy: busy,
            )
          // Платёж уже создан: главная кнопка — проверка, повторная оплата
          // спрятана в неприметную ссылку и требует подтверждения.
          else ...[
            _primaryButton(
              label: 'Проверить оплату',
              onPressed: _verify,
              busy: busy,
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: busy ? null : _onPayAgain,
                child: const Text(
                  'Оплатить заново',
                  style: TextStyle(color: textMuted, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}