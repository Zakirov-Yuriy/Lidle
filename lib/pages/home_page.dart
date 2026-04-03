// ============================================================
// "Виджет: Главная страница приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
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
import '../core/config/app_config.dart';
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
import '../main.dart'; // Для доступа к routeObserver
import 'package:lidle/core/logger.dart';

/// `HomePage` - это StatefulWidget, который отображает главную страницу
/// приложения с использованием Bloc для управления состоянием.
class HomePage extends StatefulWidget {
  /// Конструктор для `HomePage`.
  const HomePage({super.key});

  static const String routeName = '/home'; // Добавлена константа routeName

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> 
    with WidgetsBindingObserver, RouteAware, AutomaticKeepAliveClientMixin {
  /// Контроллер для сохранения позиции скролла
  late ScrollController _scrollController;
  
  /// Глобальное хранилище позиции скролла
  static double _globalScrollPosition = 0.0;
  
  /// Защита от двойного клика на кнопку поделиться
  bool _isShareInProgress = false;
  
  /// Дебоунс загрузки следующей страницы при прокручивании (3 секунды)
  static const Duration _loadMoreDebounce = Duration(seconds: 3);
  
  /// Время последней загрузки следующей страницы
  DateTime? _lastLoadMoreTime;

  /// 💾 Сохранять страницу в памяти при навигации
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Инициализируем ScrollController
    _scrollController = ScrollController();
    
    // 🔄 Кеширование: загружаем данные только если их ещё нет и нет ошибок
    final currentState = context.read<ListingsBloc>().state;

    // Загружаем данные НЕЗАВИСИМО от авторизации
    // (пользователь может просматривать контент как гость)
    if (currentState is ListingsInitial || currentState is ListingsError) {
      context.read<ListingsBloc>().add(LoadListingsEvent());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 📍 Подписываемся на RouteObserver для отслеживания маршрутов
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<dynamic>);
    
    // Восстанавливаем позицию скролла при возврате на эту страницу
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_globalScrollPosition > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(_globalScrollPosition);
        log.d('📍 Восстановлена глобальная позиция скролла: $_globalScrollPosition');
      }
    });
  }

  @override
  void deactivate() {
    // Отписываемся от RouteObserver при деактивации
    routeObserver.unsubscribe(this);
    super.deactivate();
  }

  @override
  void didPopNext() {
    // Вызывается когда экран вернулся на передний план (Navigator.pop был вызван)
    super.didPopNext();
    log.d('⬅️ Вернулись на HomePage');
    
    // 🟢 СЛОЙ 1: Восстанавливаем ИЗ КЕША (если доступны данные)
    // Даже если API не отвечает, пользователь видит кешированные данные
    final bloc = context.read<ListingsBloc>();
    final cachedState = bloc.restoreCachedData();
    
    if (cachedState != null) {
      // ✅ Есть кеш - восстанавливаем сразу (избегаем состояния ListingsLoading)
      log.d('✅ Восстановлены кешированные данные');
      bloc.emit(cachedState);
      
      // 🔄 Помимо восстановления из кеша, стараемся загрузить свежие данные в фоне
      // Через небольшую задержку, чтобы дать UI отрисоваться
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          // Отправляем событие загрузки в фоне БЕЗ forceRefresh
          // Это позволит BLoC загружать фазу 2 в фоне, если данные устарели
          bloc.add(LoadListingsEvent());
        });
      });
    } else {
      // ❌ Нет кеша - проверяем текущее состояние
      final currentState = bloc.state;
      
      if (currentState is ListingsLoading) {
        log.w('⚠️ ListingsBloc ещё загружает (нет кеша)');
      } else if (currentState is ListingsError) {
        log.w('⚠️ ListingsBloc в состоянии ошибки (нет кеша)');
        // Попытаемся перезагрузить
        WidgetsBinding.instance.addPostFrameCallback((_) {
          bloc.add(LoadListingsEvent());
        });
      }
    }
    
    // 📍 Восстанавливаем позицию скролла
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_globalScrollPosition > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(_globalScrollPosition);
        log.d('📍 Восстановлена позиция после didPopNext: $_globalScrollPosition');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Сохраняем позицию скролла перед паузой
    if (state == AppLifecycleState.paused) {
      if (_scrollController.hasClients) {
        _globalScrollPosition = _scrollController.position.pixels;
        log.d('💾 Сохранена позиция скролла при паузе: $_globalScrollPosition');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // 💾 Сохраняем позицию скролла в глобальной переменной
    if (_scrollController.hasClients) {
      _globalScrollPosition = _scrollController.position.pixels;
      log.d('💾 Сохранена глобальная позиция скролла при dispose: $_globalScrollPosition');
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Метод для обработки pull-to-refresh.
  /// Перезагружает данные объявлений и категорий с флагом forceRefresh=true.
  Future<void> _onRefresh() async {
    context.read<ListingsBloc>().add(LoadListingsEvent(forceRefresh: true));
    // Небольшая задержка для имитации загрузки и показа индикатора
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Метод для поделиться приложением.
  /// Открывает системное меню поделиться с текстом приложения и ссылкой.
  Future<void> _shareApp() async {
    _isShareInProgress = true;
    try {
      await Share.share(
        'Присоединяйся к ЛИДЛ LIDLE! 🚀\n\n'
        'Удобный маркетплейс для покупки и продажи автомобилей, недвижимости и товаров.\n\n'
        'Скачай приложение и получи эксклюзивные предложения!\n\n'
        '${AppConfig().websiteUrl}',
        subject: 'LIDLE - маркетплейс изделий',
      );
    } catch (e) {
      // Обработка ошибок при поделиться
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось поделиться приложением'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      // Даём небольшую задержку перед сбросом флага
      await Future.delayed(const Duration(milliseconds: 500));
      _isShareInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 💾 Требуется для AutomaticKeepAliveClientMixin
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Если пользователь не авторизован, показываем экран входа
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
                            padding: const EdgeInsets.only(
                              bottom: 10,
                              right: 23,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Header(),
                                Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Защита от двойного клика
                                      if (_isShareInProgress) return;
                                      
                                      // Проверяем авторизацию перед поделиться
                                      if (authState is! AuthAuthenticated) {
                                        Navigator.pushNamed(
                                          context,
                                          SignInScreen.routeName,
                                        );
                                      } else {
                                        _shareApp();
                                      }
                                    },
                                    child: SvgPicture.asset(
                                      'assets/home_page/share_outlined.svg',
                                      width: 24,
                                      height: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 7.0,
                              right: 11.0,
                            ),
                            child: custom_widgets.SearchBarWidget(
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
                                // Проверяем авторизацию перед фильтрами
                                if (authState is! AuthAuthenticated) {
                                  Navigator.pushNamed(
                                    context,
                                    SignInScreen.routeName,
                                  );
                                  return;
                                }
                                await Navigator.pushNamed(
                                  context,
                                  FiltersScreen.routeName,
                                );
                              },
                              onMenuPressed: () {
                                // Проверяем авторизацию перед профилем
                                if (authState is! AuthAuthenticated) {
                                  Navigator.pushNamed(
                                    context,
                                    SignInScreen.routeName,
                                  );
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    ProfileMenuScreen.routeName,
                                  );
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _onRefresh,
                              color: accentColor,
                              backgroundColor: formBackground,
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (ScrollNotification scrollInfo) {
                                  // 🔍 Проверяем достигнут ли конец списка
                                  // Используем небольшой threshold (50px) вместо точного == для надежности
                                  final isNearEnd = scrollInfo.metrics.pixels >=
                                      (scrollInfo.metrics.maxScrollExtent - 100);

                                  if (isNearEnd) {
                                    final state = context.read<ListingsBloc>().state;
                                    
                                    if (state is ListingsLoaded) {
                                      // 📌 ИСПРАВЛЕНИЕ: Проверяем по количеству объявлений, а не по страницам
                                      // Это надежнее, т.к. мы не знаем точное количество страниц
                                      final canLoadMore = state.listings.length < 500;
                                      
                                      // ⏱️ Добавляем дебоунс на загрузку (минимум 3 секунды между запросами)
                                      final now = DateTime.now();
                                      final shouldLoadMore = _lastLoadMoreTime == null ||
                                          now.difference(_lastLoadMoreTime!) >= _loadMoreDebounce;
                                      
                                      if (canLoadMore && shouldLoadMore) {
                                        log.d('📥 Конец достигнут, загружаем еще... (текущих: ${state.listings.length})');
                                        _lastLoadMoreTime = now;
                                        context.read<ListingsBloc>().add(LoadNextPageEvent());
                                      }
                                    }
                                  }
                                  return false;
                                },
                                child: PageStorage(
                                  bucket: PageStorageBucket(),
                                  child: SingleChildScrollView(
                                    key: const PageStorageKey<String>('home_page_scroll'),
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                      _buildCategoriesSection(
                                        listingsState,
                                        authState,
                                      ),
                                      _buildLatestSection(
                                        listingsState,
                                        authState,
                                      ),
                                      SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: BottomNavigation(
                      onItemSelected: (index) {
                        // Проверяем авторизацию перед навигацией (кроме главной)
                        if (authState is! AuthAuthenticated && index != 0) {
                          Navigator.pushNamed(context, SignInScreen.routeName);
                          return;
                        }

                        if (index == 3) {
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
      },
    );
  }

  /// Приватный метод для построения секции категорий.
  /// Включает заголовок "Предложения на LIDLE", кнопку "Смотреть все"
  /// и горизонтальный список карточек категорий.
  Widget _buildCategoriesSection(ListingsState state, AuthState authState) {
    // Обработка ListingsInitial - показываем skeleton loading
    if (state is ListingsInitial) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: getCategoriesTitleSpans()),
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
                itemCount: 6,
                itemBuilder: (context, index) {
                  return const CategoryCardSkeleton();
                },
              ),
            ),
          ),
        ],
      );
    }

    if (state is ListingsLoading) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: getCategoriesTitleSpans()),
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

    // Ограничиваем до 3 категорий
    final displayCategories = filteredCategories.length > 4
        ? filteredCategories.sublist(0, 4)
        : filteredCategories.toList();

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
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: getCategoriesTitleSpans()),
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
            padding: const EdgeInsets.only(bottom: 5.0),
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
                              // Проверка авторизации перед взаимодействием
                              if (authState is! AuthAuthenticated) {
                                Navigator.pushNamed(
                                  context,
                                  SignInScreen.routeName,
                                );
                                return;
                              }

                              // Проверяем только на "Смотреть все"
                              final isViewAll =
                                  category.title.contains('Смотреть') ||
                                  category.title.contains('все') ||
                                  category.title.contains('View All');

                              if (isViewAll) {
                                // log.d('📍 Navigating to FullCategoryScreen');
                                Navigator.pushNamed(
                                  context,
                                  FullCategoryScreen.routeName,
                                );
                              } else {
                                // log.d();

                                // Если это основной каталог, передаем catalogId
                                // Если это подкатегория, передаем categoryId
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RealEstateListingsScreen(
                                          categoryId: category.isCatalog
                                              ? null
                                              : category.id,
                                          catalogId: category.isCatalog
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
  Widget _buildLatestSection(ListingsState state, AuthState authState) {
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

    // Обработка ListingsInitial
    if (state is ListingsInitial) {
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
                  itemCount: 6,
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
                  GridView.builder(
                    padding: const EdgeInsets.only(left: 12, right: 12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 0,
                      mainAxisExtent: tileHeight,
                    ),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      return ListingCard(
                        listing: listings[index],
                        authState: authState,
                        onBeforeNavigate: () {
                          // 💾 Сохраняем позицию скролла перед навигацией
                          if (_scrollController.hasClients) {
                            _globalScrollPosition = _scrollController.position.pixels;
                            log.d('💾 Сохранена позиция перед навигацией: $_globalScrollPosition');
                          }
                        },
                      );
                    },
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
