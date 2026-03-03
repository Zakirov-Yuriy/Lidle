// ============================================================
// "Сервис: Управление избранными объявлениями"
// ============================================================
//
// Тонкий фасад над HiveService для работы с избранным.
// Используется напрямую из UI-слоя (экраны деталей),
// так как избранное — это чисто локальная реактивная операция
// без асинхронности и бизнес-логики.

import 'package:lidle/hive_service.dart';

/// Сервис для управления избранными объявлениями.
///
/// Изолирует UI от прямой зависимости от [HiveService].
class FavoritesService {
  FavoritesService._();

  /// Возвращает true, если объявление с [listingId] в избранном.
  static bool isFavorite(String listingId) => HiveService.isFavorite(listingId);

  /// Переключает состояние избранного для [listingId].
  /// Возвращает новое состояние: true если добавлено, false если удалено.
  static bool toggleFavorite(String listingId) =>
      HiveService.toggleFavorite(listingId);

  /// Возвращает список всех избранных идентификаторов объявлений.
  static List<String> getFavorites() => HiveService.getFavorites();
}
