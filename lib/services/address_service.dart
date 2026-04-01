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
      // API requires minimum 3 characters in 'q' parameter
      // If query is empty or too short, use a 3-char minimum search
      final searchQuery = query.isEmpty || query.length < 3 ? '   ' : query;

      final headers = <String, String>{
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Build request body for GET request with proper JSON serialization
      final bodyMap = <String, dynamic>{'q': searchQuery};
      if (types != null && types.isNotEmpty) {
        bodyMap['types'] = types;
      }
      if (filters != null && filters.isNotEmpty) {
        bodyMap['filters'] = filters;
      }

      final uri = Uri.parse('${ApiService.baseUrl}/addresses/search');

      // log.d('📥 GET REQUEST /addresses/search');
      // log.d('URL: $uri');
      // log.d('Body: ${jsonEncode(bodyMap)}');

      // Use http.Request to send GET with JSON body
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      request.body = jsonEncode(bodyMap);

      final streamResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamResponse);

      // log.d('✅ API Response status: ${response.statusCode}');
      // log.d();

      if (response.statusCode == 200) {
        // log.d('🔄 Parsing JSON response...');
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        // log.d('🔄 JSON decoded successfully');

        final result = AddressesResponse.fromJson(jsonResponse);
        // log.d();

        return result;
      } else {
        // log.d('❌ ${response.statusCode} Error');
        // log.d('Response: ${response.body}');
        throw Exception('Failed to search addresses: ${response.statusCode}');
      }
    } catch (e) {
      // log.d('❌ Exception in searchAddresses: $e');
      // log.d('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to search addresses: $e');
    }
  }
}


