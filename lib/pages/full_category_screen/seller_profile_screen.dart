import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/widgets/dialogs/complaint_dialog.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/core/config/app_config.dart';

// Navigation targets used by bottom navigation
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/pages/add_listing/add_listing_screen.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';
import 'package:lidle/pages/full_category_screen/full_category_screen.dart';
import 'package:lidle/core/logger.dart';

// ============================================================
// "Экран профиля продавца"
// ============================================================

const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

class SellerProfileScreen extends StatefulWidget {
  static const String routeName = "/seller-profile";

  final String sellerName;
  final ImageProvider sellerAvatar;

  /// URL аватарки продавца в виде строки (для передачи в дочерние экраны).
  /// Может быть http-ссылкой или путём к ассету.
  final String? sellerAvatarUrl;
  final String? userId;

  const SellerProfileScreen({
    super.key,
    required this.sellerName,
    required this.sellerAvatar,
    this.sellerAvatarUrl,
    this.userId,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  int selectedStars = 1;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _sellerListings = [];
  bool _isLoading = false;
  String? _error;

  /// TTL кеша объявлений продавца — 5 минут.
  static const _cacheTtl = Duration(minutes: 5);

  /// Сбросить кэш для конкретного продавца (например, после pull-to-refresh).
  static void invalidateCache(String userId) =>
      AppCacheService().invalidate(CacheKeys.sellerProfileKey(userId));

  @override
  void initState() {
    super.initState();
    _loadSellerListings();
  }

  /// Загружает объявления продавца из API по userId.
  /// При повторном открытии экрана возвращает данные из кэша мгновенно.
  /// [forceRefresh] = true — игнорирует кэш и запрашивает заново (pull-to-refresh).
  Future<void> _loadSellerListings({bool forceRefresh = false}) async {
    // Если нет userId, не загружаем
    if (widget.userId == null || widget.userId!.isEmpty) {
      setState(() {
        _sellerListings = [];
        _isLoading = false;
      });
      return;
    }

    final userId = widget.userId!;

    // Возвращаем кэш, если есть и не требуется обновление (AppCacheService сам проверяет TTL)
    if (!forceRefresh) {
      final cachedList = AppCacheService().get<List<Map<String, dynamic>>>(
        CacheKeys.sellerProfileKey(userId),
      );
      if (cachedList != null) {
        setState(() {
          _sellerListings = cachedList;
          _isLoading = false;
        });
        return;
      }
    }

    log.d('✅ SellerProfileScreen: загрузка с API');
    log.d('   userId: $userId');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ Неавторизованный пользователь может просмотреть объявления продавца
      // Токен опциональный — API обработает запрос без авторизации
      final token = TokenService.currentToken;

      // API фиксирует per_page=30 и не принимает этот параметр в body.
      // Запрос принимает только: sort (Array) и page (Integer).
      // Чтобы получить все объявления — загружаем страницы последовательно.

      final allData = <dynamic>[];

      // Шаг 1: загружаем первую страницу и читаем meta.last_page
      final firstPageBody = {
        'sort': ['new'],
        'page': 1,
      };

      final firstResponse = await ApiService.getWithBody(
        '/users/$userId/adverts',
        firstPageBody,
        token: token,
      );

      final firstPageData = firstResponse['data'] as List<dynamic>? ?? [];
      allData.addAll(firstPageData);

      // Читаем общее количество страниц из meta
      final meta = firstResponse['meta'] as Map<String, dynamic>?;
      final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;

      // Шаг 2: загружаем остальные страницы, если они есть
      if (lastPage > 1) {
        for (int page = 2; page <= lastPage; page++) {
          final pageBody = {
            'sort': ['new'],
            'page': page,
          };
          final pageResponse = await ApiService.getWithBody(
            '/users/$userId/adverts',
            pageBody,
            token: token,
          );
          final pageData = pageResponse['data'] as List<dynamic>? ?? [];
          allData.addAll(pageData);
        }
      }

      final data = allData;

      if (data.isEmpty) {
        setState(() {
          _sellerListings = [];
          _isLoading = false;
        });
        return;
      }

      // Трансформируем API ответ в формат для Listing.
      // Фильтруем до маппинга — берём только активные (status.id == 1).
      final listings = data
          .whereType<Map<String, dynamic>>()
          .where(
            (item) => (item['status'] as Map<String, dynamic>?)?['id'] == 1,
          )
          .map((item) {
            // Конвертируем API формат в формат для Listing.fromJson()
            // ВАЖНО: fromJson читает 'image', не 'imagePath'
            final thumbnail = item['thumbnail'] as String?;
            return <String, dynamic>{
              'id': item['id']?.toString() ?? '',
              'image': thumbnail ?? '', // fromJson использует 'image'
              'images': thumbnail != null && thumbnail.isNotEmpty
                  ? [thumbnail]
                  : <String>[],
              'title': item['name'] ?? '',
              'price': item['price']?.toString() ?? '0',
              'address': item['address'] ?? '',
              'date': item['date'] ?? '',
              'characteristics': {},
              'sellerName': widget.sellerName,
              'userId': widget.userId,
              // Передаём URL аватарки строкой — MiniPropertyDetailsScreen
              // читает это поле через Listing.fromJson() как sellerAvatar
              'sellerAvatar': widget.sellerAvatarUrl,
              'description': null,
              'isFavorited': item['is_wishlisted'] ?? false,
            };
          })
          .toList();

      log.d('✅ Трансформировано ${listings.length} объявлений');

      // 💾 Сохраняем в AppCacheService (TTL 5 мин) — следующее открытие экрана
      // отдаст данные мгновенно без обращения к API
      AppCacheService().set<List<Map<String, dynamic>>>(
        CacheKeys.sellerProfileKey(userId),
        listings,
        ttl: _cacheTtl,
      );

      setState(() {
        _sellerListings = listings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка при загрузке объявлений: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        // Когда интернет восстановлен - перезагружаем объявления продавца
        if (connectivityState is ConnectedState) {
          // ⏳ Добавляем задержку для стабилизации соединения
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && widget.userId != null) {
              _SellerProfileScreenState.invalidateCache(widget.userId!);
              _loadSellerListings(forceRefresh: true);
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          // Показываем экран отсутствия интернета
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(
              onRetry: () {
                context.read<ConnectivityBloc>().add(
                  const CheckConnectivityEvent(),
                );
              },
            );
          }

          // Показываем обычный контент
          return Scaffold(
      backgroundColor: primaryBackground,
      bottomNavigationBar: _buildBottomNavigation(),
      body: SafeArea(
        // RefreshIndicator позволяет пользователю свайпом вниз
        // принудительно обновить список (сбрасывает кэш для этого продавца)
        child: RefreshIndicator(
          color: activeIconColor,
          onRefresh: () async {
            if (widget.userId != null) {
              _SellerProfileScreenState.invalidateCache(widget.userId!);
            }
            await _loadSellerListings(forceRefresh: true);
          },
          child: SingleChildScrollView(
            // AlwaysScrollable нужен, чтобы RefreshIndicator работал
            // даже когда контент меньше экрана
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, left: 8),
                  child: const Header(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    children: [
                      _buildHeader(),

                      const SizedBox(height: 31),
                      _buildSellerInfo(),

                      const SizedBox(height: 18),
                      _buildRateSeller(),

                      const SizedBox(height: 25),
                      Row(children: [_buildListingsTitle()]),
                      const SizedBox(height: 16),

                      _buildListingsGrid(),

                      const SizedBox(height: 36),
                      _buildComplaintBlock(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ), // SingleChildScrollView
        ), // RefreshIndicator
      ), // SafeArea
    );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back_ios,
                color: activeIconColor,
                size: 16,
              ),
              const SizedBox(
                width: 4,
              ), // Небольшой отступ между иконкой и текстом
              const Text(
                'Назад',
                style: TextStyle(
                  color: activeIconColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        IconButton(
          icon: SvgPicture.asset(
            'assets/home_page/share_outlined.svg',
            width: 23,
            height: 23,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () {
            Share.share(
              'Профиль продавца: ${widget.sellerName}\n\n'
              'Присоединяйся к LIDLE! 🚀\n\n'
              'Удобный маркетплейс для покупки и продажи автомобилей, недвижимости и товаров.\n\n'
              '${AppConfig().websiteUrl}',
            );
          },
        ),
      ],
    );
  }

  Widget _buildSellerInfo() {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(radius: 38, backgroundImage: widget.sellerAvatar),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sellerName,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Text(
                      "На ЛИДЛ с 2024 г.",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Оценка: ",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(" 4", style: TextStyle(color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Проверенный продавец",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 14),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 15),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.lightBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {},
            child: const Text(
              "Подписаться на продавца",
              style: TextStyle(color: Colors.lightBlue, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateSeller() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Оставить оценку продавцу",
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Вы можете оставить оценку продавцу это поднимет его рейтинг.",
            style: TextStyle(color: textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 11),

          const Text(
            "Оценка:",
            style: TextStyle(color: textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 6),

          Row(
            children: List.generate(
              5,
              (index) => GestureDetector(
                onTap: () => setState(() => selectedStars = index + 1),
                child: Icon(
                  Icons.star,
                  color: index < selectedStars ? Colors.amber : Colors.grey,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTitle() {
    return const Text(
      "Объявления продавца",
      style: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildListingsGrid() {
    // Если идёт загрузка
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Загрузка объявлений...',
                style: TextStyle(color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Если была ошибка
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    // Если нет объявлений
    if (_sellerListings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: const [
              Icon(Icons.inbox, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                'Объявления отсутствуют',
                style: TextStyle(color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Отображаем сетку объявлений
    return GridView.builder(
      itemCount: _sellerListings.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 8,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (_, i) =>
          ListingCard(listing: Listing.fromJson(_sellerListings[i])),
    );
  }

  Widget _buildComplaintBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 25, left: 22, bottom: 12, right: 10),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Оставить жалобу на продавца",
            style: TextStyle(color: textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text:
                  "Вы можете оставить жалобу на продавца в случае нарушения им ",
              style: const TextStyle(color: textSecondary, fontSize: 15),
              children: [
                TextSpan(
                  text: "правил",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                ),
                TextSpan(
                  text: ".",
                  style: const TextStyle(color: textSecondary, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),

          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const ComplaintDialog();
                },
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  "Пожаловаться",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.red,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String iconPath, int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          setState(() => _selectedIndex = index);
          _navigateToScreen(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(13.5),
          child: Image.asset(
            iconPath,
            width: 28,
            height: 28,
            color: isSelected ? activeIconColor : inactiveIconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAdd(int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          setState(() => _selectedIndex = index);
          _navigateToScreen(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(13.5),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Image.asset(
              plusIconAsset,
              width: 28,
              height: 28,
              color: isSelected ? activeIconColor : inactiveIconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, bottomNavPaddingBottom),
        child: Container(
          height: bottomNavHeight,
          decoration: BoxDecoration(
            color: bottomNavBackground,
            borderRadius: BorderRadius.circular(37.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(homeIconAsset, 0, _selectedIndex),
              _buildNavItem(gridIconAsset, 1, _selectedIndex),
              _buildCenterAdd(2, _selectedIndex),
              _buildNavItem(shoppingCartAsset, 3, _selectedIndex),
              _buildNavItem(messageIconAsset, 4, _selectedIndex),
              _buildNavItem(userIconAsset, 5, _selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(int index) {
    // Индексы 2, 3, 4, 5 требуют авторизацию
    final authRequiredIndices = {2, 3, 4, 5};
    
    if (authRequiredIndices.contains(index)) {
      final token = TokenService.currentToken;
      if (token == null || token.isEmpty) {
        // ❌ Неавторизованный пользователь не может перейти на эти экраны
        SnackBarHelper.showWarning(context, 'Требуется авторизация');
        return;
      }
    }

    final String routeName;
    switch (index) {
      case 0:
        routeName = HomePage.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 1:
        routeName = FullCategoryScreen.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 2:
        routeName = AddListingScreen.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 3:
        routeName = MyPurchasesScreen.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 4:
        routeName = MessagesPage.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 5:
        routeName = ProfileDashboard.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      default:
        return;
    }
  }
}
