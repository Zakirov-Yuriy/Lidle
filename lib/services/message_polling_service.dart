// ============================================================
// "Сервис: Polling системы для мониторинга новых сообщений"
// ============================================================
//
// Периодически проверяет новые сообщения в чатах и отправляет
// пуш-уведомления при получении новых сообщений.
// Использует таймер для Polling на фоне.

import 'dart:async';
import 'package:lidle/services/notification_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:logger/logger.dart';

class MessagePollingService {
  static final MessagePollingService _instance =
      MessagePollingService._internal();
  static final _logger = Logger();

  late Timer _pollingTimer;
  bool _isPolling = false;

  // Хранит последний ID сообщения для каждого чата
  // используется для определения новых сообщений
  final Map<int, dynamic> _lastMessageIds = {};

  factory MessagePollingService() {
    return _instance;
  }

  MessagePollingService._internal();

  /// Запустить Polling новых сообщений
  ///
  /// Параметры:
  /// - [interval] - интервал проверки в секундах (по умолчанию 10)
  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    if (_isPolling) {
      _logger.w('⚠️ Polling уже запущен');
      return;
    }

    _isPolling = true;
    _logger.i('🔄 Запуск Polling новых сообщений (интервал: ${interval.inSeconds}s)');

    // Первый запуск сразу
    _checkNewMessages();

