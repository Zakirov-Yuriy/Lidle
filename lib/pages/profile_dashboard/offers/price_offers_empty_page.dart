import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
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

class _PriceOffersEmptyPageState extends State<PriceOffersEmptyPage> {
  bool isMyOffersSelected = true;

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  final List<Offer> myOffers = [
    Offer(
      id: '322 211 45',
      imageUrl: 'assets/home_page/apartment1.png',
      title: '1-к. квартира, 65,5 м²',
      description: 'Напишите сообщение',
      originalPrice: '16 500 000₽',
      yourPrice: '15 500 000₽',
      status: OfferStatus.accepted,
      viewed: true,
    ),
    Offer(
      id: '322 211 45',
      imageUrl: 'assets/home_page/apartment1.png',
      title: '1-к. квартира, 65,5 м²',
      description: 'Напишите сообщение',
      originalPrice: '16 500 000₽',
      yourPrice: '15 500 000₽',
      status: OfferStatus.rejected,
      viewed: true,
    ),
    Offer(
      id: '322 211 45',
      imageUrl: 'assets/home_page/studio.png',
      title: 'Студия, 35,7 м²',
      description: 'Напишите сообщение',
      originalPrice: '3 500 000₽',
      yourPrice: '3 000 000₽',
      status: OfferStatus.pending,
      viewed: false,
    ),
  ];

  final List<Offer> offersToMe = [
    Offer(
      id: '455 322 11',
      imageUrl: 'assets/home_page/apartment1.png',
      title: '2-к. квартира, 85 м²',
      description: 'Хорошая квартира',
      originalPrice: '20 000 000₽',
      yourPrice: '18 000 000₽',
      status: OfferStatus.pending,
      viewed: false,
      offeredPricesCount: 3,
    ),
    Offer(
      id: '456 323 12',
      imageUrl: 'assets/home_page/studio.png',
      title: 'Студия, 40 м²',
      description: 'Современная студия',
      originalPrice: '5 000 000₽',
      yourPrice: '4 500 000₽',
      status: OfferStatus.pending,
      viewed: true,
      offeredPricesCount: 1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final offersToDisplay = isMyOffersSelected ? myOffers : offersToMe;

    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToAddListing || state is NavigationToMyPurchases || state is NavigationToMessages || state is NavigationToSignIn) {
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
                            style: TextStyle(color: activeIconColor, fontSize: 16),
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
                                  color: isMyOffersSelected ? accentColor : Colors.white,
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
                              },
                              child: Text(
                                'Предложения мне',
                                style: TextStyle(
                                  color: isMyOffersSelected ? Colors.white : accentColor,
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
                    child: offersToDisplay.isEmpty
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
                                    crossAxisAlignment: CrossAxisAlignment.center,
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
                if (index == 3) { // Shopping cart icon
                  context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
                } else {
                  context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
                }
              },
            ),
          );
        },
      ),
    );
  }
}
