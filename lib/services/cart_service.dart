import 'package:flutter/foundation.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/product_favorites_service.dart';

/// Корзина покупателя.
///
/// Работает и без входа в аккаунт: покупка без регистрации предусмотрена
/// вёрсткой и подтверждена заказчиком. Гость опознаётся токеном, который
/// сервер выдаёт при первом обращении, а мы храним его на устройстве и шлём
/// заголовком `X-Cart-Token` (см. `ApiService.cartToken`).
///
/// Когда гость входит в аккаунт, сервер сам переносит гостевую корзину на него
/// и складывает с той, что была. Для этого токен надо продолжать слать и после
/// входа, хотя бы один раз, иначе переносить будет нечего.
class CartService {
  static const String _tokenKey = 'cart_token';

  /// Что сейчас в корзине: номер товара → количество (14.09.2026).
  ///
  /// Нужно карточкам товара на главной и в разделах: у добавленного товара
  /// на кнопке корзины стоит счётчик, как на знакомых маркетплейсах. Раньше
  /// карточка о корзине ничего не знала, и человек, вернувшись к ленте, не
  /// помнил, что уже положил.
  ///
  /// `ValueNotifier`, а не запрос из карточки: карточек на экране десятки, и
  /// спрашивать корзину у каждой значит выстрелить десятком запросов на
  /// прокрутку. Корзина и так приходит целиком на любое действие — здесь мы
  /// просто запоминаем её состав.
  static final ValueNotifier<Map<int, int>> quantities =
      ValueNotifier<Map<int, int>>(const {});

  /// Сколько всего позиций в корзине. Для значка на нижнем меню.
  static final ValueNotifier<int> itemsCount = ValueNotifier<int>(0);

  /// Папки корзины (18.09.2026).
  ///
  /// Держим здесь по той же причине, что и состав: диалог выбора папки
  /// открывается с карточки товара, и спрашивать корзину ради одного списка
  /// значит заставить человека ждать сеть, чтобы увидеть две строки. Список
  /// обновляется на КАЖДЫЙ ответ корзины, а она приходит целиком на любое
  /// действие.
  static final ValueNotifier<List<CartFolderInfo>> folders =
      ValueNotifier<List<CartFolderInfo>>(const []);

  /// Есть ли из чего выбирать, кроме основной папки.
  ///
  /// Диалог выбора показываем только тогда (решение заказчика 18.09.2026):
  /// окно с единственным пунктом это лишнее нажатие на пустом месте.
  static bool get hasFolders => folders.value.length > 1;

  /// Сколько штук этого товара лежит в корзине. Ноль — не лежит.
  static int quantityOf(int productId) => quantities.value[productId] ?? 0;

  /// Перечитать корзину молча, ничего не показывая человеку.
  ///
  /// Зовётся при запуске приложения: без этого счётчики на карточках были бы
  /// пустыми до первого действия с корзиной, хотя товары в ней лежат.
  static Future<void> sync() async {
    await show();
  }

  /// Запомнить состав корзины из ответа сервера.
  static void _remember(CartSnapshot cart) {
    final map = <int, int>{};

    for (final shop in cart.shops) {
      for (final line in shop.items) {
        map[line.productId] = line.quantity;

        // Заодно запоминаем сердечко (15.09.2026): корзина может быть первым
        // экраном, который человек открыл после запуска, и без этого сердечки
        // в ней были бы пустыми при полном избранном.
        //
        // Запоминаем ТОЛЬКО зажжённые. Старый сервер признака не присылает
        // вовсе, и «не в избранном» от него погасило бы сердечки, приехавшие
        // с витрины.
        if (line.isWishlisted) {
          ProductFavoritesService.remember(line.modelId, true, line.wishlistId);
        }
      }
    }

    quantities.value = map;
    itemsCount.value = cart.itemsCount;

    // Папки запоминаем только когда сервер их прислал: старый сервер поля не
    // знает, и пустой список от него стёр бы папки, приехавшие минуту назад.
    if (cart.folders.isNotEmpty) folders.value = cart.folders;
  }

  /// Ответ на любое действие с корзиной: она всегда приходит целиком.
  ///
  /// Так задумано на сервере: клиенту не нужно склеивать своё состояние с
  /// ответом и гадать, что изменилось.
  static Future<CartResult> show() => _call(() => ApiService.get('/cart'));

