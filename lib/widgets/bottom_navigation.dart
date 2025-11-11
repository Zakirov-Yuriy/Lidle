/// Виджет нижней навигационной панели приложения.
/// Обеспечивает навигацию между основными разделами приложения.
import 'package:flutter/material.dart';
import '../constants.dart';

/// `BottomNavigation` - это StatelessWidget, который отображает
/// нижнюю навигационную панель с иконками.
class BottomNavigation extends StatelessWidget {
  /// Индекс текущего выбранного элемента навигации.
  final int selectedIndex;
  /// Callback-функция, вызываемая при выборе нового элемента.
  final ValueChanged<int> onItemSelected;

  /// Конструктор для `BottomNavigation`.
  const BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          defaultPadding,
          0,
          defaultPadding,
          bottomNavPaddingBottom,
        ),
        child: Container(
          height: bottomNavHeight,
          decoration: BoxDecoration(
            color: bottomNavBackground,
            borderRadius: BorderRadius.circular(37.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                spreadRadius: 2,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(homeIconAsset, 0),
              _buildNavItem(heartIconAsset, 1),
              _buildCenterAdd(2),
              _buildNavItem(messageIconAsset, 3),
              _buildNavItem(userIconAsset, 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Приватный метод для построения отдельного элемента навигации.
  /// [iconPath] - путь к иконке элемента.
  /// [index] - индекс элемента.
  /// Возвращает виджет, представляющий элемент навигации.
  Widget _buildNavItem(String iconPath, int index) {
    final isSelected = selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => onItemSelected(index),
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

  /// Приватный метод для построения центрального элемента "Добавить".
  /// [index] - индекс элемента.
  /// Возвращает виджет, представляющий центральный элемент.
  Widget _buildCenterAdd(int index) {
    final isSelected = selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onItemSelected(index),
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
