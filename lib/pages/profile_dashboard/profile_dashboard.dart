import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/pages/profile_menu/profile_menu_screen.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';
import 'package:lidle/pages/full_category_screen/seller_qr_screen.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/components/profile_image.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
// Экран покупок пока не открывается с дашборда (карточка «Покупки» скрыта),
// импорт оставлен закомментированным вместе с ней.
// ignore: unused_import
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/support/support_screen.dart';
import 'package:lidle/pages/profile_dashboard/responses/responses_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/reviews/reviews_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/pages/bookings/my_bookings_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/pages/profile_dashboard/financial_support_dialog.dart';
import 'package:lidle/pages/orders/seller_orders_screen.dart';
import 'package:lidle/pages/products/my_orders_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/services/store_menu_service.dart';
import 'package:lidle/pages/products/your_order_screen.dart';
import 'package:lidle/models/orders/order_item.dart';

// ============================================================
// "Вспомогательная функция для правильного склонения слова"
// ============================================================
/// Склонение слова «отзыв»: 1 отзыв, 2 отзыва, 5 отзывов.
String _getReviewsPluralForm(int count) {
  if (count % 10 == 1 && count % 100 != 11) {
    return 'отзыв';
  } else if ((count % 10 >= 2 && count % 10 <= 4) &&
      (count % 100 < 10 || count % 100 >= 20)) {
    return 'отзыва';
  } else {
    return 'отзывов';
  }
}

String _getPluralForm(int count) {
  if (count % 10 == 1 && count % 100 != 11) {
    return 'товар';
  } else if ((count % 10 >= 2 && count % 10 <= 4) &&
      (count % 100 < 10 || count % 100 >= 20)) {
    return 'товара';
  } else {
    return 'товаров';
  }
}

/// Картинка штрих-кода в полоске покупок.
///
/// Берём PNG, а не SVG (17.09.2026). Файл из макета это обёртка: внутри него
/// растровая картинка, вставленная шаблоном заливки, и такие SVG наша
/// библиотека не рисует вовсе, отсюда и пустое место на экране. Картинку из
/// него вынули и положили рядом обычным PNG.
///
/// Если и PNG не читается, рисуем полоски сами: пустота на видном блоке
/// выглядит как поломка, а человеку здесь важна подсказка «покажите это
/// продавцу», а не конкретный файл.
///
/// Рисунок декоративный и не сканируется. Настоящий код получения человек
/// видит на экране своего заказа и называет его продавцу.
class _BarcodeThumb extends StatelessWidget {
  const _BarcodeThumb();

  static const String _asset = 'assets/shtrihcod/barcode.png';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _exists(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const _BarcodePainted();

        // Белая подложка: полоски на картинке чёрные, и без неё на тёмном
        // фоне они сливались бы с полоской.
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Image.asset(
            _asset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const _BarcodePainted(),
          ),
        );
      },
    );
  }

  static Future<bool> _exists() async {
    try {
      await rootBundle.load(_asset);

      return true;
    } catch (e) {
      log.d('Штрих-код из ассетов не прочитался: $e');

      return false;
    }
  }
}

/// Нарисованные полоски: запасной вариант картинки.
class _BarcodePainted extends StatelessWidget {
  const _BarcodePainted();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BarcodePainter(), size: Size.infinite);
  }
}

