import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';
import '../../hive_service.dart';
import '../../pages/sign_in_screen.dart';
import '../../pages/profile_dashboard.dart';

/// Bloc для управления состоянием навигации.
/// Обрабатывает события навигации и управляет переходами между страницами.
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  /// Конструктор NavigationBloc.
  /// Инициализирует Bloc с начальным состоянием NavigationInitial.
  NavigationBloc() : super(const NavigationInitial()) {
    on<ChangeNavigationIndexEvent>(_onChangeNavigationIndex);
    on<NavigateToProfileEvent>(_onNavigateToProfile);
    on<NavigateToHomeEvent>(_onNavigateToHome);
  }

  /// Обработчик события изменения индекса навигации.
  /// Изменяет выбранный индекс навигации.
  void _onChangeNavigationIndex(
    ChangeNavigationIndexEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(NavigationIndexChanged(event.index));
  }

  /// Обработчик события навигации к профилю.
  /// Проверяет авторизацию пользователя и выполняет соответствующий переход.
  Future<void> _onNavigateToProfile(
    NavigateToProfileEvent event,
    Emitter<NavigationState> emit,
  ) async {
    emit(const NavigationToProfile());

    // Проверяем, авторизован ли пользователь
    final token = await HiveService.getUserData('token');
    if (token != null && token.isNotEmpty) {
      // Пользователь авторизован - переходим в профиль
      _navigateToProfile();
    } else {
      // Пользователь не авторизован - переходим на вход
      _navigateToSignIn();
    }
  }

  /// Обработчик события навигации к домашней странице.
  void _onNavigateToHome(
    NavigateToHomeEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(const NavigationToHome());
    _navigateToHome();
  }

  /// Приватный метод для навигации к профилю.
  /// Используется для выполнения перехода на страницу профиля.
  void _navigateToProfile() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Приватный метод для навигации к странице входа.
  /// Используется для выполнения перехода на страницу авторизации.
  void _navigateToSignIn() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Приватный метод для навигации к домашней странице.
  /// Используется для выполнения перехода на главную страницу.
  void _navigateToHome() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Метод для выполнения навигации с учетом контекста.
  /// [context] - BuildContext для выполнения навигации.
  void executeNavigation(BuildContext context) {
    if (state is NavigationToProfile) {
      _executeProfileNavigation(context);
    } else if (state is NavigationToHome) {
      _executeHomeNavigation(context);
    }
  }

  /// Выполняет навигацию к профилю или странице входа.
  Future<void> _executeProfileNavigation(BuildContext context) async {
    final token = await HiveService.getUserData('token');
    if (!context.mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(ProfileDashboard.routeName);
    } else {
      Navigator.of(context).pushNamed(SignInScreen.routeName);
    }
  }

  /// Выполняет навигацию к домашней странице.
  void _executeHomeNavigation(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/');
  }
}
