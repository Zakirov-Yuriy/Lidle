// ============================================================
// "BLoC: Управление избранным на сервере"
// ============================================================
//
// Синхронизирует локальное хранилище избранного с серверным API.
// Использует оптимистичные обновления для быстрого отклика UI.
// При ошибке сохраняет локальное состояние и повторяет попытку.

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
/// 1. Загрузку списка избранных с сервера при старте
/// 2. Добавление/удаление объявлений в/из избранного
/// 3. Синхронизацию локального кеша с серверным состоянием
/// 4. Обработку ошибок (auth, network, rate limit)
///
/// Использует двухуровневое хранилище:
/// - Локальное (Hive) для быстрого доступа и оптимистичных обновлений
/// - Серверное (API) как источник истины для состояния после синхронизации
class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  /// Токен авторизации (извлекается из HiveService при необходимости)
  String? _token;

  /// Кеш ID избранных объявлений для отслеживания изменений
  Set<int> _cachedWishlistIds = {};

  /// Конструктор WishlistBloc.
  WishlistBloc() : super(const WishlistInitial()) {
    on<LoadWishlistEvent>(_onLoadWishlist);
    on<AddToWishlistEvent>(_onAddToWishlist);
    on<RemoveFromWishlistEvent>(_onRemoveFromWishlist);
    on<SyncWishlistEvent>(_onSyncWishlist);
  }

  /// Получить токен из HiveService.
  ///
  /// Кеширует токен чтобы избежать повторного обращения к Hive.
  String? _getToken() {
    _token ??= HiveService.getUserData('token') as String?;
    return _token;
  }

  /// Обработчик события LoadWishlistEvent.
  ///
  /// Загружает список избранного с сервера и синхронизирует
  /// с локальным хранилищем (Hive).
  Future<void> _onLoadWishlist(
    LoadWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    emit(const WishlistLoading());
    print('🎯 WishlistBloc: LoadWishlistEvent запущен');

    try {
      final token = _getToken();
      if (token == null) {
        print('❌ WishlistBloc: Токен не найден');
        emit(const WishlistError(
          message: 'Требуется авторизация для доступа к избранному',
          code: 'auth',
        ));
        return;
      }

      // Загружаем со сервера
      print('🔄 WishlistBloc: Загружаем wishlist с сервера...');
      final response = await WishlistService.getWishlist(token: token);
      print('✅ WishlistBloc: Ответ от сервера получен: $response');

      // Парсим IDs из ответа
      final wishlistIds = _parseWishlistIds(response);
      print('📝 WishlistBloc: Распарсены IDs: $wishlistIds');

      // Синхронизируем с Hive (обновляем локальный кеш)
      print('🔄 WishlistBloc: Синхронизируем с Hive...');
      await _syncLocalWishlist(wishlistIds);
      print('✅ WishlistBloc: Синхронизация завершена');

      // Обновляем внутренний кеш
      _cachedWishlistIds = wishlistIds;

      print('✨ WishlistBloc: WishlistLoaded emitted с ${wishlistIds.length} IDs');
      emit(WishlistLoaded(
        wishlistIds: wishlistIds,
        syncedAt: DateTime.now(),
      ));
    } on Exception catch (e) {
      print('❌ WishlistBloc: Ошибка при загрузке: $e');
      _emitError(emit, e);
    }
  }

  /// Обработчик события AddToWishlistEvent.
  ///
  /// Выполняет оптимистичное обновление локального хранилища,
  /// затем отправляет запрос на сервер.
  Future<void> _onAddToWishlist(
    AddToWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      // 1. Оптимистичное обновление локального хранилища
      FavoritesService.toggleFavorite(event.listingId.toString());
      _cachedWishlistIds.add(event.listingId);

      // Уведомляем UI об успехе
      emit(WishlistItemAdded(listingId: event.listingId));

      // 2. Отправляем на сервер в фоне (асинхронно)
      final token = _getToken();
      if (token != null) {
        try {
          await WishlistService.addToWishlist(
            listingId: event.listingId,
            token: token,
          );
        } catch (e) {
          // Если сервер вернул ошибку, откатываем локальное изменение
          // и уведомляем пользователя
          FavoritesService.toggleFavorite(event.listingId.toString());
          _cachedWishlistIds.remove(event.listingId);

          _emitError(emit, e as Exception);
        }
      }
    } catch (e) {
      _emitError(emit, e as Exception);
    }
  }

  /// Обработчик события RemoveFromWishlistEvent.
  ///
  /// Выполняет оптимистичное обновление локального хранилища,
  /// затем отправляет запрос на сервер.
  Future<void> _onRemoveFromWishlist(
    RemoveFromWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      // 1. Оптимистичное обновление локального хранилища
      FavoritesService.toggleFavorite(event.listingId.toString());
      _cachedWishlistIds.remove(event.listingId);

      // Уведомляем UI об успехе
      emit(WishlistItemRemoved(listingId: event.listingId));

      // 2. Отправляем на сервер в фоне (асинхронно)
      final token = _getToken();
      if (token != null) {
        try {
          await WishlistService.removeFromWishlist(
            listingId: event.listingId,
            token: token,
          );
        } catch (e) {
          // Если сервер вернул ошибку, откатываем локальное изменение
          FavoritesService.toggleFavorite(event.listingId.toString());
          _cachedWishlistIds.add(event.listingId);

          _emitError(emit, e as Exception);
        }
      }
    } catch (e) {
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

  /// Парсит IDs объявлений из ответа сервера.
  ///
  /// Работает с пагинированным ответом от /me/wishlist.
  /// Извлекает все ID объявлений из поля 'wishable.id'.
  Set<int> _parseWishlistIds(Map<String, dynamic> response) {
    final ids = <int>{};
    
    print('🔍 _parseWishlistIds: Входная response: $response');

    if (response['data'] is List) {
      final List<dynamic> items = response['data'] as List<dynamic>;
      print('📊 _parseWishlistIds: Найдено ${items.length} элементов в data');
      
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          // Получаем wishable объект (сам объявление)
          final wishable = item['wishable'];
          print('  → Элемент: $item, wishable=$wishable');
          
          if (wishable is Map<String, dynamic>) {
            final id = wishable['id'];
            print('    ID из wishable.id: $id (тип: ${id.runtimeType})');
            
            if (id is int) {
              ids.add(id);
            } else if (id is String) {
              final parsed = int.tryParse(id);
              if (parsed != null) ids.add(parsed);
            }
          }
        }
      }
    } else {
      print('⚠️ _parseWishlistIds: data не является List, тип: ${response['data'].runtimeType}');
    }

    print('✨ _parseWishlistIds: Итоговый набор IDs (ID объявлений): $ids');
    return ids;
  }

  /// Синхронизирует локальное хранилище (Hive) с серверным состоянием.
  ///
  /// Обновляет список избранных ID в Hive так чтобы он соответствовал
  /// серверному состоянию.
  Future<void> _syncLocalWishlist(Set<int> serverIds) async {
    print('🔄 _syncLocalWishlist: Начало синхронизации');
    
    final localIds = FavoritesService.getFavorites();
    print('📱 _syncLocalWishlist: Локальные IDs из Hive: $localIds');
    
    final localIdSet = localIds.map((id) => int.tryParse(id)).whereType<int>().toSet();
    print('📱 _syncLocalWishlist: Локальные IDs (int): $localIdSet');
    print('📱 _syncLocalWishlist: Серверные IDs: $serverIds');

    // Добавляем IDs которые есть на сервере но нет локально
    int addedCount = 0;
    for (final id in serverIds) {
      if (!localIdSet.contains(id)) {
        print('➕ _syncLocalWishlist: Добавляем ID $id (нет локально)');
        FavoritesService.toggleFavorite(id.toString());
        addedCount++;
      }
    }

    // Удаляем IDs которые есть локально но нет на сервере
    int removedCount = 0;
    for (final id in localIdSet) {
      if (!serverIds.contains(id)) {
        print('➖ _syncLocalWishlist: Удаляем ID $id (нет на сервере)');
        FavoritesService.toggleFavorite(id.toString());
        removedCount++;
      }
    }
    
    final updatedLocal = FavoritesService.getFavorites();
    print('✅ _syncLocalWishlist: Синхронизация завершена (добавлено: $addedCount, удалено: $removedCount)');
    print('✅ _syncLocalWishlist: Финальное состояние Hive: $updatedLocal');
  }

  /// Эмитит состояние ошибки и логирует её.
  void _emitError(Emitter<WishlistState> emit, Exception e) {
    final message = e.toString();
    String code = 'unknown';

    if (message.contains('Требуется авторизация')) {
      code = 'auth';
    } else if (message.contains('network')) {
      code = 'network';
    } else if (message.contains('timeout')) {
      code = 'timeout';
    } else if (message.contains('rate')) {
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
