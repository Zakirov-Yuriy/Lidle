// ============================================================
// "Переход по нажатию на пуш-уведомление"
// ============================================================
//
// Зачем это нужно.
//
// Уведомление само по себе бесполезно, если по нажатию приложение просто
// открывается на том экране, где его оставили. Человек видел «вам написали»,
// нажал и оказался в ленте объявлений: что именно случилось, он так и не
// узнал, и ищет это руками.
//
// Здесь собран весь разбор: вид уведомления плюс номер превращаются в экран.
// Раньше разбор был размазан по `push_service.dart` и
// `notification_service.dart`, понимал только брони и заказы, а для
// сообщений в коде стояло «TODO, навигация не сделана».
//
// ТРИ СОСТОЯНИЯ ПРИЛОЖЕНИЯ, и во всех трёх нажатие должно вести одинаково:
//
//   открыто    система уведомление не показывает, его рисует приложение
//              (`NotificationService`), нажатие приходит оттуда;
//   свёрнуто   `FirebaseMessaging.onMessageOpenedApp`;
//   закрыто    `FirebaseMessaging.getInitialMessage`, один раз при запуске.
//
// ПОЧЕМУ ЕСТЬ ОЧЕРЕДЬ. Третий случай самый неудобный: уведомление приходит
// раньше, чем приложение успевает подняться. Дерева экранов ещё нет, сессия
// не прочитана, и переход либо потеряется молча, либо откроет экран поверх
// пустоты, и кнопка «назад» уведёт человека из приложения. Поэтому пуш,
// пришедший до готовности, откладывается и открывается, как только
// приложение готово.
//
// Экран всегда ОТКРЫВАЕТСЯ ПОВЕРХ главного, а не заменяет его: после
// прочтения человек жмёт «назад» и попадает в приложение, а не на пустой
// экран.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:lidle/core/logger.dart';
import 'package:lidle/main.dart' show navigatorKey;
import 'package:lidle/models/message_model.dart';
import 'package:lidle/pages/bookings/my_bookings_screen.dart';
import 'package:lidle/pages/messages/chat_page.dart';
import 'package:lidle/pages/products/my_orders_screen.dart';
import 'package:lidle/pages/products/order_details_screen.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/responses_empty_page.dart';
import 'package:lidle/services/api/chat_api.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/services/token_service.dart';

class PushRouter {
  PushRouter._();

  /// Пуш, пришедший до готовности приложения. Хранится ровно один: если
  /// уведомлений накопилось несколько, человек нажал на последнее, и именно
  /// его он и ждёт увидеть.
  static Map<String, dynamic>? _pending;

  /// Готово ли приложение принимать переходы: дерево построено и сессия
  /// прочитана.
  static bool _ready = false;

  /// Приложение готово. Вызывается после входа и после первого кадра у
  /// человека с уже сохранённой сессией.
  static void markReady() {
    if (_ready) {
      return;
    }

    _ready = true;

    final pending = _pending;
    _pending = null;

    if (pending != null) {
      log.d('🔔 Открываю отложенный переход по уведомлению');
      _open(pending);
    }
  }

  /// Человек вышел из аккаунта: отложенный переход больше не его.
  static void reset() {
    _ready = false;
    _pending = null;
  }

  /// Разобрать уведомление и открыть нужный экран.
  static void handle(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return;
    }

    final type = '${data['type'] ?? ''}';

    // Проверочный пуш (`push:check` без ключа `--type`) никуда не ведёт, и
    // это правильно: он проверяет доставку, а не переходы.
    if (type.isEmpty || type == 'check') {
      return;
    }

    final notReady = !_ready ||
        navigatorKey.currentState == null ||
        TokenService.currentToken == null;

    if (notReady) {
      log.d('🔔 Переход отложен до готовности приложения: $type');
      _pending = data;

      return;
    }

