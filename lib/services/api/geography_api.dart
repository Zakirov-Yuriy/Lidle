// ============================================================
// Geography API — регионы и поиск адресов.
// ============================================================
// Извлечено из lib/services/api_service.dart (строки 1742–1870).
// Эти методы делают прямые HTTP-вызовы, минуя retry/refresh-обёртку.
// Такое поведение намеренное (см. комментарии в оригинале):
//   - getRegions() — non-critical, при 401 просто возвращает [].
//   - searchAddresses() — требует GET с JSON body (нестандарт, но так API).
// Логика идентична оригиналу.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

class GeographyApi {
  /// Получить список регионов.
  /// Non-critical endpoint — при 401 возвращает пустой список без refresh.
  static Future<List<Map<String, dynamic>>> getRegions({String? token}) async {
    try {
      final headers = {...ApiService.defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('${ApiService.baseUrl}/addresses/regions');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['data'] != null) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          return List<Map<String, dynamic>>.from(
            data.whereType<Map<String, dynamic>>(),
          );
        }
        return [];
      } else if (response.statusCode == 401 && token != null) {
        // Токен истёк, но это non-critical эндпоинт — не делаем refresh
        log.d(
          '⚠️ getRegions: 401 Unauthorized (token expired, skipping refresh)',
        );
        return [];
      } else {
        throw Exception('Failed to get regions: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Timeout при загрузке регионов (превышено 30 сек)');
    } catch (e) {
      log.d('⚠️ getRegions error: $e');
      return [];
    }
  }

  /// Поиск адресов по запросу.
  /// Возвращает список результатов поиска с ID region, city, street, building.
  /// API требует GET с JSON body (нестандарт, но так работает).
  static Future<List<Map<String, dynamic>>> searchAddresses(
    String query, {
    String? token,
    List<String>? types,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final headers = {...ApiService.defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Build request body for GET request (API требует JSON body, не query params)
      final bodyMap = <String, dynamic>{'q': query};
      if (types != null && types.isNotEmpty) {
        bodyMap['types'] = types;
      }
      if (filters != null && filters.isNotEmpty) {
        bodyMap['filters'] = filters;
      }

      final uri = Uri.parse('${ApiService.baseUrl}/addresses/search');

      // http.Request используется чтобы отправить GET с body
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      request.body = jsonEncode(bodyMap);

      final streamResponse =
          await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true || jsonResponse['data'] != null) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          return List<Map<String, dynamic>>.from(
            data.whereType<Map<String, dynamic>>(),
          );
        }
        return [];
      } else {
        throw Exception(
          'Failed to search addresses: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error searching addresses: $e');
    }
  }
}
