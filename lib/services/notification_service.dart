// ============================================================
// "Сервис: Управление lokальными пуш-уведомлениями"
// ============================================================
//
// Сервис для работы с локальными пуш-уведомлениями.
// Отправляет уведомления когда приходит новое сообщение в чат.
// Использует flutter_local_notifications для кроссплатформенности.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final _logger = Logger();

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  bool _isInitialized = false;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Инициализация сервиса уведомлений
  /// ДОЛЖНА вызваться в main.dart до runApp()
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.i('NotificationService уже инициализирован');
      return;
    }

    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android конфигурация
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS конфигурация
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Запрашиваем разрешения на iOS 10+
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Запрашиваем разрешение POST_NOTIFICATIONS на Android 13+ (API 33+)
    await Permission.notification.request();

    _isInitialized = true;
    _logger.i('✅ NotificationService инициализирован');
  }

  /// Отправить уведомление о новом сообщении в чате
  ///
  /// Параметры:
  /// - [senderName] - имя отправителя сообщения
  /// - [messageText] - текст сообщения
  /// - [chatId] - ID чата для навигации при клике
  /// - [senderImage] - опциональный URL аватара отправителя
  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    required int chatId,
    String? senderImage,
  }) async {
    _logger.i('📬 showChatMessageNotification вызван:');
    _logger.i('  - senderName: $senderName');
    _logger.i('  - messageText: $messageText');
    _logger.i('  - chatId: $chatId');
    _logger.i('  - senderImage: ${senderImage != null ? "$senderImage" : "null"}');
    
    if (!_isInitialized) {
      _logger.w('⚠️ NotificationService не инициализирован');
      return;
    }

    try {
      // Обрезаем длинный текст сообщения
      final displayText = messageText.length > 100 
          ? '${messageText.substring(0, 100)}...' 
          : messageText;

      // Создаём улучшенный стиль Big Text для Android 5+
      // Это позволяет показать больше информации в раскрытом виде
      final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
        displayText,
        contentTitle: senderName,
      );

      // Android уведомление с красивым стилем
      // Загружаем и кешируем аватар отправителя если доступен
      String? largeIconPath;
      _logger.d('🔍 Проверка avatara: senderImage=$senderImage, isEmpty=${senderImage?.isEmpty}, isNotNull=${senderImage != null}');
      
      if (senderImage != null && senderImage.isNotEmpty) {
        _logger.i('📥 Загрузка аватара: $senderImage');
        try {
          largeIconPath = await _downloadAndCacheImage(senderImage);
          if (largeIconPath != null) {
            _logger.i('✅ Аватар успешно загружен и применен');
            _logger.d('   Путь: $largeIconPath');
          } else {
            _logger.w('⚠️ _downloadAndCacheImage вернул null');
          }
        } catch (e) {
          _logger.e('❌ Ошибка загрузки аватара: $e');
          // Продолжаем без аватара если ошибка
        }
      } else {
        _logger.d('ℹ️ Аватар не предоставлен (null или пусто)');
      }
      
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'chat_messages_channel',
        'Chat Messages',
        channelDescription: 'Уведомления о новых сообщениях в чатах',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        styleInformation: bigTextStyle,
        // 🎨 Используем аватар отправителя слева от уведомления
        largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
        // Log: аватар применен? largeIconPath=$largeIconPath
        // Форматирование как в чате-мессенджере
        showWhen: true,
        ticker: 'Новое сообщение',
      );

      // iOS уведомление с красивым оформлением
      const DarwinNotificationDetails iosDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        threadIdentifier: 'chat',
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Форматируем заголовок с именем и статусом "Сейчас"
      final title = '$senderName • Сейчас';

      await _flutterLocalNotificationsPlugin.show(
        chatId,
        title,
        displayText,
        platformDetails,
        payload: 'chat_$chatId',
      );

      _logger.i(
        '📬 Отправлено красивое уведомление от $senderName (чат #$chatId)',
      );
    } catch (e) {
      _logger.e('❌ Ошибка отправки уведомления: $e');
    }
  }

  /// Отправить уведомление общего типа
  Future<void> showNotification({
    required String title,
    required String body,
    required int id,
    String? payload,
  }) async {
    if (!_isInitialized) {
      _logger.w('⚠️ NotificationService не инициализирован');
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'general_channel',
        'General Notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );

      _logger.i('📬 Отправлено общее уведомление: $title');
    } catch (e) {
      _logger.e('❌ Ошибка отправки уведомления: $e');
    }
  }

  /// Закрыть уведомление по ID
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      _logger.i('✅ Уведомление #$id отменено');
    } catch (e) {
      _logger.e('❌ Ошибка при отмене уведомления: $e');
    }
  }

  /// Закрыть все уведомления
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      _logger.i('✅ Все уведомления отменены');
    } catch (e) {
      _logger.e('❌ Ошибка при отмене всех уведомлений: $e');
    }
  }

  /// Callback при клике на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('👆 Пользователь нажал на уведомление: ${response.payload}');

    // Обработка payload - можно использовать для навигации
    final payload = response.payload;
    if (payload != null && payload.startsWith('chat_')) {
      final chatId = int.tryParse(payload.replaceFirst('chat_', ''));
      if (chatId != null) {
        _logger.i('📱 Переход в чат #$chatId');
        // TODO: Навигация в чат через go_router
        // Это обычно обрабатывается в main.dart через callback
      }
    }
  }

  /// Загружает изображение с URL и кеширует в временную папку
  /// 
  /// Параметры:
  /// - [imageUrl] - URL изображения (аватара отправителя)
  /// 
  /// Возвращает: путь к сохраненному файлу или null если ошибка
  Future<String?> _downloadAndCacheImage(String imageUrl) async {
    _logger.d('🔌 _downloadAndCacheImage начало: imageUrl=$imageUrl');
    try {
      if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
        _logger.e('❌ ПРОБЛЕМА: Неправильный URL аватара: $imageUrl');
        return null;
      }
      
      // Скачиваем изображение с таймаутом 5 секунд
      _logger.d('📡 Скачивание из интернета: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout при загрузке изображения'),
      );
      _logger.d('📡 Получен ответ: statusCode=${response.statusCode}, bytes=${response.bodyBytes.length}');
      
      if (response.statusCode != 200) {
        _logger.e('❌ ПРОБЛЕМА: HTTP ${response.statusCode}: ${response.reasonPhrase}');
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
      
      // Получаем папку для кеша приложения
      _logger.d('💾 Получаем temp directory...');
      final tempDir = await getTemporaryDirectory();
      _logger.d('💾 Temp directory: ${tempDir.path}');
      
      // Генерируем уникальное имя файла на основе URL
      final fileName = 'avatar_${imageUrl.hashCode.abs()}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      _logger.d('💾 Путь файла: $filePath');
      
      // Сохраняем файл на диск
      _logger.d('💾 Сохранение ${response.bodyBytes.length} bytes на диск...');
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      _logger.d('💾 Файл успешно сохранен: ${file.existsSync()}');
      
      _logger.i('✅ _downloadAndCacheImage успешно завершена');
      _logger.d('💾 Аватар сохранен: $filePath (${response.bodyBytes.length} bytes)');
      return filePath;
      
    } catch (e, stackTrace) {
      _logger.e('❌ ПРОБЛЕМА в _downloadAndCacheImage: $e');
      _logger.e('📍 StackTrace: $stackTrace');
      return null;  // Возвращаем null вместо выброса исключения
    }
  }

}
