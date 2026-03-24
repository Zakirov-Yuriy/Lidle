// ============================================================
// "Сервис: API интеграция для управления избранным"
// ============================================================
//
// Взаимодействие с серверными endpoints:
// - GET /me/wishlist - получить список избранных объявлений
// - POST /me/wishlist/add - добавить объявление в избранное
// - DELETE /me/wishlist/destroy/{id} - удалить объявление из избранного

import 'api_service.dart';

/// Сервис для работы с API избранного (wishlist).
///
/// Предоставляет методы для добавления, удаления и получения
/// списка избранных объявлений с сервера.
class WishlistService {
  /// Добавить объявление в избранное на сервере.
  ///
  /// [listingId] - ID объявления для добавления
  /// [token] - токен авторизации
  ///
  /// Возвращает ответ сервера или выбрасывает исключение.
  static Future<Map<String, dynamic>> addToWishlist({
    required int listingId,
    required String token,
  }) async {
    try {
      final body = {'listing_id': listingId};
      final response = await ApiService.post(
        '/me/wishlist/add',
        body,
        token: token,
      );
      return response;
    } catch (e) {
      throw Exception('Ошибка при добавлении в избранное: $e');
    }
  }

  /// Удалить объявление из избранного на сервере.
  ///
  /// [listingId] - ID объявления в wishlist для удаления
  /// [token] - токен авторизации
  ///
  /// Выбрасывает исключение при ошибке.
  static Future<void> removeFromWishlist({
    required int listingId,
    required String token,
  }) async {
    try {
      await ApiService.delete(
        '/me/wishlist/destroy/$listingId',
        token: token,
      );
    } catch (e) {
      throw Exception('Ошибка при удалении из избранного: $e');
    }
  }

  /// Получить список избранных объявлений с сервера.
  ///
  /// [token] - токен авторизации
  /// [page] - номер страницы (опционально)
  /// [sort] - тип сортировки: 'new', 'old', 'expensive', 'cheap' (опционально)
  ///
  /// Возвращает Map с данными wishlist от сервера.
  static Future<Map<String, dynamic>> getWishlist({
    required String token,
    int? page,
    String? sort,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) params['page'] = page;
      if (sort != null) params['sort'] = sort;

      print('🌐 WishlistService.getWishlist(): Загружаем с сервера...');
      final response = await ApiService.getWithQuery(
        '/me/wishlist',
        params.isEmpty ? {} : params,
        token: token,
      );
      print('🌐 WishlistService.getWishlist(): Ответ получен: $response');
      return response;
    } catch (e) {
      print('❌ WishlistService.getWishlist(): Ошибка: $e');
      throw Exception('Ошибка при загрузке избранного: $e');
    }
  }

  /// Получить только список ID из избранного с сервера.
  ///
  /// Удобный метод для получения просто списка ID без полных данных.
  static Future<List<int>> getWishlistIds({
    required String token,
  }) async {
    try {
      final response = await getWishlist(token: token);
      
      if (response['data'] is List) {
        final List<dynamic> items = response['data'] as List<dynamic>;
        return items
            .whereType<Map<String, dynamic>>()
            .map((item) => (item['id'] as int?))
            .whereType<int>()
            .toList();
      }
      
      return [];
    } catch (e) {
      throw Exception('Ошибка при загрузке ID избранного: $e');
    }
  }
}
