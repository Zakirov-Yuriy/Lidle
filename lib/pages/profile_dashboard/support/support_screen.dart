import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const String routeName = '/support';

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
                          'Поддержка Lidle',
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

                  // ───── Cards ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      children: [
                        _SupportCard(
                          imagePath: 'assets/support/sale.png',
                          iconBg: Color(0xFF3DBE8B),
                          title: 'Скидки и акции',
                          subtitle: 'О всех скидках и акциях \nможно узнать здесь',
                          onTap: () => Navigator.pushNamed(context, '/discounts-and-promotions'),
                        ),
                        SizedBox(height: 12),
                        _SupportCard(
                          imagePath: 'assets/support/support.png',
                          iconBg: Color(0xFF4DA3FF),
                          title: 'Поддержка',
                          subtitle: 'Все вопросы про Lidle \nможете задать тут',
                          onTap: () => Navigator.pushNamed(context, '/support-chat'),
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
// SUPPORT CARD
// ─────────────────────────────────────────────

class _SupportCard extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SupportCard({
    this.icon,
    this.imagePath,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // icon or image
          Container(
            width: 65,
            height: 88,
            decoration: BoxDecoration(
              color: imagePath != null ? null : iconBg,
              shape: BoxShape.circle,
            ),
            child: imagePath != null
                ? Image.asset(imagePath!, fit: BoxFit.cover)
                : Icon(icon, color: Colors.white, size: 26),
          ),

          const SizedBox(width: 12),

          // text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
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
    );

    return onTap != null
        ? GestureDetector(
            onTap: onTap,
            child: card,
          )
        : card;
  }
}
