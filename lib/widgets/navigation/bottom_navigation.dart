// ============================================================
// "Виджет: Нижняя навигация"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/pages/favorites_screen.dart';
import 'package:lidle/pages/add_listing/add_listing_screen.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';

class BottomNavigation extends StatelessWidget {
  final ValueChanged<int>? onItemSelected;

  const BottomNavigation({super.key, this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    int getSelectedIndex() {
      switch (currentRoute) {
        case HomePage.routeName:
        case '/': // home property в main.dart использует "/"
          return 0;
        case FavoritesScreen.routeName:
          return 1;
        case AddListingScreen.routeName:
          return 2;
        case MyPurchasesScreen.routeName:
          return 3;
        case MessagesPage.routeName:
          return 4;
        case ProfileDashboard.routeName:
          return 5;
        default:
          return -1; // На дочерних экранах все иконки белые
      }
    }

    final selectedIndex = getSelectedIndex();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, bottomNavPaddingBottom),
        child: Container(
          height: bottomNavHeight,
          decoration: BoxDecoration(
            color: bottomNavBackground,
            borderRadius: BorderRadius.circular(37.5),
            boxShadow: const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, homeIconAsset, 0, selectedIndex),
              _buildNavItem(context, heartIconAsset, 1, selectedIndex),
              _buildCenterAdd(context, 2, selectedIndex),
              _buildNavItem(context, shoppingCartIconAsset, 3, selectedIndex),
              _buildNavItem(context, messageIconAsset, 4, selectedIndex),
              _buildNavItem(context, userIconAsset, 5, selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String iconPath,
    int index,
    int currentSelected,
  ) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          _navigateToScreen(context, index);
          onItemSelected?.call(index);
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

  Widget _buildCenterAdd(BuildContext context, int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          _navigateToScreen(context, index);
          onItemSelected?.call(index);
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

  void _navigateToScreen(BuildContext context, int index) {
    final String routeName;
    switch (index) {
      case 0:
        routeName = HomePage.routeName;
        break;
      case 1:
        routeName = FavoritesScreen.routeName;
        break;
      case 2:
        routeName = AddListingScreen.routeName;
        break;
      case 3:
        routeName = MyPurchasesScreen.routeName;
        break;
      case 4:
        routeName = MessagesPage.routeName;
        break;
      case 5:
        routeName = ProfileDashboard.routeName;
        break;
      default:
        return;
    }

    // Для AddListingScreen (index 2) используем pushNamed вместо pushReplacementNamed,
    // чтобы можно было вернуться назад на предыдущий экран по кнопке "крестик"
    if (index == 2) {
      Navigator.of(context).pushNamed(routeName);
    } else {
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }
}
