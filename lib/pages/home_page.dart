// ============================================================
// "Виджет: Главная страница приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../models/home_models.dart';
import '../widgets/components/header.dart';
import '../widgets/components/search_bar.dart' as custom_widgets;
import '../widgets/cards/category_card.dart';
import '../widgets/cards/listing_card.dart';
import '../widgets/skeletons/category_card_skeleton.dart';
import '../widgets/skeletons/listing_card_skeleton.dart';
import '../widgets/navigation/bottom_navigation.dart';
import '../blocs/listings/listings_bloc.dart';
import '../blocs/listings/listings_state.dart';
import '../blocs/listings/listings_event.dart';
import '../blocs/navigation/navigation_bloc.dart';
import '../blocs/navigation/navigation_state.dart';
import '../blocs/navigation/navigation_event.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../pages/filters_screen.dart';
import '../pages/full_category_screen/full_category_screen.dart';
import '../pages/full_category_screen/real_estate_listings_screen.dart';
import 'profile_menu/profile_menu_screen.dart';
import '../pages/auth/sign_in_screen.dart';

/// `HomePage` - это StatefulWidget, который отображает главную страницу
/// приложения с использованием Bloc для управления состоянием.
class HomePage extends StatefulWidget {
  /// Конструктор для `HomePage`.
  const HomePage({super.key});

