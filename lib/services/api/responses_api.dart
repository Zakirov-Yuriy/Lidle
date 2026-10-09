// ============================================================
// Responses API — отклики на объявления (09.10.2026, задача 15).
// ============================================================
//
// Отклик и предложение цены вещи похожие, и путать их легко. Разница в том,
// кто кому нужен:
//
//   предложение цены  товар есть, цена названа, покупатель хочет дешевле;
//                     сумма обязательна, сообщение к ней приписка;
//   отклик            нужен ЧЕЛОВЕК: вакансия, подработка, разовая задача;
//                     главное здесь сообщение, цена необязательна.
//
// Разбор на сервере: back/api/adverts/responses-api.md.
//
// Методы:
//   - submitResponse({advertId, message, price})
//   - getMyResponses({page})            мои отклики
//   - getReceivedResponses({page})      отклики на мои объявления
//   - updateResponseStatus({responseId, statusId})  принять или отклонить

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api/_api_base.dart';

class ResponsesApi {
  /// Отправить отклик на объявление.
  /// POST /v1/adverts/{id}/response
  ///
  /// Сервер заодно заводит сообщение автору объявления с этим же текстом и
  /// плашкой объявления в шапке переписки. Отдельно писать в чат не нужно.
  static Future<Map<String, dynamic>> submitResponse({
    required int advertId,
    required String message,
    double? price,
    String? token,
  }) async {
    final effectiveToken = ApiBase.requireToken(token);

    final body = <String, dynamic>{'message': message};

    // Пустую цену НЕ отправляем: сервер её не ждёт, а ноль означал бы
    // «готов работать бесплатно», а не «цену не назвал».
    if (price != null) {
      body['price'] = price;
    }

    return ApiService.post(
      '/adverts/$advertId/response',
      body,
      token: effectiveToken,
    );
  }

  /// Мои отклики: на что откликнулся я.
  /// GET /v1/me/responses
  static Future<List<Map<String, dynamic>>> getMyResponses({
    String? token,
    int page = 1,
  }) async {
    final effectiveToken = ApiBase.requireToken(token);

    final response = await ApiService.getWithQuery(
      '/me/responses',
      {'page': page},
      token: effectiveToken,
    );

    return _list(response, 'getMyResponses');
  }

  /// Отклики мне: на МОИ объявления.
  /// GET /v1/me/responses/received
  static Future<List<Map<String, dynamic>>> getReceivedResponses({
    String? token,
    int page = 1,
  }) async {
    final effectiveToken = ApiBase.requireToken(token);

    final response = await ApiService.getWithQuery(
      '/me/responses/received',
      {'page': page},
      token: effectiveToken,
    );

    return _list(response, 'getReceivedResponses');
  }

  /// Принять или отклонить отклик.
  /// PUT /v1/me/responses/{id}
  ///
  /// statusId: 2 принять, 3 отклонить. Единицу («новый») сервер не примет:
  /// вернуть отклик в непрочитанное нельзя.
  static Future<Map<String, dynamic>> updateResponseStatus({
    required int responseId,
    required int statusId,
    String? token,
  }) async {
    final effectiveToken = ApiBase.requireToken(token);

    return ApiService.put(
      '/me/responses/$responseId',
      {'response_status_id': statusId},
      token: effectiveToken,
    );
  }

  /// Разбор ответа.
  ///
  /// Ресурс отдаёт список в `data`, но пустой ответ приходит и как пустой
  /// список, и как отсутствующий ключ. Обе формы это «откликов нет», а не
  /// ошибка.
  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> response,
    String where,
  ) {
    if (response['data'] is List) {
      final rows = List<Map<String, dynamic>>.from(
        (response['data'] as List).whereType<Map<String, dynamic>>(),
      );

      log.d('$where: получено откликов ${rows.length}');

      return rows;
    }

    log.d('$where: списка в ответе нет, ключи ${response.keys.toList()}');

    return const [];
  }
}
