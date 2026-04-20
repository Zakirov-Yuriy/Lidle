// ============================================================
// Wishlist API — избранное.
// ============================================================
// Извлечено из lib/services/api_service.dart (строки 2632–2661).
// Методы:
//   - removeFromWishlist({advertId})

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api/_api_base.dart';

class WishlistApi {
  /// 🗑️ Удалить объявление из избранного
  /// DELETE /v1/me/wishlist/destroy/{advertId}
  /// Параметры:
  /// - advertId: ID объявления для удаления из избранного
  /// - token: Bearer токен пользователя
  static Future<Map<String, dynamic>> removeFromWishlist({
    required int advertId,
    String? token,
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      log.d('🗑️ Удаляем объявление #$advertId из избранного...');

      final response = await ApiService.delete(
        '/me/wishlist/destroy/$advertId',
        token: effectiveToken,
      );

      log.d('✅ Ответ от API: $response');
      return response;
    } catch (e) {
      log.d('❌ Ошибка удаления из избранного: $e');
      rethrow;
    }
  }
}