class _BarcodePainter extends CustomPainter {
  /// Ширины полос: набор постоянный, чтобы картинка не мелькала при каждой
  /// перерисовке.
  static const List<double> _bars = [
    3, 1, 2, 1, 1, 3, 1, 2, 2, 1, 1, 1, 3, 1, 2, 1, 1, 2, 1, 3, 1, 1, 2, 1,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final total = _bars.fold<double>(0, (sum, width) => sum + width);
    final unit = size.width / (total * 2);

    var x = 0.0;

    for (var i = 0; i < _bars.length; i++) {
      final width = _bars[i] * unit * 2;

      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      }

      x += width;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Одна карточка карусели: товар внутри заказа.
///
/// Держим пару целиком: код получения и способ доставки лежат у заказа, а
/// название с картинкой у позиции, и разносить их по разным спискам значит
/// потом сводить их обратно по номерам.
class _PurchaseEntry {
  final OrderModel order;
  final OrderLine line;

  const _PurchaseEntry({required this.order, required this.line});
}

class ProfileDashboard extends StatefulWidget {
  static const routeName = '/profile-dashboard';

  const ProfileDashboard({super.key});

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard>
    with WidgetsBindingObserver {
  int _activeListingsCount = 0;
  // ignore: unused_field
  int _inactiveListingsCount = 0;
  int _priceOffersCount = 0;

  /// Новые заказы на товары: те, по которым продавец ещё не решил, принять
  /// или отклонить (16.09.2026).
  int _newOrdersCount = 0;

  /// Счётчики броней в меню. Живые предстоящие: отменённая вчера бронь в
  /// меню не нужна, она там только пугает числом.
  BookingCounts _bookingCounts = const BookingCounts.empty();

  /// Покупки, которые ещё нужно забрать (17.09.2026).
  ///
  /// Карточка на КАЖДЫЙ товар, а не на заказ: так просил заказчик, и человеку
  /// действительно ближе «моя куртка готова», чем «заказ 260917-104 готов».
  /// Код получения при этом один на заказ, и на экране заказа он один и тот же
  /// для всех его товаров.
  List<_PurchaseEntry> _activePurchases = const [];
  bool _purchasesLoading = false;

  /// Сколько отзывов оставили на объявления пользователя — подпись на
  /// быстрой карточке «Отзывы». Берём meta.total из /me/received-reviews.
  int _reviewsCount = 0;
  bool _isLoadingListings = true;
  // ignore: unused_field
  bool _isLoadingPriceOffers = false;

  /// Актуальное название компании (магазина) из GET /companies/{myId}.
  /// Тянем с сервера, чтобы в карточке «Ваш магазин» показывать правильное имя,
  /// а не устаревший локальный кеш.
  String? _companyName;

  /// Фотография компании из того же `GET /companies/{myId}`.
  ///
  /// В карточке «Ваш магазин» стоит именно она, а не аватарка владельца:
  /// покупатель узнаёт магазин, а не человека, и эта же картинка видна ему на
  /// витрине. Пусто — показываем значок по умолчанию.
  String? _companyImage;

  // ignore: unused_field
  static const String _cacheKeyListings = CacheKeys.profileListingsCounts;
  // ignore: unused_field
  static const String _cacheKeyPriceOffers = CacheKeys.profilePriceOffersCount;

  /// TTL кэша счётчиков — 60 секунд.
  static const Duration _cacheTtl = Duration(seconds: 60);

  /// Инвалидировать кэш счётчиков объявлений (например, после удаления объявления).
  // ignore: unused_element
  static void invalidateListingsCache() =>
      AppCacheService().invalidate(CacheKeys.profileListingsCounts);

  /// Инвалидировать кэш предложений цен.
  // ignore: unused_element
  static void invalidatePriceOffersCache() =>
      AppCacheService().invalidate(CacheKeys.profilePriceOffersCount);

  @override
  void initState() {
    super.initState();
    // Добавляем observer для отслеживания жизненного цикла приложения
    WidgetsBinding.instance.addObserver(this);
    // 🔄 Ленивая загрузка профиля при входе на страницу профиля
    context.read<ProfileBloc>().add(LoadProfileEvent());
    // ⚡ Загружаем объявления: сначала из кэша (если свежий), потом в фоне обновляем
    _loadListingsCounts(useCache: true);
    // 💰 Загружаем количество предложений цен
    _loadPriceOffersCount(useCache: true);
    // ⭐ Количество отзывов на объявления пользователя
    _loadReviewsCount();
    // 📅 Счётчики броней
    _loadBookingCounts();
    // 🧾 Новые заказы на товары
    _loadOrdersCount();
    // 🛍 Покупки, которые ждут получения
    _loadActivePurchases();
    // 🏪 Подтягиваем актуальное название компании (магазина) с сервера
    _loadCompanyName();
  }

  /// Подтягивает актуальное название компании (GET /companies/{myId} → data.name)
  /// и кладёт его в состояние и локальный кеш, чтобы карточка «Ваш магазин»
  /// показывала правильное имя (а не ник/устаревший кеш).
  Future<void> _loadCompanyName() async {
    try {
      final rawId = UserService.getLocal('userId')?.toString().trim() ?? '';
      final id = rawId.replaceFirst('ID: ', '').trim();
      if (id.isEmpty) return;
      final token = TokenService.currentToken;
      final resp = await ApiService.get('/companies/$id', token: token);
      final data = (resp['data'] is Map)
          ? Map<String, dynamic>.from(resp['data'] as Map)
          : <String, dynamic>{};
      // Фотография компании. Забираем тем же запросом, что и название: он уже
      // делается, и второй поход за одной картинкой ничего не даст.
      final imageRaw = data['image'];
      final image = (imageRaw is String && imageRaw.trim().isNotEmpty)
          ? imageRaw.trim()
          : '';

      if (image.isNotEmpty) {
        await UserService.saveLocal('companyImage', image);
      }

      final nameRaw = data['name'];
      final name = (nameRaw is String && nameRaw.trim().isNotEmpty)
          ? nameRaw.trim()
          : '';

      if (name.isNotEmpty) {
        await UserService.saveLocal('companyName', name);
      }

      if (!mounted) return;

      setState(() {
        if (name.isNotEmpty) _companyName = name;
        if (image.isNotEmpty) _companyImage = image;
      });
    } catch (e) {
      log.d('Не удалось загрузить название компании: $e');
    }
  }

  @override
  void dispose() {
    // Удаляем observer при удалении виджета
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // При возвращении в приложение проверяем кэш — если данные свежие,
    // показываем их мгновенно, если нет — обновляем в фоне
    if (state == AppLifecycleState.resumed && mounted) {
      _loadListingsCounts(useCache: true);
      _loadPriceOffersCount(useCache: true);
      _loadBookingCounts();
      _loadOrdersCount();
    }
  }

  /// Покупки, которые ещё не получены.
  ///
  /// Берём заказы покупателя и оставляем те, по которым ещё надо прийти:
  /// новые, принятые и готовые к выдаче. Полученные и отменённые сюда не
  /// попадают, им место в истории, а не в напоминании.
  Future<void> _loadActivePurchases() async {
    final token = TokenService.currentToken;

    if (token == null || token.isEmpty) return;

    if (mounted) setState(() => _purchasesLoading = true);

    try {
      final orders = await OrdersService.myOrders(all: true);

      const waiting = {'new', 'accepted', 'ready'};

      final entries = <_PurchaseEntry>[];

      for (final order in orders) {
        if (!waiting.contains(order.status)) continue;

        for (final line in order.items) {
          // Отклонённую продавцом позицию забирать не нужно.
          if (line.status == 'rejected') continue;

          entries.add(_PurchaseEntry(order: order, line: line));
        }
      }

      if (!mounted) return;

      setState(() {
        _activePurchases = entries;
        _purchasesLoading = false;
      });
    } catch (e) {
      log.d('Покупки к получению не загрузились: $e');

      if (mounted) setState(() => _purchasesLoading = false);
    }
  }

  /// Полоска с напоминанием: штрих-код показывают продавцу.
  ///
  /// Код получения тут не пишем: он у каждого заказа свой, а покупок в карусели
  /// несколько, и одно число под общей подписью выглядело бы как код на всё
  /// сразу. Сам код человек видит на экране своего заказа.
  Widget _buildPurchasesBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Картинка лежит прямо на тёмном фоне полоски, без белой подложки:
          // штрих-код в макете нарисован белым, и на белой плашке его не было
          // видно вовсе (17.09.2026).
          const SizedBox(width: 64, height: 40, child: _BarcodeThumb()),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Покажите штрих-код продавцу для получения товара',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Карусель покупок: по карточке на каждый купленный товар.
  Widget _buildPurchasesCarousel() {
    if (_purchasesLoading && _activePurchases.isEmpty) {
      return const SizedBox(
        height: 82,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _activePurchases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => _buildPurchaseCard(_activePurchases[index]),
      ),
    );
  }

  Widget _buildPurchaseCard(_PurchaseEntry entry) {
    final order = entry.order;
    final line = entry.line;
    final hours = order.shop?.todayHours;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YourOrderScreen(order: order, line: line),
        ),
      ),
      // Картинка слева во всю высоту карточки, текст справа отдельной
      // колонкой: при мелкой картинке строка с часами работы не помещалась
      // рядом и вылезала под неё (правка заказчика 17.09.2026).
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Размер картинки задан макетом: 72 на 64, отступ слева 10,
            // сверху и снизу по 9.
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 9, bottom: 9),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 72,
                  height: 64,
                  child: (line.image ?? '').isEmpty
                      ? Container(
                          color: primaryBackground,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: textMuted,
                            size: 22,
                          ),
                        )
                      : Image.network(
                          line.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: primaryBackground,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      order.deliveryType == 'courier'
                          ? (order.deliveryTitle ?? 'Доставка')
                          : 'Самовывоз',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.statusTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: order.status == 'ready'
                            ? const Color(0xFF4CD964)
                            : const Color(0xFFFFB800),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Название товара из карточки убрано (17.09.2026): в
                    // макете его нет, а четвёртой строкой оно не помещалось по
                    // высоте. Что именно куплено, человек видит на экране
                    // заказа, куда карточка и ведёт.
                    if (hours != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hours,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Счётчики броней для меню.
  ///
  /// Без кэша: чисел здесь мало, запрос лёгкий, а устаревший счётчик заявок
  /// хуже отсутствующего — человек решит, что отвечать не на что.
  Future<void> _loadBookingCounts() async {
    if (TokenService.currentToken == null) return;

    final counts = await BookingsService.counts();

    if (!mounted) return;

    setState(() => _bookingCounts = counts);
  }

  /// Сколько новых заказов ждут решения.
  ///
  /// Без кэша, по той же причине, что и брони: число маленькое, запрос
  /// лёгкий, а устаревший счётчик хуже отсутствующего.
  Future<void> _loadOrdersCount() async {
    if (TokenService.currentToken == null) return;

    final counts = await OrdersService.counts();

    if (!mounted) return;

    setState(() => _newOrdersCount = counts.newOrders);
  }

  /// Показывает диалоговое окно финансовой поддержки
  // Диалог финансовой поддержки: блок скрыт с дашборда, метод оставлен
  // для быстрого возврата.
  // ignore: unused_element
  void _showFinancialSupportDialog() {
    FinancialSupportDialog.show(context);
  }

  /// Формирует ссылку на магазин (публичный профиль/витрину продавца).
  /// Prod: https://lidle.io/ru/users/{userId}
  /// Dev:  https://dev.lidle.io/ru/users/{userId}
  /// Ссылка на страницу компании продавца для QR/шаринга. Домен — по окружению
  /// (dev.lidle.io/lidle.io), путь /companies/{id}, как у бэкенда и как на
  /// экране продавца (seller_profile_screen).
  String _buildStoreUrl(String userId) {
    final cleanUserId = userId.replaceFirst('ID: ', '').trim();
    return '${AppConfig().documentDomain}/companies/$cleanUserId';
  }

  /// Загрузить количество объявлений.
  /// [useCache] = true: сначала показать из кэша (если свежий), потом обновить в фоне
  /// [useCache] = false: всегда загружать со свежими указанными данными
  Future<void> _loadListingsCounts({bool useCache = false}) async {
    try {
      // Проверяем AppCacheService (L1 RAM, TTL 60с)
      if (useCache) {
        final cached = AppCacheService().get<Map<String, dynamic>>(
          CacheKeys.profileListingsCounts,
        );
        if (cached != null) {
          if (mounted) {
            setState(() {
              _activeListingsCount = cached['activeCount'] as int? ?? 0;
              _inactiveListingsCount = cached['inactiveCount'] as int? ?? 0;
              _isLoadingListings = false;
            });
          }
          return;
        }
      }

      final token = TokenService.currentToken;
      if (token == null) {
        if (mounted) setState(() => _isLoadingListings = false);
        return;
      }

      if (mounted) setState(() => _isLoadingListings = true);

      // Статусы: 1=Active, 2=Inactive, 3=Moderation, 8=Archived
      final statuses = [1, 2, 3, 8];
      var allAdverts = <dynamic>[];

      for (final statusId in statuses) {
        var pageNum = 1;
        var hasMorePages = true;

        while (hasMorePages) {
          try {
            final response = await MyAdvertsService.getMyAdverts(
              token: token,
              page: pageNum,
              statusId: statusId,
            );

            allAdverts.addAll(response.data);

            final currentPage = response.page ?? 1;
            final lastPage = response.lastPage ?? 1;

            if (currentPage >= lastPage) {
              hasMorePages = false;
            } else {
              pageNum++;
            }
          } catch (e) {
            hasMorePages = false;
            break;
          }
        }
      }

      final totalCount = allAdverts.length;

      // Есть объявления — значит, есть и магазин: пункт в нижнем меню должен
      // появиться сразу после первой публикации, а не со следующего запуска.
      if (totalCount > 0) {
        StoreMenuService.markHasStore();
      }

      // 💾 Сохраняем в AppCacheService (TTL 60с)
      AppCacheService().set<Map<String, dynamic>>(
        CacheKeys.profileListingsCounts,
        {'activeCount': totalCount, 'inactiveCount': 0},
        ttl: _cacheTtl,
      );

      if (mounted) {
        setState(() {
          _activeListingsCount = totalCount;
          _inactiveListingsCount = 0;
          _isLoadingListings = false;
        });
      }
    } catch (e) {
      log.d('❌ Ошибка загрузки объявлений: $e');
      if (mounted) {
        setState(() {
          _isLoadingListings = false;
        });
      }
    }
  }

  /// Загрузить количество предложений цен (Предложения мне).
  /// [useCache] = true: сначала показать из кэша (если свежий), потом обновить в фоне
  /// [useCache] = false: всегда загружать со свежими указанными данными
  /// Количество отзывов на объявления пользователя (для подписи быстрой
  /// карточки «Отзывы»). Берём meta.total первой страницы — сами отзывы
  /// здесь не нужны, поэтому список не разбираем.
  Future<void> _loadReviewsCount() async {
    try {
      final response = await ApiService.getReceivedReviews(page: 1);
      final total = ReviewModel.totalFromResponse(response) ?? 0;
      if (!mounted) return;
      setState(() => _reviewsCount = total);
    } catch (e) {
      // Молча: подпись просто останется нулевой, экран это не ломает.
      log.d('Не удалось получить количество отзывов: $e');
    }
  }

  Future<void> _loadPriceOffersCount({bool useCache = false}) async {
    try {
      // Проверяем AppCacheService (L1 RAM, TTL 60с)
      if (useCache) {
        final cachedCount = AppCacheService().get<int>(
          CacheKeys.profilePriceOffersCount,
        );
        if (cachedCount != null) {
          if (mounted) {
            setState(() {
              _priceOffersCount = cachedCount;
              _isLoadingPriceOffers = false;
            });
          }
          return;
        }
      }

      final token = TokenService.currentToken;
      if (token == null) {
        if (mounted) setState(() => _isLoadingPriceOffers = false);
        return;
      }

      if (mounted) setState(() => _isLoadingPriceOffers = true);

      // Загружаем список объявлений с полученными предложениями цен ("Предложения мне")
      final listingsWithOffers = await ApiService.getOffersReceivedList(token: token);
      
      // Подсчитываем общее количество предложений:
      // Для каждого объявления берём new_offers_count
      var totalOffersCount = 0;
      for (final listing in listingsWithOffers) {
        final newOffersCount = listing['new_offers_count'] as int? ?? 0;
        totalOffersCount += newOffersCount;
      }

      // 💾 Сохраняем в AppCacheService (TTL 60с)
      AppCacheService().set<int>(
        CacheKeys.profilePriceOffersCount,
        totalOffersCount,
        ttl: _cacheTtl,
      );

      if (mounted) {
        setState(() {
          _priceOffersCount = totalOffersCount;
          _isLoadingPriceOffers = false;
        });
      }
    } catch (e) {
      log.d('❌ Ошибка загрузки количества предложений цен: $e');
      if (mounted) {
        setState(() {
          _isLoadingPriceOffers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.read<ProfileBloc>().add(LoadProfileEvent(forceRefresh: true));
              _loadListingsCounts(useCache: false);
              _loadPriceOffersCount(useCache: false);
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(onRetry: () {
              context.read<ConnectivityBloc>().add(const CheckConnectivityEvent());
            });
          }

          return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthLoggedOut) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            SignInScreen.routeName,
            (route) => route.settings.name == '/' || route.isFirst,
          );
        } else if (state is AuthAuthenticated) {
          // Новый пользователь вошёл — сбрасываем кэш и загружаем актуальные данные.
          // forceRefresh: true гарантирует, что старое состояние ProfileBloc
          // (от предыдущей сессии) заменится спиннером и затем свежими данными.
          context.read<ProfileBloc>().add(LoadProfileEvent(forceRefresh: true));
        }
      },
      child: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoggedOut) {
            Navigator.of(context).pushReplacementNamed('/');
          }
        },
        child: BlocListener<NavigationBloc, NavigationState>(
          listener: (context, state) {
            if (state is NavigationToProfile ||
                state is NavigationToHome ||
                state is NavigationToFavorites ||
                state is NavigationToMessages) {
              context.read<NavigationBloc>().executeNavigation(context);
            }
          },
          child: BlocBuilder<NavigationBloc, NavigationState>(
            builder: (context, navigationState) {
              return BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, profileState) {
                  // log.d();
                  if (profileState is ProfileLoaded) {
                    // log.d('✅ ProfileLoaded: ${profileState.name}');
                  }
                  return Scaffold(
                      extendBody: true,
                      backgroundColor: primaryBackground,
                      body: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                // Контент уходит под плавающее нижнее меню
                                // (extendBody: true). Нижний отступ = высота меню
                                // + системный inset + 10px, чтобы при полной
                                // прокрутке последний блок («Ваш магазин»)
                                // останавливался ровно в 10px над меню и не
                                // перекрывался им.
                                padding: EdgeInsets.only(
                                  left: 21,
                                  right: 21,
                                  top: 12,
                                  bottom: bottomNavHeight +
                                      MediaQuery.of(context).padding.bottom +
                                      10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // // ЛОГО
                                    // Padding(
                                    //   padding: const EdgeInsets.only(
                                    //     left: 41.0,
                                    //     top: 44.0,
                                    //     bottom: 35.0,
                                    //   ),
                                    //   child: Row(
                                    //     children: [
                                    //       SvgPicture.asset(logoAsset, height: logoHeight),
                                    //       const Spacer(),
                                    //     ],
                                    //   ),
                                    // ),

                                    // Хедер профиля (аватар + имя + ID)
                                    _ProfileHeader(
                                      name: profileState is ProfileLoaded
                                          ? profileState.name
                                          : 'Загрузка...',
                                      userId: profileState is ProfileLoaded
                                          ? profileState.userId
                                          : '...',
                                      profileImage: profileState is ProfileLoaded
                                          ? profileState.profileImage
                                          : null,
                                      username: profileState is ProfileLoaded
                                          ? profileState.username
                                          : 'Name',
                                    ),
                                    const SizedBox(height: 8),

                                    // 3 быстрых карточки
                                    Row(
                                      children: [
                                        ValueListenableBuilder(
                                          valueListenable: HiveService.settingsBox
                                              .listenable(keys: ['favorites']),
                                          builder: (context, box, child) {
                                            final favorites =
                                                HiveService.getFavorites();

                                            // ✅ Отладка: логируем количество избранных
                                            // log.d();
                                            // log.d('   Favorites IDs: $favorites');

                                            // Используем длину списка избранного напрямую
                                            // (это более надёжно чем подсчёт через ListingsBloc.staticListings)
                                            final favoritedCount =
                                                favorites.length;

                                            return _QuickCard(
                                              iconPath:
                                                  'assets/profile_dashboard/heart-rounded.svg',
                                              title: 'Избранные товары',
                                              subtitle:
                                                  '$favoritedCount ${_getPluralForm(favoritedCount)}',
                                              onTap: () => Navigator.of(
                                                context,
                                              ).pushNamed('/favorites'),
                                            );
                                          },
                                        ),
                                        // Карточка «Покупки» скрыта до появления
                                        // раздела покупок. Вернуть — раскомментировать.
                                        // SizedBox(width: 10),
                                        // _QuickCard(
                                        //   iconPath:
                                        //       'assets/profile_dashboard/shopping-cart-01.svg',
                                        //   title: 'Покупки',
                                        //   subtitle: '0 товаров',
                                        //   onTap: () =>
                                        //       Navigator.of(context).pushNamed(
                                        //         MyPurchasesScreen.routeName,
                                        //       ),
                                        // ),
                                        SizedBox(width: 10),
                                        _QuickCard(
                                          iconPath:
                                              'assets/profile_dashboard/eva_star-fill.svg',
                                          title: 'Отзывы о товарах',
                                          subtitle:
                                              '$_reviewsCount ${_getReviewsPluralForm(_reviewsCount)}',
                                          onTap: () => Navigator.of(
                                            context,
                                          ).pushNamed(ReviewsEmptyPage.routeName),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),

                                  /*
                                  // Раздел «Ваши покупки»
                                  const _SectionTitle('Ваши покупки'),
                                  const SizedBox(height: 12),
                                  // Карточка со штрихкодом
                                  _BarcodeCard(),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 82,
                                    child: PageView(
                                      controller: PageController(
                                        viewportFraction: 0.70,
                                      ),
                                      padEnds: false,
                                      pageSnapping: true,
                                      children: [
                                        // Карточка с товаром 1
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: _PurchaseCard(
                                            productImage:
                                                'assets/profile_dashboard/image.png',
                                            title: 'Самовывоз',
                                            subtitle: 'Готов к выдаче',
                                            date: '21/04 c 14:00 до 18:00',
                                          ),
                                        ),
                                        // Карточка с товаром 2
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: _PurchaseCard(
                                            productImage:
                                                'assets/profile_dashboard/image.png',
                                            title: 'Курьеров',
                                            subtitle: 'Ожидание',
                                            date: '21/04 с 14:00 до 18:00',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  */

                                  // Раздел «Ваши покупки»: что куплено и ещё
                                  // не получено (17.09.2026).
                                  if (_activePurchases.isNotEmpty ||
                                      _purchasesLoading) ...[
                                    const _SectionTitle('Ваши покупки'),
                                    const SizedBox(height: 10),
                                    _buildPurchasesBanner(),
                                    const SizedBox(height: 10),
                                    _buildPurchasesCarousel(),
                                    const SizedBox(height: 16),
                                  ],

                                  // Раздел «Ваши объявления»
                                  const _SectionTitle('Ваши объявления'),
                                  // const SizedBox(height: 10),
                                  _MenuItem(
                                    title: 'Все объявления',
                                    count: _isLoadingListings
                                        ? 0
                                        : _activeListingsCount,
                                    trailingChevron: true,
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pushNamed(MyListingsScreen.routeName),
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  // Бронирование. Два пункта, а не один:
                                  // «мои» и «ко мне» человек смотрит разными
                                  // глазами, и объединять их в один список
                                  // значит заставлять его фильтровать.
                                  _MenuItem(
                                    title: 'Мои брони',
                                    count: _bookingCounts.mine,
                                    trailingChevron: true,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const MyBookingsScreen(initialTab: 0),
                                      ),
                                    ).then((_) => _loadBookingCounts()),
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  _MenuItem(
                                    title: 'Заявки ко мне',
                                    count: _bookingCounts.incoming,
                                    // Подсвечиваем, только когда есть чему
                                    // ждать ответа: подтверждённые брони
                                    // действия не требуют.
                                    isHighlight:
                                        _bookingCounts.incomingPending > 0,
                                    trailingChevron: true,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const MyBookingsScreen(initialTab: 1),
                                      ),
                                    ).then((_) => _loadBookingCounts()),
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  _MenuItem(
                                    title: 'Отклики',
                                    count: 0,
                                    trailingChevron: true,
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pushNamed(ResponsesEmptyPage.routeName),
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  _MenuItem(
                                    title: 'Предложения цен',
                                    count: _priceOffersCount,
                                    trailingChevron: true,
                                    isHighlight: true,
                                    onTap: () {
                                      Navigator.of(context)
                                          .pushNamed(
                                            PriceOffersEmptyPage.routeName,
                                          )
                                          .then((_) {
                                            // Обновляем счётчик при возврате на экран
                                            _loadPriceOffersCount(
                                              useCache: false,
                                            );
                                          });
                                    },
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  // Заказы на товары, которые сделали у меня
                                  // (16.09.2026). Раньше пункт был скрыт,
                                  // потому что вёл в никуда: раздела не
                                  // существовало, и попасть в заказы можно
                                  // было только по пушу.
                                  //
                                  // Число в кружке это НОВЫЕ заказы, а не все:
                                  // «принять или отклонить» ждёт именно их.
                                  _MenuItem(
                                    title: 'Заказы',
                                    count: _newOrdersCount,
                                    trailingChevron: true,
                                    isHighlight: _newOrdersCount > 0,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SellerOrdersScreen(),
                                      ),
                                    ),
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),

                                  // Мои покупки: то, что я заказал сам. Это
                                  // ДРУГОЙ список, и держать его на одном
                                  // экране с заказами ко мне нельзя: путать
                                  // «я купил» и «у меня купили» дороже, чем
                                  // завести два пункта.
                                  _MenuItem(
                                    title: 'Покупки',
                                    count: 0,
                                    trailingChevron: true,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const MyOrdersScreen(onlyMine: true),
                                      ),
                                    ),
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  
                                  
                                  const SizedBox(height: 10),
                                  // Поддержка и ФИНАНСЫ — две карточки в ряд.
                                  // Блок «Финансовая поддержка владельца ЛИДЛЕ»
                                  // скрыт (см. _FinancialSupportCard ниже),
                                  // вместо него — баланс пользователя.
                                  SizedBox(
                                    height: 48,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _MessageCard(
                                            title: 'Поддержка ЛИДЛЕ',
                                            subtitle: 'Сообщения: Нет',
                                            highlight: false,
                                            onTap: () => Navigator.of(context)
                                                .pushNamed(
                                                    SupportScreen.routeName),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: _FinanceCard(balance: 0),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Карточка «Ваш магазин» с кнопкой «Поделиться»
                                  Builder(
                                    builder: (context) {
                                      final storeName =
                                          profileState is ProfileLoaded
                                              ? profileState.name
                                              : '';
                                      final rawNick =
                                          (profileState is ProfileLoaded
                                                  ? profileState.username
                                                  : '')
                                              .trim();
                                      // Убираем ведущий символ «@» — нужно только имя аккаунта
                                      final nick = rawNick.startsWith('@')
                                          ? rawNick.substring(1).trim()
                                          : rawNick;
                                      // Если ник пустой — используем имя аккаунта
                                      final displayName = nick.isNotEmpty
                                          ? nick
                                          : storeName.trim();
                                      // Название КОМПАНИИ. Приоритет — свежее
                                      // значение с сервера (_companyName из
                                      // GET /companies/{id}); если ещё не
                                      // загрузилось — локальный кеш. Показываем
                                      // его в карточке магазина вместо ника.
                                      final freshCompany =
                                          _companyName?.trim() ?? '';
                                      final companyName = freshCompany.isNotEmpty
                                          ? freshCompany
                                          : (UserService.getLocal('companyName')
                                                      as String? ??
                                                  '')
                                              .trim();
                                      final userId =
                                          profileState is ProfileLoaded
                                              ? profileState.userId
                                              : '';
                                      final storeUrl = _buildStoreUrl(userId);

                                      // Аватарка владельца. Нужна только для
                                      // перехода на страницу продавца: там
                                      // показан человек, а не магазин.
                                      final profileImg =
                                          profileState is ProfileLoaded
                                              ? profileState.profileImage
                                              : null;

                                      // Фотография КОМПАНИИ, не владельца:
                                      // сначала свежая с сервера, иначе
                                      // локальный кеш. Аватарка пользователя
                                      // здесь не подставляется вовсе — это
                                      // карточка магазина.
                                      final freshImage =
                                          _companyImage?.trim() ?? '';
                                      final companyImg = freshImage.isNotEmpty
                                          ? freshImage
                                          : (UserService.getLocal(
                                                          'companyImage')
                                                      as String? ??
                                                  '')
                                              .trim();
                                      // SellerProfileScreen ждёт числовой id (int.tryParse)
                                      final cleanUserId = userId
                                          .replaceFirst('ID: ', '')
                                          .trim();
                                      return SizedBox(
                                        width: double.infinity,
                                        child: _StoreShareCard(
                                          storeName: storeName,
                                          ownerNick: displayName,
                                          companyName: companyName,
                                          companyImage:
                                              companyImg.isEmpty ? null : companyImg,
                                          // Тап по иконке → экран QR продавца
                                          // (как кнопка «Поделиться» на экране
                                          // продавца seller_profile_screen).
                                          onShare: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => SellerQrScreen(
                                                  sellerName: companyName.isNotEmpty
                                                      ? companyName
                                                      : (displayName.isNotEmpty
                                                          ? displayName
                                                          : storeName),
                                                  sellerUrl: storeUrl,
                                                ),
                                              ),
                                            );
                                          },
                                          // Тап по карточке → магазин продавца
                                          onOpenStore: () {
                                            final ImageProvider avatarProvider =
                                                (profileImg != null &&
                                                        profileImg.isNotEmpty)
                                                    ? NetworkImage(profileImg)
                                                    : const AssetImage(
                                                        'assets/profile_dashboard/default-photo.svg',
                                                      );
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    SellerProfileScreen(
                                                  sellerName:
                                                      displayName.isNotEmpty
                                                          ? displayName
                                                          : storeName,
                                                  sellerAvatar: avatarProvider,
                                                  sellerAvatarUrl: profileImg,
                                                  userId: cleanUserId,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: BottomNavigation(
                      onItemSelected: (index) {
                        context.read<NavigationBloc>().add(
                          SelectNavigationIndexEvent(index),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
        },
      ),
    );
  }
}

/* =========================  WIDGETS  ========================= */

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String userId;
  final String? profileImage;
  final String username;

  const _ProfileHeader({
    required this.name,
    required this.userId,
    this.profileImage,
    this.username = 'Name',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватар с синей окантовкой
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: activeIconColor, width: 3),
          ),
          child: CircleAvatar(
            radius: 54.5,
            backgroundColor: formBackground,
            child: profileImage != null
                ? ClipOval(
                    child: buildProfileImage(
                      profileImage,
                      width: 109,
                      height: 109,
                      fit: BoxFit.cover,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/profile_dashboard/default-photo.svg',
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$username',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$userId',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        // Бургер-меню → переход на экран меню профиля
        IconButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(ProfileMenuScreen.routeName),
          icon: const Icon(Icons.menu, color: Colors.white, size: 30),
          tooltip: 'Меню',
          splashRadius: 24,
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 96,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF474747)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 13.0, left: 10.0, bottom: 2),
            child: Row(
              children: [
                SvgPicture.asset(iconPath, height: 24, color: Colors.white70),
              ],
            ),
          ),

          // Заголовок карточки.
          //
          // Названия стали длиннее («Отзывы о ваших товарах» вместо «Отзывы»),
          // а карточка занимает половину экрана и имеет жёсткую высоту. Одна
          // строка без запаса на узком телефоне вылезала бы за край полосатой
          // ошибкой, поэтому текст ужимается ровно настолько, насколько не
          // помещается: на обычном экране он остаётся 16-м кеглем.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: Row(
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: card,
            )
          : card,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final int? count;
  final bool trailingChevron;
  final VoidCallback? onTap;
  final bool isHighlight;

  const _MenuItem({
    required this.title,
    this.count,
    this.trailingChevron = false,
    this.onTap,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            if (count != null)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isHighlight
                        ? const Color(0xFFE3E335)
                        : const Color(0xFF767676),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isHighlight
                        ? const Color(0xFFE3E335)
                        : const Color(0xFF767676),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            if (trailingChevron) ...[
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback? onTap;

  const _MessageCard({
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = highlight
        ? Border.all(color: const Color(0xFFE3E335), width: 1)
        : Border.all(color: const Color(0xFF474747));

    final card = Container(
      // УДАЛЯЕМ: constraints: const BoxConstraints(minHeight: 86),
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(9),
        border: border,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 1.0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: highlight ? const Color(0xFFE3E335) : textSecondary,
                fontSize: 10,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }
}

/// Карточка «ФИНАНСЫ» — баланс пользователя в приложении.
///
/// ВАЖНО: API баланса на бэке пока НЕТ. Биллинг сейчас работает через
/// подписки (feed_subscriptions), а не через лицевой счёт, поэтому число
/// приходит снаружи и по умолчанию нулевое. Когда появится эндпоинт
/// баланса — сюда достаточно передать реальное значение.
class _FinanceCard extends StatelessWidget {
  /// Баланс в рублях.
  final int balance;

  const _FinanceCard({this.balance = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF474747)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 1.0),
              child: Text(
                'ФИНАНСЫ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Row(
              children: [
                const Text(
                  'Баланс: ',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  '$balance',
                  style: const TextStyle(
                    color: Color(0xFF4CD964),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Блок «Финансовая поддержка» временно скрыт с дашборда (вместо него —
// карточка ФИНАНСЫ). Класс и диалог оставлены, чтобы вернуть блок одной
// строкой, поэтому анализатор о неиспользуемом коде не предупреждает.
// ignore: unused_element
/// Виджет "Финансовая поддержка владельца ЛИДЛЕ LIDLE"
/// Отображает информацию о программе финансовой поддержки продавцов
class _FinancialSupportCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _FinancialSupportCard({
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF474747)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 1.0),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Финансовая поддержка владельца ЛИДЛЕ ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: 'LIDLE',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Ваш вклад - энергия для новых функций и быстро...',
              style: const TextStyle(
                color: textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }
}

/// Карточка «Ваш магазин» с кнопкой «Поделиться».
/// По нажатию на иконку (или на всю карточку) открывается меню
/// с разными способами поделиться ссылкой на магазин.
class _StoreShareCard extends StatelessWidget {
  final String storeName;
  final String ownerNick;
  final String companyName;

  /// Фотография КОМПАНИИ. Пусто — показываем значок по умолчанию.
  ///
  /// Раньше здесь стояла аватарка владельца. Это вводило в заблуждение:
  /// карточка про магазин, покупатель видит на витрине снимок компании, а
  /// продавец в кабинете — своё лицо, и понять, что именно увидят люди, было
  /// невозможно.
  final String? companyImage;

  final VoidCallback onShare;
  final VoidCallback onOpenStore;

  const _StoreShareCard({
    required this.storeName,
    required this.onShare,
    required this.onOpenStore,
    this.ownerNick = '',
    this.companyName = '',
    this.companyImage,
  });

  @override
  Widget build(BuildContext context) {
    // После «Ваш магазин» выводим название КОМПАНИИ. Если названия компании
    // ещё нет в кеше — используем ник владельца как запасной вариант.
    final owner =
        companyName.trim().isNotEmpty ? companyName.trim() : ownerNick.trim();
    final title = owner.isEmpty ? 'Ваш магазин' : 'Ваш магазин $owner';

    return GestureDetector(
      // Тап по всей карточке → переход в магазин продавца
      onTap: onOpenStore,
      child: Container(
        decoration: BoxDecoration(
          color: primaryBackground,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF474747)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            // Аватарка и кнопка «Поделиться» стоят по центру по вертикали
            // относительно обеих строк текста.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Аватарка магазина слева от текста: раньше она стояла внутри
              // строки с заголовком, из-за чего заголовок начинался правее
              // подписи и блок выглядел ступенькой.
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: _avatar(),
                ),
              ),
              const SizedBox(width: 10),
              // Заголовок и подпись одной колонкой: оба текста начинаются
              // с одной вертикали.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Подпись всегда в одну строку. Если она не помещается по
                    // ширине, шрифт уменьшается ровно настолько, насколько
                    // нужно: перенос на вторую строку растягивал карточку, а
                    // обрезка многоточием прятала конец фразы.
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Делитесь вашей ссылкой в своих соц сетях и с покупателями',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Кнопка «Поделиться» — по центру по вертикали
              IconButton(
                onPressed: onShare,
                tooltip: 'Поделиться',
                splashRadius: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: SvgPicture.asset(
                  'assets/home_page/share_outlined.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Значок магазина: снимок компании либо заглушка из ассетов.
  ///
  /// Общий `buildProfileImage` рисует на месте неудачи серый квадрат с иконкой
  /// ошибки. Для этой карточки так не годится: магазин без фотографии это
  /// обычное дело, а не поломка, и человек видел серый прямоугольник вместо
  /// понятного значка. Здесь на любой неудаче показываем заглушку: пусто,
  /// битая ссылка, пропавший файл, неизвестный путь.
  Widget _avatar() {
    const double size = 32;

    final placeholder = SvgPicture.asset(
      'assets/profile_dashboard/default-photo.svg',
      width: size,
      height: size,
    );

    final path = companyImage?.trim() ?? '';

    if (path.isEmpty) {
      return placeholder;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        // Пока снимок грузится, на его месте стоит заглушка, а не пустота:
        // карточка не дёргается по высоте.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      );
    }

    final file = File(path);

    if (!file.existsSync()) {
      return placeholder;
    }

    return Image.file(
      file,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

// ignore: unused_element
class _BarcodeCard extends StatelessWidget {
  const _BarcodeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      // margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Штрихкод
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SvgPicture.asset(
              'assets/profile_dashboard/barcode.svg',
              width: 69,
              height: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          // Текст
          Expanded(
            child: Text(
              'Покажите штрих-код продавцу для получение товара',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _PurchaseCard extends StatelessWidget {
  final String productImage;
  final String title;
  final String subtitle;
  final String date;

  const _PurchaseCard({
    required this.productImage,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Изображение товара
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              productImage,
              fit: BoxFit.cover,
              width: 72,
              height: 64,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 72,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white24,
                    size: 30,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          // Информация о товаре
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Название
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Статус
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitle == 'Готов к выдаче'
                        ? const Color(0xFF86DE59)
                        : const Color(0xFFE3E335),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Дата
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}