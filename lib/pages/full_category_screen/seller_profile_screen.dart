import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:lidle/services/user_service.dart';
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
  String? _registrationDate; // дата регистрации (created_at, формат дд.мм.гггг)
  bool _isWishlisted = false; // подписан ли текущий пользователь
  int? _wishlistId; // id записи избранного (для отписки)
  bool _subscribing = false; // идёт запрос подписки/отписки
  List<String> _phones = [];
  List<String> _telegrams = [];
  List<String> _maxes = [];

  // Состояния «свёрнуто/развёрнуто» для секций.
  // По умолчанию все секции ЗАКРЫТЫ.
  bool _descExpanded = false;
  bool _locExpanded = false;
  bool _contactsExpanded = false;
  // Блок «Поделиться компанией» по умолчанию свёрнут (как остальные секции).
  bool _shareExpanded = false;

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

  /// true — если открыт СОБСТВЕННЫЙ профиль текущего пользователя.
  /// Только в этом случае показываем подсказку «Заполните поля» и ведём
  /// на экран редактирования контактных данных (чужие профили не трогаем).
  bool get _isOwnProfile {
    final me = UserService.getLocal('userId')?.toString().trim();
    final viewing = widget.userId?.trim();
    return me != null &&
        me.isNotEmpty &&
        viewing != null &&
        viewing.isNotEmpty &&
        me == viewing;
  }

  /// Открывает экран «Контактные данные» для заполнения профиля.
  /// После возврата перечитывает профиль, чтобы подсказка исчезла, если
  /// пользователь заполнил поля.
  void _openContactDataEditor() {
    Navigator.of(context).pushNamed('/contact_data').then((_) {
      if (mounted) _loadSellerProfile();
    });
  }

  /// Маскирует номер телефона для показа в профиле: оставляет только код
  /// страны и код оператора (например «+7 949»), остальное скрывает
  /// звёздочками — «+7 949 ***-**-**». Реальный номер пользователь получает
  /// по кнопке «Позвонить».
  String _maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    // Отбрасываем код страны (7/8), если номер полной длины.
    final rest = (digits.startsWith('7') || digits.startsWith('8')) &&
            digits.length > 10
        ? digits.substring(1)
        : digits;
    final code = rest.length >= 3 ? rest.substring(0, 3) : '';
    return code.isNotEmpty ? '+7 $code ***-**-**' : '+7 ***-**-**';
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

      // Дата регистрации продавца (created_at приходит как "дд.мм.гггг").
      final createdRaw = data['created_at'];
      final registrationDate =
          (createdRaw is String && createdRaw.trim().isNotEmpty)
              ? createdRaw.trim()
              : null;

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
        _registrationDate = registrationDate;
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

    // Оптимистично переключаем состояние сразу (как на главном экране) —
    // без лоадера. При ошибке откатываем.
    final wasWishlisted = _isWishlisted;
    final prevWishlistId = _wishlistId;
    setState(() {
      _isWishlisted = !wasWishlisted;
      _subscribing = true;
    });

    try {
      if (!wasWishlisted) {
        await ApiService.post('/me/wishlist/add', {'user_id': id}, token: token);
        // Ответ добавления не содержит id записи — перечитываем профиль.
        final data = await ApiService.getUserProfile(userId: id, token: token);
        final wid = _asInt(data['wishlist_id']);
        if (!mounted) return;
        setState(() {
          _wishlistId = wid;
          _subscribing = false;
        });
      } else {
        // Нужен id записи избранного; если его нет — перечитываем профиль.
        int? wid = prevWishlistId;
        if (wid == null) {
          final data = await ApiService.getUserProfile(userId: id, token: token);
          wid = _asInt(data['wishlist_id']);
        }
        if (wid != null) {
          await ApiService.delete('/me/wishlist/destroy/$wid', token: token);
        }
        if (!mounted) return;
        setState(() {
          _wishlistId = null;
          _subscribing = false;
        });
      }
    } catch (e) {
      log.w('❌ SellerProfileScreen: ошибка подписки: $e');
      if (!mounted) return;
      // Откат оптимистичного переключения.
      setState(() {
        _isWishlisted = wasWishlisted;
        _wishlistId = prevWishlistId;
        _subscribing = false;
      });
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

                      const SizedBox(height: 0),
                      _buildSellerInfo(),

                      const SizedBox(height: 20),
                      _buildDescriptionSection(),
                      _buildLocationSection(),
                      _buildContactsSection(),

                      const SizedBox(height: 0),
                      _buildRateSeller(),

                      const SizedBox(height: 12),
                      _buildShareCompanySection(),

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

  /// Измеряет ширину набора текстовых спанов в одну строку (для адаптива).
  double _measureSpanWidth(List<InlineSpan> spans) {
    final tp = TextPainter(
      text: TextSpan(children: spans),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// Строка «На ЛИДЛ LIDLE c ДАТА · Оценка: ⭐ 5».
  /// Адаптив: если не помещается по ширине — «LIDLE» уменьшается с 10 до 7,
  /// а если и тогда не влезает — «LIDLE» скрывается совсем.
  Widget _buildRegistrationRow() {
    const double fs = 13; // размер остального текста
    final date = _registrationDate ?? widget.sellerRegistrationDate ?? '';

    // Фиксированный «хвост»: «Оценка: ⭐ 5» + отступ.
    const ratingText = 'Оценка: ';
    const ratingValue = ' 5';
    const double starSize = 16;
    const double gap = 10;

    // Спаны даты без «LIDLE».
    const prefixSpan = TextSpan(
      text: 'На ЛИДЛ ',
      style: TextStyle(color: textSecondary, fontSize: fs),
    );
    final dateSpan = TextSpan(
      text: ' c $date',
      style: const TextStyle(color: textSecondary, fontSize: fs),
    );
    TextSpan lidleSpan(double size) => TextSpan(
          text: 'LIDLE',
          style: TextStyle(color: activeIconColor, fontSize: size),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Доступная ширина = вся ширина строки минус фиксированный «хвост».
        final tailWidth = _measureSpanWidth(const [
              TextSpan(
                text: ratingText,
                style: TextStyle(color: textSecondary, fontSize: fs),
              ),
              TextSpan(
                text: ratingValue,
                style: TextStyle(color: textPrimary, fontSize: fs),
              ),
            ]) +
            starSize +
            gap +
            2; // небольшой запас
        final available = constraints.maxWidth - tailWidth;

        // Подбираем размер «LIDLE»: 10 → 9 → 8 → 7, иначе скрываем.
        List<InlineSpan> chosen = [prefixSpan, dateSpan];
        for (final size in [10.0, 9.0, 8.0, 7.0]) {
          final candidate = <InlineSpan>[prefixSpan, lidleSpan(size), dateSpan];
          if (_measureSpanWidth(candidate) <= available) {
            chosen = candidate;
            break;
          }
        }

        return Row(
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(children: chosen),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: gap),
            const Text(
              ratingText,
              style: TextStyle(color: textSecondary, fontSize: fs),
            ),
            const Icon(Icons.star, color: Colors.amber, size: starSize),
            const Text(
              ratingValue,
              style: TextStyle(color: textPrimary, fontSize: fs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSellerInfo() {
    return Column(
      children: [
        Row(
          children: [
            _buildSellerAvatar(widget.sellerAvatarUrl),
            const SizedBox(width: 16),
            // Expanded — чтобы блок имени/даты был ограничен по ширине
            // и корректно работал адаптив (иначе строка уходит за экран).
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildRegistrationRow(),
                  const SizedBox(height: 6),
                  const Text(
                    "Проверенный продавец",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Кнопка "Подписаться на продавца" временно СКРЫТА: пользуемся
        // иконкой избранного (сердечко в блоке оценки продавца).
        // Чтобы вернуть кнопку — поменяй visible: false на visible: true.
        Visibility(
          visible: false,
          child: Column(
            children: [
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
    IconData? leadingIcon,
    // Если true — секция не заполнена: рядом с заголовком показываем красную
    // подсказку «Заполните поля», а тап по секции ведёт на [onFillTap]
    // (экран редактирования), а не раскрывает/сворачивает секцию.
    bool showFillHint = false,
    VoidCallback? onFillTap,
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
            // Пока поле не заполнено — тап ведёт на заполнение данных.
            onTap: showFillHint ? onFillTap : onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  // Необязательная иконка слева от заголовка секции.
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, color: textSecondary, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Красная подсказка о незаполненном поле. Если текст не
                  // помещается по ширине — FittedBox пропорционально уменьшает
                  // его, чтобы он влез в одну строку.
                  if (showFillHint) ...[
                    const SizedBox(width: 8),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Заполните поля',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  // Иконка секции — как в исходном виде (обычный шеврон).
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
          // Раскрытие доступно только для заполненных секций.
          if (expanded && !showFillHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(width: double.infinity, child: child),
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final isEmpty = (_description ?? '').trim().isEmpty;
    final showHint = _isOwnProfile && !_profileLoading && isEmpty;
    return _buildCollapsibleSection(
      title: 'Описание',
      expanded: _descExpanded,
      onToggle: () => setState(() => _descExpanded = !_descExpanded),
      showFillHint: showHint,
      onFillTap: _openContactDataEditor,
      child: Text(
        _profileLoading && _description == null
            ? 'Загрузка...'
            : (_description ?? 'Описание отсутствует'),
        style: const TextStyle(color: textSecondary, fontSize: 15, height: 1.4),
      ),
    );
  }

  Widget _buildLocationSection() {
    final isEmpty = (_addressText ?? '').trim().isEmpty;
    final showHint = _isOwnProfile && !_profileLoading && isEmpty;
    return _buildCollapsibleSection(
      title: 'Расположение',
      // Иконка теперь слева от заголовка «Расположение».
      leadingIcon: Icons.location_on_outlined,
      expanded: _locExpanded,
      onToggle: () => setState(() => _locExpanded = !_locExpanded),
      showFillHint: showHint,
      onFillTap: _openContactDataEditor,
      child: Text(
        _profileLoading && _addressText == null
            ? 'Загрузка...'
            : (_addressText ?? 'Не указано'),
        style: const TextStyle(color: textPrimary, fontSize: 15),
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
        // Показываем номер замаскированным (+7 949 ***-**-**).
        // Реальный номер доступен по кнопке «Позвонить».
        children.add(contactValue(_maskPhone(p)));
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

    final showHint = _isOwnProfile && !_profileLoading && !hasAny;
    return _buildCollapsibleSection(
      title: 'Контакты',
      expanded: _contactsExpanded,
      onToggle: () => setState(() => _contactsExpanded = !_contactsExpanded),
      showFillHint: showHint,
      onFillTap: _openContactDataEditor,
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
      padding: const EdgeInsets.all(10),
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
              // Мгновенное переключение без лоадера (как на главном экране);
              // сам запрос идёт в фоне, при ошибке состояние откатывается.
              GestureDetector(
                onTap: _toggleSubscription,
                behavior: HitTestBehavior.opaque,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isWishlisted ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey<bool>(_isWishlisted),
                    color: _isWishlisted ? Colors.redAccent : textSecondary,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          // const SizedBox(height: 7),
          // const Text(
          //   "Вы можете оставить оценку продавцу это поднимет его рейтинг.",
          //   style: TextStyle(color: textSecondary, fontSize: 16),
          // ),
          // const SizedBox(height: 11),

          // const Text(
          //   "Оценка:",
          //   style: TextStyle(color: textPrimary, fontSize: 16),
          // ),
          // const SizedBox(height: 6),

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

  /// Блок «Поделиться компанией» (как на макете): заголовок, подпись и ряд
  /// иконок для шаринга ссылки на профиль продавца.
  Widget _buildShareCompanySection() {
    return _buildCollapsibleSection(
      title: 'Поделиться компанией',
      expanded: _shareExpanded,
      onToggle: () => setState(() => _shareExpanded = !_shareExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Отправьте ссылку друзьям или в соцсети удобным для вас способом',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 16),
          // Ряд иконок шаринга: всегда в одну строку. Размер плитки считаем
          // из доступной ширины, чтобы иконки динамически уменьшались и все
          // помещались (иначе последняя, MAX, переносилась на новую строку).
          LayoutBuilder(
            builder: (context, constraints) {
              // Порядок плиток — как на макете: ВК, Яндекс, ОК, почта, Telegram, MAX.
              const socials = [
                ('ВКонтакте', 'assets/socials/vk.png', 'vk'),
                ('Яндекс', 'assets/socials/yandex.png', 'yandex'),
                ('Одноклассники', 'assets/socials/ok.png', 'ok'),
                ('Электронная почта', 'assets/socials/email.png', 'email'),
                ('Telegram', 'assets/socials/telegram.png', 'telegram'),
                ('MAX', 'assets/socials/max.png', 'max'),
              ];
              final count = socials.length;
              const spacing = 8.0; // зазор между плитками
              const maxTile = 46.0; // как на макете; на широком экране не больше
              // Ширина плитки под доступное место (с учётом зазоров).
              // Не превышаем maxTile; на узком экране плитки уменьшаются и
              // никогда не переполняют строку (сумма всегда <= доступной ширины).
              final raw =
                  (constraints.maxWidth - spacing * (count - 1)) / count;
              final tile = raw > maxTile ? maxTile : raw;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final s in socials)
                    _shareTile(
                      label: s.$1,
                      asset: s.$2,
                      onTap: () => _shareVia(s.$3),
                      size: tile,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Квадратная кнопка-иконка для ряда шаринга.
  /// [size] — сторона плитки (считается динамически под ширину экрана),
  /// иконка внутри масштабируется пропорционально (24/46 от плитки).
  Widget _shareTile({
    required String asset,
    required String label,
    required VoidCallback onTap,
    double size = 46,
  }) {
    final iconSize = size * (24 / 46); // сохраняем пропорцию макета
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Плитка темнее панели секции — как на макете.
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Image.asset(asset, width: iconSize, height: iconSize),
        ),
      ),
    );
  }

  /// Открывает нужный способ шаринга ссылки на профиль продавца.
  /// Для соцсетей используется web/deep-link через url_launcher; при неудаче
  /// (нет приложения/браузера) — системный лист шаринга (share_plus).
  Future<void> _shareVia(String kind) async {
    final url = _generateSellerProfileUrl();
    final text = 'Профиль продавца ${widget.sellerName} на LIDLE';
    final encUrl = Uri.encodeComponent(url);
    final encText = Uri.encodeComponent(text);
    final encAll = Uri.encodeComponent('$text\n$url');

    String? link;
    switch (kind) {
      case 'vk':
        link = 'https://vk.com/share.php?url=$encUrl&title=$encText';
        break;
      case 'ok':
        link = 'https://connect.ok.ru/offer?url=$encUrl&title=$encText';
        break;
      case 'telegram':
        link = 'https://t.me/share/url?url=$encUrl&text=$encText';
        break;
      case 'whatsapp':
        link = 'https://wa.me/?text=$encAll';
        break;
      case 'email':
        link = 'mailto:?subject=$encText&body=$encAll';
        break;
      case 'yandex':
        // У Яндекса нет универсального web-share intent — открываем системный
        // лист шаринга (можно выбрать Яндекс.Мессенджер/почту, если стоит).
        await Share.share('$text\n\n$url');
        return;
      case 'max':
        // MAX (мессенджер) не имеет публичного share-URL — системный лист.
        await Share.share('$text\n\n$url');
        return;
      case 'more':
      default:
        await Share.share('$text\n\n$url');
        return;
    }

    try {
      final launched =
          await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      if (!launched) {
        await Share.share('$text\n\n$url');
      }
    } catch (_) {
      await Share.share('$text\n\n$url');
    }
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