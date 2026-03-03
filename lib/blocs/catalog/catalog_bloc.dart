import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_event.dart';
import 'package:lidle/blocs/catalog/catalog_state.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  /// Флаг для отслеживания, уже ли загружены каталоги
  bool _isCatalogsLoaded = false;

  /// TTL кеша каталогов — 10 минут. Каталоги меняются редко.
  static const Duration _catalogsTtl = Duration(minutes: 10);

  /// Кеш отдельного каталога/категории — 5 минут.
  static const Duration _singleItemTtl = Duration(minutes: 5);

  CatalogBloc() : super(CatalogInitial()) {
    on<LoadCatalogs>(_onLoadCatalogs);
    on<LoadCatalog>(_onLoadCatalog);
    on<LoadCategory>(_onLoadCategory);
  }

  Future<void> _onLoadCatalogs(
    LoadCatalogs event,
    Emitter<CatalogState> emit,
  ) async {
    // L1/L2 кеш: если не forceRefresh — сначала проверяем AppCacheService
    if (!event.forceRefresh) {
      final cached = AppCacheService().get<List>(CacheKeys.catalogsData);
      if (cached != null) {
        _isCatalogsLoaded = true;
        emit(CatalogsLoaded(cached.cast()));
        return;
      }
    }

    emit(CatalogLoading());
    try {
      final token = TokenService.currentToken;
      final response = await ApiService.getCatalogs(token: token);

      // 💾 Сохраняем в L1 + L2 Hive (TTL 10 мин)
      AppCacheService().set<List>(
        CacheKeys.catalogsData,
        response.data,
        ttl: _catalogsTtl,
        persist: true,
      );

      _isCatalogsLoaded = true;
      emit(CatalogsLoaded(response.data));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onLoadCatalog(
    LoadCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    // Проверяем кеш перед запросом к API
    final cacheKey = 'catalog_${event.catalogId}';
    final cached = AppCacheService().get<dynamic>(cacheKey);
    if (cached != null) {
      emit(CatalogLoaded(cached));
      return;
    }

    emit(CatalogLoading());
    try {
      final token = TokenService.currentToken;
      final catalog = await ApiService.getCatalog(
        event.catalogId,
        token: token,
      );
      // 💾 Сохраняем в L1 (TTL 5 мин)
      AppCacheService().set(cacheKey, catalog, ttl: _singleItemTtl);
      emit(CatalogLoaded(catalog));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onLoadCategory(
    LoadCategory event,
    Emitter<CatalogState> emit,
  ) async {
    // Проверяем кеш перед запросом к API
    final cacheKey = 'category_${event.categoryId}';
    final cached = AppCacheService().get<dynamic>(cacheKey);
    if (cached != null) {
      emit(CategoryLoaded(cached));
      return;
    }

    emit(CatalogLoading());
    try {
      final token = TokenService.currentToken;
      final category = await ApiService.getCategory(
        event.categoryId,
        token: token,
      );
      // 💾 Сохраняем в L1 (TTL 5 мин)
      AppCacheService().set(cacheKey, category, ttl: _singleItemTtl);
      emit(CategoryLoaded(category));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }
}
