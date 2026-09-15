import 'package:flutter/foundation.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/api_service.dart';

/// Избранные ТОВАРЫ (15.09.2026).
///
/// Отдельно от избранного объявлений, и это не дублирование. На сервере
/// хранилище одно — `user_wishlists` с типом сущности, — а вот на клиенте
/// избранное объявлений держит номера объявлений в `Hive` и в своём блоке.
/// Номера товаров и объявлений совпадают сплошь и рядом: товар 20 и
/// объявление 20 существуют оба. Сложить их в одну кучу значит получить
/// сердечко, которое загорается не на той карточке.
///
/// Устроено как корзина: общее состояние в `ValueNotifier`, а не своё поле в
/// каждой карточке. Один и тот же товар виден и в ленте главной, и в разделе;
/// собственная память карточки разошлась бы с правдой при первом же
/// возвращении назад.
///
/// Здесь НЕТ загрузки списка избранного целиком: признак `is_wishlisted` и
/// номер записи приходят вместе с каждой карточкой, и мы просто запоминаем
/// то, что уже приехало.
class ProductFavoritesService {
  /// Номер товара → номер записи избранного.
  ///
  /// Номер записи нужен, чтобы снять сердечко одним запросом, не перебирая
  /// весь список избранного ради одного числа. Пусто в значении означает
  /// «в избранном, но номер записи неизвестен» — такое бывает у старого
  /// сервера, и тогда снятие идёт через повторную загрузку карточки.
  static final ValueNotifier<Map<int, int?>> items =
      ValueNotifier<Map<int, int?>>(const {});

  static bool isFavorite(int productId) => items.value.containsKey(productId);

  static int? wishlistIdOf(int productId) => items.value[productId];

  /// Запомнить то, что приехало вместе с карточкой товара.
  ///
  /// Зовётся при разборе ответа сервера. Своё состояние при этом не
  /// затирается целиком: карточки приходят страницами, и полная замена
  /// стёрла бы сердечки товаров с предыдущих страниц.
  static void remember(int productId, bool isWishlisted, int? wishlistId) {
    final map = Map<int, int?>.from(items.value);

    if (isWishlisted) {
      map[productId] = wishlistId ?? map[productId];
    } else {
      map.remove(productId);
    }

    items.value = map;
  }

  /// Вошёл ли человек. Избранное принадлежит аккаунту: у гостя его нет.
  static bool get isGuest {
    final token = HiveService.getUserData('token');

    return token == null || '$token'.isEmpty;
  }

  /// Переключить сердечко.
  ///
  /// Возвращает `null`, если всё получилось, иначе текст для человека.
  /// Состояние меняем СРАЗУ, до ответа сервера, и откатываем при отказе:
  /// сердечко должно загораться под пальцем, а не через полсекунды.
  static Future<String?> toggle(int productId) async {
    if (isGuest) {
      return 'Войдите, чтобы сохранять товары в избранное';
    }

    final wasFavorite = isFavorite(productId);
    final wishlistId = wishlistIdOf(productId);

    remember(productId, !wasFavorite, wishlistId);

    try {
      if (wasFavorite) {
        if (wishlistId == null) {
          // Номера записи нет: снять нечего, вернём состояние и попросим
          // открыть товар — оттуда номер приедет.
          remember(productId, true, null);

          return 'Не получилось убрать из избранного. Откройте товар и попробуйте ещё раз.';
        }

        final response = await ApiService.delete('/me/wishlist/destroy/$wishlistId');

        if (response['success'] != true) {
          remember(productId, true, wishlistId);

          return '${response['message'] ?? 'Не получилось убрать из избранного'}';
        }

        return null;
      }

      final response = await ApiService.post('/me/wishlist/add', {
        'product_id': productId,
      });

      if (response['success'] != true) {
        remember(productId, false, null);

        return '${response['message'] ?? 'Не получилось добавить в избранное'}';
      }

      // Номер записи приходит прямо в ответе: он нужен, чтобы следующее
      // нажатие сняло сердечко без похода за списком.
      final created = response['wishlist_id'];

      remember(
        productId,
        true,
        created is int ? created : int.tryParse('${created ?? ''}'),
      );

      return null;
    } catch (e) {
      log.d('Избранное товара $productId не сохранилось: $e');

      remember(productId, wasFavorite, wishlistId);

      return 'Не получилось изменить избранное. Проверьте связь.';
    }
  }
}
