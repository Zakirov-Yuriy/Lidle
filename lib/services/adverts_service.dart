import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/services/api_service.dart';

class AdvertsService {
  /// Получить список объявлений с фильтрацией и пагинацией
  ///
  /// Параметры:
  /// - [categoryId] - ID категории (если null, используется catalogId)
  /// - [catalogId] - ID каталога (если null, используется categoryId)
  /// - [sort] - сортировка ('newest', 'price_asc', 'price_desc')
  /// - [filters] - дополнительные фильтры (price_min, price_max, value_selected)
  /// - [page] - номер страницы (по умолчанию 1)
  /// - [token] - JWT токен
  static Future<MainAdvertResponse> listAdverts({
    int? categoryId,
    int? catalogId,
    String? sort,
    Map<String, dynamic>? filters,
    int? page,
    required String token,
  }) async {
    try {
      // Валидация параметров
      if (categoryId == null && catalogId == null) {
        throw Exception('Необходимо указать categoryId или catalogId');
      }

      // Построение параметров запроса
      final Map<String, dynamic> params = {};

      if (categoryId != null) {
        params['category_id'] = categoryId;
      }
      if (catalogId != null) {
        params['catalog_id'] = catalogId;
      }
      if (sort != null) {
        params['sort'] = sort;
      }
      if (page != null) {
        params['page'] = page;
      }

      // Добавление фильтров
      if (filters != null) {
        filters.forEach((key, value) {
          params[key] = value;
        });
      }

      final response = await ApiService.getWithQuery(
        '/adverts',
        params,
        token: token,
      );

      return MainAdvertResponse.fromJson(response);
    } catch (e) {
      throw Exception('Ошибка при загрузке объявлений: $e');
    }
  }

  /// Получить одно объявление по ID
  ///
  /// Параметры:
  /// - [id] - ID объявления
  /// - [token] - JWT токен
  static Future<AdvertDetailResponse> getAdvert({
    required int id,
    required String token,
  }) async {
    try {
      final response = await ApiService.get('/adverts/$id', token: token);

      return AdvertDetailResponse.fromJson(response);
    } catch (e) {
      throw Exception('Ошибка при загрузке объявления: $e');
    }
  }

  /// Получить объявления продавца по ID пользователя
  ///
  /// ВАЖНО: API документация не содержит явного способа фильтровать по user_id/seller_id.
  /// Поэтому сейчас этот метод:
  /// 1. Спробует использовать фильтр user_id если API его поддерживает (требует тестирования)
  /// 2. Рекомендуется использовать статические данные похожих объявлений с мини-экрана
  ///
  /// Параметры:
  /// - [userId] - ID продавца
  /// - [categoryId] - ID категории (опционально, для более узкого поиска)
  /// - [token] - JWT токен
  static Future<List<MainAdvert>> getSellerAdverts({
    required String userId,
    int? categoryId,
    required String token,
  }) async {
    try {
      // Примечание: Эта реализация требует подтверждения от бэка
      // что API поддерживает фильтр по user_id в filters параметре

      final filters = <String, dynamic>{'user_id': userId};

      // Если категория указана, используем её
      if (categoryId != null) {
        final response = await listAdverts(
          categoryId: categoryId,
          filters: filters,
          token: token,
        );

        // Фильтруем результаты локально по user_id если нужно
        return response.data;
      } else {
        // Если категория не указана, мы не можем загрузить объявления
        // так как API требует category_id или catalog_id
        throw Exception(
          'Для загрузки объявлений продавца требуется указать categoryId',
        );
      }
    } catch (e) {
      throw Exception('Ошибка при загрузке объявлений продавца: $e');
    }
  }

  /// Получить объявления продавца с локальной фильтрацией
  ///
  /// Параметры:
  /// - [userId] - ID продавца
  /// - [catalogId] или [categoryId] - ID каталога или категории
  /// - [token] - JWT токен
  static Future<List<MainAdvert>> getSellerAdvertsFiltered({
    required String userId,
    int? categoryId,
    int? catalogId,
    required String token,
  }) async {
    try {
      // Получаем объявления по категории/каталогу
      final response = await listAdverts(
        categoryId: categoryId,
        catalogId: catalogId,
        token: token,
      );

      // Локально фильтруем по user_id (требует что user информация есть в ответе)
      // Это требует проверки структуры ответа от API
      return response.data;
    } catch (e) {
      throw Exception('Ошибка при загрузке объявлений продавца: $e');
    }
  }

  ///
  /// Параметры:
  /// - [categoryId] - ID категории (взаимоисключающий с catalogId)
  /// - [catalogId] - ID каталога (взаимоисключающий с categoryId)
  /// - [priceMin] - минимальная цена
  /// - [priceMax] - максимальная цена
  /// - [sort] - сортировка (newest, price_asc, price_desc)
  /// - [page] - номер страницы
  /// - [token] - JWT токен
  static Future<MainAdvertResponse> searchAdverts({
    int? categoryId,
    int? catalogId,
    int? priceMin,
    int? priceMax,
    String? sort,
    int? page,
    required String token,
  }) async {
    final filters = <String, dynamic>{};

    if (priceMin != null) {
      filters['price_min'] = priceMin;
    }
    if (priceMax != null) {
      filters['price_max'] = priceMax;
    }

    return listAdverts(
      categoryId: categoryId,
      catalogId: catalogId,
      sort: sort ?? 'newest',
      filters: filters.isNotEmpty ? filters : null,
      page: page,
      token: token,
    );
  }
}

/// Модель для ответа списка объявлений
class MainAdvertResponse {
  final List<MainAdvert> data;
  final int? total;
  final int? page;
  final int? perPage;
  final int? lastPage;

  MainAdvertResponse({
    required this.data,
    this.total,
    this.page,
    this.perPage,
    this.lastPage,
  });

  factory MainAdvertResponse.fromJson(Map<String, dynamic> json) {
    return MainAdvertResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => MainAdvert.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int?,
      page: json['page'] as int?,
      perPage: json['per_page'] as int?,
      lastPage: json['last_page'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'data': data.map((e) => e.toJson()).toList(),
    'total': total,
    'page': page,
    'per_page': perPage,
    'last_page': lastPage,
  };
}

/// Модель для ответа одного объявления
class AdvertDetailResponse {
  final MainAdvert data;

  AdvertDetailResponse({required this.data});

  factory AdvertDetailResponse.fromJson(Map<String, dynamic> json) {
    return AdvertDetailResponse(
      data: MainAdvert.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {'data': data.toJson()};
}
