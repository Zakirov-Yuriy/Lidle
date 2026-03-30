import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import Bloc
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart'; // Import NavigationBloc
import 'package:lidle/blocs/navigation/navigation_event.dart'; // Import NavigationEvent
import 'package:lidle/blocs/navigation/navigation_state.dart'; // Import NavigationState
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart'; // Import custom BottomNavigation
import 'package:lidle/constants.dart'; // Import constants
import 'package:lidle/widgets/components/header.dart'; // Import Header widget
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/models/home_models.dart'; // Import Listing model
import 'package:lidle/widgets/components/product_card.dart'; // Import ProductCard widget

class MyPurchasesScreen extends StatelessWidget {
  static const String routeName = '/my-purchases'; // Define route name
  MyPurchasesScreen({super.key});

// Скрытые обьявления статические для демонстрации состояния "Нет покупок" — оставляем список пустым.
  //  // Dummy data for purchases
  // final List<Listing> dummyPurchases = [
  //   Listing(
  //     id: '1',
  //     imagePath: 'assets/product_card/image1.png',
  //     title: 'Диван раскладной...',
  //     price: '31 627',
  //     location: 'Москва, ул. Куусинена, 21А',
  //     date: 'Сегодня',
  //     isFavorited: true,
  //   ),
  //   Listing(
  //     id: '2',
  //     imagePath: 'assets/product_card/image2.png',
  //     title: 'Лайфмебель Стулья...',
  //     price: '21 000',
  //     location: 'Москва, ул. Казакова, 7',
  //     date: '29.08.2024',
  //     isFavorited: false,
  //   ),
  //   Listing(
  //     id: '3',
  //     imagePath: 'assets/product_card/image3.png',
  //     title: 'Лайфмебель Стулья...',
  //     price: '16 000',
  //     location: 'Москва, Отрадная ул., 11',
  //     date: '29.08.2024',
  //     isFavorited: true,
  //   ),
  // ];

  // Dummy data for purchases (temporarily hidden)
  // Чтобы временно показать состояние "Нет покупок" — оставляем список пустым.
  final List<Listing> dummyPurchases = [];

  @override
  Widget build(BuildContext context) {
    final bool hasPurchases =
        dummyPurchases.isNotEmpty; // Check if there are purchases

    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          // Refresh screen data when connection is restored
          Future.delayed(const Duration(milliseconds: 500), () {
            // Screen will rebuild automatically when state changes
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
                  state is NavigationToCategorySelection ||
                  state is NavigationToMessages) {
                context.read<NavigationBloc>().executeNavigation(context);
              }
            },
            child: Scaffold(
              backgroundColor: primaryBackground,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Header(), // Add the Header widget
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 19,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: textPrimary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10), // Added spacing
                          const Text(
                            'Мои покупки', // Title from the mockup
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.import_export,
                              color: textPrimary,
                            ), // Иконка сортировки
                            onPressed: () {
                              // TODO: Реализовать функцию сортировки
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: hasPurchases
                          ? GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 0,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 9,
                                    mainAxisSpacing: 5,
                                    childAspectRatio: 0.55,
                                  ),
                              itemCount: dummyPurchases.length,
                              itemBuilder: (context, index) {
                                return ProductCard(listing: dummyPurchases[index]);
                              },
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/my_purchases/shopping-bag-01.svg',
                                    height: 120,
                                    width: 120,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFFFEDC02),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Нет покупок',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                                    child: Text(
                                      'У вас нет покупок, как только вы\n купите товар здесь он будет\n отображен',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFFAAAAAA),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: BottomNavigation(
                onItemSelected: (index) {
                  context.read<NavigationBloc>().add(
                    SelectNavigationIndexEvent(index),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