  static const String routeName = '/home'; // Добавлена константа routeName

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 🔄 Кеширование: загружаем данные только если их ещё нет
    final currentState = context.read<ListingsBloc>().state;
    if (currentState is! ListingsLoaded) {
      context.read<ListingsBloc>().add(LoadListingsEvent());
    }
  }

  /// Метод для обработки pull-to-refresh.
  /// Перезагружает данные объявлений и категорий с флагом forceRefresh=true.
  Future<void> _onRefresh() async {
    context.read<ListingsBloc>().add(LoadListingsEvent(forceRefresh: true));
    // Небольшая задержка для имитации загрузки и показа индикатора
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToAddListing ||
            state is NavigationToMyPurchases ||
            state is NavigationToMessages ||
            state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return BlocBuilder<ListingsBloc, ListingsState>(
            builder: (context, listingsState) {
              return Scaffold(
                extendBody: true,
                backgroundColor: primaryBackground,
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 21, right: 23),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Header(),
                            Padding(
                              padding: const EdgeInsets.only(top: 19.0),
                              child: SvgPicture.asset(
                                'assets/home_page/share_outlined.svg',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 7.0, right: 11.0),
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, authState) {
                            return custom_widgets.SearchBarWidget(
                              onSearchChanged: (query) {
                                if (query.isNotEmpty) {
                                  context.read<ListingsBloc>().add(
                                    SearchListingsEvent(query: query),
                                  );
                                } else {
                                  context.read<ListingsBloc>().add(
                                    ResetFiltersEvent(),
                                  );
                                }
                              },
                              onSettingsPressed: () async {
                                await Navigator.pushNamed(
                                  context,
                                  FiltersScreen.routeName,
                                );
                              },
                              onMenuPressed: () {
                                if (authState is AuthAuthenticated) {
                                  Navigator.pushNamed(
                                    context,
                                    ProfileMenuScreen.routeName,
                                  );
                                } else {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    SignInScreen.routeName,
                                    (route) =>
                                        route.settings.name == '/' ||
                                        route.isFirst,
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: accentColor, // Цвет стрелки и индикатора
                          backgroundColor:
                              formBackground, // Цвет фона индикатора
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCategoriesSection(listingsState),
                                _buildLatestSection(listingsState),
                                SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: BottomNavigation(
                  onItemSelected: (index) {
                    if (index == 3) {
                      // Shopping cart icon
                      context.read<NavigationBloc>().add(
                        NavigateToMyPurchasesEvent(),
                      );
                    } else {
                      context.read<NavigationBloc>().add(
                        SelectNavigationIndexEvent(index),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Приватный метод для построения секции категорий.
  /// Включает заголовок "Предложения на LIDLE", кнопку "Смотреть все"
  /// и горизонтальный список карточек категорий.
  Widget _buildCategoriesSection(ListingsState state) {
    if (state is ListingsLoading) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categoriesTitle,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    viewAll,
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: SizedBox(
              height: 85,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6, // Показываем 6 skeleton карточек
                itemBuilder: (context, index) {
                  return const CategoryCardSkeleton();
                },
              ),
            ),
          ),
        ],
      );
    }

    if (state is ListingsError) {
      return Column(
        children: [
          const SizedBox(height: 50),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки категорий',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<ListingsBloc>().add(LoadListingsEvent()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      );
    }

    final categories = (state is ListingsLoaded)
        ? state.categories
        : <Category>[];

    // Отфильтруем категории, исключив "Смотреть все"
    final filteredCategories = categories
        .where(
          (cat) =>
              !cat.title.contains('Смотреть') && !cat.title.contains('все'),
        )
        .toList();

    // Берем максимум 3 первые категории
    final displayCategories = filteredCategories.take(4).toList();

    // Добавляем "Смотреть все" в конец если оно есть в исходном списке
    final viewAllCategory = categories.firstWhere(
      (cat) => cat.title.contains('Смотреть') || cat.title.contains('все'),
      orElse: () => Category(title: '', color: Colors.grey, imagePath: ''),
    );
    if (viewAllCategory.title.isNotEmpty) {
      displayCategories.add(viewAllCategory);
    }

    return AnimatedOpacity(
      opacity: displayCategories.isNotEmpty ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 25,
              top: 15,
              bottom: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categoriesTitle,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    FullCategoryScreen.routeName,
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    viewAll,
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 19.0),
            child: SizedBox(
              height: 85,
              child: displayCategories.isEmpty
                  ? Center(
                      child: Text(
                        'Категории не загружены',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayCategories.length,
                      itemBuilder: (context, index) {
                        final category = displayCategories[index];
                        return AnimatedScale(
                          scale: 1.0,
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          child: CategoryCard(
                            category: category,
                            onTap: () {
                              // Проверяем только на "Смотреть все"
                              final isViewAll =
                                  category.title.contains('Смотреть') ||
                                  category.title.contains('все') ||
                                  category.title.contains('View All');

                              if (isViewAll) {
                                print('📍 Navigating to FullCategoryScreen');
                                Navigator.pushNamed(
                                  context,
                                  FullCategoryScreen.routeName,
                                );
                              } else {
                                // Специальная обработка для каталогов - показать все объявления каталога
                                final isCatalogCategory = [
                                  'Недвижимость',
                                  'Работа',
                                  'Подработка',
                                  'Авто запчасти',
                                ].contains(category.title);
                                print(
                                  '📍 Opening category: ${category.title} (ID: ${category.id})',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RealEstateListingsScreen(
                                          categoryId: isCatalogCategory
                                              ? null
                                              : category.id,
                                          catalogId: isCatalogCategory
                                              ? category.id
                                              : null,
                                          categoryName: category.title,
                                        ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Приватный метод для построения секции последних объявлений.
  /// Включает заголовок "Самое новое" и адаптивную сетку карточек объявлений.
  Widget _buildLatestSection(ListingsState state) {
    if (state is AdvertLoaded) {
      // Если состояние AdvertLoaded (после возврата с деталей), перезагружаем объявления
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ListingsBloc>().add(LoadListingsEvent());
      });
      // Показываем индикатор загрузки
      return Padding(
        padding: const EdgeInsets.only(bottom: 110.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                latestTitle,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: const CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    if (state is ListingsLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 110.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                latestTitle,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12 - 12 - 9) / 2;
                double tileHeight = 263;
                if (itemWidth < 170) tileHeight = 275;
                if (itemWidth < 140) tileHeight = 300;

                return GridView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 0,
                    mainAxisExtent: tileHeight,
                  ),
                  itemCount: 6, // Показываем 6 skeleton карточек
                  itemBuilder: (context, index) {
                    return const ListingCardSkeleton();
                  },
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                );
              },
            ),
          ],
        ),
      );
    }

    if (state is ListingsError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              latestTitle,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ошибка загрузки объявлений',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ListingsBloc>().add(LoadListingsEvent()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final listings = (state is ListingsLoaded)
        ? state.listings
        : (state is ListingsSearchResults)
        ? state.searchResults
        : (state is ListingsFiltered)
        ? state.filteredListings
        : <Listing>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 110.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              latestTitle,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12 - 12 - 9) / 2;
              double tileHeight = 263;
              if (itemWidth < 170) tileHeight = 275;
              if (itemWidth < 140) tileHeight = 300;

              return Column(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      // Проверяем достигнут ли конец списка
                      if (scrollInfo.metrics.pixels ==
                          scrollInfo.metrics.maxScrollExtent) {
                        // Загружаем следующую страницу если есть еще страницы
                        if (state is ListingsLoaded &&
                            state.currentPage < state.totalPages) {
                          context.read<ListingsBloc>().add(LoadNextPageEvent());
                        }
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.only(left: 12, right: 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 9,
                        mainAxisSpacing: 0,
                        mainAxisExtent: tileHeight,
                      ),
                      itemCount: listings.length,
                      itemBuilder: (context, index) {
                        return ListingCard(listing: listings[index]);
                      },
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
