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

      print('📡 Calling ApiService.getAllReceivedOffers()...');
      final offersData = await ApiService.getAllReceivedOffers(token: token);
      print('📦 API returned ${offersData.length} received offers');

      if (mounted) {
        setState(() {
          _offersToMe = offersData.map((data) {
            print(
              '🔄 Parsing received offer: ${data['id']} - '
              'Message: ${data['message']}, '
              'Price: ${data['price']}, '
              'Status: ${data['status']?['id']}',
            );
            return _parseOfferFromApi(data);
          }).toList();
          print('✅ Successfully parsed ${_offersToMe.length} received offers');
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
  /// Поддерживает как собственные предложения, так и полученные предложения
  Offer _parseOfferFromApi(Map<String, dynamic> apiData) {
    final model = apiData['model'] as Map<String, dynamic>? ?? {};
    final status = apiData['status'] as Map<String, dynamic>? ?? {};
    final seller = apiData['seller'] as Map<String, dynamic>? ?? {};

    print('🔄 Parsing offer API data:');
    print('   apiData id (offer ID): ${apiData['id']}');
    print('   model id (advert ID): ${model['id']}');
    print('   model name: ${model['name']}');
    print('   seller name: ${seller['name']}');
    print('   message (offer details): ${apiData['message']}');
    print('   offered price: ${apiData['price']}');
    print('   original price: ${model['price']}');

    return Offer(
      id: apiData['id']?.toString() ?? '', // ✅ ID предложения
      advertisementId: model['id']?.toString(), // ✅ ID объявления (товара)
      imageUrl:
          (model['thumbnail'] as String?) ?? 'assets/home_page/apartment1.png',
      title: model['name'] as String? ?? 'Объявление',
      description: apiData['message'] as String? ?? '',
      originalPrice: model['price'] as String? ?? '0',
      yourPrice: apiData['price'] as String? ?? '0',
      status: _parseStatusFromId(status['id'] as int?),
      viewed: (apiData['read_at'] as String?) != null,
    );
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
    // Выбираем какой список отображать
    final offersToDisplay = isMyOffersSelected ? _myOffers : _offersToMe;
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
                              return OfferCard(offer: offersToDisplay[index]);
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
