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
  /// POST /v1/me/wishlist/add
  /// Тело: {"advert_id": int}
  ///
  /// [advertId] - ID объявления для добавления
  /// [token] - токен авторизации
  ///
  /// Возвращает ответ сервера или выбрасывает исключение при ошибке.
  static Future<Map<String, dynamic>> addToWishlist({
    required int advertId,
    required String token,
  }) async {
    try {
      print('📤 WishlistService.addToWishlist(): Добавляем advert_id=$advertId');
      
      final body = {'advert_id': advertId};
      final response = await ApiService.post(
        '/me/wishlist/add',
        body,
        token: token,
      );
      
      print('✅ WishlistService.addToWishlist(): Успешно добавлено, ответ: $response');
      return response;
    } catch (e) {
      print('❌ WishlistService.addToWishlist(): Ошибка: $e');
      throw Exception('Ошибка при добавлении в избранное: $e');
    }
  }

  /// Удалить объявление из избранного на сервере.
  ///
  /// DELETE /v1/me/wishlist/destroy/{advert_id}
  ///
  /// [advertId] - ID объявления для удаления из wishlist
  /// [token] - токен авторизации
  ///
  /// Возвращает ответ сервера или выбрасывает исключение при ошибке.
  static Future<Map<String, dynamic>> removeFromWishlist({
    required int advertId,
    required String token,
  }) async {
    try {
      print('📤 WishlistService.removeFromWishlist(): Удаляем advert_id=$advertId');
      
      final response = await ApiService.delete(
        '/me/wishlist/destroy/$advertId',
        token: token,
      );
      
      print('✅ WishlistService.removeFromWishlist(): Успешно удалено, ответ: $response');
      return response;
    } catch (e) {
      print('❌ WishlistService.removeFromWishlist(): Ошибка: $e');
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
