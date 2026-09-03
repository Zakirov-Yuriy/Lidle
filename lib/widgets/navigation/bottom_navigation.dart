// ============================================================
// "Виджет: Нижняя навигация"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/pages/favorites_screen.dart';
import 'package:lidle/pages/add_listing/category_selection_screen.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';
import 'package:lidle/pages/profile_menu/settings/contact_data/contact_data_screen.dart';
import 'package:lidle/pages/profile_menu/settings/contact_data/company_contact_data_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/dialogs/fill_contacts_dialog.dart';
import 'package:lidle/blocs/messages/messages_bloc.dart';
import 'package:lidle/blocs/messages/messages_state.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/core/logger.dart';

class BottomNavigation extends StatelessWidget {
  final ValueChanged<int>? onItemSelected;

  const BottomNavigation({super.key, this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    // 🔐 Слушаем состояние авторизации
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // 🟢 Если пользователь не авторизован, не загружаем сообщения
        final isAuthenticated = authState is AuthAuthenticated;
        
        return BlocBuilder<MessagesBloc, MessagesState>(
          builder: (context, messagesState) {
            // 📊 Подсчитываем непрочитанные сообщения только если авторизованы
            int unreadCount = 0;
            if (isAuthenticated && messagesState is MessagesLoaded) {
              if (messagesState.totalUnread > 0) {
                unreadCount = messagesState.totalUnread; // авторитетное число с бэка
              } else {
                for (final msg in messagesState.mainMessages) {
                  final count = msg['unreadCount'];
                  if (count is int) unreadCount += count;
                  else if (count is String) unreadCount += int.tryParse(count) ?? 0;
                }
              }
            } else if (!isAuthenticated) {
              log.d('🟦 BottomNav: Пользователь НЕ авторизован, бейдж не показывается');
            } else {
              log.d('🟦 BottomNav: ⏰ ${DateTime.now().millisecondsSinceEpoch % 100000} State is not MessagesLoaded: ${messagesState.runtimeType}');
            }

        final currentRoute = ModalRoute.of(context)?.settings.name;

        int getSelectedIndex() {
          switch (currentRoute) {
            case HomePage.routeName:
            case '/': // home property в main.dart использует "/"
              return 0;
            case FavoritesScreen.routeName:
              return 1;
            case CategorySelectionScreen.routeName:
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
                  _buildNavItem(context, homeIconAsset, 0, selectedIndex, 0),
                  _buildNavItem(context, heartIconAsset, 1, selectedIndex, 0),
                  _buildCenterAdd(context, 2, selectedIndex),
                  // Корзина. Была скрыта «до появления раздела покупок»:
                  // товаров в приложении не существовало, и вести было некуда.
                  // Раздел появился 03.09.2026 — витрина, корзина, оформление
                  // и заказы, — поэтому пункт открыт.
                  //
                  // Индекс 3 сохранён намеренно: навигация в _navigateToScreen
                  // идёт по номеру, и сдвиг сломал бы остальные пункты.
                  _buildNavItem(context, shoppingCartIconAsset, 3, selectedIndex, 0),
                  // 💬 Передаем количество непрочитанных для иконки сообщений
                  _buildNavItem(context, messageIconAsset, 4, selectedIndex, unreadCount),
                  _buildNavItem(context, userIconAsset, 5, selectedIndex, 0),
                ],
              ),
            ),
          ),
        );
            },
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String iconPath,
    int index,
    int currentSelected,
    int unreadCount,
  ) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          final wasNavigated = _navigateToScreen(context, index);
          // Вызываем callback только если навигация была успешна
          if (wasNavigated) {
            onItemSelected?.call(index);
          }
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(13.5),
              child: Image.asset(
                iconPath,
                width: 28,
                height: 28,
                color: isSelected ? activeIconColor : inactiveIconColor,
              ),
            ),
            // 🔴 Бейдж с количеством непрочитанных сообщений (только для иконки сообщений)
            if (index == 4 && unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: activeIconColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
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
        onTap: () => _handleAddTap(context, index),
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

  /// Нажатие на «плюс» (создание объявления).
  ///
  /// Сначала спрашиваем у бэка, заполнены ли обязательные контактные данные
  /// (GET /me/adverts/can-create). Если нет — вместо выбора категории ведём
  /// пользователя на экран контактных данных и подсказываем, какие поля надо
  /// заполнить. Если да — обычный переход к созданию объявления.
  Future<void> _handleAddTap(BuildContext context, int index) async {
    // Проверка авторизации (как для остальных защищённых экранов).
    final token = TokenService.currentToken;
    final isAuthorized = token != null && token.isNotEmpty;
    if (!isAuthorized) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в свой профиль или создайте новый, чтобы продолжить',
      );
      return;
    }

    bool canCreate = true;
    List<dynamic> missing = const [];
    try {
      final resp = await ApiService.get('/me/adverts/can-create', token: token);
      canCreate = resp['can_create'] == true;
      missing = (resp['missing'] as List?) ?? const [];
    } catch (_) {
      // Если проверка не удалась (нет сети и т.п.) — не блокируем: пусть
      // работает как раньше, финальную защиту даёт бэк при публикации (422).
      canCreate = true;
    }

    if (!context.mounted) return;

    if (!canCreate) {
      // Сначала показываем диалог-подсказку. Переход на экран заполнения
      // происходит ТОЛЬКО если пользователь нажал «Заполнить». Закрытие по
      // крестику — остаёмся на месте, без перехода.
      final shouldFill = await showDialog<bool>(
        context: context,
        builder: (_) => const FillContactsDialog(),
      );
      if (shouldFill != true) return;
      if (!context.mounted) return;

      // По префиксу поля решаем, на какой экран вести. Сейчас гейтинг завязан
      // только на контакты компании (company.*), поэтому обычно ведём на экран
      // контактов компании. Если вдруг прилетит user.* — на экран пользователя.
      final hasCompanyMissing = missing.any((m) =>
          m is Map &&
          (m['field']?.toString().startsWith('company.') ?? false));
      final route = hasCompanyMissing
          ? CompanyContactDataScreen.routeName
          : ContactDataScreen.routeName;
      Navigator.of(context).pushNamed(route);
      return;
    }

    // Всё заполнено — обычный переход к выбору категории / созданию объявления.
    Navigator.of(context).pushNamed(CategorySelectionScreen.routeName);
    onItemSelected?.call(index);
  }

  /// Переходит на экран с индексом [index].
  /// Возвращает [true] если навигация была успешна, [false] если авторизация отклонена.
  bool _navigateToScreen(BuildContext context, int index) {
    // Проверяем авторизацию для защищенных экранов
    final token = TokenService.currentToken;
    final isAuthorized = token != null && token.isNotEmpty;
    
    // Индексы защищённых экранов: 2 (категории), 4 (сообщения), 5 (профиль).
    //
    // Раздел товаров (3) намеренно ОТКРЫТ гостю: покупка без регистрации
    // предусмотрена вёрсткой и подтверждена заказчиком, а витрину и корзину
    // за вход не спрячешь — иначе гостевой заказ невозможен в принципе.
    // Личное внутри раздела (список своих заказов) спрашивает вход само.
    const protectedScreens = {2, 4, 5};
    
    if (protectedScreens.contains(index) && !isAuthorized) {
      // Показываем плашку авторизации
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в свой профиль или создайте новый, чтобы продолжить',
      );
      return false; // Навигация отклонена
    }

    final String routeName;
    switch (index) {
      case 0:
        routeName = HomePage.routeName;
        break;
      case 1:
        routeName = FavoritesScreen.routeName;
        break;
      case 2:
        routeName = CategorySelectionScreen.routeName;
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
        return false;
    }

    // Используем pushNamed для всех экранов, чтобы сохранить стек навигации
    // Это позволяет пользователю вернуться на предыдущий экран по кнопке back
    Navigator.of(context).pushNamed(routeName);
    
    return true; // Навигация успешна
  }
}
