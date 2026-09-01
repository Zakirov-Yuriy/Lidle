// ============================================================
// "Сервис: пуш-уведомления через Firebase Cloud Messaging"
// ============================================================
//
// Зачем это нужно.
//
// Раньше уведомления держались на постоянном соединении с нашим сервером,
// которое жило внутри приложения. Пока приложение открыто или свёрнуто,
// такое соединение работает. Но как только пользователь закрывает
// приложение из списка задач, Android убивает и его, и соединение: система
// не даёт закрытому приложению держать сеть, и с каждой версией правило
// строже.
//
// Firebase Cloud Messaging решает это иначе: уведомление доставляет сервис
// Google, который на телефоне работает всегда. Он и показывает уведомление,
// и при необходимости будит приложение. Так сделаны все мессенджеры.
//
// Дополнительно это снимает риск отказа в Google Play: обоснование
// «держим соединение ради уведомлений» там считают неправильным
// использованием фоновых сервисов.

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/notification_service.dart';
import 'package:lidle/services/token_service.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _initialized = false;
  String? _lastSentToken;

  /// Токен, полученный до входа в аккаунт. Отправлять его тогда некуда, но и
  /// терять нельзя: следующий раз Firebase выдаст тот же самый и обновления
  /// не будет, а сервер про него так и не узнает.
  String? _pendingToken;

  /// Подключить уведомления. Вызывается после успешного входа: без токена
  /// пользователя отправлять регистрацию некуда.
  Future<void> init() async {
    // iOS подключим отдельно, там нужен сертификат APNs.
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Разрешение на уведомления. На Android 13 и новее система спрашивает
      // его у пользователя; на более старых выдаётся автоматически.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        log.w('🔕 Пользователь запретил уведомления');
        return;
      }

      if (!_initialized) {
        // Уведомление пришло, когда приложение открыто. В этом случае
        // система его не показывает, рисуем сами.
        FirebaseMessaging.onMessage.listen(_showForegroundNotification);

        // Токен меняется при переустановке, очистке данных и иногда сам по
        // себе. Старый после этого перестаёт работать, поэтому новый сразу
        // отправляем на сервер.
        messaging.onTokenRefresh.listen(_sendTokenToBackend);

        _initialized = true;
      }

      // Отложенный токен, полученный до входа, отправляем в первую очередь.
      final pending = _pendingToken;
      if (pending != null) {
        await _sendTokenToBackend(pending);
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      } else {
        log.w('⚠️ Не удалось получить токен FCM');
      }
    } catch (e) {
      // Уведомления — не критичная часть: если что-то пошло не так,
      // приложение должно продолжать работать.
      log.w('⚠️ Не удалось подключить пуш-уведомления: $e');
    }
  }

  /// Отвязать устройство при выходе из аккаунта, чтобы новому владельцу
  /// телефона или следующему пользователю не приходили чужие уведомления.
  Future<void> unregister() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final token = _lastSentToken ?? await FirebaseMessaging.instance.getToken();
      final authToken = TokenService.currentToken;

      if (token != null && authToken != null) {
        // Токен устройства длинный и со спецсимволами, поэтому передаём его
        // телом запроса, а не в адресе.
        await ApiService.delete(
          '/me/push/device',
          token: authToken,
          body: {'token': token},
        );
      }
      await FirebaseMessaging.instance.deleteToken();
      _lastSentToken = null;
    } catch (e) {
      log.w('⚠️ Не удалось отвязать устройство от уведомлений: $e');
    }
  }

  /// Отправить токен устройства на бэкенд.
  Future<void> _sendTokenToBackend(String token) async {
    if (token == _lastSentToken) {
      return;
    }

    final authToken = TokenService.currentToken;
    if (authToken == null) {
      // Запоминаем: отправим, как только человек войдёт.
      _pendingToken = token;
      log.d('🔒 Токен FCM получен, но пользователь не авторизован — отложим');
      return;
    }

    try {
      await ApiService.post(
        '/me/push/device',
        {'token': token, 'platform': 'android'},
        token: authToken,
      );
      _lastSentToken = token;
      _pendingToken = null;
      log.i('✅ Устройство подключено к пуш-уведомлениям');
    } catch (e) {
      log.w('⚠️ Не удалось отправить токен устройства: $e');
    }
  }

  /// Показать уведомление, пришедшее при открытом приложении.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    final data = message.data;
    final chatId = int.tryParse('${data['chat_id'] ?? ''}');

    // Сообщение в чате показываем отдельным видом уведомления: у него есть
    // имя отправителя и переход в нужный чат по нажатию.
    if (chatId != null) {
      await NotificationService().showChatMessageNotification(
        senderName: notification.title ?? 'Новое сообщение',
        messageText: notification.body ?? '',
        chatId: chatId,
        senderImage: data['sender_avatar'] as String?,
      );
      return;
    }

    await NotificationService().showNotification(
      title: notification.title ?? 'ЛИДЛЕ',
      body: notification.body ?? '',
      id: message.hashCode,
      payload: data['url'] as String?,
    );
  }
}
