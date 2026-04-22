// ============================================================
// "BLoC: Управление избранным (локальное + серверное)"
// ============================================================
//
// Синхронизирует локальное хранилище избранного с серверным API.
// Использует оптимистичные обновления для быстрого отклика UI.
// При ошибке сохраняет локальное состояние и повторяет попытку.
//
// Поддерживает две режима:
// 1. Неавторизованный пользователь: работает только с локальным Hive
// 2. Авторизованный пользователь: синхронизирует с серверным API

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive_service.dart';
import '../../services/favorites_service.dart';
import '../../services/wishlist_service.dart';

part 'wishlist_event.dart';
part 'wishlist_state.dart';

/// BLoC для управления избранным объявлениями.
///
/// Отвечает за:
/// 1. Загрузку списка избранных (с сервера для авторизованных, локально для неавторизованных)
/// 2. Добавление/удаление объявлений в/из избранного
/// 3. Синхронизацию локального кеша с серверным состоянием
/// 4. Обработку ошибок (auth, network, rate limit)
/// 5. Синхронизацию локального избранного при авторизации пользователя
///
/// Использует двухуровневое хранилище:
/// - Локальное (Hive) для быстрого доступа и оптимистичных обновлений
/// - Серверное (API) как источник истины для авторизованных пользователей
///
/// Поведение по статусу авторизации:
/// - Неавторизованный: работает только с Hive (локальное избранное)
/// - Авторизованный: синхронизирует локальное с серверным при загрузке
class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  /// Кеш ID избранных объявлений для отслеживания изменений
  Set<int> _cachedWishlistIds = {};
  
  /// Маппинг ID товаров (advertId) к ID wishlist entries
  /// Используется для DELETE операции - нужно отправить ID wishlist entry, а не ID товара
  /// Структура: {advertId -> wishlistEntryId}
  /// Пример: {147 -> 201} означает что товар 147 имеет wishlist entry ID 201
  Map<int, int> _wishlistIdMapping = {};

  /// Дебоунс правилл: предотвращает множественные LoadWishlistEvent в короткий промежуток
  DateTime? _lastLoadWishlistTime;
  static const Duration _loadWishlistDebounce = Duration(seconds: 2);

  /// Конструктор WishlistBloc.
  /// 
  /// Инициализирует события и начинает слушать AuthBloc
  /// для синхронизации при авторизации.
  WishlistBloc() : super(const WishlistInitial()) {
    on<LoadWishlistEvent>(_onLoadWishlist);
    on<AddToWishlistEvent>(_onAddToWishlist);
    on<RemoveFromWishlistEvent>(_onRemoveFromWishlist);
    on<SyncWishlistEvent>(_onSyncWishlist);
    on<SyncLocalWishlistOnAuthEvent>(_onSyncLocalWishlistOnAuth);
  }

  /// Получить свежий токен из HiveService каждый раз.
  ///
  /// ⚠️ ВАЖНО: Не кешируем токен! Он может измениться после авторизации.
  /// Каждый вызов получает актуальное значение из Hive.
  String? _getToken() {
    final token = HiveService.getUserData('token') as String?;
    if (token == null) {
      // log.w('⚠️ WishlistBloc._getToken(): Токен НЕ НАЙДЕН в Hive!');
    } else {
      // log.i('✅ WishlistBloc._getToken(): Токен получен (${token.length} символов)');
    }
    return token;
  }

  /// Обработчик события LoadWishlistEvent.
  ///
  /// Поведение зависит от статуса авторизации:
  /// 1. Для авторизованных: загружает со сервера и синхронизирует с локальным
  /// 2. Для неавторизованных: загружает из локального Hive хранилища
  /// 
  /// ⏱️ Дебоунс: Игнорирует событие если последний запрос был менее 2 секунд назад
  /// Это предотвращает слишком частые запросы при Hot Reload или множественных
  /// срабатываниях listenerов.
  Future<void> _onLoadWishlist(
    LoadWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    // 🔐 Проверяем дебоунс: если последний запрос был недавно, пропускаем
    final now = DateTime.now();
    if (_lastLoadWishlistTime != null) {
      final timeSinceLastLoad = now.difference(_lastLoadWishlistTime!);
      if (timeSinceLastLoad < _loadWishlistDebounce) {
        // log.d('⏱️ WishlistBloc: LoadWishlistEvent дебоунсен (последний запрос ${timeSinceLastLoad.inMilliseconds}ms назад)');
        // НЕ эмитим ничего, просто пропускаем событие
        return;
      }
    }
    _lastLoadWishlistTime = now;

    emit(const WishlistLoading());
    // log.i('🎏 WishlistBloc: LoadWishlistEvent запущен');

    try {
      final token = _getToken();
      
      // 🔐 Проверяем авторизацию
      if (token == null || token.isEmpty) {
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // 📱 РЕЖИМ 1: НЕАВТОРИЗОВАННЫЙ ПОЛЬЗОВАТЕЛЬ
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // log.i('👤 WishlistBloc: Пользователь НЕ авторизован, загружаем локальное избранное из Hive');
        
        // Получаем ID из локального хранилища
        final localFavorites = FavoritesService.getFavorites();
        final localIds = localFavorites
            .map((id) => int.tryParse(id))
            .whereType<int>()
            .toSet();
        
        _cachedWishlistIds = localIds;
        
        // log.i('✅ WishlistBloc: Локальное избранное загружено: $localIds (${localIds.length} товаров)');
        emit(WishlistLoaded(
          wishlistIds: localIds,
          syncedAt: DateTime.now(),
          isLocal: true, // Флаг что это локальное избранное
        ));
        return;
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 🔐 РЕЖИМ 2: АВТОРИЗОВАННЫЙ ПОЛЬЗОВАТЕЛЬ
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // log.i('🔐 WishlistBloc: Пользователь авторизован, загружаем со сервера');
      
      // Загружаем со сервера
      // log.d('🔄 WishlistBloc: Загружаем wishlist с сервера...');
      final response = await WishlistService.getWishlist(token: token);
      // log.i('✅ WishlistBloc: Ответ от сервера получен');

      // Парсим IDs из ответа
      final wishlistIds = _parseWishlistIds(response);
      // log.d('📏 WishlistBloc: Распарсены IDs: $wishlistIds');

      // Синхронизируем с Hive (обновляем локальный кеш)
      // log.d('🔄 WishlistBloc: Синхронизируем с Hive...');
      await _syncLocalWishlist(wishlistIds);
      // log.i('✅ WishlistBloc: Синхронизация завершена');

      // Обновляем внутренний кеш
      _cachedWishlistIds = wishlistIds;

      // log.i('✨ WishlistBloc: WishlistLoaded emitted с ${wishlistIds.length} IDs');
      emit(WishlistLoaded(
        wishlistIds: wishlistIds,
        syncedAt: DateTime.now(),
        isLocal: false,
      ));
    } on Exception catch (e) {
      // log.e('❌ WishlistBloc: Ошибка при загрузке: $e');
      _emitError(emit, e);
    }
  }

  /// Обработчик события AddToWishlistEvent.
  ///
  /// Поведение зависит от статуса авторизации:
  /// 1. Для неавторизованных: добавляет только в локальное Hive
  /// 2. Для авторизованных: добавляет в Hive и синхронизирует с сервером
  ///
  /// Выполняет оптимистичное обновление локального хранилища,
  /// затем отправляет POST запрос на сервер (если авторизован).
  /// 
  /// 📤 Шаги:
  /// 1. Обновляет локальное хранилище (Hive) оптимистично
  /// 2. Отправляет асинхронный запрос на сервер (если авторизован)
  /// 3. При ошибке откатывает локальное изменение
  Future<void> _onAddToWishlist(
    AddToWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      // log.i('🎏 WishlistBloc._onAddToWishlist: START добавляем advertId=${event.listingId}');
      
      // 1. Оптимистичное обновление локального хранилища
      FavoritesService.toggleFavorite(event.listingId.toString());
      _cachedWishlistIds.add(event.listingId);
      // log.i('✅ WishlistBloc: Локальное хранилище обновлено, ID: ${event.listingId}');

      // Уведомляем UI об успехе локального обновления
      emit(WishlistItemAdded(listingId: event.listingId));

      // 2. Проверяем авторизацию - если есть токен, синхронизируем с сервером
      final token = _getToken();
      
      if (token == null || token.isEmpty) {
        // 📱 Пользователь НЕ авторизован - просто сохраняем локально
        // log.i('📱 WishlistBloc: Пользователь не авторизован, добавлено в локальное избранное');
        
        // Эмитим обновленное состояние
        emit(WishlistLoaded(
          wishlistIds: _cachedWishlistIds,
          syncedAt: DateTime.now(),
          isLocal: true,
        ));
        return;
      }
      
      // 🔐 Пользователь авторизован - отправляем на сервер
      try {
        // log.d('═══════════════════════════════════════════════════════');
        // log.d('📤 WishlistBloc: Отправляем POST запрос на /me/wishlist/add');
        // log.d('   Параметры: advert_id=${event.listingId}, token_length=${token.length}');
        // log.d('═══════════════════════════════════════════════════════');
        
        final response = await WishlistService.addToWishlist(
          advertId: event.listingId,
          token: token,
        );
        
        // ⚠️ Проверяем success в ответе add
        // log.d('🔍 WishlistBloc: Проверяем ответ сервера для add:');
        // log.d('   success: ${response['success']}');
        // log.d('   message: ${response['message']}');
        
        if (response['success'] != true) {
          // Любое значение, не true = ошибка
          // log.e('❌ WishlistBloc: Сервер вернул ошибку при add!');
          // log.e('   ${response['message'] ?? 'Неизвестная ошибка'}');
          throw Exception('${response['message'] ?? 'Ошибка при добавлении в избранное'}');
        }
        
        // log.d('✅ WishlistBloc: Сервер подтвердил добавление объявления');
        
        // 📡 Обновляем состояние с новыми IDs для синхронизации UI
        // log.d('📢 WishlistBloc: Эмитим WishlistLoaded с обновленными IDs: $_cachedWishlistIds');
        emit(WishlistLoaded(
          wishlistIds: _cachedWishlistIds,
          syncedAt: DateTime.now(),
          isLocal: false,
        ));
      } catch (e) {
        // Если сервер вернул ошибку, откатываем локальное изменение
        // и уведомляем пользователя
        // log.d('⚠️ WishlistBloc: Ошибка при добавлении на сервер: $e');
        // log.d('⏮️ WishlistBloc: Откатываем локальное изменение');
        FavoritesService.toggleFavorite(event.listingId.toString());
        _cachedWishlistIds.remove(event.listingId);

        _emitError(emit, e as Exception);
      }
    } catch (e) {
      // log.d('❌ WishlistBloc._onAddToWishlist: Непредвиденная ошибка: $e');
      _emitError(emit, e as Exception);
    }
  }

  /// Обработчик события RemoveFromWishlistEvent.
  /// 
  /// Поведение зависит от статуса авторизации:
  /// 1. Для неавторизованных: удаляет только из локального Hive
  /// 2. Для авторизованных: удаляет из Hive и синхронизирует с сервером
  ///
  /// Выполняет оптимистичное обновление локального хранилища,
  /// затем отправляет DELETE запрос на сервер (если авторизован).
  /// 
  /// 📤 Шаги:
  /// 1. Обновляет локальное хранилище (Hive) оптимистично
  /// 2. Отправляет асинхронный DELETE запрос на сервер (если авторизован)
  /// 3. При ошибке откатывает локальное изменение
  Future<void> _onRemoveFromWishlist(
    RemoveFromWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      // log.d('🎯 WishlistBloc._onRemoveFromWishlist: START удаляем advertId=${event.listingId}');
      
      // 🛡️ Получаем токен перед началом операции
      final token = _getToken();
      
      // 1. Оптимистичное обновление локального хранилища
      final wasFavorite = FavoritesService.isFavorite(event.listingId.toString());
      if (wasFavorite) {
        FavoritesService.toggleFavorite(event.listingId.toString());
        _cachedWishlistIds.remove(event.listingId);
        // log.d('✅ WishlistBloc: Локальное хранилище обновлено (удалено), ID: ${event.listingId}');

        // Уведомляем UI об успехе локального обновления
        emit(WishlistItemRemoved(listingId: event.listingId));

        // 2. Если авторизован - отправляем на сервер в фоне (асинхронно)
        if (token == null || token.isEmpty) {
          // 📱 Пользователь НЕ авторизован - просто удалили локально
          // log.i('📱 WishlistBloc: Пользователь не авторизован, удалено из локального избранного');
          
          // Эмитим обновленное состояние
          emit(WishlistLoaded(
            wishlistIds: _cachedWishlistIds,
            syncedAt: DateTime.now(),
            isLocal: true,
          ));
          return;
        }
        
        try {
          // 🔗 Получаем ID wishlist entry из маппинга
          final wishlistEntryId = _wishlistIdMapping[event.listingId];
          final deleteId = wishlistEntryId ?? event.listingId;
          
          if (wishlistEntryId == null) {
            // log.d('⚠️ WishlistBloc: Маппинг не найден для advertId=${event.listingId}');
            // log.d('   Доступные маппинги: $_wishlistIdMapping');
            // log.d('   Используем fallback: отправляем advertId=${event.listingId}');
          } else {
            // log.d('🔗 WishlistBloc: Найден маппинг: advertId=${event.listingId} -> wishlistEntryId=$wishlistEntryId');
          }
          
          // log.d('═══════════════════════════════════════════════════════');
          // log.d('📡 WishlistBloc: Отправляем DELETE запрос на /me/wishlist/destroy/$deleteId');
          // log.d('   Параметры: delete_id=$deleteId, token_length=${token.length}');
          // log.d('═══════════════════════════════════════════════════════');
          
          final response = await WishlistService.removeFromWishlist(
            advertId: deleteId,
            token: token,
          );
          
          // ⚠️ КРИТИЧНО: Проверяем success в ответе
          // API может вернуть 200 но success: false (товара нет на сервере, уже удален, нет доступа и т.д.)
          // log.d('🔍 WishlistBloc: Проверяем ответ сервера:');
          // log.d('   success: ${response['success']}');
          // log.d('   message: ${response['message']}');
          
          if (response['success'] != true) {
            // Любое значение, не true (false, null, что угодно) = ошибка
            // log.d('❌ WishlistBloc: Сервер вернул ошибку при delete!');
            // log.d('   ${response['message'] ?? 'Неизвестная ошибка'}');
            throw Exception('${response['message'] ?? 'Ошибка при удалении из избранного'}');
          }
          
          // log.d('✅ WishlistBloc: Сервер подтвердил удаление объявления');
          
          // Удаляем из маппинга
          _wishlistIdMapping.remove(event.listingId);
          
          // 📡 Обновляем состояние с новыми IDs для синхронизации UI
          // log.d('📢 WishlistBloc: Эмитим WishlistLoaded с обновленными IDs: $_cachedWishlistIds');
          emit(WishlistLoaded(
            wishlistIds: _cachedWishlistIds,
            syncedAt: DateTime.now(),
            isLocal: false,
          ));
        } catch (e) {
          // ⚠️ ВАЖНО: Если ошибка (любая), товар всё равно ОСТАЕТСЯ удаленным из Hive
          // Причины:
          // 1. Если 404 - товара нет на сервере, нечего откатывать
          // 2. Если сеть - лучше пересинхронизировать при следующей загрузке
          // 3. Если 500 - и сервер и клиент согласны что удаления не было, загрузим при синхронизации
          
          // log.d('⚠️ WishlistBloc: Ошибка при удалении на сервере: $e');
          // log.d('🔄 WishlistBloc: Товар ОСТАЕТСЯ удаленным из локального хранилища (фиксированное состояние)');
          // log.d('💡 WishlistBloc: При следующей синхронизации состояние будет согласовано с серверм');
          
          // НЕ откатываем Hive - товар остается удаленным!
          // Синхронизация при LoadWishlistEvent уточнит реальное состояние на сервере
          
          _emitError(emit, e as Exception);
        }
      } else {
        // Object не в избранном локально, но все равно пытаемся удалить с сервера
        // (может быть рассинхронизация между локальным и серверным состоянием)
        // log.d('⚠️ WishlistBloc: Объявление ${event.listingId} не в локальном избранном, пытаемся удалить с сервера...');
        
        if (token == null || token.isEmpty) {
          // Не авторизован - ничего не делаем
          // log.d('📱 WishlistBloc: Пользователь не авторизован, игнорируем');
          emit(WishlistLoaded(
            wishlistIds: _cachedWishlistIds,
            syncedAt: DateTime.now(),
            isLocal: true,
          ));
          return;
        }
        
        try {
          // 🔗 Получаем ID wishlist entry из маппинга для fallback пути
          final wishlistEntryId = _wishlistIdMapping[event.listingId];
          final deleteId = wishlistEntryId ?? event.listingId;
          
          if (wishlistEntryId == null) {
            // log.d('⚠️ WishlistBloc (fallback): Маппинг не найден для advertId=${event.listingId}');
            // log.d('   Используем fallback ID из события');
          } else {
            // log.d('🔗 WishlistBloc (fallback): Найден маппинг: advertId=${event.listingId} -> wishlistEntryId=$wishlistEntryId');
          }
          
          // log.d('📡 WishlistBloc: Отправляем DELETE запрос (fallback) на /me/wishlist/destroy/$deleteId');
          
          final response = await WishlistService.removeFromWishlist(
            advertId: deleteId,
            token: token,
          );
          
          // ⚠️ Проверяем success даже в fallback ветке
          // log.d('🔍 WishlistBloc: Проверяем ответ fallback delete: success=${response['success']}');
          if (response['success'] != true) {
            // log.d('❌ WishlistBloc: Fallback delete вернул ошибку: ${response['message']}');
            throw Exception('${response['message'] ?? 'Ошибка при удалении'}');
          }
          
          // log.d('✅ WishlistBloc: Fallback delete подтвержден сервером');
          
          // Обновляем состояние
          emit(WishlistLoaded(
            wishlistIds: _cachedWishlistIds,
            syncedAt: DateTime.now(),
            isLocal: false,
          ));
        } catch (e) {
          // log.d('⚠️ WishlistBloc: Ошибка при fallback delete: $e');
          _emitError(emit, e as Exception);
        }
      }
    } catch (e) {
      // log.d('❌ WishlistBloc._onRemoveFromWishlist: Непредвиденная ошибка: $e');
      _emitError(emit, e as Exception);
    }
  }

  /// Обработчик события SyncWishlistEvent.
  ///
  /// Синхронизирует локальное состояние с серверным.
  /// Может быть использовано для периодической синхронизации.
  Future<void> _onSyncWishlist(
    SyncWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      final token = _getToken();
      if (token == null) {
        emit(const WishlistError(
          message: 'Требуется авторизация',
          code: 'auth',
        ));
        return;
      }

      if (event.fullSync) {
        // Полная синхронизация: загружаем с сервера
        emit(const WishlistLoading());
        final response = await WishlistService.getWishlist(token: token);
        final wishlistIds = _parseWishlistIds(response);
        await _syncLocalWishlist(wishlistIds);
        _cachedWishlistIds = wishlistIds;

        emit(WishlistSynced(wishlistIds: wishlistIds));
      } else {
        // Частичная синхронизация: только проверяем
        emit(WishlistSynced(wishlistIds: _cachedWishlistIds));
      }
    } on Exception catch (e) {
      _emitError(emit, e);
    }
  }

  /// Обработчик события SyncLocalWishlistOnAuthEvent.
  ///
  /// Вызывается когда пользователь авторизуется.
  /// Синхронизирует локальное избранное (из Hive) с серверным.
  ///
  /// Процесс:
  /// 1. Загружает избранное с сервера
  /// 2. Загружает локальное избранное из Hive
  /// 3. Объединяет локальное с серверным (приоритет серверу)
  /// 4. Обновляет состояние
  Future<void> _onSyncLocalWishlistOnAuth(
    SyncLocalWishlistOnAuthEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      final token = _getToken();
      if (token == null) {
        // Странная ситуация - AuthBloc сказал что авторизован, но токена нет
        // log.w('⚠️ WishlistBloc: AuthBloc сказал что авторизован но токена нет');
        return;
      }

      // log.i('🔄 WishlistBloc: Синхронизация локального избранного при авторизации');
      
      // Загружаем со сервера
      final response = await WishlistService.getWishlist(token: token);
      final serverIds = _parseWishlistIds(response);
      
      // log.d('🌐 WishlistBloc: Получено с сервера: $serverIds');
      
      // Получаем локальное избранное
      final localFavorites = FavoritesService.getFavorites();
      final localIds = localFavorites
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toSet();
      
      // log.d('📱 WishlistBloc: Локальное избранное: $localIds');
      
      // Синхронизируем - это обновит Hive чтобы соответствовал серверу
      await _syncLocalWishlist(serverIds);
      
      // Обновляем внутренний кеш
      _cachedWishlistIds = serverIds;
      
      // log.i('✅ WishlistBloc: Синхронизация завершена. Итого: ${serverIds.length} товаров');
      
      emit(WishlistLoaded(
        wishlistIds: serverIds,
        syncedAt: DateTime.now(),
        isLocal: false,
      ));
    } catch (e) {
      // log.e('❌ WishlistBloc: Ошибка при синхронизации на авторизацию: $e');
      _emitError(emit, e as Exception);
    }
  }

  /// Парсит IDs объявлений из ответа сервера.
  ///
  /// Работает с пагинированным ответом от /me/wishlist.
  /// Извлекает все ID объявлений из поля 'wishable.id'.
  Set<int> _parseWishlistIds(Map<String, dynamic> response) {
    final ids = <int>{};
    _wishlistIdMapping.clear(); // Очищаем старое маппинг перед заполнением
    
    // log.d('🔍 _parseWishlistIds: Входная response: $response');

    if (response['data'] is List) {
      final List<dynamic> items = response['data'] as List<dynamic>;
      // log.d('📊 _parseWishlistIds: Найдено ${items.length} элементов в data');
      
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          // Получаем wishable объект (сам объявление)
          final wishable = item['wishable'];
          final wishlistEntryId = item['id']; // ID wishlist entry (201)
          // log.d('  → Элемент: $item, wishable=$wishable');
          
          if (wishable is Map<String, dynamic>) {
            final id = wishable['id']; // ID товара (147)
            // log.d('    ID из wishable.id: $id (тип: ${id.runtimeType})');
            // log.d('    ID wishlist entry: $wishlistEntryId (тип: ${wishlistEntryId.runtimeType})');
            
            if (id is int) {
              ids.add(id);
              // 🔗 Сохраняем маппинг: товар 147 -> wishlist entry 201
              if (wishlistEntryId is int) {
                _wishlistIdMapping[id] = wishlistEntryId;
                // log.d('    ✅ Маппинг добавлен: $id -> $wishlistEntryId');
              }
            } else if (id is String) {
              final parsed = int.tryParse(id);
              if (parsed != null) {
                ids.add(parsed);
                if (wishlistEntryId is int) {
                  _wishlistIdMapping[parsed] = wishlistEntryId;
                  // log.d('    ✅ Маппинг добавлен: $parsed -> $wishlistEntryId');
                }
              }
            }
          }
        }
      }
    } else {
      // log.d('⚠️ _parseWishlistIds: data не является List, тип: ${response['data'].runtimeType}');
    }

    // log.d('✨ _parseWishlistIds: Итоговый набор IDs (ID объявлений): $ids');
    // log.d('🔗 _parseWishlistIds: Маппинг (advertId -> wishlistEntryId): $_wishlistIdMapping');
    return ids;
  }

  /// Синхронизирует локальное хранилище (Hive) с серверным состоянием.
  ///
  /// Обновляет список избранных ID в Hive так чтобы он соответствовал
  /// серверному состоянию.
  /// 
  /// Решает проблему рассинхронизации:
  /// - Если товар на сервере но не локально → добавляет в Hive
  /// - Если товар локально но не на сервере → удаляет из Hive
  Future<void> _syncLocalWishlist(Set<int> serverIds) async {
    // log.d('🔄 _syncLocalWishlist: Начало синхронизации');
    // log.d('╔════════════════════════════════════════════════════════');
    
    final localIds = FavoritesService.getFavorites();
    // log.d('📱 _syncLocalWishlist: Локальные IDs из Hive: $localIds');
    
    final localIdSet = localIds.map((id) => int.tryParse(id)).whereType<int>().toSet();
    // log.d('📱 _syncLocalWishlist: Локальные IDs (int): $localIdSet');
    // log.d('🌐 _syncLocalWishlist: Серверные IDs: $serverIds');

    // Добавляем IDs которые есть на сервере но нет локально
    int addedCount = 0;
    for (final id in serverIds) {
      if (!localIdSet.contains(id)) {
        // log.d('➡️ _syncLocalWishlist: Добавляем ID $id (есть на сервере, нет локально)');
        FavoritesService.toggleFavorite(id.toString());
        addedCount++;
      }
    }

    // Удаляем IDs которые есть локально но нет на сервере
    int removedCount = 0;
    for (final id in localIdSet) {
      if (!serverIds.contains(id)) {
        // log.d('➢️ _syncLocalWishlist: Удаляем ID $id (есть локально, нет на сервере)');
        // log.d('   ⚠️ Причина: товар был удален на сервере (другой клиент/веб) или не был добавлен');
        FavoritesService.toggleFavorite(id.toString());
        removedCount++;
      }
    }
    
    final updatedLocal = FavoritesService.getFavorites();
    // log.d('✅ _syncLocalWishlist: Синхронизация завершена');
    // log.d('   Добавлено: $addedCount товаров');
    // log.d('   Удалено: $removedCount товаров');
    // log.d('   Финальное состояние Hive: $updatedLocal');
    // log.d('╘════════════════════════════════════════════════════════');
  }

  /// Эмитит состояние ошибки и логирует её.
  void _emitError(Emitter<WishlistState> emit, Exception e) {
    final message = e.toString();
    String code = 'unknown';

    // 🔍 Проверяем тип ошибки
    if (e.runtimeType.toString().contains('RateLimitException')) {
      code = 'rate_limit';
      // log.d('⚠️ WishlistBloc: Обнаружена RateLimitException - API возвращает 429');
      // log.d('   ApiService будет автоматически повторять запрос с exponential backoff');
      // log.d('   Макс попыток: 4, задержка: 2s, 4s, 8s, 16s');
    } else if (message.contains('Требуется авторизация')) {
      code = 'auth';
    } else if (message.contains('network') || message.contains('Network')) {
      code = 'network';
    } else if (message.contains('timeout') || message.contains('Timeout')) {
      code = 'timeout';
    } else if (message.contains('rate') || message.contains('Rate')) {
      code = 'rate_limit';
    } else if (message.contains('429')) {
      code = 'rate_limit';
    } else if (message.contains('404')) {
      code = 'not_found';
    } else if (message.contains('500')) {
      code = 'server_error';
    }

    // TODO: Добавить логирование ошибок
    // logger.error('WishlistBloc error: $message', e);

    emit(WishlistError(
      message: message,
      code: code,
    ));
  }
}
