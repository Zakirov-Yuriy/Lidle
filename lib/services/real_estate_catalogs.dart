// ============================================================
// Какие каталоги — недвижимость.
// ============================================================
//
// Нужно ровно для одного правила (16.09.2026): в объявлении о недвижимости
// область и город подставляются из компании, а улица и номер дома остаются
// ПУСТЫМИ. Компания работает в одном городе, но дома у неё каждый раз разные,
// и подставленный адрес офиса приходилось стирать перед каждой подачей.
//
// Почему отдельная служба, а не проверка названия на месте. Название каталога
// переводится и меняется руками в админке, а номер — нет. Здесь мы один раз
// спрашиваем список каталогов и запоминаем номера тех, что оказались
// недвижимостью; дальше проверка идёт по номеру каталога, который лежит в
// самой категории.
//
// Устроено как `ProductCatalogs`: тот же приём с одним запросом на всех и
// коротким сроком годности.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

class RealEstateCatalogs {
  /// Насколько доверяем запомненному списку.
  static const Duration _lifetime = Duration(minutes: 5);

  static Set<int>? _ids;
  static DateTime? _loadedAt;
  static Future<Set<int>>? _loading;

  /// Похоже ли название или адресная строка каталога на недвижимость.
  ///
  /// Запасной путь на случай, если список каталогов не пришёл: тогда решение
  /// принимается по тому, что экран уже знает о каталоге.
  static bool looksLikeRealEstate(String? name) {
    if (name == null || name.isEmpty) return false;

    final value = name.toLowerCase();

    return value.contains('недвижим') ||
        value.contains('nedvizh') ||
        value.contains('real-estate') ||
        value.contains('real estate') ||
        value.contains('realty');
  }

  /// Номера каталогов недвижимости.
  static Future<Set<int>> ids({bool refresh = false}) {
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _lifetime;

    if (!refresh && _ids != null && fresh) {
      return Future.value(_ids);
    }

    return _loading ??= _load();
  }

  /// Каталог недвижимости или нет. Ошибка запроса означает «нет»: тогда форма
  /// ведёт себя как раньше и подставляет адрес компании целиком.
  static Future<bool> contains(int catalogId) async {
    final ids = await RealEstateCatalogs.ids();

    return ids.contains(catalogId);
  }

  /// Уже известный ответ, без запроса. Нужен там, где ждать нельзя.
  static bool? knows(int catalogId) => _ids?.contains(catalogId);

  static Future<Set<int>> _load() async {
    try {
      final response = await ApiService.getCatalogs();

      _ids = response.data
          .where((catalog) =>
              looksLikeRealEstate(catalog.name) ||
              looksLikeRealEstate(catalog.slug))
          .map((catalog) => catalog.id)
          .toSet();

      _loadedAt = DateTime.now();

      return _ids!;
    } catch (e) {
      log.d('Не удалось узнать каталоги недвижимости: $e');

      // Пустой ответ не запоминаем как правду: следующий заход попробует снова.
      return _ids ?? <int>{};
    } finally {
      _loading = null;
    }
  }
}
