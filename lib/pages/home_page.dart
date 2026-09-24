import 'dart:async';
// ============================================================
// "Виджет: Главная страница приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../widgets/components/lidle_title_spans.dart';
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
import 'package:lidle/services/companies_search_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/wishlist_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';

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

    // 🚀 ОПТИМИЗАЦИЯ: Отложить загрузку после отрисовки UI
    // Это позволяет показать скелетоны немедленно вместо замороженного экрана
    if (currentState is ListingsInitial || currentState is ListingsError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ListingsBloc>().add(LoadListingsEvent());
      });
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
        // log.d('📋 Восстановлена глобальная позиция скролла: $_globalScrollPosition');
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
    // log.d('⬅️ Вернулись на HomePage');
    
    // 🟢 СЛОЙ 1: Восстанавливаем ИЗ КЕША (если доступны данные)
    // Даже если API не отвечает, пользователь видит кешированные данные
    final bloc = context.read<ListingsBloc>();
    final cachedState = bloc.restoreCachedData();
    
    if (cachedState != null) {
      // ✅ Есть кеш - восстанавливаем сразу (избегаем состояния ListingsLoading)
      // log.d('✅ Восстановлены кешированные данные');
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

  /// Что сейчас введено в поиске. Нужно, чтобы обновление ленты не сбрасывало
  /// поиск: в строке осталось слово, а выдача менялась на обычную ленту
  /// (24.09.2026).
  String _searchQuery = '';

  /// Метод для обработки pull-to-refresh.
  /// Перезагружает данные объявлений и категорий с флагом forceRefresh=true.
  Future<void> _onRefresh() async {
    final query = _searchQuery.trim();

    if (query.isNotEmpty) {
      // В поиске что-то введено: повторяем поиск, а не возвращаем ленту.
      context.read<ListingsBloc>().add(SearchListingsEvent(query: query));
    } else {
      context.read<ListingsBloc>().add(LoadListingsEvent(forceRefresh: true));
    }

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
                                      
                                      // Разрешаем делиться приложением всем пользователям
                                      _shareApp();
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
                                _searchQuery = query;

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
                                      // Спрашиваем у состояния, есть ли ещё
                                      // что добирать. Раньше здесь стояло
                                      // «меньше 500 штук», и когда лента
                                      // упиралась в потолок, экран каждые три
                                      // секунды перезапрашивал одну и ту же
                                      // страницу впустую.
                                      final canLoadMore = state.hasMore &&
                                          state.listings.length <
                                              ListingsBloc.homeFeedLimit;

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
                        // Авторизация проверяется внутри BottomNavigation
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

    // Не загрузилось — показываем ТО ЖЕ, что при загрузке (16.09.2026).
    //
    // Красный восклицательный знак с кнопкой «Повторить» человек видел чаще,
    // чем саму главную. Он всё равно ничего не чинит этой кнопкой: связь
    // возвращается сама, а приложение теперь повторяет попытку само, с
    // нарастающей паузой. Поэтому здесь скелетоны и одна спокойная строка
    // внизу, без красного.
    if (state is ListingsError) {
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
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
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
          const _WaitingForConnection(),
          const SizedBox(height: 12),
        ],
      );
    }

    final categories = (state is ListingsLoaded)
        ? state.categories
        : (state is ListingsSearchResults)
        ? state.categories
        : <Category>[];

    // Отфильтруем категории, исключив служебную карточку «Смотреть все».
    //
    // Раньше здесь стояла проверка по словам в названии, и она выбрасывала
    // из списка настоящий каталог «Работа и вакансии ВСЕХ сфере
    // специальностях»: в слове «всех» есть подстрока «все». Опознаём
    // карточку по явному признаку.
    final filteredCategories = categories.where((cat) => !cat.isViewAll).toList();

    // Ограничиваем до 3 категорий
    final displayCategories = filteredCategories.length > 4
        ? filteredCategories.sublist(0, 4)
        : filteredCategories.toList();

    // Добавляем «Смотреть все» в конец, если карточка есть в исходном списке.
    final viewAllCategory = categories.firstWhere(
      (cat) => cat.isViewAll,
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
                              // Неавторизованный пользователь может просматривать
                              // категории. Отдельно обрабатываем только служебную
                              // карточку «Смотреть все»: по явному признаку, а не
                              // по словам в названии — иначе каталог со словом
                              // «всех» открывал бы не тот экран.
                              if (category.isViewAll) {
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
                                          catalogName: category.isCatalog ? category.title : null, // 🎯 Если это каталог, передаём его название
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
  /// Подпись «лента по вашему городу» и кнопка сброса (задача 70).
  ///
  /// Город берётся из профиля, а человек мог указать его когда-то и забыть.
  /// Без подписи выдача выглядит просто странной: «почему у меня всё из
  /// Мариуполя». Сбрасывать надо там же, где виден результат, а не в глубине
  /// настроек, поэтому кнопка стоит прямо над лентой. На сайте она уже есть,
  /// и логика теперь одинаковая.
  /// Сердечко на карточке компании: подписка на магазин (24.09.2026).
  ///
  /// Хранится там же, где избранные магазины экрана «Моё избранное»
  /// (`/me/wishlist` с `user_id`), поэтому отмеченное здесь видно и там.
  Future<void> _toggleCompanyWishlist(CompanySearchItem company) async {
    final token = TokenService.currentToken;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в свой профиль, чтобы добавлять магазины в избранное',
      );

      return;
    }

    final wasAdded = company.isWishlisted;

    // Сердечко закрашиваем сразу, ответ сервера догоняет: иначе нажатие
    // выглядит как «не сработало».
    setState(() {
      company.isWishlisted = !wasAdded;
    });

    try {
      if (wasAdded) {
        final id = company.wishlistId;

        if (id != null) {
          await WishlistService.removeFromWishlist(advertId: id, token: token);
        }

        company.wishlistId = null;
      } else {
        final response = await WishlistService.addToWishlist(
          companyId: company.userId,
          token: token,
        );

        company.wishlistId = (response['wishlist_id'] as num?)?.toInt();
      }
    } catch (e) {
      log.e('❌ Избранное магазина: $e');

      if (mounted) {
        setState(() => company.isWishlisted = wasAdded);
      }
    }
  }

  /// Нажали на карточку компании в результатах поиска: открываем её витрину
  /// (задача 28, 24.09.2026).
  void _openCompany(CompanySearchItem company) {
    final url = company.image;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerName: company.name,
          sellerAvatar: url != null && url.startsWith('http')
              ? NetworkImage(url) as ImageProvider
              : const AssetImage('assets/profile_dashboard/default-photo.svg'),
          sellerAvatarUrl: url,
          userId: '${company.userId}',
        ),
      ),
    );
  }

  Widget _buildFeedCityNotice(String cityName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 16, color: textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Сначала показываем ваш город: $cityName',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () {
              context.read<ListingsBloc>().add(const ResetFeedCityEvent());
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Сбросить',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

    // Не загрузилось — скелетоны вместо красной ошибки (16.09.2026),
    // объяснение выше, в блоке категорий.
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
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 24 - 9) / 2;
              double tileHeight = 330;
              if (itemWidth < 160) tileHeight = 315;
              if (itemWidth < 140) tileHeight = 300;

              return GridView.builder(
                padding: const EdgeInsets.only(left: 12, right: 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 0,
                  mainAxisExtent: tileHeight,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return const ListingCardSkeleton();
                },
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              );
            },
          ),
          const _WaitingForConnection(),
          const SizedBox(height: 110),
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

    // Компании и магазины, найденные по той же строке (задача 28,
    // 24.09.2026): человек ищет «ZAC» и должен увидеть саму компанию.
    final companies = state is ListingsSearchResults && _searchQuery.trim().isNotEmpty
        ? state.companies
        : const <CompanySearchItem>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 110.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (companies.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Компании и магазины',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Плитками по две в ряд, как объявления (24.09.2026).
            LayoutBuilder(
              builder: (context, constraints) {
                // Ровно те же размеры, что у плитки объявления ниже: карточки
                // стоят в одном списке и обязаны быть одинаковыми.
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
                  itemCount: companies.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) => _CompanySearchCard(
                    company: companies[index],
                    onTap: () => _openCompany(companies[index]),
                    onWishlist: () => _toggleCompanyWishlist(companies[index]),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
          ],
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
          if (state is ListingsLoaded && state.feedCityName != null)
            _buildFeedCityNotice(state.feedCityName!),
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
                        countImpression: true,
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
                  // 🔘 Показываем кнопку "Показать больше объявлений" если >= 24 объявлений
                  if (listings.length >= 24)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 20,
                        bottom: 0,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            // 💾 Сохраняем позицию скролла перед навигацией
                            if (_scrollController.hasClients) {
                              _globalScrollPosition = _scrollController.position.pixels;
                              log.d('💾 Сохранена позиция перед навигацией: $_globalScrollPosition');
                            }
                            // ➡️ Переходим на экран со всеми объявлениями
                            Navigator.pushNamed(
                              context,
                              FullCategoryScreen.routeName,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: accentColor,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          // Текст в одну строку с адаптивным размером: на
                          // широких экранах — 16px, на узких FittedBox
                          // пропорционально уменьшает его, чтобы влез без
                          // переноса и остался по центру кнопки.
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Показать больше 100 тыс. объявлений',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
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

/// Спокойная строка «связи нет, сами повторим» под скелетонами главной.
///
/// Появляется не сразу: короткий провал связи лечится повторной попыткой за
/// пару секунд, и сообщать о нём человеку незачем. Если через три секунды
/// главная всё ещё пуста, честно говорим, что ждём связь, и продолжаем
/// пробовать сами. Кнопки «Повторить» здесь намеренно нет: она перекладывает
/// на человека работу, которую приложение делает само.
class _WaitingForConnection extends StatefulWidget {
  const _WaitingForConnection();

  @override
  State<_WaitingForConnection> createState() => _WaitingForConnectionState();
}

class _WaitingForConnectionState extends State<_WaitingForConnection> {
  bool _visible = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Обновляем ленту, связь слабая',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка компании в результатах поиска (задача 28, 24.09.2026).
///
/// Выглядит как строка магазина: вывеска, название, город и описание. По
/// нажатию открывается витрина продавца, та же, что из объявления.
class _CompanySearchCard extends StatelessWidget {
  const _CompanySearchCard({
    required this.company,
    required this.onTap,
    required this.onWishlist,
  });

  final CompanySearchItem company;
  final VoidCallback onTap;
  final VoidCallback onWishlist;

  @override
  Widget build(BuildContext context) {
    // Вёрстка повторяет ListingCard: те же пропорции картинки, то же
    // скругление и то же сердечко без подложки (24.09.2026).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;
        final scale = cardHeight / 263;

        final imageProportion = cardWidth < 140 ? 0.50 : 0.58;
        final imageHeight = cardHeight * imageProportion;

        final about = company.about;
        final city = company.city;
        final image = company.image;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: imageHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5 * scale),
                        child: image == null || image.isEmpty
                            ? Container(
                                color: formBackground,
                                alignment: Alignment.center,
                                child: Text(
                                  company.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 34 * scale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : Image.network(image, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: onWishlist,
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          company.isWishlisted ? Icons.favorite : Icons.favorite_border,
                          color: company.isWishlisted ? Colors.red : textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (city != null) ...[
                      SizedBox(height: 3 * scale),
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textSecondary, fontSize: 13 * scale),
                      ),
                    ],
                    if (about != null) ...[
                      SizedBox(height: 3 * scale),
                      // Описание в две строки с троеточием, а не «сколько
                      // влезло»: раньше Expanded резал текст по высоте, и
                      // снизу торчали половинки букв (24.09.2026).
                      Flexible(
                        child: Text(
                          about,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12 * scale,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      company.advertsCount > 0
                          ? 'Объявлений: ${company.advertsCount}'
                          : 'Пока без объявлений',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 12 * scale),
                    ),
                    SizedBox(height: 8 * scale),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
