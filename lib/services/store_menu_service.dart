// ============================================================
// "Пункт «Мой магазин» в нижнем меню"
// ============================================================
//
// Продавцу нужен короткий путь на свою витрину: сейчас он лежит через кабинет
// и карточку «Ваш магазин», то есть два нажатия и прокрутка (17.09.2026).
// Пункт показывается не всем: у человека без единого объявления и товара
// витрина пустая, и вести туда не за чем.
//
// Признак магазина спрашиваем у сервера один раз на вход в приложение и
// держим в памяти: нижнее меню рисуется почти на каждом экране, и запрос на
// каждую отрисовку был бы десятками обращений в минуту. Ответ ещё и
// запоминается локально, поэтому при следующем запуске пункт появляется
// сразу, не дожидаясь сети.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';

class StoreMenuService {
  StoreMenuService._();

  /// Показывать ли пункт магазина. Меню слушает это значение.
  static final ValueNotifier<bool> hasStore = ValueNotifier<bool>(false);

  /// Для какого пользователя уже спрашивали. Сменился человек — спросим заново.
  static String? _checkedFor;

  static bool _checking = false;

  /// Ключ локальной памяти: id владельца магазина, а не просто «да».
  /// Иначе после смены учётной записи чужой ответ показал бы пункт тому, у
  /// кого магазина нет.
  static const String _cacheKey = 'storeMenuOwnerId';

  static String get _currentUserId =>
      (UserService.getLocal('userId')?.toString() ?? '')
          .replaceFirst('ID: ', '')
          .trim();

  /// Поднять сохранённый ответ. Зовётся при первой отрисовке меню.
  static void restore() {
    final saved = (UserService.getLocal(_cacheKey)?.toString() ?? '').trim();
    final me = _currentUserId;

    if (me.isNotEmpty && saved == me) {
      _set(true);
    }
  }

  /// Спросить сервер, есть ли магазину что показывать.
  ///
  /// Считаем и объявления, и товары: витрина состоит из двух разных разделов,
  /// и продавец только с товарами тоже продавец.
  static Future<void> ensureChecked({bool force = false}) async {
    final token = TokenService.currentToken;
    final me = _currentUserId;

    if (token == null || token.isEmpty || me.isEmpty) {
      // Гость: пункта нет и спрашивать нечего.
      reset();

      return;
    }

    if (_checking) return;
    if (!force && _checkedFor == me) return;

    _checking = true;

    try {
      var found = false;

      try {
        // Первая страница без отбора по статусу: нужен сам факт, а не число, и
        // объявление на модерации тоже означает, что магазин у человека есть.
        final adverts = await MyAdvertsService.getMyAdverts(
          token: token,
          page: 1,
          limit: 1,
        );

        found = adverts.data.isNotEmpty || (adverts.total ?? 0) > 0;
      } catch (e) {
        log.d('Магазин: объявления не спросились: $e');
      }

      if (!found) {
        final products = await ApiService.getSellerProducts(
          userId: me,
          token: token,
          perPage: 1,
        );

        found = products.isNotEmpty;
      }

      _checkedFor = me;
      _set(found);

      // Запоминаем только положительный ответ: пустой магазин наполняется
      // часто, и держать «магазина нет» между запусками смысла нет.
      if (found) {
        await UserService.saveLocal(_cacheKey, me);
      }
    } finally {
      _checking = false;
    }
  }

  /// Сменить значение безопасно для отрисовки.
  ///
  /// Меню спрашивает признак прямо во время построения экрана, а менять
  /// слушаемое значение в этот момент нельзя: Flutter ругается на изменение
  /// состояния посреди кадра. Поэтому в такой момент переносим изменение на
  /// конец кадра.
  static void _set(bool value) {
    if (hasStore.value == value) return;

    final binding = SchedulerBinding.instance;

    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => hasStore.value = value);

      return;
    }

    hasStore.value = value;
  }

  /// Выход из учётной записи или смена пользователя.
  static void reset() {
    _checkedFor = null;
    _set(false);
  }

  /// Магазин наполнился прямо сейчас (опубликовали объявление или товар).
  /// Пункт должен появиться, не дожидаясь перезапуска.
  static void markHasStore() {
    _set(true);

    final me = _currentUserId;

    if (me.isNotEmpty) {
      _checkedFor = me;
      UserService.saveLocal(_cacheKey, me);
    }
  }
}
