// ============================================================
// "Нижняя навигация"
// ============================================================

import 'package:flutter/material.dart';
import '../constants.dart';
import '../pages/my_purchases_screen.dart';

class BottomNavigation extends StatelessWidget {
  final ValueChanged<int>? onItemSelected;

  const BottomNavigation({
    super.key,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    int getSelectedIndex() {
      switch (currentRoute) {
        case '/':
          return 0;
        case '/favorites':
          return 1;
        case MyPurchasesScreen.routeName:
          return 3;
        case '/profile-dashboard':
          return 5;
        default:
          return 0;
      }
    }

    final selectedIndex = getSelectedIndex();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          bottomNavPaddingBottom,
        ),
        child: Container(
          height: bottomNavHeight,
          decoration: BoxDecoration(
            color: bottomNavBackground,
            borderRadius: BorderRadius.circular(37.5),
            boxShadow: const [

            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(homeIconAsset, 0, selectedIndex),
              _buildNavItem(heartIconAsset, 1, selectedIndex),
              _buildCenterAdd(2, selectedIndex),
              _buildNavItem(shoppingCartIconAsset, 3, selectedIndex),
              _buildNavItem(messageIconAsset, 4, selectedIndex),
              _buildNavItem(userIconAsset, 5, selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String iconPath, int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => onItemSelected?.call(index),
        child: Padding(
          padding: const EdgeInsets.all(0),
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
        borderRadius: BorderRadius.circular(22),
        onTap: () => onItemSelected?.call(index),
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
    );
  }
}
