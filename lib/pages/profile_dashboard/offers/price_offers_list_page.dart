import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/profile_dashboard/offers/incoming_price_offer_page.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api_request_queue.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';

class PriceOffersListPage extends StatefulWidget {
  final Offer offer;

  const PriceOffersListPage({super.key, required this.offer});

  static const routeName = '/price-offers-list';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const yellowColor = Color(0xFFE8FF00);
  static const dangerColor = Color(0xFFFF3B30);

  @override
  State<PriceOffersListPage> createState() => _PriceOffersListPageState();
}

class _PriceOffersListPageState extends State<PriceOffersListPage> {
  late List<PriceOfferItem> items;
  bool _isLoading = true;
  String? _errorMessage;

  // 💾 Кэш данных офферов: ключ = advertisementId, значение = список офферов
  static final Map<String, List<PriceOfferItem>> _offersCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Время жизни кэша: 5 минут
  static const Duration _cacheTTL = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    items = [];
    _loadOffers();
  }

  /// Возвращает ключ кэша для текущего объявления
  String _getCacheKey() =>
      '${widget.offer.advertisementId}_${widget.offer.typeSlug}';

  /// Проверяет, существует ли валидный кэш для текущего объявления
  bool _isCacheValid() {
    final cacheKey = _getCacheKey();
    if (!_offersCache.containsKey(cacheKey)) return false;

    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    // Проверяем не истек ли кэш
    final isExpired = DateTime.now().difference(timestamp) > _cacheTTL;
    if (isExpired) {
      _offersCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      return false;
    }

    return true;
  }

  /// Загружает список предложений для объявления пользователя
  Future<void> _loadOffers({bool forceRefresh = false}) async {
    try {
      final cacheKey = _getCacheKey();

      // Проверяем кэш (если не принудительное обновление)
      if (!forceRefresh && _isCacheValid()) {
        log.d(
          '💾 Using cached offers for advert: ${widget.offer.advertisementId}',
        );
        if (mounted) {
          setState(() {
            items = _offersCache[cacheKey] ?? [];
            itemChecked = List<bool>.filled(items.length, false);
            _isLoading = false;
          });
        }
        return;
      }

      log.d('📡 Loading offers for advert: ${widget.offer.advertisementId}');
      log.d('   typeSlug: ${widget.offer.typeSlug}');
      log.d('   slug: ${widget.offer.slug}');

      if (mounted) {
        setState(() => _isLoading = true);
      }

      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        throw Exception('Требуется авторизация');
      }

      // ✅ Используем type.slug для URL: /me/offers/received/{type.slug}/{id}
      // Например: /me/offers/received/adverts/114
      final typeSlug = widget.offer.typeSlug ?? 'adverts';
      final advertId = int.parse(
        widget.offer.advertisementId ?? widget.offer.id,
      );

      log.d('   typeSlug: $typeSlug');
      log.d('   Final API call: /me/offers/received/$typeSlug/$advertId');

      final offersData = await ApiService.getPriceOffers(
        advertId: advertId,
        advertSlug: typeSlug,
        token: token,
      );

      log.d('📦 Loaded ${offersData.length} offers');

      if (offersData.isNotEmpty) {
        final parsed = await _parseOffers(offersData);
        if (mounted) {
          setState(() {
            items = parsed;
            itemChecked = List<bool>.filled(items.length, false);
            _isLoading = false;
          });

          // 💾 Сохраняем в кэш
          _offersCache[_getCacheKey()] = parsed;
          _cacheTimestamps[_getCacheKey()] = DateTime.now();
          log.d(
            '💾 Cached ${parsed.length} offers for advert ${widget.offer.advertisementId}',
          );

          // ✅ Если нет никаких предложений вообще — возвращаемся
          if (parsed.isEmpty) {
            log.d(
              '⚡ No offers returned for advert ${widget.offer.advertisementId} '
              '— auto-popping with result=true',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop(true);
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            items = [];
            itemChecked = [];
            _isLoading = false;
          });

          // ✅ API вернул пустой список — тоже возвращаемся
          log.d(
            '⚡ No offers returned for advert ${widget.offer.advertisementId} '
            '— auto-popping with result=true',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(true);
          });
        }
      }
    } catch (e) {
      log.d('❌ Error loading offers: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки предложений: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Преобразует API ответ в объекты PriceOfferItem.
  /// Загружает контактную информацию пользователя для получения номера телефона.
  /// Показываем все предложения независимо от статуса:
  /// - statusId == 1: новое предложение (жёлтый badge)
  /// - statusId == 2: принято (зелёный badge)
  /// - statusId == 3: отклонено (красный badge)
  /// - statusId == null: старые записи без статуса (жёлтый badge)
  /// 
  /// 🚀 УЛУЧШЕНИЕ: Используем ApiRequestQueue вместо Future.wait()
  /// Это ограничивает параллельные запросы до 3 одновременно
  Future<List<PriceOfferItem>> _parseOffers(
    List<Map<String, dynamic>> offersData,
  ) async {
    log.d(
      '🔄 _parseOffers: Starting parallel profile loading for ${offersData.length} offers (max 3 concurrent)',
    );
    final token = HiveService.getUserData('token') as String?;

    // Собираем функции запросов для загрузки профилей
    // 🚀 Используем ApiRequestQueue вместо Future.wait()
    final profileRequestFunctions = <Future<Map<int, Map<String, dynamic>>> Function()>[];
    final userIds = <int>[];

    for (final offer in offersData) {
      final user = offer['user'] as Map<String, dynamic>? ?? {};
      final userId = user['id'] as int?;

      if (userId != null && token != null) {
        userIds.add(userId);
        profileRequestFunctions.add(
          () => ApiService.getUserProfile(
            userId: userId,
            token: token,
          ).then((profile) => {userId: profile}).catchError((e) {
            log.d('   ⚠️ Error loading profile for userId $userId: $e');
            return {userId: <String, dynamic>{}};
          }),
        );
      }
    }

    // Загружаем профили используя очередь (ограничиваем до 3 одновременных)
    // Это предотвращает Rate Limit ошибки при большом количестве пользователей
    final profileResults = profileRequestFunctions.isEmpty
        ? <Map<int, Map<String, dynamic>>>[]
        : await ApiRequestQueue.instance.queueBatch(
            profileRequestFunctions,
            batchSize: 3, // Максимум 3 одновременных запроса
          );

    // Объединяем результаты в одну карту для быстрого доступа
    final profileCache = <int, Map<String, dynamic>>{};
    for (final result in profileResults) {
      profileCache.addAll(result);
    }

    log.d('✅ Loaded profiles for ${profileCache.length} users (${ApiRequestQueue.instance.stats})');

    // Теперь парсим офферы, используя закэшированные профили
    List<PriceOfferItem> result = [];

    for (final offer in offersData) {
      final statusMap = offer['status'] as Map<String, dynamic>?;
      final statusId = statusMap?['id'] as int?;

      // Определяем флаги статуса
      final isAccepted = statusId == 2;
      final isRejected = statusId == 3;

      final user = offer['user'] as Map<String, dynamic>? ?? {};
      final model = offer['model'] as Map<String, dynamic>? ?? {};
      final createdAt = offer['created_at'] as String? ?? '';
      final price = offer['price'] as String? ?? '0';
      final userAvatar = user['avatar'] as String?;
      final message = offer['message'] as String?;
      final userId = user['id'] as int?;

      // Получаем номер телефона и никнейм пользователя из кэша
      String? userPhone;
      String? userNickname;

      if (userId != null && profileCache.containsKey(userId)) {
        final userProfile = profileCache[userId]!;
        if (userProfile.isNotEmpty) {
          final userName = userProfile['name'] as String?;
          userNickname = userName != null ? '@$userName' : '@user';

          // Номер телефона из контактов
          final contacts = userProfile['contacts'] as Map<String, dynamic>?;
          if (contacts != null) {
            final phones = contacts['phones'] as List?;
            if (phones != null && phones.isNotEmpty) {
              final firstPhone = phones[0] as Map<String, dynamic>?;
              userPhone = firstPhone?['phone'] as String?;
            }
          }
        }
      }

      result.add(
        PriceOfferItem(
          name: user['name'] as String? ?? 'Неизвестный пользователь',
          subtitle: _formatDate(createdAt),
          price: _formatPrice(price),
          badgeCount: '1',
          avatar: _getAvatarUrl(userAvatar),
          phone: userPhone,
          nickname: userNickname,
          offerId: offer['id']?.toString(),
          listingId: model['id']?.toString(),
          listingTitle: model['name'] as String?,
          listingPrice: model['price'] as String?,
          listingImage: model['thumbnail'] as String?,
          message: message,
          isAccepted: isAccepted,
          isRejected: isRejected,
        ),
      );
    }

    return result;
  }

  /// Возвращает URL аватара или default avatar если avatar не доступен
  String _getAvatarUrl(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Если это полный URL
      if (avatarUrl.startsWith('http')) {
        return avatarUrl;
      }
      // Если это относительный путь, то добавляем базовый URL
      return 'https://dev-img.lidle.io/$avatarUrl';
    }
    // Использует default avatar если нет данных
    return _defaultAvatar();
  }

  /// Форматирует дату в относительный формат ("был(а) сегодня", "вчера", "3 дня назад")
  String _formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'недавно';

      // API возвращает дату в формате: "23.01.2026"
      final parts = dateString.split('.');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[2]), // год
          int.parse(parts[1]), // месяц
          int.parse(parts[0]), // день
        );

        final now = DateTime.now();
        final difference = now.difference(date).inDays;

        if (difference == 0) {
          return 'был(а) сегодня';
        } else if (difference == 1) {
          return 'был(а) вчера';
        } else if (difference < 7) {
          return '$difference дн${difference == 1 ? 'ь' : 'ей'} назад';
        } else {
          return dateString;
        }
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  /// Форматирует цену (добавляет разделители и символ валюты)
  String _formatPrice(String priceStr) {
    try {
      final price = double.parse(priceStr);
      final formatter = _formatNumberWithSpaces(price.toInt().toString());
      return '$formatter₽';
    } catch (e) {
      return '$priceStr₽';
    }
  }

  /// Добавляет пробелы в число для большей читаемости (например: 41 000 000)
  String _formatNumberWithSpaces(String number) {
    String result = '';
    int count = 0;
    for (int i = number.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ' $result';
      }
      result = '${number[i]}$result';
      count++;
    }
    return result;
  }

  /// Возвращает аватар по умолчанию
  String _defaultAvatar() {
    return 'assets/property_details_screen/Andrey.png';
  }

  List<bool> itemChecked = [];
  bool selectAllChecked = false;
  bool isSelectionMode = false;

  @override
  void didUpdateWidget(PriceOffersListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем itemChecked когда список items изменяется
    if (itemChecked.length != items.length) {
      itemChecked = List<bool>.filled(items.length, false);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      selectAllChecked = !selectAllChecked;
      for (int i = 0; i < itemChecked.length; i++) {
        itemChecked[i] = selectAllChecked;
      }

      // Exit selection mode if deselecting all
      if (!selectAllChecked) {
        isSelectionMode = false;
      }
    });
  }

  void _toggleItem(int index) {
    setState(() {
      itemChecked[index] = !itemChecked[index];
      selectAllChecked = itemChecked.every((checked) => checked);

      // Exit selection mode if no items are checked
      if (!itemChecked.any((checked) => checked)) {
        isSelectionMode = false;
      }
    });
  }

  void _deleteSelected() {
    setState(() {
      for (int i = itemChecked.length - 1; i >= 0; i--) {
        if (itemChecked[i]) {
          items.removeAt(i);
          itemChecked.removeAt(i);
        }
      }
      selectAllChecked = false; // Reset select all after deletion
      isSelectionMode = false; // Exit selection mode after deletion
    });
  }

  void _enterSelectionMode() {
    setState(() {
      isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectAllChecked = false;
      for (int i = 0; i < itemChecked.length; i++) {
        itemChecked[i] = false;
      }
    });
  }

  /// Перезагружает данные экрана при восстановлении подключения
  void _reloadScreenData() {
    if (mounted) {
      _loadOffers(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _reloadScreenData();
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
            child: Scaffold(
        extendBody: true,
        backgroundColor: PriceOffersListPage.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 5, right: 23),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Header(), const Spacer()],
                ),
              ),

              // ───── Back / Cancel ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Color.fromARGB(255, 255, 255, 255),
                        size: 16,
                      ),
                    ),
                    const Text(
                      'Предложения цен',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // GestureDetector(
                    //   onTap: () {
                    //     log.d('🔄 Manually refreshing offers cache...');
                    //     _loadOffers(forceRefresh: true);
                    //   },
                    //   child: const Icon(
                    //     Icons.refresh,
                    //     color: activeIconColor,
                    //     size: 20,
                    //   ),
                    // ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        if (isSelectionMode) {
                          _exitSelectionMode();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: activeIconColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ───── Select all / Delete ─────
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      CustomCheckbox(
                        value: selectAllChecked,
                        onChanged: (value) => _toggleSelectAll(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Выбрать все',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: itemChecked.contains(true)
                            ? _deleteSelected
                            : null,
                        child: Text(
                          'Удалить',
                          style: TextStyle(
                            color: itemChecked.contains(true)
                                ? PriceOffersListPage.dangerColor
                                : Colors.white38,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isSelectionMode) const SizedBox(height: 12),
              if (isSelectionMode)
                const Divider(color: Colors.white24, height: 0),

              // ───── List ─────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF00B7FF),
                          ),
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inbox_outlined,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Нет предложений',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Column(
                            children: [
                              _OfferItem(
                                offerItem: item,
                                isChecked: itemChecked[index],
                                isSelectionMode: isSelectionMode,
                                onChanged: () => _toggleItem(index),
                                onTap: () async {
                                  if (isSelectionMode) {
                                    _toggleItem(index);
                                  } else {
                                    // Всегда показываем экран обработки предложения
                                    // независимо от статуса (новое, принято или отклонено)
                                    final result = await Navigator.pushNamed(
                                      context,
                                      IncomingPriceOfferPage.routeName,
                                      arguments: item,
                                    );
                                    if (result == true) {
                                      // Ждём завершения загрузки перед проверкой
                                      // forceRefresh = true чтобы обновить кэш с новыми данными
                                      await _loadOffers(forceRefresh: true);
                                      // Если нет ни новых, ни принятых — возвращаемся к списку объявлений
                                      if (mounted && items.isEmpty) {
                                        Navigator.of(context).pop(true);
                                      }
                                    }
                                  }
                                },
                                onLongPress: () {
                                  if (!isSelectionMode) {
                                    _enterSelectionMode();
                                    _toggleItem(index);
                                  }
                                },
                              ),
                              if (index < items.length - 1)
                                const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            if (index == 3) {
              // Shopping cart icon
              context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
            } else {
              context.read<NavigationBloc>().add(
                SelectNavigationIndexEvent(index),
              );
            }
          },
        ),
      ),
      );
    },
  ),
);
}
}

