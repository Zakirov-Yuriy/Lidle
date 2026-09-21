// ============================================================
//  Онлайн-оплата заказа через YooKassa (22.09.2026)
// ============================================================
//
// Как идёт оплата:
//   1. Сервер завёл платёж и дал ссылку на страницу YooKassa.
//   2. Открываем её во встроенном браузере. Человек вводит карту, банк
//      проверяет, YooKassa возвращает его на адрес с путём `/order-payment`.
//      Этот возврат ловим и закрываем браузер.
//   3. Спрашиваем сервер, чем кончилось. Вебхук может прийти на пару секунд
//      позже возврата, поэтому спрашиваем несколько раз.
//   4. Оплачено — дальше как обычно. Отказ — экран «Заказ не оплачен»
//      (order_unpaid_screen.dart) с причиной и выбором другого способа.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/models/orders/order_payment.dart';
import 'package:lidle/pages/products/order_unpaid_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Чем кончилась оплата для экрана оформления.
enum OrderPaymentOutcome {
  /// Оплачено онлайн.
  paid,

  /// Человек перешёл на наличные при получении.
  cash,

  /// Заказ отменён с экрана «Заказ не оплачен».
  cancelled,
}

class OrderPaymentFlowResult {
  final OrderPaymentOutcome outcome;

  /// Свежие заказы после перехода на наличные.
  final List<OrderModel> orders;

  const OrderPaymentFlowResult(this.outcome, {this.orders = const []});
}

/// Провести оплату от начала до исхода.
Future<OrderPaymentFlowResult> runOrderPayment(
  BuildContext context,
  OrderPaymentInfo payment,
) async {
  final result = await payOrderOnce(context, payment);

  if (result.paid) {
    return const OrderPaymentFlowResult(OrderPaymentOutcome.paid);
  }

  if (!context.mounted) {
    return const OrderPaymentFlowResult(OrderPaymentOutcome.cancelled);
  }

  final choice = await Navigator.push<OrderPaymentFlowResult>(
    context,
    MaterialPageRoute(builder: (_) => OrderUnpaidScreen(payment: result)),
  );

  return choice ?? const OrderPaymentFlowResult(OrderPaymentOutcome.cancelled);
}

/// Одна попытка: страница оплаты, затем ожидание исхода.
///
/// Возвращает последнее известное состояние. Если исход так и не пришёл
/// (человек закрыл страницу, не заплатив), возвращает платёж с причиной
/// «Оплата не завершена», чтобы экран «Заказ не оплачен» было чем заполнить.
Future<OrderPaymentInfo> payOrderOnce(
  BuildContext context,
  OrderPaymentInfo payment,
) async {
  // Отказ уже известен (YooKassa не ответила или сохранённую карту
  // отклонили сразу): страницу открывать незачем.
  if (payment.isFailed || payment.paid) return payment;

  final url = payment.confirmationUrl;

  if (url != null) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => OrderPaymentWebView(url: url)),
    );
  }

  if (!context.mounted) return payment;

  final latest = await _waitForOutcome(context, payment.token);

  if (latest == null) {
    return _unfinished(payment, 'Нет связи с сервером',
        'Проверьте интернет и попробуйте ещё раз');
  }

  if (latest.isPending) {
    return _unfinished(latest, 'Оплата не завершена',
        'Попробуйте ещё раз или выберите другой способ оплаты');
  }

  return latest;
}

OrderPaymentInfo _unfinished(OrderPaymentInfo p, String title, String hint) {
  return OrderPaymentInfo(
    token: p.token,
    status: p.status,
    paid: false,
    amount: p.amount,
    reason: 'unfinished',
    reasonTitle: title,
    reasonHint: hint,
    cards: p.cards,
  );
}

/// Спросить исход несколько раз, пока крутится индикатор.
Future<OrderPaymentInfo?> _waitForOutcome(
  BuildContext context,
  String token,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: activeIconColor)),
    ),
  );

  OrderPaymentInfo? latest;

  for (var attempt = 0; attempt < 6; attempt++) {
    latest = await OrdersService.paymentStatus(token) ?? latest;

    if (latest != null && !latest.isPending) break;

    await Future.delayed(const Duration(seconds: 2));
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

  return latest;
}

/// Страница оплаты YooKassa во встроенном браузере.
class OrderPaymentWebView extends StatefulWidget {
  const OrderPaymentWebView({super.key, required this.url});

  final String url;

  @override
  State<OrderPaymentWebView> createState() => _OrderPaymentWebViewState();
}

class _OrderPaymentWebViewState extends State<OrderPaymentWebView> {
  // Возврат ловим по ПУТИ: домен в ORDERS_PAYMENT_RETURN_URL на сервере
  // может смениться без пересборки приложения.
  static const String _returnPath = '/order-payment';

  late final WebViewController _controller;
  bool _loading = true;
  bool _closed = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);

            if (uri == null) return NavigationDecision.navigate;

            if (uri.path.startsWith(_returnPath)) {
              _close();

              return NavigationDecision.prevent;
            }

            // SberPay, T-Pay и СБП открывают приложение банка своей ссылкой.
            // Встроенный браузер такие ссылки не открывает, отдаём системе.
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              launchUrl(uri, mode: LaunchMode.externalApplication);

              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Оплата заказа',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _close,
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Готово',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
