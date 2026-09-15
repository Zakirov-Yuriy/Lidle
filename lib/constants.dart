// ============================================================
// "Константы: Цвета, размеры и ассеты приложения"
// ============================================================

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

/// «Сохранено, но не опубликовано» (14.09.2026).
///
/// Один цвет на все три места, где об этом говорится: полоса на сводке,
/// полоса на экране позиций и подсветка самой позиции. Разные оттенки жёлтого
/// в трёх местах читались бы как три разных состояния.
const Color draftAccent = Color(0xFFE0B33C);
const Color draftBackground = Color(0xFF3A2E14);
const Color draftBorder = Color(0xFF7A5C1E);
const Color draftText = Color(0xFFE8D6A8);

/// «Уже в корзине» (15.09.2026).
///
/// Зелёный здесь несёт смысл, а не украшает: он отличает состояние «лежит» от
/// действия «положить», и человек читает кнопку цветом, не разбирая надпись.
/// Один цвет на карточку товара и на всё, что скажет об этом дальше: два
/// разных зелёных читались бы как два разных состояния.
const Color inCartGreen = Color(0xFF34A853);

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
const String shoppingCartIconAsset = 'assets/BottomNavigation/shopping-cart-01.png';
const String messageIconAsset = 'assets/BottomNavigation/message-circle-01.png';
const String userIconAsset = 'assets/BottomNavigation/user-01.png';