// ─────────────────────────────────────────────

class _OfferItem extends StatelessWidget {
  final PriceOfferItem offerItem;
  final bool isChecked;
  final bool isSelectionMode;
  final VoidCallback onChanged;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _OfferItem({
    required this.offerItem,
    required this.isChecked,
    required this.isSelectionMode,
    required this.onChanged,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (isSelectionMode)
                    CustomCheckbox(
                      value: isChecked,
                      onChanged: (value) => onChanged(),
                    ),
                  if (isSelectionMode) const SizedBox(width: 12),

                  // avatar
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.black26,
                    backgroundImage:
                        offerItem.avatar.startsWith('http://') ||
                            offerItem.avatar.startsWith('https://')
                        ? NetworkImage(offerItem.avatar) as ImageProvider
                        : AssetImage(offerItem.avatar),
                  ),

                  const SizedBox(width: 12),

                  // name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offerItem.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offerItem.subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // badge
                  // 🔴 Красный — отклонено (statusId == 3)
                  // 🟢 Зелёный — принято (statusId == 2)
                  // 🟡 Жёлтый — новое или ожидает решения
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: offerItem.isRejected
                            ? PriceOffersListPage
                                  .dangerColor // 🔴 Красный
                            : offerItem.isAccepted
                            ? Colors.green[400]! // 🟢 Зелёный
                            : PriceOffersListPage.yellowColor, // 🟡 Жёлтый
                      ),
                    ),
                    child: Center(
                      child: Text(
                        offerItem.badgeCount,
                        style: TextStyle(
                          color: offerItem.isRejected
                              ? PriceOffersListPage
                                    .dangerColor // 🔴 Красный
                              : offerItem.isAccepted
                              ? Colors.green[400]! // 🟢 Зелёный
                              : PriceOffersListPage.yellowColor, // 🟡 Жёлтый
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Text(
                    'Предложил цену:',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    offerItem.price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
