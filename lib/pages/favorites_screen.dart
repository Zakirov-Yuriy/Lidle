import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/widgets/header.dart';
import '../constants.dart';
import '../widgets/bottom_navigation.dart';

class FavoritesScreen extends StatelessWidget {
  static const routeName = '/favorites';

  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 0.0),
                        child: Header(),
                      ),
            const SizedBox(height: headerTopPadding),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: textPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Мое избранное',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.swap_vert,
                    color: textPrimary,
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Здесь можно будет вставить список избранного
            const Expanded(
              child: Center(
                child: Text(
                  'Пока что здесь пусто',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        selectedIndex: 1,
        onItemSelected: (index) {
          if (index == 0) {
            // Возврат на домашнюю страницу
            Navigator.of(context).pushReplacementNamed('/');
          } else if (index == 4) {
            // Переход к профилю - нужно будет обновить логику позже
            Navigator.of(context).pushNamed('/profile_dashboard');
          }
          // Другие индексы пока не обрабатываем
        },
      ),
    );
  }
}
