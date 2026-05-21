import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lidle/models/address_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/logger.dart';

/// Сервис для работы с адресами
class AddressService {
  /// Получить список регионов
  static Future<RegionsResponse> getRegions({String? token}) async {
    try {
      final response = await ApiService.get('/addresses/regions', token: token);
      return RegionsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load regions: $e');
    }
  }

  /// Поиск адресов
  ///
  /// Parameters:
  /// - query: поисковая строка (требуется, минимум 3 символа)
  /// - types: массив типов [main_region, region, city, district, street, building]
  /// - filters: объект с фильтрами (main_region_id, region_id, city_id и т.д.)
  static Future<AddressesResponse> searchAddresses({
    required String query,
    List<String>? types,
    Map<String, dynamic>? filters,
    String? token,
  }) async {
    try {
      // API требует минимум 3 символа в 'q'.
      // Если запрос короче, возвращаем пустой результат вместо подмены на "ули",
      // которая раньше отсекала все улицы без подстроки "ули" в названии
      // (проспекты, переулки, бульвары и т.п.).
      final searchQuery = query.trim();
      if (searchQuery.length < 3) {
        log.d('   ⚠️ Query слишком короткий: "$query" (нужно 3+), возвращаем пустой список');
        return AddressesResponse(success: true, data: []);
      }

      final headers = <String, String>{
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Build query parameters (как на веб-сайте)
      final queryParams = <String, dynamic>{'q': searchQuery};
      
      if (types != null && types.isNotEmpty) {
        // Add types as array parameters: types[]=city&types[]=street
        for (int i = 0; i < types.length; i++) {
          queryParams['types[$i]'] = types[i];
        }
      }
      
      if (filters != null && filters.isNotEmpty) {
        // Add filters as nested parameters: filters[main_region_id]=1
        filters.forEach((key, value) {
          queryParams['filters[$key]'] = value.toString();
        });
      }

      final uri = Uri.parse('${ApiService.baseUrl}/addresses/search')
          .replace(queryParameters: queryParams);

      log.d('📥 GET REQUEST /addresses/search');
      log.d('URL: $uri');
      log.d('');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
      );

      log.d('✅ API Response status: ${response.statusCode}');
      log.d('Response length: ${response.body.length}');
      log.d('');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final result = AddressesResponse.fromJson(jsonResponse);
        
        log.d('✅ Успешно распарсили ${result.data.length} результатов');

        return result;
      } else {
        log.d('❌ ${response.statusCode} Error');
        final errorBody = response.body.length > 200 ? response.body.substring(0, 200) : response.body;
        log.d('Response: $errorBody');
        throw Exception('Failed to search addresses: ${response.statusCode}');
      }
    } catch (e, st) {
      log.d('❌ Exception in searchAddresses: $e');
      log.d('Stack: $st');
      throw Exception('Failed to search addresses: $e');
    }
  }
}