  static Future<CartResult> add(
    int productId, {
    int quantity = 1,
    int? folderId,
  }) =>
      _call(
        () => ApiService.post('/cart/items', {
          'product_id': productId,
          'quantity': quantity,

          // Папку шлём, только когда человек её выбрал: пустое значение
          // означает основную, и присылать его незачем.
          if (folderId != null) 'folder_id': folderId,
        }),
      );

  /// Установить количество. Ноль удаляет позицию: отдельная кнопка удаления и
  /// минус до нуля должны делать одно и то же, иначе человек нажимает минус и
  /// упирается в единицу.
  static Future<CartResult> setQuantity(int productId, int quantity) => _call(
        () => ApiService.put('/cart/items/$productId', {'quantity': quantity}),
      );

  static Future<CartResult> remove(int productId) =>
      _call(() => ApiService.delete('/cart/items/$productId'));

  static Future<CartResult> clear() => _call(() => ApiService.delete('/cart'));

  // ── Папки (18.09.2026) ──────────────────────────────────────────────

  /// Убрать отмеченные позиции одним запросом.
  ///
  /// Не десять вызовов `remove` подряд: десять запросов из приложения это
  /// десять шансов оборваться на середине и оставить полуудалённую корзину.
  static Future<CartResult> removeMany(Set<int> productIds) => _call(
        () => ApiService.delete(
          '/cart/items',
          body: {'product_ids': productIds.toList()},
        ),
      );

  /// Переложить позиции в папку. `folderId: null` — в основную.
  static Future<CartResult> moveToFolder(
    Set<int> productIds, {
    required int? folderId,
  }) =>
      _call(
        () => ApiService.post('/cart/items/move', {
          'product_ids': productIds.toList(),
          'folder_id': folderId,
        }),
      );

  static Future<CartResult> createFolder(String name) =>
      _call(() => ApiService.post('/cart/folders', {'name': name}));

  static Future<CartResult> renameFolder(int folderId, String name) =>
      _call(() => ApiService.put('/cart/folders/$folderId', {'name': name}));

  /// Убрать папку. Товары из неё сервер вернёт в основную, а не удалит.
  static Future<CartResult> deleteFolder(int folderId) =>
      _call(() => ApiService.delete('/cart/folders/$folderId'));

  /// Достать токен гостевой корзины из хранилища при старте приложения.
  ///
  /// Без этого человек, закрывший приложение, находил бы пустую корзину:
  /// сервер опознаёт её только по токену.
  static Future<void> restoreToken() async {
    try {
      final saved = HiveService.getSetting(_tokenKey);

      if (saved is String && saved.isNotEmpty) {
        ApiService.cartToken = saved;
      }
    } catch (e) {
      log.d('Не удалось прочитать токен корзины: $e');
    }
  }

  static Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty) return;
    if (ApiService.cartToken == token) return;

    ApiService.cartToken = token;

    try {
      await HiveService.saveSetting(_tokenKey, token);
    } catch (e) {
      log.d('Не удалось сохранить токен корзины: $e');
    }
  }

  static Future<CartResult> _call(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final response = await request();

      if (response['success'] != true) {
        return CartResult.failure(
          '${response['message'] ?? 'Не получилось обновить корзину'}',
        );
      }

      final data = response['data'];

      if (data is! Map<String, dynamic>) {
        _remember(CartSnapshot.empty());

        return CartResult.success(CartSnapshot.empty());
      }

      final cart = CartSnapshot.fromJson(data);

      // Состав запоминаем на КАЖДЫЙ ответ, а не только на добавление:
      // корзина приходит целиком, и удаление с изменением количества должны
      // гасить счётчики так же, как добавление их зажигает.
      _remember(cart);

      await _saveToken(cart.cartToken);

      return CartResult.success(cart, message: response['message']?.toString());
    } catch (e) {
      log.d('Ошибка корзины: $e');

      return CartResult.failure('Не получилось связаться с сервером');
    }
  }
}

/// Итог действия с корзиной.
///
/// Отдельный тип, а не исключение: отказ сервера здесь обычный ход событий,
/// о котором надо рассказать человеку, а не сбой.
class CartResult {
  final bool isOk;
  final CartSnapshot? cart;
  final String? message;
  final String? error;

  const CartResult._({required this.isOk, this.cart, this.message, this.error});

  factory CartResult.success(CartSnapshot cart, {String? message}) =>
      CartResult._(isOk: true, cart: cart, message: message);

  factory CartResult.failure(String error) =>
      CartResult._(isOk: false, error: error);
}
