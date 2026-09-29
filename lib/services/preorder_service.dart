import 'package:flutter/foundation.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/bookings/preorder.dart';
import 'package:lidle/services/api_service.dart';

/// Предзаказ к брони (29.09.2026).
///
/// Витрина публичная, корзина только после входа. Корзина живёт на сервере, а
/// не в телефоне: человек набрал блюда, вышел из приложения и вернулся — всё
/// на месте.
///
/// Сервер после любого действия возвращает корзину целиком, поэтому здесь нет
/// перечитывания: что пришло, то и показываем.
class PreorderService {
  /// Последняя известная корзина. Экраны слушают её, чтобы счётчик в шапке и
  /// кнопки «Заказать» менялись все разом, без передачи состояния по цепочке.
  static final ValueNotifier<PreorderCart> cart =
      ValueNotifier<PreorderCart>(const PreorderCart());

  /// Чья это корзина: у другого заведения свой набор.
  static int? _advertId;

  /// Витрина заведения: меню, товары, услуги, доставка.
  static Future<List<PreorderBlock>> catalog(int advertId) async {
    try {
      final response = await ApiService.get('/adverts/$advertId/preorder');
      final blocks = response['data']?['blocks'];

      if (blocks is! List) return const [];

      final out = <PreorderBlock>[];

      for (final row in blocks) {
        final block = PreorderBlock.tryParse(row);

        if (block != null) out.add(block);
      }

      return out;
    } catch (e) {
      log.d('Витрина предзаказа недоступна для объявления $advertId: $e');

      return const [];
    }
  }

  /// Корзина этого заведения. Зал и стол нужны только для депозита в счёте.
  static Future<PreorderCart> load(
    int advertId, {
    int? hallId,
    String? tableKey,
  }) async {
    try {
      final response = await ApiService.get(
        '/adverts/$advertId/preorder/cart${_query(hallId, tableKey)}',
      );

      return _remember(advertId, response);
    } catch (e) {
      log.d('Корзина предзаказа недоступна: $e');

      return cart.value;
    }
  }

  /// Добавить позицию или прибавить к уже добавленной.
  static Future<String?> add(
    int advertId, {
    required int blockItemId,
    required String itemKey,
    int quantity = 1,
    int? hallId,
    String? tableKey,
  }) async {
    return _act(advertId, () => ApiService.post(
          '/adverts/$advertId/preorder/cart/items${_query(hallId, tableKey)}',
          {
            'block_item_id': blockItemId,
            'item_key': itemKey,
            'quantity': quantity,
          },
        ));
  }

  /// Задать количество. Ноль убирает позицию.
  static Future<String?> setQuantity(
    int advertId, {
    required int lineId,
    required int quantity,
    int? hallId,
    String? tableKey,
  }) async {
    return _act(advertId, () => ApiService.put(
          '/adverts/$advertId/preorder/cart/items/$lineId${_query(hallId, tableKey)}',
          {'quantity': quantity},
        ));
  }

  /// Убрать отмеченные позиции.
  static Future<String?> remove(
    int advertId, {
    required List<int> ids,
    int? hallId,
    String? tableKey,
  }) async {
    return _act(advertId, () => ApiService.delete(
          '/adverts/$advertId/preorder/cart/items${_query(hallId, tableKey)}',
          body: {'ids': ids},
        ));
  }

  /// Очистить корзину заведения.
  static Future<String?> clear(int advertId) async {
    return _act(advertId, () => ApiService.delete('/adverts/$advertId/preorder/cart'));
  }

  /// Забыть корзину в памяти: бронь создана, набранное уехало в неё.
  static void forget() {
    _advertId = null;
    cart.value = const PreorderCart();
  }

  /// Сколько штук этой позиции уже лежит в корзине.
  static int quantityOf(int blockItemId, String itemKey) =>
      cart.value.quantityOf(blockItemId, itemKey);

  /// Общее действие: выполнить запрос, запомнить корзину, вернуть ошибку.
  ///
  /// Возвращает текст ошибки или null, если всё получилось: экранам нужно
  /// показать сообщение сервера («этой позиции больше нет»), а не своё.
  static Future<String?> _act(
    int advertId,
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final response = await request();

      if (response['success'] == false) {
        return '${response['message'] ?? 'Не получилось'}';
      }

      _remember(advertId, response);

      return null;
    } catch (e) {
      log.d('Действие с корзиной предзаказа не прошло: $e');

      return 'Не получилось. Проверьте связь и попробуйте ещё раз.';
    }
  }

  static PreorderCart _remember(int advertId, Map<String, dynamic> response) {
    final parsed = PreorderCart.fromJson(response['data']);

    _advertId = advertId;
    cart.value = parsed;

    return parsed;
  }

  /// Чужая корзина в памяти: человек перешёл в другое заведение.
  static bool isForeign(int advertId) => _advertId != null && _advertId != advertId;

  static String _query(int? hallId, String? tableKey) {
    final parts = <String>[
      if (hallId != null) 'hall_id=$hallId',
      if (tableKey != null && tableKey.isNotEmpty) 'table_key=$tableKey',
    ];

    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }
}
