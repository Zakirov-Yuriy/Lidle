// ============================================================
// Какие каталоги — товарные.
// ============================================================
//
// Один и тот же каталог живёт сразу в двух списках, и в объявлениях, и в
// товарах (решение заказчика от 09.09.2026), поэтому отличить товарный по
// названию или типу нельзя. Список знает только сервер:
// `GET /v1/products/catalogs` отдаёт дерево товарных каталогов.
//
// Зачем отдельная служба, а не запрос в экране. Признак нужен в момент, когда
// человек выбрал конечный раздел, и не годится «загрузим и потом посмотрим»:
// 09.09.2026 экран выбора каталогов грузил список параллельно, человек
// нажимал раньше, чем список приезжал, и открывалась форма объявления вместо
// формы товара. Здесь список запрашивается один раз и ждётся там, где он
// действительно нужен.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/products_service.dart';

class ProductCatalogs {
  /// Насколько доверяем запомненному списку.
  ///
  /// Каталоги переводят руками и редко, но в день перевода админ ждёт, что
  /// приложение подхватит это без переустановки. Пять минут — компромисс.
  static const Duration _lifetime = Duration(minutes: 5);

  static Set<int>? _ids;
  static DateTime? _loadedAt;
  static Future<Set<int>>? _loading;

  /// Номера товарных каталогов.
  ///
  /// Повторные вызовы, пока запрос в пути, ждут ОДИН запрос, а не заводят
  /// свой: иначе на экране категорий их улетало бы по одному на нажатие.
  static Future<Set<int>> ids({bool refresh = false}) {
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _lifetime;

    if (!refresh && _ids != null && fresh) {
      return Future.value(_ids);
    }

    return _loading ??= _load();
  }

  /// Товарный ли каталог. Ошибка запроса означает «нет»: тогда человек
  /// попадёт в привычную форму объявления, а не в пустой экран.
  static Future<bool> contains(int catalogId) async {
    final ids = await ProductCatalogs.ids();

    return ids.contains(catalogId);
  }

  /// Уже известный ответ, без запроса. Нужен там, где ждать нельзя.
  static bool? knows(int catalogId) => _ids?.contains(catalogId);

  static Future<Set<int>> _load() async {
    try {
      final catalogs = await ProductsService.catalogs();

      _ids = catalogs.map((catalog) => catalog.id).toSet();
      _loadedAt = DateTime.now();

      return _ids!;
    } catch (e) {
      log.d('Не удалось узнать товарные каталоги: $e');

      // Пустой ответ не запоминаем как правду: следующий заход попробует
      // снова. Иначе одна неудачная минута увела бы все товары в объявления
      // до перезапуска приложения.
      return _ids ?? <int>{};
    } finally {
      _loading = null;
    }
  }
}
