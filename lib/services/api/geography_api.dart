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
  /// Передаём q/types/filters как query-параметры (как это делает веб-сайт).
  static Future<List<Map<String, dynamic>>> searchAddresses(
    String query, {
    String? token,
    List<String>? types,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // API требует минимум 3 символа в 'q'. Если запрос короче,
      // возвращаем пустой список, чтобы не получать рандомные результаты.
      final cleanQuery = query.trim();
      if (cleanQuery.length < 3) {
        log.d('⚠️ GeographyApi.searchAddresses: query слишком короткий ("$query"), возвращаем []');
        return [];
      }

      // Заголовки без Content-Type: application/json — запрос идёт с query-
      // параметрами, тела нет. Раньше отправлялся GET с JSON-телом, но тело GET
      // отбрасывается частью прокси/серверов, из-за чего поиск работал «не всегда».
      final headers = <String, String>{
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Query-параметры: q, types[i], filters[key]. Пустые/null-фильтры
      // пропускаем, иначе сервер вернёт 422 (см. address_service.dart).
      final queryParams = <String, dynamic>{'q': cleanQuery};
      if (types != null && types.isNotEmpty) {
        for (int i = 0; i < types.length; i++) {
          queryParams['types[$i]'] = types[i];
        }
      }
      if (filters != null && filters.isNotEmpty) {
        filters.forEach((key, value) {
          if (value == null) return;
          final stringValue = value.toString();
          if (stringValue.isEmpty ||
              stringValue == 'null' ||
              stringValue == '0') {
            return;
          }
          queryParams['filters[$key]'] = stringValue;
        });
      }

      final uri = Uri.parse('${ApiService.baseUrl}/addresses/search')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

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