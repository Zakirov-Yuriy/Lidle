// ============================================================
//  Онлайн-оплата заказа через YooKassa (22.09.2026)
// ============================================================
//
// Основной путь (22.09.2026, мобильный SDK YooKassa):
//   1. Сервер завёл платёж, но в YooKassa его ещё не отправлял.
//   2. Человек вводит карту в форме SDK прямо в приложении (или выбирает
//      SberPay, СБП). SDK отдаёт одноразовый токен.
//   3. Сервер создаёт платёж с этим токеном. Карта без 3-D Secure решается
//      сразу, и отказ банка («Недостаточно средств») приходит в ответе.
//      Нужен код из СМС — SDK сам открывает страницу банка.
//   4. Отказ — экран «Заказ не оплачен» с причиной и другими способами.
//
// Запасной путь (сервер без ключа SDK, T-Pay): страница оплаты YooKassa во
// встроенном браузере:
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
import 'package:yookassa_payments_flutter/input_data/saved_card_module_input_data.dart';
import 'package:yookassa_payments_flutter/yookassa_payments_flutter.dart';

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
  // Сервер завёл платёж под форму SDK: ссылки нет, ждёт токен карты.
  final result = payment.sdk != null &&
          payment.isPending &&
          payment.confirmationUrl == null
      ? await payOrderWithSdk(context, payment)
      : await payOrderOnce(context, payment);

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

/// Оплата формой SDK YooKassa.
///
/// [methods] — какие способы показать в форме; по умолчанию карта, SberPay
/// и СБП. [card] — заплатить сохранённой картой (SDK спросит только CVC).
Future<OrderPaymentInfo> payOrderWithSdk(
  BuildContext context,
  OrderPaymentInfo payment, {
  List<PaymentMethod> methods = const [
    PaymentMethod.bankCard,
    PaymentMethod.sberbank,
    PaymentMethod.sbp,
  ],
  SavedPaymentCard? card,
}) async {
  final sdk = payment.sdk;

  if (sdk == null) return payOrderOnce(context, payment);

  final amount = Amount(value: sdk.amount, currency: Currency.rub);
  final save = sdk.canSave ? SavePaymentMethod.on : SavePaymentMethod.off;

  TokenizationResult result;

  try {
    if (card != null && (card.methodId ?? '').isNotEmpty) {
      result = await YookassaPaymentsFlutter.bankCardRepeat(
        SavedBankCardModuleInputData(
          clientApplicationKey: sdk.clientKey,
          title: sdk.title,
          subtitle: sdk.subtitle,
          amount: amount,
          savePaymentMethod: SavePaymentMethod.off,
          shopId: sdk.shopId,
          paymentMethodId: card.methodId!,
          isSafeDeal: false,
          customerId: sdk.customerId,
          lang: 'ru',
        ),
      );
    } else {
      result = await YookassaPaymentsFlutter.tokenization(
        TokenizationModuleInputData(
          clientApplicationKey: sdk.clientKey,
          title: sdk.title,
          subtitle: sdk.subtitle,
          amount: amount,
          savePaymentMethod: save,
          shopId: sdk.shopId,
          tokenizationSettings: TokenizationSettings(
            PaymentMethodTypes(methods),
          ),
          customerId: sdk.customerId,
          applicationScheme: '$kPaymentAppScheme://',
          lang: 'ru',
        ),
      );
    }
  } catch (e) {
    return payment.withReason(
      'Не удалось открыть форму оплаты',
      'Попробуйте ещё раз или выберите другой способ оплаты',
    );
  }

  if (result is CanceledTokenizationResult) {
    return payment.withReason(
      'Оплата не завершена',
      'Вы закрыли форму оплаты. Выберите способ и попробуйте ещё раз',
    );
  }

  if (result is! SuccessTokenizationResult) {
    return payment.withReason(
      'Не удалось открыть форму оплаты',
      'Попробуйте ещё раз или выберите другой способ оплаты',
    );
  }

  final success = result;
  final method = success.paymentMethodType ?? PaymentMethod.bankCard;

  if (!context.mounted) return payment;

  final charged = await _withSpinner(
    context,
    () => OrdersService.chargePayment(
      payment.token,
      paymentToken: success.token,
      methodType: _methodKey(method),
      save: sdk.canSave && card == null,
    ),
  );

  if (charged == null) {
    return payment.withReason(
      'Нет связи с сервером',
      'Проверьте интернет и попробуйте ещё раз',
    );
  }

  if (charged.paid || charged.isFailed) return charged;

  // Нужно подтверждение: код из СМС (3-D Secure) или приложение Сбера.
  final url = charged.confirmationUrl;

  if (url != null) {
    try {
      await YookassaPaymentsFlutter.confirmation(
        url,
        method,
        sdk.clientKey,
        sdk.shopId,
      );
    } catch (_) {
      // Исход всё равно спросим у сервера ниже.
    }
  }

  if (!context.mounted) return charged;

  final latest = await _waitForOutcome(context, charged.token);

  if (latest == null) {
    return charged.withReason(
      'Нет связи с сервером',
      'Проверьте интернет и попробуйте ещё раз',
    );
  }

  if (latest.isPending) {
    return latest.withReason(
      'Оплата не завершена',
      'Попробуйте ещё раз или выберите другой способ оплаты',
    );
  }

  return latest;
}

/// Схема приложения для возврата из Сбера (strings.xml, `ym_app_scheme`).
const String kPaymentAppScheme = 'lidlepay';

String _methodKey(PaymentMethod method) => switch (method) {
  PaymentMethod.bankCard => 'bank_card',
  PaymentMethod.sberbank => 'sberbank',
  PaymentMethod.sbp => 'sbp',
  PaymentMethod.yooMoney => 'yoo_money',
  _ => 'bank_card',
};

Future<T> _withSpinner<T>(BuildContext context, Future<T> Function() job) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: activeIconColor)),
    ),
  );

  try {
    return await job();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Одна попытка через страницу оплаты YooKassa, затем ожидание исхода.
///
/// Запасной путь: сервер без ключа SDK или T-Pay, которого в SDK нет.
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
    return payment.withReason(
      'Нет связи с сервером',
      'Проверьте интернет и попробуйте ещё раз',
    );
  }

  if (latest.isPending) {
    return latest.withReason(
      'Оплата не завершена',
      'Попробуйте ещё раз или выберите другой способ оплаты',
    );
  }

  return latest;
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
