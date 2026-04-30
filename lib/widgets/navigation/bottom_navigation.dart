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
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
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
              log.d('🟦 BottomNav: ⏰ ${DateTime.now().millisecondsSinceEpoch % 100000} Пользователь авторизован. MessagesLoaded с ${messagesState.mainMessages.length} сообщениями');
              for (int i = 0; i < messagesState.mainMessages.length; i++) {
                final msg = messagesState.mainMessages[i];
                final count = msg['unreadCount'];
                int msgUnread = 0;
                
                if (count is int) {
                  msgUnread = count;
                } else if (count is String) {
                  msgUnread = int.tryParse(count) ?? 0;
                }
                
                log.d('  [$i] ${msg['name']} - unreadCount=$count (type: ${count.runtimeType}) → $msgUnread');
                unreadCount += msgUnread;
              }
              log.d('🟦 BottomNav: ⏰ ${DateTime.now().millisecondsSinceEpoch % 100000} Total unreadCount = $unreadCount');
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
        onTap: () {
          final wasNavigated = _navigateToScreen(context, index);
          // Вызываем callback только если навигация была успешна
          if (wasNavigated) {
            onItemSelected?.call(index);
          }
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

  /// Переходит на экран с индексом [index].
  /// Возвращает [true] если навигация была успешна, [false] если авторизация отклонена.
  bool _navigateToScreen(BuildContext context, int index) {
    // Проверяем авторизацию для защищенных экранов
    final token = TokenService.currentToken;
    final isAuthorized = token != null && token.isNotEmpty;
    
    // Индексы защищенных экранов: 2 (категории), 3 (покупки), 4 (сообщения), 5 (профиль)
    const protectedScreens = {2, 3, 4, 5};
    
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
