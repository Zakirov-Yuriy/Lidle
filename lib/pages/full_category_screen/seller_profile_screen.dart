import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/widgets/dialogs/report_user_dialog.dart';
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
import 'package:lidle/pages/add_listing/category_selection_screen.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';
import 'package:lidle/pages/full_category_screen/full_category_screen.dart';
import 'package:lidle/core/logger.dart';

// Профиль продавца: контакты (звонок), чат, избранное.
import 'package:lidle/widgets/dialogs/phone_dialog.dart';
import 'package:lidle/pages/messages/chat_page.dart';
import 'package:lidle/models/message_model.dart';

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
  final String? sellerRegistrationDate;

  const SellerProfileScreen({
    super.key,
    required this.sellerName,
    required this.sellerAvatar,
    this.sellerAvatarUrl,
    this.userId,
    this.sellerRegistrationDate,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  int selectedStars = 5;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _sellerListings = [];
  bool _isLoading = false;
  String? _error;

  // ── Данные профиля продавца (GET /v1/users/{id}) ──────────────────────
  bool _profileLoading = false;
  String? _description; // поле description (профильное about)
  String? _addressText; // собранная строка регион/город
  bool _isWishlisted = false; // подписан ли текущий пользователь
  int? _wishlistId; // id записи избранного (для отписки)
  bool _subscribing = false; // идёт запрос подписки/отписки
  List<String> _phones = [];
  List<String> _telegrams = [];
  List<String> _maxes = [];

  // Состояния «свёрнуто/развёрнуто» для секций.
  bool _descExpanded = true;
  bool _locExpanded = true;
  bool _contactsExpanded = true;

  /// TTL кеша объявлений продавца — 5 минут.
  static const _cacheTtl = Duration(minutes: 5);

  /// Сбросить кэш для конкретного продавца (например, после pull-to-refresh).
  static void invalidateCache(String userId) =>
      AppCacheService().invalidate(CacheKeys.sellerProfileKey(userId));

  /// Генерирует URL профиля продавца для шарингаnull
  /// Пример: https://lidle.io/ru/users/29/advertisements
  String _generateSellerProfileUrl() {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      // Если нет userId, возвращаем URL главной страницы
      return 'https://lidle.io/ru';
    }
    return 'https://lidle.io/ru/users/$userId/advertisements';
  }

  @override
  void initState() {
    super.initState();
    _loadSellerListings();
    _loadSellerProfile();
  }

  /// Безопасное приведение к int (для wishlist_id, приходящего как num).
  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Загружает профиль продавца (GET /v1/users/{id}): описание, адрес,
  /// признак избранного (is_wishlisted / wishlist_id) и контакты.
  Future<void> _loadSellerProfile() async {
    final id = int.tryParse(widget.userId ?? '');
    if (id == null) return;

    setState(() => _profileLoading = true);
    try {
      final token = TokenService.currentToken;
      // Возвращает уже data[0] (см. UserApi.getUserProfile), либо {} при ошибке.
      final data = await ApiService.getUserProfile(userId: id, token: token);

      if (data.isEmpty) {
        if (mounted) setState(() => _profileLoading = false);
        return;
      }

      // Описание.
      final descRaw = data['description'];
      final desc = (descRaw is String && descRaw.trim().isNotEmpty)
          ? descRaw.trim()
          : null;

      // Адрес: собираем строку из main_region / region / city (без дублей и null).
      final parts = <String>[];
      final address = data['address'];
      if (address is Map) {
        for (final key in ['main_region', 'region', 'city']) {
          final node = address[key];
          if (node is Map && node['name'] != null) {
            final name = node['name'].toString().trim();
            if (name.isNotEmpty && !parts.contains(name)) parts.add(name);
          }
        }
      }
      final addr = parts.isNotEmpty ? parts.join(', ') : null;

      // Избранное.
      final isWishlisted = data['is_wishlisted'] == true;
      final wishlistId = _asInt(data['wishlist_id']);

      // Контакты.
      final phones = <String>[];
      final telegrams = <String>[];
      final maxes = <String>[];
      final contacts = data['contacts'];
      if (contacts is Map) {
        for (final p in (contacts['phones'] as List? ?? const [])) {
          final v = (p is Map) ? p['phone'] : p;
          if (v != null && v.toString().trim().isNotEmpty) {
            phones.add(v.toString().trim());
          }
        }
        for (final t in (contacts['telegrams'] as List? ?? const [])) {
          final v = (t is Map) ? t['username'] : t;
          if (v != null && v.toString().trim().isNotEmpty) {
            telegrams.add(v.toString().trim());
          }
        }
        for (final m in (contacts['maxes'] as List? ?? const [])) {
          final v = (m is Map) ? m['username'] : m;
          if (v != null && v.toString().trim().isNotEmpty) {
            maxes.add(v.toString().trim());
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _description = desc;
        _addressText = addr;
        _isWishlisted = isWishlisted;
        _wishlistId = wishlistId;
        _phones = phones;
        _telegrams = telegrams;
        _maxes = maxes;
        _profileLoading = false;
      });
    } catch (e) {
      log.w('❌ SellerProfileScreen: ошибка загрузки профиля: $e');
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  /// Подписаться / отписаться от продавца (избранное компаний).
  /// POST /me/wishlist/add {user_id} — добавить; после добавления перечитываем
  /// профиль, чтобы получить wishlist_id для последующей отписки.
  /// DELETE /me/wishlist/destroy/{wishlist_id} — удалить.
  Future<void> _toggleSubscription() async {
    if (_subscribing) return;

    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы подписаться на продавца',
        avatarUrl: widget.sellerAvatarUrl,
      );
      return;
    }

    final id = int.tryParse(widget.userId ?? '');
    if (id == null) {
      SnackBarHelper.showError(context, 'Ошибка: ID продавца не найден');
      return;
    }

    setState(() => _subscribing = true);
    try {
      if (!_isWishlisted) {
        await ApiService.post('/me/wishlist/add', {'user_id': id}, token: token);
        // Ответ добавления не содержит id записи — перечитываем профиль.
        final data = await ApiService.getUserProfile(userId: id, token: token);
        final wid = _asInt(data['wishlist_id']);
        if (!mounted) return;
        setState(() {
          _isWishlisted = true;
          _wishlistId = wid;
          _subscribing = false;
        });
        SnackBarHelper.showSuccess(context, 'Вы подписались на продавца');
      } else {
        // Нужен id записи избранного; если его нет — перечитываем профиль.
        int? wid = _wishlistId;
        if (wid == null) {
          final data = await ApiService.getUserProfile(userId: id, token: token);
          wid = _asInt(data['wishlist_id']);
        }
        if (wid == null) {
          if (!mounted) return;
          setState(() => _subscribing = false);
          return;
        }
        await ApiService.delete('/me/wishlist/destroy/$wid', token: token);
        if (!mounted) return;
        setState(() {
          _isWishlisted = false;
          _wishlistId = null;
          _subscribing = false;
        });
        SnackBarHelper.showSuccess(context, 'Вы отписались от продавца');
      }
    } catch (e) {
      log.w('❌ SellerProfileScreen: ошибка подписки: $e');
      if (!mounted) return;
      setState(() => _subscribing = false);
      SnackBarHelper.showError(context, 'Не удалось изменить подписку');
    }
  }

  /// «Позвонить» — показывает диалог с телефонами продавца.
  void _callSeller() {
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы позвонить продавцу',
        avatarUrl: widget.sellerAvatarUrl,
      );
      return;
    }
    if (_phones.isEmpty) {
      SnackBarHelper.showWarning(context, 'У продавца не указан номер телефона');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => PhoneDialog(phoneNumbers: _phones),
    );
  }

  /// «Написать» — открывает чат с продавцом (без привязки к объявлению).
  void _writeSeller() {
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы написать продавцу',
        avatarUrl: widget.sellerAvatarUrl,
      );
      return;
    }
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      SnackBarHelper.showWarning(context, 'Информация о продавце недоступна');
      return;
    }
    final message = Message(
      senderName: widget.sellerName,
      senderAvatar: widget.sellerAvatarUrl,
      lastMessageTime: 'сейчас',
      unreadCount: 0,
      isInternal: true,
      isCompany: false,
      userId: userId,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(message: message)),
    );
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
              _loadSellerProfile();
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
            await Future.wait([
              _loadSellerListings(forceRefresh: true),
              _loadSellerProfile(),
            ]);
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

                      const SizedBox(height: 20),
                      _buildDescriptionSection(),
                      _buildLocationSection(),
                      _buildContactsSection(),

                      const SizedBox(height: 6),
                      _buildRateSeller(),

                      const SizedBox(height: 16),
                      _buildCallWriteButtons(),

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
            final profileUrl = _generateSellerProfileUrl();
            Share.share(
              'Профиль продавца: ${widget.sellerName}\n\n'
              'Присоединяйся к LIDLE! 🚀\n\n'
              'Удобный маркетплейс для покупки и продажи автомобилей, недвижимости и товаров.\n\n'
              '$profileUrl',
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
            _buildSellerAvatar(widget.sellerAvatarUrl),
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
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'На ЛИДЛ ',
                            style: const TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          // TextSpan(
                          //   text: 'LIDLE',
                          //   style: const TextStyle(color: activeIconColor, fontSize: 10),
                          // ),
                          TextSpan(
                            text: ' с ${RegExp(r'\d{4}').firstMatch(widget.sellerRegistrationDate ?? '')?.group(0) ?? '2024'} г.',
                            style: const TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Оценка: ",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(" 5", style: TextStyle(color: textPrimary)),
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
              side: BorderSide(
                color: _isWishlisted ? textSecondary : Colors.lightBlue,
              ),
              backgroundColor:
                  _isWishlisted ? Colors.lightBlue.withValues(alpha: 0.12) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _subscribing ? null : _toggleSubscription,
            child: _subscribing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                    ),
                  )
                : Text(
                    _isWishlisted
                        ? "Вы подписаны"
                        : "Подписаться на продавца",
                    style: TextStyle(
                      color: _isWishlisted ? textPrimary : Colors.lightBlue,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Универсальная сворачиваемая секция (Описание/Расположение/Контакты).
  Widget _buildCollapsibleSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(width: double.infinity, child: child),
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _buildCollapsibleSection(
      title: 'Описание',
      expanded: _descExpanded,
      onToggle: () => setState(() => _descExpanded = !_descExpanded),
      child: Text(
        _profileLoading && _description == null
            ? 'Загрузка...'
            : (_description ?? 'Описание отсутствует'),
        style: const TextStyle(color: textSecondary, fontSize: 15, height: 1.4),
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildCollapsibleSection(
      title: 'Расположение',
      expanded: _locExpanded,
      onToggle: () => setState(() => _locExpanded = !_locExpanded),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: textSecondary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _profileLoading && _addressText == null
                  ? 'Загрузка...'
                  : (_addressText ?? 'Не указано'),
              style: const TextStyle(color: textPrimary, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSection() {
    final hasAny =
        _phones.isNotEmpty || _telegrams.isNotEmpty || _maxes.isNotEmpty;

    // Показываем только два последних номера.
    final visiblePhones =
        _phones.length > 2 ? _phones.sublist(_phones.length - 2) : _phones;

    Widget contactLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            text,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        );

    Widget contactValue(String text, {bool link = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              color: link ? activeIconColor : textPrimary,
              fontSize: 15,
            ),
          ),
        );

    // Колонка мессенджера (Телеграм / MAX): метка + значения.
    Widget messengerColumn(String label, List<String> values) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            contactLabel(label),
            for (final v in values) contactValue(v, link: true),
          ],
        );

    final children = <Widget>[];
    if (visiblePhones.isNotEmpty) {
      children.add(contactLabel('Номер'));
      for (final p in visiblePhones) {
        children.add(contactValue(p));
      }
    }
    // Телеграм и MAX — в две колонки рядом (как на макете).
    if (_telegrams.isNotEmpty || _maxes.isNotEmpty) {
      children.add(const SizedBox(height: 6));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _telegrams.isNotEmpty
                  ? messengerColumn('Телеграм', _telegrams)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _maxes.isNotEmpty
                  ? messengerColumn('MAX', _maxes)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return _buildCollapsibleSection(
      title: 'Контакты',
      expanded: _contactsExpanded,
      onToggle: () => setState(() => _contactsExpanded = !_contactsExpanded),
      child: hasAny
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            )
          : Text(
              _profileLoading ? 'Загрузка...' : 'Контакты не указаны',
              style: const TextStyle(color: textSecondary, fontSize: 15),
            ),
    );
  }

  /// Кнопки «Позвонить» (зелёная) и «Написать» (синяя).
  Widget _buildCallWriteButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _callSeller,
            child: const Text(
              'Позвонить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeIconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _writeSeller,
            child: const Text(
              'Написать',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  "Оставить оценку продавцу",
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Сердечко = добавить/убрать продавца из избранного.
              // Синхронизировано с кнопкой «Подписаться на продавца»
              // (единый механизм избранного на бэке).
              _subscribing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.redAccent),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _toggleSubscription,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        _isWishlisted
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _isWishlisted ? Colors.redAccent : textSecondary,
                        size: 28,
                      ),
                    ),
            ],
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
              final token = TokenService.currentToken;
              if (token == null || token.isEmpty) {
                // ❌ Неавторизованный пользователь не может оставить жалобу
                SnackBarHelper.showAuthRequired(
                  context,
                  'Войдите в свой профиль или создайте новый, чтобы продолжить',
                );
                return;
              }
              
              // ✅ Авторизованный пользователь может оставить жалобу на продавца
              final userId = widget.userId != null ? int.tryParse(widget.userId!) : null;
              if (userId == null) {
                SnackBarHelper.showError(
                  context,
                  'Ошибка: ID продавца не найден',
                );
                return;
              }
              
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return ReportUserDialog(
                    userId: userId,
                    userName: widget.sellerName,
                  );
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
          final wasNavigated = _navigateToScreen(index);
          // Обновляем индекс только если навигация была успешна
          if (wasNavigated) {
            setState(() => _selectedIndex = index);
          }
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
          final wasNavigated = _navigateToScreen(index);
          // Обновляем индекс только если навигация была успешна
          if (wasNavigated) {
            setState(() => _selectedIndex = index);
          }
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

  /// Переходит на экран с индексом [index].
  /// Возвращает [true] если навигация была успешна, [false] если авторизация отклонена.
  bool _navigateToScreen(int index) {
    // Индексы 2, 3, 4, 5 требуют авторизацию
    final authRequiredIndices = {2, 3, 4, 5};
    
    if (authRequiredIndices.contains(index)) {
      final token = TokenService.currentToken;
      if (token == null || token.isEmpty) {
        // ❌ Неавторизованный пользователь не может перейти на эти экраны
        SnackBarHelper.showAuthRequired(
          context,
          'Войдите в свой профиль или создайте новый, чтобы продолжить',
        );
        return false; // Навигация отклонена
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
        routeName = CategorySelectionScreen.routeName;
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
        return false;
    }
    
    return true; // Навигация успешна
  }

  /// Вспомогательный метод для безопасного отображения аватара продавца
  /// Поддерживает: сетевые изображения (PNG, JPG), локальные ассеты и SVG файлы
  /// При ошибке загрузки сетевого изображения показывает дефолтную SVG аватарку
  Widget _buildSellerAvatar(String? avatarUrl) {
    final defaultAvatar = 'assets/profile_dashboard/default-photo.svg';
    
    // Если нет аватарки или URL пуст - показываем дефолтную SVG
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultAvatarContainer();
    }
    
    // Для SVG файлов используем SvgPicture
    if (avatarUrl.endsWith('.svg')) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: formBackground,
        ),
        child: ClipOval(
          child: SvgPicture.asset(
            avatarUrl,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => Container(
              color: formBackground,
            ),
          ),
        ),
      );
    }
    
    // Для сетевых изображений с fallback на дефолтную аватарку
    if (avatarUrl.startsWith('http')) {
      return ClipOval(
        child: SizedBox(
          width: 76,
          height: 76,
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              log.w('❌ Failed to load avatar from: $avatarUrl, using default');
              return _buildDefaultAvatarContainer();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: formBackground,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Для локальных растровых изображений (PNG, JPG)
    return ClipOval(
      child: SizedBox(
        width: 76,
        height: 76,
        child: Image.asset(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            log.w('❌ Failed to load local avatar from: $avatarUrl, using default');
            return _buildDefaultAvatarContainer();
          },
        ),
      ),
    );
  }

  /// Вспомогательный метод для отображения дефолтной аватарки
  Widget _buildDefaultAvatarContainer() {
    const defaultAvatar = 'assets/profile_dashboard/default-photo.svg';
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: formBackground,
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          defaultAvatar,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => Container(
            color: formBackground,
          ),
        ),
      ),
    );
  }
}