    _open(data);
  }

  /// Тот же разбор для уведомления, нарисованного самим приложением: там
  /// привязка едет текстом, потому что подпись у локального уведомления
  /// одна-единственная строка.
  static void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    // Старый вид подписи, оставшийся от прежних версий: `chat_42`.
    if (payload.startsWith('chat_')) {
      final chatId = payload.replaceFirst('chat_', '');
      handle({'type': 'chat_message', 'chat_id': chatId});

      return;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map) {
        handle(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      log.d('🔔 Подпись уведомления не разобрана: $payload');
    }
  }

  /// Подпись для локального уведомления: та же привязка, но строкой.
  static String encode(Map<String, dynamic> data) => jsonEncode(data);

  static Future<void> _open(Map<String, dynamic> data) async {
    final type = '${data['type'] ?? ''}';
    final event = '${data['event'] ?? ''}';

    log.i('🔔 Переход по уведомлению: $type');

    switch (type) {
      case 'chat_message':
        await _openChat(_int(data['chat_id']));

        return;

      case 'response':
        // Экран откликов открывается на вкладке «Отклики мне»: уведомление
        // приходит тому, кому откликнулись.
        _push(const ResponsesEmptyPage());

        return;

      case 'price_offer':
        _push(const PriceOffersEmptyPage());

        return;

      case 'order':
        await _openOrder(_int(data['order_id']), event);

        return;

      case 'booking':
        _openBooking(_int(data['booking_id']), event);

        return;

      default:
        log.d('🔔 Неизвестный вид уведомления: $type');
    }
  }

  /// Переписка по номеру чата.
  ///
  /// Экран просит собеседника целиком, а в уведомлении есть только номер,
  /// поэтому чат сначала перечитывается с сервера. Не получилось, значит не
  /// открываем ничего: пустой экран переписки хуже, чем его отсутствие.
  static Future<void> _openChat(int? chatId) async {
    if (chatId == null) {
      return;
    }

    final chat = await ChatApi.getChat(chatId);

    if (chat == null) {
      log.d('🔔 Чат #$chatId не загрузился, перехода не будет');

      return;
    }

    final user = chat['user'];
    final name = user is Map ? '${user['name'] ?? ''}'.trim() : '';
    final lastName = user is Map ? '${user['last_name'] ?? ''}'.trim() : '';
    final avatar = user is Map ? user['avatar'] as String? : null;
    final userId = user is Map ? '${user['id'] ?? ''}' : '';

    final fullName = [name, lastName].where((p) => p.isNotEmpty).join(' ');

    _push(
      ChatPage(
        message: Message(
          senderName: fullName.isNotEmpty ? fullName : 'Собеседник',
          senderAvatar: avatar,
          lastMessageTime: '',
          unreadCount: 0,
          isInternal: false,
          isCompany: false,
          userId: userId.isNotEmpty ? userId : null,
          chatId: chatId,
        ),
      ),
    );
  }

  /// Карточка заказа, а не список: по решению заказчика от 12.10.2026 человек
  /// должен попадать ровно туда, о чём его уведомили.
  ///
  /// Если заказ не загрузился (сеть отвалилась, заказ удалён), открываем
  /// список с нужной стороной. Это хуже карточки, но лучше, чем ничего.
  static Future<void> _openOrder(int? orderId, String event) async {
    if (orderId != null) {
      final order = await OrdersService.details(orderId);

      if (order != null) {
        _push(OrderDetailsScreen(order: order));

        return;
      }
    }

    // Сторона списка по событию, а не по роли из ответа сервера: уведомление
    // приходит тому, кто ничего не решал. Новый заказ видит продавец, решения
    // продавца видит покупатель.
    _push(MyOrdersScreen(startWithIncoming: event == 'created'));
  }

  /// Брони: список с нужной вкладкой и подсветкой той самой брони.
  ///
  /// Отдельного экрана брони в приложении нет, карточка живёт в списке.
  /// Поэтому «открыть карточку» здесь означает открыть список, прокрутить к
  /// ней и подсветить, ровно как после собственного бронирования.
  static void _openBooking(int? bookingId, String event) {
    const ownerEvents = {'created', 'cancelled_by_guest'};

    _push(
      MyBookingsScreen(
        initialTab: ownerEvents.contains(event) ? 1 : 0,
        highlightId: bookingId,
      ),
    );
  }

  static void _push(Widget screen) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static int? _int(Object? value) {
    if (value == null) {
      return null;
    }

    return int.tryParse('$value');
  }
}
