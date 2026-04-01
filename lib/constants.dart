// ============================================================
// "Константы: Цвета, размеры и ассеты приложения"
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lidle/core/logger.dart';

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
const double headerTopPadding = 10.0;
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

const String appTitle = 'ЛИДЛ LIDLE';
const String searchPlaceholder = 'Поиск';
const String categoriesTitle = 'Предложения на ЛИДЛ LIDLE';
const String viewAll = 'Смотреть все';
const String latestTitle = 'Самое новое';

// ============================================================
//  Пути к ассетам
// ============================================================

const String logoAsset = 'assets/home_page/logo2.svg';
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

/// Возвращает List<TextSpan> для форматирования заголовка возможностей
/// ЛИДЛ отображается обычным цветом, LIDLE - цветом activeIconColor и размером 13
List<TextSpan> getCapabilitiesTitleSpans() {
  return [
    const TextSpan(
      text: 'Возможности ЛИДЛ ',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    const TextSpan(
      text: 'LIDLE',
      style: TextStyle(
        color: activeIconColor,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    ),
  ];
}

/// Возвращает List<TextSpan> для форматирования заголовка приложения
/// ЛИДЛ отображается обычным цветом, LIDLE - цветом activeIconColor и размером 13
List<TextSpan> getAppTitleSpans() {
  return [
    const TextSpan(
      text: 'ЛИДЛ ',
      style: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    const TextSpan(
      text: 'LIDLE',
      style: TextStyle(
        color: activeIconColor,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    ),
  ];
}

/// Возвращает List<TextSpan> для форматирования заголовка поддержки
/// ЛИДЛ отображается обычным цветом, LIDLE - цветом activeIconColor и размером 13
List<TextSpan> getSupportTitleSpans() {
  return [
    const TextSpan(
      text: 'Поддержка ЛИДЛ ',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),
    const TextSpan(
      text: 'LIDLE',
      style: TextStyle(
        color: activeIconColor,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  ];
}

/// Возвращает List<TextSpan> для форматирования заголовка с категориями
/// ЛИДЛ отображается обычным цветом, LIDLE - цветом activeIconColor и размером 13
List<TextSpan> getCategoriesTitleSpans() {
  return [
    const TextSpan(
      text: 'Предложения на ЛИДЛ ',
      style: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    const TextSpan(
      text: 'LIDLE',
      style: TextStyle(
        color: activeIconColor,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    ),
  ];
}

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
      // log.d('❌ Error loading profile image: $e');
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      );
    }
  }
}
