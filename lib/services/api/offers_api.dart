// ============================================================
// Offers API — ценовые предложения (buyer ↔ seller).
// ============================================================
// Извлечено из lib/services/api_service.dart (строки 1943–2283).
// Логика идентична оригиналу; дубли заменены на ApiBase.requireToken().
//
// Методы:
//   - submitPriceOffer({advertId, price, message})
//   - getPriceOffers({advertId, advertSlug, page, sort})
//   - getMyOffers({page, sort})
//   - getOffersReceivedList({page, sort})
//   - getAllReceivedOffers() — комбинирует два запроса
//   - updateReceivedOfferStatus({offerId, statusId})   [PUT]
//   - updateOfferStatus({offerId, statusId})           [DELETE — это не опечатка, API так требует]

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api/_api_base.dart';

class OffersApi {
  /// 💰 Отправить предложение цены для объявления
  /// POST /v1/adverts/{id}/offer
  static Future<Map<String, dynamic>> submitPriceOffer({
    required int advertId,
    required double price,
    required String message,
    String? token,
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final body = {'price': price, 'message': message};

      final response = await ApiService.post(
        '/adverts/$advertId/offer',
        body,
        token: effectiveToken,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 💵 Получить список предложений цены для объявления
  /// GET /v1/me/offers/received/{slug}/{id}
  static Future<List<Map<String, dynamic>>> getPriceOffers({
    required int advertId,
    required String advertSlug,
    String? token,
    int page = 1,
    List<String> sort = const ['new'],
  }) async {
    try {
      log.d(
        '🔗 getPriceOffers() calling: /me/offers/received/$advertSlug/$advertId',
      );

      final effectiveToken = ApiBase.requireToken(token);

      // Endpoint принимает параметры через query string (sort — опциональный)
      final queryParams = <String, dynamic>{'page': page};

      final response = await ApiService.getWithQuery(
        '/me/offers/received/$advertSlug/$advertId',
        queryParams,
        token: effectiveToken,
      );

      log.d('📊 getPriceOffers() response:');
      log.d('   Keys: ${response.keys.toList()}');
      log.d('   Full response: $response');

      if (response['data'] is List) {
        final offers = List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );
        log.d('✅ getPriceOffers() returning ${offers.length} offers');
        return offers;
      }

      log.d('⚠️ getPriceOffers() data is not a List, returning empty');
      return [];
    } catch (e) {
      log.d('❌ Error getting price offers: $e');
      rethrow;
    }
  }

  /// 📤 Получить список МОИХ ОТПРАВЛЕННЫХ предложений цены
  /// GET /v1/me/offers
  static Future<List<Map<String, dynamic>>> getMyOffers({
    String? token,
    int page = 1,
    List<String> sort = const ['new'],
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final body = {'sort': sort, 'page': page};

      final response = await ApiService.getWithBody(
        '/me/offers',
        body,
        token: effectiveToken,
      );

      // Если нет предложений, API возвращает data: null вместо пустого массива
      if (response['data'] is List) {
        final offers = List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );
        return offers;
      } else if (response['data'] == null) {
        return [];
      }

      return [];
    } catch (e) {
      log.d('❌ Error in getMyOffers: $e');
      return [];
    }
  }

  /// 💵 Получить список объявлений, на которые я получил предложения
  /// GET /v1/me/offers/received (в оригинале — GET с JSON body)
  static Future<List<Map<String, dynamic>>> getOffersReceivedList({
    String? token,
    int page = 1,
    List<String> sort = const ['new'],
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final body = {'sort': sort, 'page': page};

      final response = await ApiService.getWithBody(
        '/me/offers/received',
        body,
        token: effectiveToken,
      );

      if (response['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );
      } else if (response['data'] == null) {
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// 💵 Получить все полученные предложения со всех объявлений.
  /// Комбинирует getOffersReceivedList + getPriceOffers.
  static Future<List<Map<String, dynamic>>> getAllReceivedOffers({
    String? token,
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final listingsWithOffers =
          await getOffersReceivedList(token: effectiveToken);

      if (listingsWithOffers.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> allOffers = [];

      for (final listing in listingsWithOffers) {
        final id = listing['id'];
        final slug = listing['slug'];

        if (id != null && slug != null) {
          final offers = await getPriceOffers(
            advertId: id as int,
            advertSlug: slug as String,
            token: effectiveToken,
          );
          allOffers.addAll(offers);
        }
      }

      return allOffers;
    } catch (e) {
      return [];
    }
  }

  /// 🔄 Обновить статус ПОЛУЧЕННОГО предложения
  /// PUT /v1/me/offers/received/{id}
  /// statusId: 2 = Accepted, 3 = Refused
  static Future<Map<String, dynamic>> updateReceivedOfferStatus({
    required int offerId,
    required int statusId,
    String? token,
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final body = {'offer_status_id': statusId};

      log.d(
        '🔄 Обновляем статус полученного предложения #$offerId на $statusId',
      );

      final response = await ApiService.put(
        '/me/offers/received/$offerId',
        body,
        token: effectiveToken,
      );

      log.d('✅ updateReceivedOfferStatus response: $response');
      return response;
    } catch (e) {
      log.d('❌ Ошибка updateReceivedOfferStatus: $e');
      rethrow;
    }
  }

  /// 🔄 Обновить статус СВОЕГО ОТПРАВЛЕННОГО предложения
  /// DELETE /v1/me/offers/{id}  (именно DELETE — так требует API)
  /// statusId: 2 = Accepted, 3 = Refused
  static Future<Map<String, dynamic>> updateOfferStatus({
    required int offerId,
    required int statusId,
    String? token,
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final body = {'offer_status_id': statusId};

      log.d(
        '🔄 Обновляем статус своего предложения #$offerId на статус $statusId',
      );
      log.d('   Endpoint: /me/offers/$offerId');
      log.d('   Body: $body');
      log.d('   ℹ️  Это МОЕ предложение которое я отправил');

      final response = await ApiService.delete(
        '/me/offers/$offerId',
        token: effectiveToken,
        body: body,
      );

      log.d('✅ API Response received:');
      log.d('   Response type: ${response.runtimeType}');
      log.d('   Response keys: ${response.keys.toList()}');
      log.d('   Full response: $response');

      final success = response['success'];
      final message = response['message'];
      final data = response['data'];

      log.d('   success field: $success (type: ${success.runtimeType})');
      log.d(
        '   message field: $message (type: ${message?.runtimeType ?? "null"})',
      );
      log.d('   data field: $data (type: ${data?.runtimeType ?? "null"})');

      // Проверяем успешность — success может быть true/false/null
      if (success == true) {
        log.d('   ✅ Статус успешно обновлен!');
        return response;
      } else if (success == false) {
        final errMsg = message ?? 'Неизвестная ошибка';
        log.d('   ❌ API вернул success=false');
        log.d('   Message: $errMsg');
        throw Exception(errMsg);
      } else {
        // success может быть null или отсутствовать
        log.d('   ⚠️ Поле success имеет неожиданное значение: $success');
        if (message != null) {
          log.d('   Message: $message');
          throw Exception(message);
        } else {
          log.d(
            '   Предположим что операция успешна (success не присутствует)',
          );
          return response;
        }
      }
    } catch (e) {
      log.d('❌ Ошибка при обновлении статуса предложения: $e');
      rethrow;
    }
  }
}
