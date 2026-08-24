import 'package:flutter/material.dart';
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
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/pages/profile_dashboard/financial_support_dialog.dart';

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
      final nameRaw = data['name'];
      final name = (nameRaw is String && nameRaw.trim().isNotEmpty)
          ? nameRaw.trim()
          : '';
      if (name.isEmpty) return;
      await UserService.saveLocal('companyName', name);
      if (!mounted) return;
      setState(() => _companyName = name);
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
    }
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
                                  top: 15,
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
                                    const SizedBox(height: 10),

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
                                              title: 'Избранное',
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
                                          title: 'Отзывы',
                                          subtitle:
                                              '$_reviewsCount ${_getReviewsPluralForm(_reviewsCount)}',
                                          onTap: () => Navigator.of(
                                            context,
                                          ).pushNamed(ReviewsEmptyPage.routeName),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 10),

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
                                  // Пункт «Заказы» скрыт до появления раздела
                                  // заказов — кнопка вела в никуда (onTap пустой).
                                  // Вернуть: раскомментировать блок ниже.
                                  // _MenuItem(
                                  //   title: 'Заказы',
                                  //   count: 0,
                                  //   trailingChevron: true,
                                  //   isHighlight: true,
                                  //   onTap: () {},
                                  // ),
                                  // const Divider(
                                  //   color: Color(0xFF474747),
                                  //   height: 8,
                                  // ),
                                  
                                  
                                  const SizedBox(height: 12),
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

                                  const SizedBox(height: 12),

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
                                      final profileImg =
                                          profileState is ProfileLoaded
                                              ? profileState.profileImage
                                              : null;
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
                                          profileImage: profileImg,
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

          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
  final String? profileImage;
  final VoidCallback onShare;
  final VoidCallback onOpenStore;

  const _StoreShareCard({
    required this.storeName,
    required this.onShare,
    required this.onOpenStore,
    this.ownerNick = '',
    this.companyName = '',
    this.profileImage,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            // Кнопка «Поделиться» центрируется по вертикали относительно
            // всего блока (аватар + заголовок + подпись)
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Левый блок: строка (аватар + заголовок) и подпись под ней
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Первая строка: иконка/аватар + заголовок «Ваш магазин ...»
                    Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: profileImage != null
                                ? buildProfileImage(
                                    profileImage,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  )
                                : SvgPicture.asset(
                                    'assets/profile_dashboard/default-photo.svg',
                                    width: 32,
                                    height: 32,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Подпись — под строкой с иконкой и заголовком
                    const Text(
                      'Делитесь вашей ссылкой в своих соц сетях и с покупателями',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
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