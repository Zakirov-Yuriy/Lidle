/// Главная страница приложения Lidle.
/// Отображает категории предложений, строку поиска, последние объявления
/// и нижнюю навигационную панель.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../models/home_models.dart';
import '../widgets/header.dart';
import '../widgets/search_bar.dart' as custom_widgets;
import '../widgets/category_card.dart';
import '../widgets/listing_card.dart';
import '../widgets/bottom_navigation.dart';
import '../blocs/listings/listings_bloc.dart';
import '../blocs/listings/listings_state.dart';
import '../blocs/listings/listings_event.dart';
import '../blocs/navigation/navigation_bloc.dart';
import '../blocs/navigation/navigation_state.dart';
import '../blocs/navigation/navigation_event.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../pages/filters_screen.dart';
import '../pages/profile_menu_screen.dart';
import '../pages/sign_in_screen.dart';

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
    // Загружаем данные при инициализации страницы
    context.read<ListingsBloc>().add(LoadListingsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToAddListing || state is NavigationToMyPurchases || state is NavigationToSignIn) {
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Header(),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(top: 15.0),
                              child: SvgPicture.asset(
                                'assets/home_page/marker-pin.svg',
                                width: 20,
                                height: 20,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Padding(
                              padding: const EdgeInsets.only(top: 15.0),
                              child: const Text(
                                'г. Мариуполь. ДНР',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFAAAAAA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only( left: 7.0, right: 11.0),
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, authState) {
                            return custom_widgets.SearchBarWidget(
                              onSearchChanged: (query) {
                                if (query.isNotEmpty) {
                                  context.read<ListingsBloc>().add(SearchListingsEvent(query: query));
                                } else {
                                  context.read<ListingsBloc>().add(ResetFiltersEvent());
                                }
                              },
                              onSettingsPressed: () {
                                Navigator.pushNamed(context, FiltersScreen.routeName);
                              },
                              onMenuPressed: () {
                                if (authState is AuthAuthenticated) {
                                  Navigator.pushNamed(context, ProfileMenuScreen.routeName);
                                } else {
                                  Navigator.pushNamed(context, SignInScreen.routeName);
                                }
                              },
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
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
                    ],
                  ),
                ),
                bottomNavigationBar: BottomNavigation(
                  onItemSelected: (index) {
                    if (index == 3) { // Shopping cart icon
                      context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
                    } else {
                      context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
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
      return const Column(
        children: [
          SizedBox(height: 50),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          SizedBox(height: 50),
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
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<ListingsBloc>().add(LoadListingsEvent()),
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

    final categories = (state is ListingsLoaded) ? state.categories : <Category>[];

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
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return CategoryCard(category: categories[index]);
              },
            ),
          ),
        ),

      ],
    );
  }

  /// Приватный метод для построения секции последних объявлений.
  /// Включает заголовок "Самое новое" и адаптивную сетку карточек объявлений.
  Widget _buildLatestSection(ListingsState state) {
    if (state is ListingsLoading) {
      return Column(
        // crossAxisAlignment: CrossAxisAlignment.start,
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
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
          ),
        ],
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
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ListingsBloc>().add(LoadListingsEvent()),
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
        ? state.filteredListings
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
              final itemWidth =
                  (constraints.maxWidth -
                      12 -
                      12 -
                      9) /
                  2;
              double tileHeight = 263;
              if (itemWidth < 170) tileHeight = 275;
              if (itemWidth < 140) tileHeight = 300;
      
              return GridView.builder(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                ),
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
              );
            },
          ),
      
        ],
      ),
    );
  }
}
