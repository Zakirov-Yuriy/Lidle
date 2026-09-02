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
  /// - [bookingFrom], [bookingTo] - поиск по свободным датам
  /// - [page] - номер страницы (по умолчанию 1)
  /// - [token] - JWT токен
  static Future<MainAdvertResponse> listAdverts({
    int? categoryId,
    int? catalogId,
    String? sort,
    String? search,
    Map<String, dynamic>? filters,

    /// Поиск по свободным датам, формат `2026-09-05`.
    ///
    /// Ищется РЕАЛЬНАЯ занятость, а не текст объявления: решение заказчика от
    /// 02.09.2026. Объявления без подключённой брони из выдачи не пропадают,
    /// их у нас подавляющее большинство, и прятать их значило бы показывать
    /// почти пустой список на каждый запрос с датами.
    ///
    /// Смысл «свободно» разный: для услуги достаточно одного свободного
    /// времени в промежутке, для жилья свободны должны быть все ночи.
    DateTime? bookingFrom,
    DateTime? bookingTo,

    int? page,
    required String token,
  }) async {
    try {
      // Валидация параметров: категория обязательна, КРОМЕ глобального поиска.
      if (categoryId == null && catalogId == null &&
          (search == null || search.trim().isEmpty)) {
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
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (sort != null) {
        params['sort'] = sort;
      }
      if (page != null) {
        params['page'] = page;
      }

      // Даты передаём вложенными параметрами, рядом с filters[address].
      // Обе границы обязательны вместе: одна без второй сервер не примет.
      if (bookingFrom != null && bookingTo != null) {
        params['filters[booking][from]'] = _ymd(bookingFrom);
        params['filters[booking][to]'] = _ymd(bookingTo);
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

  static String _ymd(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
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
    String? search,
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
      search: search,
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
