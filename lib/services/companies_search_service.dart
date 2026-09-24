// Поиск компаний и магазинов (задача 28, 24.09.2026).
//
// Человек вводит в поиске название компании («ZAC», «Ajax») и ожидает увидеть
// саму компанию, а не только её объявления. Эти карточки главный экран
// показывает над результатами поиска, нажатие ведёт на витрину продавца.
//
//   GET /v1/companies/search?search=zac&page=1&limit=10

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lidle/services/api_service.dart';

class CompanySearchItem {
  const CompanySearchItem({
    required this.userId,
    required this.name,
    this.about,
    this.image,
    this.city,
    this.advertsCount = 0,
  });

  final int userId;
  final String name;
  final String? about;
  final String? image;
  final String? city;
  final int advertsCount;

  static CompanySearchItem? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = (raw['user_id'] as num?)?.toInt();
    final name = '${raw['name'] ?? ''}'.trim();

    if (id == null || name.isEmpty) return null;

    String? text(dynamic v) {
      final s = '${v ?? ''}'.trim();
      return s.isEmpty ? null : s;
    }

    return CompanySearchItem(
      userId: id,
      name: name,
      about: text(raw['about']),
      image: text(raw['image']),
      city: text(raw['city']),
      advertsCount: (raw['adverts_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CompaniesSearchService {
  /// Компании и магазины по строке поиска. Ошибку не поднимаем: поиск
  /// объявлений важнее, и из-за упавшего запроса компаний выдача пустой
  /// остаться не должна.
  static Future<List<CompanySearchItem>> search(String query, {int limit = 10}) async {
    final text = query.trim();

    if (text.length < 2) return [];

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/companies/search'
        '?search=${Uri.encodeQueryComponent(text)}&limit=$limit',
      );

      final response = await http.get(uri, headers: ApiService.defaultHeaders);

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;

      if (data is! List) return [];

      return [
        for (final row in data)
          if (CompanySearchItem.tryParse(row) != null) CompanySearchItem.tryParse(row)!,
      ];
    } catch (_) {
      return [];
    }
  }
}
