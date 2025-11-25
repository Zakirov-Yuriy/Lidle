/// Виджет нижней навигационной панели приложения.
/// Автоматически определяет текущий экран и обеспечивает навигацию.
import 'package:flutter/material.dart';
import '../constants.dart';

/// `BottomNavigation` - это StatelessWidget, который отображает
/// нижнюю навигационную панель с иконками.
class BottomNavigation extends StatelessWidget {
  /// Callback-функция, вызываемая при выборе нового элемента.
  final ValueChanged<int>? onItemSelected;

  /// Конструктор для `BottomNavigation`.
  const BottomNavigation({
    super.key,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // Определяем индекс на основе текущего роута
    int getSelectedIndex() {
      switch (currentRoute) {
        case '/':
          return 0; // Домой
        case '/favorites':
          return 1; // Избранное
        case '/profile-dashboard':
          return 5; // Профиль
        default:
          return 0; // По умолчанию домой
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

  /// Приватный метод для построения отдельного элемента навигации.
  /// [iconPath] - путь к иконке элемента.
  /// [index] - индекс элемента.
  /// [currentSelected] - текущий выбранный индекс.
  /// Возвращает виджет, представляющий элемент навигации.
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

  /// Приватный метод для построения центрального элемента "Добавить".
  /// [index] - индекс элемента.
  /// [currentSelected] - текущий выбранный индекс.
  /// Возвращает виджет, представляющий центральный элемент.
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
