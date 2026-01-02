import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class DiscountsAndPromotionsPage extends StatelessWidget {
  const DiscountsAndPromotionsPage({super.key});

  static const String routeName = '/discounts-and-promotions';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
                    padding: const EdgeInsets.only(bottom: 5, right: 25),
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
                          'Скидки и акции',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Назад',
                            style: TextStyle(color: activeIconColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 10),

            // ───── Grid ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          imagePath: 'assets/support/sale_1.png',
                          iconColor: Color(0xFFFFD54F),
                          title: 'Скидки',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _CategoryCard(
                          imagePath: 'assets/support/present.png',
                          iconColor: Color(0xFFB388FF),
                          title: 'Подарки',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          imagePath: 'assets/support/stock.png',
                          iconColor: Color(0xFF64B5F6),
                          title: 'Акции',
                        ),
                      ),
                      Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),
            const SizedBox(height: 80), // под bottom nav
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

// ─────────────────────────────────────────────
// CATEGORY CARD
// ─────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final String? imagePath;
  final Color iconColor;
  final String title;

  const _CategoryCard({
    this.imagePath,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 146,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(imagePath!, height: 88, width: 65),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
