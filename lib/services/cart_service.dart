import 'package:lidle/core/logger.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/services/api_service.dart';

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

  /// Ответ на любое действие с корзиной: она всегда приходит целиком.
  ///
  /// Так задумано на сервере: клиенту не нужно склеивать своё состояние с
  /// ответом и гадать, что изменилось.
  static Future<CartResult> show() => _call(() => ApiService.get('/cart'));

  static Future<CartResult> add(int productId, {int quantity = 1}) => _call(
        () => ApiService.post('/cart/items', {
          'product_id': productId,
          'quantity': quantity,
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
        return CartResult.success(CartSnapshot.empty());
      }

      final cart = CartSnapshot.fromJson(data);

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
