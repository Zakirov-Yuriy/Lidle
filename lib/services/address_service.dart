import 'package:lidle/models/address_model.dart';
import 'package:lidle/services/api_service.dart';

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
  /// - q: поисковая строка (требуется)
  /// - types: массив типов [main_region, region, city, district, street, building]
  /// - filters: объект с фильтрами (main_region_id, region_id, city_id и т.д.)
  static Future<AddressesResponse> searchAddresses({
    required String query,
    List<String>? types,
    Map<String, dynamic>? filters,
    String? token,
  }) async {
    try {
      final body = {
        'q': query,
        if (types != null) 'types': types,
        if (filters != null) 'filters': filters,
      };

      final response = await ApiService.getWithQuery(
        '/addresses/search',
        body,
        token: token,
      );
      return AddressesResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search addresses: $e');
    }
  }
}