    // Затем периодически
    _pollingTimer = Timer.periodic(interval, (_) {
      _checkNewMessages();
    });
  }

  /// Остановить Polling
  void stopPolling() {
    if (!_isPolling) {
      _logger.w('⚠️ Polling не был запущен');
      return;
    }

    _pollingTimer.cancel();
    _isPolling = false;
    _logger.i('⏹️ Polling остановлен');
  }

  /// Проверить наличие новых сообщений во всех чатах
  Future<void> _checkNewMessages() async {
    try {
      _logger.d('🔍 Начинаем проверку новых сообщений в ${_lastMessageIds.length} чатах...');
      
      // Загружаем список чатов
      final chats = await ApiService.getChats();
      _logger.d('📋 Загружено чатов: ${chats.length}');

      for (final chat in chats) {
        final chatId = chat['id'] as int?;
        if (chatId == null) continue;

        await _checkChatMessages(chatId, chat);
      }
      
      _logger.d('✅ Проверка новых сообщений завершена');
    } catch (e) {
      _logger.e('❌ Ошибка при Polling сообщений: $e');
    }
  }

  /// Проверить новые сообщения в конкретном чате
  Future<void> _checkChatMessages(int chatId, Map<String, dynamic> chat) async {
    try {
      // Загружаем сообщения из чата
      final messages = await ApiService.getChatMessages(chatId);

      if (messages.isEmpty) {
        _logger.w('⚠️ Чат #$chatId: нет сообщений');
        return;
      }

      // Получаем информацию о отправителе из данных чата
      final senderName = chat['participant_name'] ?? chat['name'] ?? 'Новое сообщение';
      final senderImage = chat['participant_avatar'];
      
      // Логируем ВСЕ ID сообщений для анализа
      final allIds = messages.map((m) => m['id']).toList();
      _logger.d('📋 Чат #$chatId: загружено ${messages.length} сообщений (IDs: $allIds)');
      
      // ФИКС: Берём ПЕРВОЕ сообщение (новейшее), т.к. список отсортирован по убыванию ID
      final lastMessage = messages.isNotEmpty ? messages.first : null;

      if (lastMessage == null) {
        _logger.w('⚠️ Чат #$chatId: последнее сообщение = null');
        return;
      }

      final lastMessageId = lastMessage['id'];
      final messageText = lastMessage['content'] ?? lastMessage['message'] ?? '';

      _logger.d('🔍 Чат #$chatId - ID последнего сообщения: $lastMessageId (тип: ${lastMessageId.runtimeType}) [первое в списке]');

      // Проверяем - это первый раз загружаем этот чат?
      if (!_lastMessageIds.containsKey(chatId)) {
        // Первый раз - просто сохраняем ID последнего сообщения
        _lastMessageIds[chatId] = lastMessageId;
        _logger.i('📊 Добавлен чат #$chatId для мониторинга (ID сообщений: ${messages.length}, последний ID: $lastMessageId)');
        await _saveLastMessageId(chatId, lastMessageId);
        return;
      }

      // Проверяем - есть ли новые сообщения?
      final previousLastMessageId = _lastMessageIds[chatId];
      _logger.d('🔄 Чат #$chatId - Сравнение: $lastMessageId vs $previousLastMessageId (всего сообщений: ${messages.length})');

      // Нужно сравнивать как строки для надёжности
      final lastMessageIdStr = lastMessageId.toString();
      final previousLastMessageIdStr = previousLastMessageId.toString();

      if (lastMessageIdStr != previousLastMessageIdStr) {
        _logger.i(
          '🆕 Новое сообщение в чате #$chatId от $senderName (старый ID: $previousLastMessageId, новый ID: $lastMessageId)',
        );

        // Отправляем пуш-уведомление
        await NotificationService().showChatMessageNotification(
          senderName: senderName,
          messageText: messageText,
          chatId: chatId,
          senderImage: senderImage,
        );

        // Обновляем последний известный ID
        _lastMessageIds[chatId] = lastMessageId;

        // Сохраняем в локальное хранилище (для восстановления после рестарта)
        await _saveLastMessageId(chatId, lastMessageId);
      } else {
        _logger.d('⏭️ Чат #$chatId: новых сообщений нет (тот же ID, всего сообщений: ${messages.length})');
      }
    } catch (e) {
      _logger.e('❌ Ошибка проверки сообщений чата #$chatId: $e');
    }
  }

  /// Выполнить одноразовую проверку новых сообщений (для фоновых задач)
  Future<void> checkNewMessagesOnce() async {
    try {
      _logger.i('🔍 Одноразовая проверка новых сообщений (фоновая)');
      
      // Загружаем сохранённые ID если они ещё не загружены
      if (_lastMessageIds.isEmpty) {
        await loadLastMessageIds();
      }
      
      // Выполняем проверку
      await _checkNewMessages();
      
      _logger.i('✅ Одноразовая проверка завершена');
    } catch (e) {
      _logger.e('❌ Ошибка одноразовой проверки: $e');
    }
  }

  /// Загрузить сохранённые ID последних сообщений из хранилища
  Future<void> loadLastMessageIds() async {
    try {
      _logger.i('📁 Загружаем сохранённые ID сообщений из Hive...');
      
      final stored =
          HiveService.getUserData('last_message_ids') as Map<dynamic, dynamic>?;
      if (stored != null) {
        _lastMessageIds.clear();
        stored.forEach((key, value) {
          final chatId = int.tryParse(key.toString());
          if (chatId != null) {
            _lastMessageIds[chatId] = value;
            _logger.d('  Чат #$chatId: последний ID = $value (тип: ${value.runtimeType})');
          }
        });
        _logger.i('✅ Загружены сохранённые ID сообщений для ${_lastMessageIds.length} чатов');
      } else {
        _logger.i('ℹ️ Сохранённых ID сообщений не найдено (первый запуск)');
      }
    } catch (e) {
      _logger.e('❌ Ошибка загрузки сохранённых ID: $e');
    }
  }

  /// Сохранить ID последнего сообщения в хранилище
  Future<void> _saveLastMessageId(int chatId, dynamic messageId) async {
    try {
      final stored = HiveService.getUserData('last_message_ids') as Map<dynamic, dynamic>? ?? {};
      final mutableMap = Map<dynamic, dynamic>.from(stored);
      mutableMap[chatId.toString()] = messageId;
      await HiveService.saveUserData('last_message_ids', mutableMap);
    } catch (e) {
      _logger.e('❌ Ошибка сохранения ID сообщения: $e');
    }
  }

  /// Получить статус Polling
  bool get isPolling => _isPolling;

  /// Получить количество мониторируемых чатов
  int get monitoredChatsCount => _lastMessageIds.length;
}
