// ============================================================
// "BLoC: Управление избранным (локальное + серверное)"
// ============================================================

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive_service.dart';
import '../../models/home_models.dart';
import '../../services/favorites_service.dart';
import '../../services/wishlist_service.dart';

part 'wishlist_event.dart';
part 'wishlist_state.dart';

class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  // ── Внутренний кеш ──────────────────────────────────────────────────────

  /// ID избранных объявлений
  Set<int> _cachedWishlistIds = {};

  /// Полные данные объявлений (заполняются при загрузке с сервера).
  List<Listing> _cachedListings = [];

  /// Маппинг advertId → wishlistEntryId для DELETE запросов
  Map<int, int> _wishlistIdMapping = {};

  /// Дебоунс для LoadWishlistEvent (2 сек)
  DateTime? _lastLoadWishlistTime;
  static const Duration _loadWishlistDebounce = Duration(seconds: 2);

  // ── Конструктор ─────────────────────────────────────────────────────────

  WishlistBloc() : super(const WishlistInitial()) {
    on<LoadWishlistEvent>(_onLoadWishlist);
    on<AddToWishlistEvent>(_onAddToWishlist);
    on<RemoveFromWishlistEvent>(_onRemoveFromWishlist);
    on<SyncWishlistEvent>(_onSyncWishlist);
    on<SyncLocalWishlistOnAuthEvent>(_onSyncLocalWishlistOnAuth);
  }

  // ── Токен ────────────────────────────────────────────────────────────────

  String? _getToken() => HiveService.getUserData('token') as String?;

  // ── Обработчики событий ──────────────────────────────────────────────────

  /// Загрузка избранного.
  Future<void> _onLoadWishlist(
    LoadWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    // Дебоунс
    final now = DateTime.now();
    if (_lastLoadWishlistTime != null &&
        now.difference(_lastLoadWishlistTime!) < _loadWishlistDebounce) {
      return;
    }
    _lastLoadWishlistTime = now;

    emit(const WishlistLoading());

    final token = _getToken();

    if (token == null || token.isEmpty) {
      // Неавторизованный — только Hive
      final localIds = FavoritesService.getFavorites()
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toSet();
      _cachedWishlistIds = localIds;
      emit(WishlistLoaded(
        wishlistIds: localIds,
        listings: const [],
        syncedAt: DateTime.now(),
        isLocal: true,
      ));
      return;
    }

    // Авторизованный — загружаем с сервера
    try {
      final response = await WishlistService.getWishlist(token: token);
      final ids      = _parseWishlistIds(response);
      final listings = _parseWishlistListings(response);

      await _syncLocalWishlist(ids);
      _cachedWishlistIds = ids;
      _cachedListings    = listings;

      debugPrint('✅ WishlistBloc.LoadWishlist: ${ids.length} items');

      emit(WishlistLoaded(
        wishlistIds: ids,
        listings:    listings,
        syncedAt:    DateTime.now(),
        isLocal:     false,
      ));
    } catch (serverError) {
      // Сервер упал (500, сеть и т.д.) — используем Hive как fallback
      debugPrint('⚠️ WishlistBloc.LoadWishlist: server error, Hive fallback. Error: $serverError');

      final localIds = FavoritesService.getFavorites()
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toSet();

      _cachedWishlistIds = localIds;

      emit(WishlistLoaded(
        wishlistIds: localIds,
        listings:    List.from(_cachedListings),
        syncedAt:    DateTime.now(),
        isLocal:     localIds.isNotEmpty || _cachedListings.isEmpty,
      ));
    }
  }

  /// Добавление в избранное.
  ///
  /// Откатываем Hive ТОЛЬКО если POST на сервер упал.
  /// Не делаем лишний GET после POST — это устраняет ложный rollback.
  Future<void> _onAddToWishlist(
    AddToWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      // 1. Оптимистичное обновление Hive + кеш
      FavoritesService.toggleFavorite(event.listingId.toString());
      _cachedWishlistIds.add(event.listingId);
      emit(WishlistItemAdded(listingId: event.listingId));

      final token = _getToken();

      if (token == null || token.isEmpty) {
        // Не авторизован — только локально
        emit(WishlistLoaded(
          wishlistIds: Set.from(_cachedWishlistIds),
          listings:    List.from(_cachedListings),
          syncedAt:    DateTime.now(),
          isLocal:     true,
        ));
        return;
      }

      // 2. POST на сервер
      try {
        final response = await WishlistService.addToWishlist(
          advertId: event.listingId,
          token:    token,
        );

        if (response['success'] != true) {
          final msg = (response['message'] ?? '').toString().toLowerCase();
          // Если сервер говорит "уже в списке" — это не ошибка с нашей стороны.
          // Элемент реально есть на сервере, rollback делать не нужно.
          final alreadyExists = msg.contains('уже') ||
              msg.contains('already') ||
              msg.contains('duplicate');

          if (alreadyExists) {
            debugPrint('ℹ️ WishlistBloc.Add: already on server for ${event.listingId}, keeping Hive');
            emit(WishlistLoaded(
              wishlistIds: Set.from(_cachedWishlistIds),
              listings:    List.from(_cachedListings),
              syncedAt:    DateTime.now(),
              isLocal:     false,
            ));
            return;
          }

          throw Exception(response['message'] ?? 'Ошибка при добавлении в избранное');
        }

        debugPrint('✅ WishlistBloc.Add: OK for advert ${event.listingId}');

        emit(WishlistLoaded(
          wishlistIds: Set.from(_cachedWishlistIds),
          listings:    List.from(_cachedListings),
          syncedAt:    DateTime.now(),
          isLocal:     false,
        ));
      } catch (serverError) {
        // POST упал — откатываем Hive и кеш ID
        debugPrint('❌ WishlistBloc.Add: server error for ${event.listingId}: $serverError');
        FavoritesService.toggleFavorite(event.listingId.toString());
        _cachedWishlistIds.remove(event.listingId);
        _emitError(
          emit,
          serverError is Exception ? serverError : Exception(serverError.toString()),
        );
      }
    } catch (e) {
      _emitError(emit, e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Удаление из избранного.
  ///
  /// При ошибке сервера НЕ откатываем — следующий LoadWishlist синхронизирует.
  Future<void> _onRemoveFromWishlist(
    RemoveFromWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      final token = _getToken();

      // 1. Оптимистичное обновление Hive + кеш
      if (FavoritesService.isFavorite(event.listingId.toString())) {
        FavoritesService.toggleFavorite(event.listingId.toString());
      }
      _cachedWishlistIds.remove(event.listingId);
      _cachedListings.removeWhere((l) => l.id == event.listingId.toString());
      emit(WishlistItemRemoved(listingId: event.listingId));

      if (token == null || token.isEmpty) {
        emit(WishlistLoaded(
          wishlistIds: Set.from(_cachedWishlistIds),
          listings:    List.from(_cachedListings),
          syncedAt:    DateTime.now(),
          isLocal:     true,
        ));
        return;
      }

      // 2. DELETE на сервер
      final wishlistEntryId = _wishlistIdMapping[event.listingId];
      final deleteId        = wishlistEntryId ?? event.listingId;

      try {
        final response = await WishlistService.removeFromWishlist(
          advertId: deleteId,
          token:    token,
        );

        if (response['success'] != true) {
          debugPrint('⚠️ WishlistBloc.Remove: server returned false for ${event.listingId}');
        } else {
          _wishlistIdMapping.remove(event.listingId);
          debugPrint('✅ WishlistBloc.Remove: OK for advert ${event.listingId}');
        }
      } catch (serverError) {
        // Ошибка сервера — не откатываем, LoadWishlist синхронизирует
        debugPrint('⚠️ WishlistBloc.Remove: server error for ${event.listingId}: $serverError');
      }

      emit(WishlistLoaded(
        wishlistIds: Set.from(_cachedWishlistIds),
        listings:    List.from(_cachedListings),
        syncedAt:    DateTime.now(),
        isLocal:     false,
      ));
    } catch (e) {
      _emitError(emit, e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Ручная синхронизация.
  Future<void> _onSyncWishlist(
    SyncWishlistEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      final token = _getToken();
      if (token == null) {
        emit(const WishlistError(message: 'Требуется авторизация', code: 'auth'));
        return;
      }

      if (event.fullSync) {
        emit(const WishlistLoading());
        final response = await WishlistService.getWishlist(token: token);
        final ids      = _parseWishlistIds(response);
        final listings = _parseWishlistListings(response);

        await _syncLocalWishlist(ids);
        _cachedWishlistIds = ids;
        _cachedListings    = listings;

        emit(WishlistSynced(wishlistIds: ids));
      } else {
        emit(WishlistSynced(wishlistIds: _cachedWishlistIds));
      }
    } on Exception catch (e) {
      _emitError(emit, e);
    }
  }

  /// Синхронизация при авторизации.
  Future<void> _onSyncLocalWishlistOnAuth(
    SyncLocalWishlistOnAuthEvent event,
    Emitter<WishlistState> emit,
  ) async {
    try {
      final token = _getToken();
      if (token == null) return;

      final response  = await WishlistService.getWishlist(token: token);
      final serverIds = _parseWishlistIds(response);
      final listings  = _parseWishlistListings(response);

      await _syncLocalWishlist(serverIds);
      _cachedWishlistIds = serverIds;
      _cachedListings    = listings;

      debugPrint('✅ WishlistBloc.SyncOnAuth: ${serverIds.length} items');

      emit(WishlistLoaded(
        wishlistIds: serverIds,
        listings:    listings,
        syncedAt:    DateTime.now(),
        isLocal:     false,
      ));
    } catch (e) {
      // Сервер упал (например 500 из-за удалённых объявлений в wishlist).
      // НЕ трогаем Hive — используем его как источник истины.
      debugPrint('⚠️ WishlistBloc.SyncOnAuth: server error, falling back to Hive. Error: $e');

      final localIds = FavoritesService.getFavorites()
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toSet();

      _cachedWishlistIds = localIds;
      // _cachedListings остаётся пустым — экран покажет fallback через ListingsBloc

      emit(WishlistLoaded(
        wishlistIds: localIds,
        listings:    const [],
        syncedAt:    DateTime.now(),
        isLocal:     true, // помечаем как локальное чтобы FavoritesScreen использовал ListingsBloc fallback
      ));
    }
  }

  // ── Парсинг ответа ────────────────────────────────────────────────────────

  Set<int> _parseWishlistIds(Map<String, dynamic> response) {
    final ids = <int>{};
    _wishlistIdMapping.clear();

    final data = response['data'];
    if (data is! List) return ids;

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final wishable        = item['wishable'];
      final wishlistEntryId = item['id'];
      if (wishable is! Map<String, dynamic>) continue;

      final rawId = wishable['id'];
      int? advertId;
      if (rawId is int) {
        advertId = rawId;
      } else if (rawId is String) {
        advertId = int.tryParse(rawId);
      }
      if (advertId == null) continue;

      ids.add(advertId);
      if (wishlistEntryId is int) {
        _wishlistIdMapping[advertId] = wishlistEntryId;
      }
    }

    return ids;
  }

  List<Listing> _parseWishlistListings(Map<String, dynamic> response) {
    final listings = <Listing>[];
    final data     = response['data'];
    if (data is! List) return listings;

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final wishable = item['wishable'];
      if (wishable is! Map<String, dynamic>) continue;

      final rawId = wishable['id'];
      final id    = rawId is int
          ? rawId.toString()
          : (rawId is String ? rawId : null);
      if (id == null) continue;

      listings.add(Listing(
        id:        id,
        slug:      wishable['slug']        as String?,
        imagePath: (wishable['thumbnail']  as String?) ?? '',
        images:    const [],
        title:     (wishable['name']       as String?) ?? '',
        price:     (wishable['price']      as String?) ?? '',
        location:  (wishable['address']    as String?) ?? '',
        date:      (wishable['created_at'] as String?) ?? '',
      ));
    }

    return listings;
  }

  // ── Синхронизация Hive ────────────────────────────────────────────────────

  Future<void> _syncLocalWishlist(Set<int> serverIds) async {
    final localIds = FavoritesService.getFavorites()
        .map((id) => int.tryParse(id))
        .whereType<int>()
        .toSet();

    for (final id in serverIds) {
      if (!localIds.contains(id)) FavoritesService.toggleFavorite(id.toString());
    }
    for (final id in localIds) {
      if (!serverIds.contains(id)) FavoritesService.toggleFavorite(id.toString());
    }
  }

  // ── Эмит ошибки ──────────────────────────────────────────────────────────

  void _emitError(Emitter<WishlistState> emit, Exception e) {
    final message = e.toString();
    String code = 'unknown';

    if (message.contains('Требуется авторизация')) code = 'auth';
    else if (message.contains('429') || message.contains('rate')) code = 'rate_limit';
    else if (message.contains('network') || message.contains('Network')) code = 'network';
    else if (message.contains('timeout') || message.contains('Timeout')) code = 'timeout';
    else if (message.contains('404')) code = 'not_found';
    else if (message.contains('500')) code = 'server_error';

    emit(WishlistError(message: message, code: code));
  }
}
