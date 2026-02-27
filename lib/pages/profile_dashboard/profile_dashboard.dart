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
import 'package:lidle/core/cache/cacheable_bloc.dart';

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
  int _inactiveListingsCount = 0;
  bool _isLoadingListings = true;

  static const String _cacheKeyListings = 'profile_listings_counts';

  @override
  void initState() {
    super.initState();
    // Добавляем observer для отслеживания жизненного цикла приложения
    WidgetsBinding.instance.addObserver(this);
    // 🔄 Ленивая загрузка профиля при входе на страницу профиля
    context.read<ProfileBloc>().add(LoadProfileEvent());
    // ⚠️ ВСЕГДА загружаем свежие данные о объявлениях (не используем кеш)
    _loadListingsCounts(forceRefresh: true);
  }

  @override
  void dispose() {
    // Удаляем observer при удалении виджета
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Перезагружаем счетчики при возвращении в приложение
    if (state == AppLifecycleState.resumed && mounted) {
      // print('🔄 Приложение вернулось в фокус - обновляем счетчики объявлений');
      _loadListingsCounts(forceRefresh: true);
    }
  }

  /// Загрузить количество активных и неактивных объявлений
  /// ⚠️ ВСЕГДА загружает свежие данные со ВСЕХ категорий и статусов
  /// Загрузить количество объявлений со ВСЕХ статусов
  /// ⚠️ ВСЕГДА загружает свежие данные (кеш НЕ используется)
  Future<void> _loadListingsCounts({bool forceRefresh = false}) async {
    try {
      setState(() => _isLoadingListings = true);

      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        // print('❌ Нет токена!');
        setState(() => _isLoadingListings = false);
        return;
      }

      // print('🔄 Загружаем ВСЕ объявления пользователя (все статусы)...');

      // Статусы: 1=Active, 2=Inactive, 3=Moderation, 8=Archived
      final statuses = [1, 2, 3, 8];
      var allAdverts = <dynamic>[];

      for (final statusId in statuses) {
        // print('📄 Загружаем объявления со статусом $statusId...');
        var pageNum = 1;
        var hasMorePages = true;

        while (hasMorePages) {
          // print();

          try {
            final response = await MyAdvertsService.getMyAdverts(
              token: token,
              page: pageNum,
              statusId: statusId,
            );

            // print('   ✓ Response: data.length=${response.data.length}');
            // print('   ✓ Response.page=${response.page}');
            // print('   ✓ Response.lastPage=${response.lastPage}');

            allAdverts.addAll(response.data);
            // print('   ✓ Всего в памяти: ${allAdverts.length}');

            final currentPage = response.page ?? 1;
            final lastPage = response.lastPage ?? 1;

            if (currentPage >= lastPage) {
              hasMorePages = false;
              // print('   ✓ Последняя страница для статуса $statusId');
            } else {
              pageNum++;
            }
          } catch (e, st) {
            // print('   ❌ Ошибка статус $statusId страница $pageNum: $e');
            hasMorePages = false;
            // Не пробрасываем - продолжаем со следующего статуса
            break;
          }
        }
      }

      final totalCount = allAdverts.length;

      // print('');
      // print('✅ ФИНАЛЬНЫЙ РЕЗУЛЬТАТ:');
      // print('   ✓ Всего объявлений: $totalCount');
      // print('   ✓ По статусам загружено');
      if (allAdverts.isNotEmpty) {
        // print(
        //   '   ✓ Первые объявления: ${allAdverts.take(3).map((a) => '${a.name}').toList()}',
        // );
      } else {
        // print('   ⚠️ Объявления не загружены!');
      }
      // print('');

      setState(() {
        _activeListingsCount = totalCount;
        _inactiveListingsCount = 0;
        _isLoadingListings = false;
      });
    } catch (e, st) {
      // print('');
      // print('❌ КРИТИЧЕСКАЯ ОШИБКА ЗАГРУЗКИ:');
      // print('   Error: $e');
      // print('   StackTrace: $st');
      // print('');
      setState(() {
        _activeListingsCount = 0;
        _inactiveListingsCount = 0;
        _isLoadingListings = false;
      });
    }
  }

  /// Инвалидировать кеш объявлений (вызывается после добавления/удаления объявления)
  static void invalidateListingsCache() {
    CacheManager().clear('profile_listings_counts');
    // print('🗑️ Кеш объявлений инвалидирован');
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
                                    count: 2,
                                    trailingChevron: true,
                                    isHighlight: true,
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pushNamed(PriceOffersEmptyPage.routeName),
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
