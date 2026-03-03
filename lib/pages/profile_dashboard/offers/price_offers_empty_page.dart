import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/profile_dashboard/offers/offer_card.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class PriceOffersEmptyPage extends StatefulWidget {
  const PriceOffersEmptyPage({super.key});

  static const routeName = '/price-offers-empty';

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);
  static const yellowColor = Color(0xFFE8FF00);

  @override
  State<PriceOffersEmptyPage> createState() => _PriceOffersEmptyPageState();
}

class _PriceOffersEmptyPageState extends State<PriceOffersEmptyPage>
    with WidgetsBindingObserver {
  bool isMyOffersSelected = true;
  bool _isLoadingMyOffers = false;
  bool _isLoadingOffersToMe = false;
  List<Offer> _myOffers = [];
  List<Offer> _offersToMe = [];

  /// ИД объявлений (Предложения мне), все предложения по которым уже обработаны.
  /// Static — сохраняется на всю сессию приложения, не сбрасывается при
  /// перестроении виджета или переходе назад/вперёд.
  /// Бэкенд пока возвращает обработанные объявления, этот фильтр — клиентский
  /// костыль до исправления new_offers_count на сервере.
  static final Set<String> _handledAdvertIds = <String>{};

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMyOffers();
    // 📌 Также загружаем предложения мне при инициализации
    _loadOffersToMe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Перезагружаем список при возвращении на экран
    if (state == AppLifecycleState.resumed) {
      print('📱 Экран вернулся в фокус, перезагружаем список предложений');
      _loadMyOffers();
    }
  }

  /// Загружает "Мои предложения" с API
  Future<void> _loadMyOffers() async {
    setState(() {
      _isLoadingMyOffers = true;
    });

    try {
      final token = HiveService.getUserData('token') as String?;
      print(
        '🔍 Token from HiveService: ${token != null ? "✅ Found" : "❌ Not found"}',
      );

      if (token == null) {
        print('❌ No token - cannot load offers');
        setState(() {
          _isLoadingMyOffers = false;
        });
        return;
      }

      print('📡 Calling ApiService.getMyOffers()...');
      final offersData = await ApiService.getMyOffers(token: token);
      print('📦 API returned ${offersData.length} offers');

      if (mounted) {
        setState(() {
          _myOffers = offersData.map((data) {
            print('🔄 Parsing offer: ${data['id']} - ${data['message']}');
            return _parseOfferFromApi(data);
          }).toList();
          print('✅ Successfully parsed ${_myOffers.length} offers');
          _isLoadingMyOffers = false;
        });
      }
    } catch (e) {
      print('❌ Error in _loadMyOffers: $e');
      if (mounted) {
        setState(() {
          _isLoadingMyOffers = false;
        });
      }
    }
  }

  /// Загружает "Предложения мне" с API
  Future<void> _loadOffersToMe() async {
    setState(() {
      _isLoadingOffersToMe = true;
    });

    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        print('❌ No token - cannot load received offers');
        setState(() {
          _isLoadingOffersToMe = false;
        });
        return;
      }

      print('📡 Calling ApiService.getOffersReceivedList()...');
      final listingsWithOffers = await ApiService.getOffersReceivedList(
        token: token,
      );
      print(
        '📦 API returned ${listingsWithOffers.length} listings with offers',
      );

      // Парсим объявления в объекты Offer
      final parsedListings = listingsWithOffers.map((data) {
        print(
          '🔄 Parsing received listing: ${data['id']} - '
          'Name: ${data['name']}, '
          'New offers count: ${data['new_offers_count']}',
        );
        return _parseOfferFromApi(data, isReceivedOffer: true);
      }).toList();

      // ✅ Prefetch: для каждого объявления параллельно загружаем детали
      // предложений, чтобы сразу скрыть те у которых нет реальных «Новых»
      // предложений. Это решает проблему когда бэкенд возвращает
      // new_offers_count > 0, но все предложения уже приняты/отклонены.
      print(
        '🔍 Prefetching offer details for ${parsedListings.length} listings...',
      );
      final prefetchResults = await Future.wait(
        parsedListings.map((offer) async {
          final advertId = int.tryParse(
            offer.advertisementId ?? offer.id ?? '',
          );
          final typeSlug = offer.typeSlug ?? 'adverts';
          // -1 = ошибка (показываем с оригинальным счётчиком)
          if (advertId == null) return MapEntry(offer, -1);

          try {
            final offersData = await ApiService.getPriceOffers(
              advertId: advertId,
              advertSlug: typeSlug,
              token: token,
            );
            // Считаем ТОЧНОЕ количество предложений со статусом «Новый»
            // (id==1 или null — старые записи без статуса)
            final newCount = offersData.where((o) {
              final statusMap = o['status'] as Map<String, dynamic>?;
              final statusId = statusMap?['id'] as int?;
              return statusId == null || statusId == 1;
            }).length;
            print(
              '   📊 Advert ${offer.advertisementId}: '
              '${offersData.length} total, $newCount new',
            );
            return MapEntry(offer, newCount);
          } catch (e) {
            // При ошибке — показываем объявление, чтобы не скрыть лишнего
            print(
              '   ⚠️ Prefetch error for advert ${offer.advertisementId}: $e',
            );
            return MapEntry(offer, -1);
          }
        }),
      );

      // Оставляем только объявления где newCount > 0 (или -1 при ошибке).
      // Обновляем offeredPricesCount точным значением через copyWith.
      final listingsWithNewOffers = prefetchResults
          .where((entry) => entry.value != 0)
          .map((entry) {
            // -1 = ошибка, оставляем оригинальный счётчик
            if (entry.value == -1) return entry.key;
            // Обновляем точным количеством новых предложений
            return entry.key.copyWith(offeredPricesCount: entry.value);
          })
          .toList();

      // Те у которых нет новых — помечаем как обработанные (добавляем в blacklist).
      // Те у которых есть новые — убираем из blacklist, чтобы показались снова
      // (например, если по ранее обработанному объявлению пришло новое предложение).
      for (final entry in prefetchResults) {
        final id = entry.key.advertisementId ?? entry.key.id;
        if (id == null) continue;

        if (entry.value == 0) {
          // Нет новых предложений → скрываем
          _handledAdvertIds.add(id);
          print('   🗑️ Marked advert $id as handled (no new offers)');
        } else {
          // Есть новые (или ошибка) → убираем из blacklist
          _handledAdvertIds.remove(id);
          print(
            '   ✅ Advert $id has ${entry.value} new offers — removed from blacklist',
          );
        }
      }

      if (mounted) {
        setState(() {
          _offersToMe = listingsWithNewOffers;
          print(
            '✅ Successfully loaded ${_offersToMe.length} listings with new offers',
          );
          _isLoadingOffersToMe = false;
        });
      }
    } catch (e) {
      print('❌ Error in _loadOffersToMe: $e');
      if (mounted) {
        setState(() {
          _isLoadingOffersToMe = false;
        });
      }
    }
  }

  /// Преобразует API ответ в объект Offer
  /// Поддерживает как собственные предложения (Мои предложения),
  /// так и полученные предложения (Предложения мне)
  Offer _parseOfferFromApi(
    Map<String, dynamic> apiData, {
    bool isReceivedOffer = false,
  }) {
    // ✅ Для "Мои предложения" структура:
    // {
    //   "id": offer_id,
    //   "message": "...",
    //   "price": "500000",
    //   "model": {...},
    //   "status": {...}
    // }
    //
    // ✅ Для "Предложения мне" структура (объявление пользователя):
    // {
    //   "id": advert_id,
    //   "name": "...",
    //   "thumbnail": "...",
    //   "price": "...",
    //   "slug": "...",
    //   "new_offers_count": 3
    // }

    if (isReceivedOffer) {
      // 📥 Это объявление пользователя на которое получены предложения

      // Извлекаем type.slug — используется в URL: /me/offers/received/{type.slug}/{id}
      final type = apiData['type'] as Map<String, dynamic>? ?? {};
      final typeSlugValue = type['slug'] as String? ?? 'adverts';

      print('🔄 Parsing received offer (my advertisement):');
      print('   advert id: ${apiData['id']}');
      print('   name: ${apiData['name']}');
      print('   price: ${apiData['price']}');
      print('   slug: ${apiData['slug']}');
      print('   type.slug: $typeSlugValue');
      print('   new_offers_count: ${apiData['new_offers_count']}');

      return Offer(
        id: apiData['id']?.toString() ?? '', // ✅ ID объявления
        advertisementId: apiData['id']?.toString(), // ✅ ID объявления
        slug: apiData['slug'] as String?, // ✅ Listing slug (информационный)
        typeSlug:
            typeSlugValue, // ✅ type.slug для URL: /me/offers/received/{typeSlug}/{id}
        imageUrl: (apiData['thumbnail'] as String?) ?? '',
        title: apiData['name'] as String? ?? 'Объявление',
        description: '', // Нет описания в списке объявлений с предложениями
        originalPrice: apiData['price'] as String? ?? '0',
        yourPrice: '0', // Нет "вашей цены" - это входящие предложения
        status: OfferStatus.pending,
        viewed: false,
        offeredPricesCount:
            apiData['new_offers_count'] as int? ??
            0, // ✅ Количество предложений
      );
    } else {
      // 📤 Это предложение цены которое пользователь сам отправил
      final model = apiData['model'] as Map<String, dynamic>? ?? {};
      final status = apiData['status'] as Map<String, dynamic>? ?? {};

      print('🔄 Parsing my offer (sent by me):');
      print('   offer id: ${apiData['id']}');
      print('   advert id: ${model['id']}');
      print('   model name: ${model['name']}');
      print('   message: ${apiData['message']}');
      print('   offered price: ${apiData['price']}');
      print('   original price: ${model['price']}');

      return Offer(
        id: apiData['id']?.toString() ?? '', // ✅ ID предложения
        advertisementId: model['id']?.toString(), // ✅ ID объявления (товара)
        slug: null, // ✅ Не используем для собственных предложений
        typeSlug: null, // ✅ Не используем для собственных предложений
        imageUrl: (model['thumbnail'] as String?) ?? '',
        title: model['name'] as String? ?? 'Объявление',
        description: apiData['message'] as String? ?? '',
        originalPrice: model['price'] as String? ?? '0',
        yourPrice: apiData['price'] as String? ?? '0',
        status: _parseStatusFromId(status['id'] as int?),
        viewed: (apiData['read_at'] as String?) != null,
        offeredPricesCount: null, // ✅ Не заполняем для собственных предложений
      );
    }
  }

  /// Преобразует status ID в OfferStatus
  OfferStatus _parseStatusFromId(int? statusId) {
    switch (statusId) {
      case 2:
        return OfferStatus.accepted;
      case 3:
        return OfferStatus.rejected;
      default:
        return OfferStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Для "Мои предложения" показываем ВСЕ предложения без фильтра —
    // пользователь видит свои предложения в любом статусе (pending/accepted/rejected).
    // Для "Предложения мне" фильтруем: скрываем объявления без новых предложений
    // (_handledAdvertIds = blacklist объявлений где все предложения уже обработаны).
    final offersToDisplay = isMyOffersSelected
        ? _myOffers
        : _offersToMe
              .where(
                (o) => !_handledAdvertIds.contains(o.advertisementId ?? o.id),
              )
              .toList();
    final isLoading = isMyOffersSelected
        ? _isLoadingMyOffers
        : _isLoadingOffersToMe;

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
          return Scaffold(
            extendBody: true,
            backgroundColor: backgroundColor,
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
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              color: activeIconColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ───── Tabs ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isMyOffersSelected = true;
                                });
                              },
                              child: Text(
                                'Мои предложения',
                                style: TextStyle(
                                  color: isMyOffersSelected
                                      ? accentColor
                                      : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isMyOffersSelected = false;
                                });
                                // Загружаем предложения когда пользователь переходит на этот таб
                                if (_offersToMe.isEmpty &&
                                    !_isLoadingOffersToMe) {
                                  _loadOffersToMe();
                                }
                              },
                              child: Text(
                                'Предложения мне',
                                style: TextStyle(
                                  color: isMyOffersSelected
                                      ? Colors.white
                                      : accentColor,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Stack(
                          children: [
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: Colors.white24,
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              left: isMyOffersSelected ? 0 : 157,
                              child: Container(
                                height: 2,
                                width: 133,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00B7FF),
                              ),
                            ),
                          )
                        : offersToDisplay.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 110.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  isMyOffersSelected
                                      ? 'assets/offers/My_applications.png'
                                      : 'assets/offers/Applications_for_me.png',
                                  height: 72,
                                  width: 72,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  isMyOffersSelected
                                      ? 'Вы не предложили цены'
                                      : 'Вам не предложили цены',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'У вас нет откликов на быструю',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      Text(
                                        'подработку, как только вы уберете',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      Text(
                                        'объявление с активных оно тут',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      Text(
                                        'появится',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: offersToDisplay.length,
                            itemBuilder: (context, index) {
                              final offerItem = offersToDisplay[index];
                              return OfferCard(
                                offer: offerItem,
                                // При обработке всех предложений по этому объявлению:
                                // 1. запоминаем его ID — чтобы не показывать снова
                                // 2. перезагружаем список чтобы бэкенд обновил данные
                                onRefreshNeeded: () {
                                  final id =
                                      offerItem.advertisementId ?? offerItem.id;
                                  setState(() {
                                    _handledAdvertIds.add(id);
                                  });
                                  if (!isMyOffersSelected) {
                                    _loadOffersToMe();
                                  } else {
                                    _loadMyOffers();
                                  }
                                },
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
      ),
    );
  }
}
