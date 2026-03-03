// ============================================================
// "Виджет: Панель управления профилем пользователя"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
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
import 'package:lidle/pages/my_purchases_screen.dart'; // Import MyPurchasesScreen
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/support/support_screen.dart';
import 'package:lidle/pages/profile_dashboard/responses/responses_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/reviews/reviews_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';

// ============================================================
// "Вспомогательная функция для правильного склонения слова"
// ============================================================
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
  bool _isLoadingListings = true;
  // ignore: unused_field
  bool _isLoadingPriceOffers = false;

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
      print('❌ Ошибка загрузки объявлений: $e');
      if (mounted) {
        setState(() {
          _isLoadingListings = false;
        });
      }
    }
  }

  /// Загрузить количество предложений цен.
  /// [useCache] = true: сначала показать из кэша (если свежий), потом обновить в фоне
  /// [useCache] = false: всегда загружать со свежими указанными данными
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

      // Загружаем список предложений цен (мои предложения)
      final offersData = await ApiService.getMyOffers(token: token);
      final count = offersData.length;

      // 💾 Сохраняем в AppCacheService (TTL 60с)
      AppCacheService().set<int>(
        CacheKeys.profilePriceOffersCount,
        count,
        ttl: _cacheTtl,
      );

      if (mounted) {
        setState(() {
          _priceOffersCount = count;
          _isLoadingPriceOffers = false;
        });
      }
    } catch (e) {
      print('❌ Ошибка загрузки количества предложений цен: $e');
      if (mounted) {
        setState(() {
          _isLoadingPriceOffers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Загружаем профиль при первом построении
    context.read<ProfileBloc>().add(LoadProfileEvent());
    // print('🔄 ProfileDashboard: LoadProfileEvent добавлено');

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthLoggedOut) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            SignInScreen.routeName,
            (route) => route.settings.name == '/' || route.isFirst,
          );
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
                  // print();
                  if (profileState is ProfileLoaded) {
                    // print('✅ ProfileLoaded: ${profileState.name}');
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 21,
                                vertical: 15,
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
                                          // print();
                                          // print('   Favorites IDs: $favorites');

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
                                      SizedBox(width: 10),
                                      _QuickCard(
                                        iconPath:
                                            'assets/profile_dashboard/shopping-cart-01.svg',
                                        title: 'Покупки',
                                        subtitle: '2 товаров',
                                        onTap: () =>
                                            Navigator.of(context).pushNamed(
                                              MyPurchasesScreen.routeName,
                                            ),
                                      ),
                                      SizedBox(width: 10),
                                      _QuickCard(
                                        iconPath:
                                            'assets/profile_dashboard/eva_star-fill.svg',
                                        title: 'Отзывы',
                                        subtitle: '0 отзовов',
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
                                    count: 4,
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
                                  _MenuItem(
                                    title: 'Заказы',
                                    count: 0,
                                    trailingChevron: true,
                                    isHighlight: true,
                                    onTap: () {},
                                  ),
                                  const Divider(
                                    color: Color(0xFF474747),
                                    height: 8,
                                  ),
                                  const SizedBox(height: 58),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 185,
                                      height: 48,
                                      child: _MessageCard(
                                        title: 'Поддержка LIDLE',
                                        subtitle: 'Сообщения: Нет',
                                        highlight: false,
                                        onTap: () => Navigator.of(
                                          context,
                                        ).pushNamed(SupportScreen.routeName),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 129),
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
        Column(
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
