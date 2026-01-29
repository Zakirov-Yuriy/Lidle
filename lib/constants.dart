// ============================================================
// "Константы: Цвета, размеры и ассеты приложения"
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';

// ============================================================
//  Цвета приложения
// ============================================================

const Color primaryBackground = Color(0xFF232E3C);
const Color formBackground = Color(0xFF17212B);
const Color secondaryBackground = Color(0xFF1E2831);
const Color bottomNavBackground = Color(0xFF17212B);
const Color activeIconColor = Color(0xFF00A6FF);
const Color inactiveIconColor = Color(0xFFE5EDF5);
const Color textPrimary = Colors.white;
const Color textSecondary = Color(0xFF9BA5B0);
const Color textMuted = Color(0xFF6B7684);
const Color accentColor = Color(0xFF00B7FF);

// ============================================================
//  Размеры и отступы
// ============================================================

const double defaultPadding = 25.0;
const double headerTopPadding = 19.0;
const double headerBottomPadding = 12.0;
const double headerLeftPadding = 25.0;

const double logoHeight = 20.0;
const double searchBarHeight = 48.0;
const double categoryCardWidth = 115.0;
const double categoryCardHeight = 83.0;
const double listingCardSpacing = 16.0;
const double bottomNavHeight = 57.0;
const double bottomNavPaddingBottom = 0.0;

// ============================================================
//  Текстовые строки
// ============================================================

const String appTitle = 'LIDLE';
const String searchPlaceholder = 'Поиск';
const String categoriesTitle = 'Предложения на LIDLE';
const String viewAll = 'Смотреть все';
const String latestTitle = 'Самое новое';

// ============================================================
//  Пути к ассетам
// ============================================================

const String logoAsset = 'assets/home_page/logo.svg';
const String settingsIconAsset = 'assets/home_page/settings.svg';
const String homeIconAsset = 'assets/BottomNavigation/home-02.png';
const String heartIconAsset = 'assets/BottomNavigation/heart-rounded.png';
const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String plusIconAsset = 'assets/BottomNavigation/plus-circle.png';
const String shoppingCartIconAsset =
    'assets/BottomNavigation/shopping-cart-01.png';
const String messageIconAsset = 'assets/BottomNavigation/message-circle-01.png';
const String userIconAsset = 'assets/BottomNavigation/user-01.png';

// ============================================================
//  Вспомогательные функции
// ============================================================

/// Возвращает Widget для отображения изображения профиля
/// Если imagePath это URL (начинается с http), использует Image.network
/// Если это локальный путь к файлу, использует Image.file
Widget buildProfileImage(
  String? imagePath, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(color: Colors.grey[300]),
    );
  }

  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    // URL - используем Image.network
    return Image.network(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        );
      },
    );
  } else {
    // Локальный файл - используем Image.file
    try {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } catch (e) {
      print('❌ Error loading profile image: $e');
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      );
    }
  }
}
