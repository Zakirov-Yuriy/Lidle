import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';
import '../../services/token_service.dart';
import '../../pages/auth/sign_in_screen.dart';
import '../../pages/profile_dashboard/profile_dashboard.dart';
import '../../pages/favorites_screen.dart';
import '../../pages/add_listing/add_listing_screen.dart';
import '../../pages/add_listing/category_selection_screen.dart';
import '../../pages/my_purchases_screen.dart'; // Import MyPurchasesScreen
import '../../pages/messages/messages_page.dart'; // Import MessagesPage

/// Bloc для управления состоянием навигации.
/// Обрабатывает события навигации и управляет переходами между страницами.
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  /// Текущий выбранный индекс в BottomNavigation
  int _currentNavigationIndex = 0;

  /// Сохраняет текущий индекс в качестве предыдущего перед изменением
  int _previousNavigationIndex = 0;

  /// Конструктор NavigationBloc.
  /// Инициализирует Bloc с начальным состоянием NavigationInitial.
  NavigationBloc() : super(const NavigationInitial()) {
    on<ChangeNavigationIndexEvent>(_onChangeNavigationIndex);
    on<NavigateToProfileEvent>(_onNavigateToProfile);
    on<NavigateToHomeEvent>(_onNavigateToHome);
    on<NavigateToFavoritesEvent>(_onNavigateToFavorites);
    on<NavigateToAddListingEvent>(_onNavigateToAddListing);
    on<NavigateToCategorySelectionEvent>(_onNavigateToCategorySelection);
    on<NavigateToMyPurchasesEvent>(
      _onNavigateToMyPurchases,
    ); // Handle new event
    on<NavigateToMessagesEvent>(_onNavigateToMessages);
    on<SelectNavigationIndexEvent>(_onSelectNavigationIndex);
  }

  /// Возвращает текущий индекс навигации
  int get currentNavigationIndex => _currentNavigationIndex;

  /// Возвращает предыдущий индекс навигации
  int get previousNavigationIndex => _previousNavigationIndex;

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
    final token = TokenService.currentToken;
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

  /// Обработчик события навигации к избранному.
  void _onNavigateToFavorites(
    NavigateToFavoritesEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(const NavigationToFavorites());
    _navigateToFavorites();
  }

  /// Обработчик события навигации к выбору категории объявления.
  void _onNavigateToCategorySelection(
    NavigateToCategorySelectionEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(const NavigationToCategorySelection());
    _navigateToCategorySelection();
  }

  /// Обработчик события навигации к добавлению объявления.
  void _onNavigateToAddListing(
    NavigateToAddListingEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(const NavigationToAddListing());
    _navigateToAddListing();
  }

  /// Обработчик события навигации к Моим покупкам.
  void _onNavigateToMyPurchases(
    NavigateToMyPurchasesEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(const NavigationToMyPurchases());
    _navigateToMyPurchases();
  }

  /// Обработчик события навигации к сообщениям.
  void _onNavigateToMessages(
    NavigateToMessagesEvent event,
    Emitter<NavigationState> emit,
  ) {
    emit(const NavigationToMessages());
    _navigateToMessages();
  }

  /// Обработчик события выбора элемента навигации.
  /// Проверяет авторизацию для защищенных разделов.
  /// Избранное (индекс 1) доступно всем пользователям.
  Future<void> _onSelectNavigationIndex(
    SelectNavigationIndexEvent event,
    Emitter<NavigationState> emit,
  ) async {
    // Сохраняем предыдущий индекс перед изменением
    _previousNavigationIndex = _currentNavigationIndex;
    _currentNavigationIndex = event.index;

    // Индексы: 0 - Домой, 1 - Избранное, 2 - Добавить, 3 - Мои покупки, 4 - Сообщения, 5 - Профиль
    // Проверяем авторизацию
    final token = TokenService.currentToken;
    final isAuthenticated = token != null && token.isNotEmpty;

    switch (event.index) {
      case 0:
        // Домой всегда доступен
        emit(const NavigationToHome());
        _navigateToHome();
        break;
      case 1:
        // 🎏 Избранное доступно ВСЕМ (авторизованным и неавторизованным)
        emit(const NavigationToFavorites());
        _navigateToFavorites();
        break;
      case 2:
      case 3:
      case 4:
      case 5:
        // Остальные разделы требуют авторизацию
        if (isAuthenticated) {
          switch (event.index) {
            case 2:
              emit(const NavigationToCategorySelection());
              _navigateToCategorySelection();
              break;
            case 3: // Мои покупки
              emit(const NavigationToMyPurchases());
              _navigateToMyPurchases();
              break;
            case 4: // Сообщения
              emit(const NavigationToMessages());
              _navigateToMessages();
              break;
            case 5: // Профиль
              emit(const NavigationToProfile());
              _navigateToProfile();
              break;
          }
        } else {
          // Не авторизован - редирект на sign_in
          emit(const NavigationToSignIn());
          _navigateToSignIn();
        }
        break;
      default:
        // Для других - пока на home
        emit(const NavigationToHome());
        _navigateToHome();
    }
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

  /// Приватный метод для навигации к избранному.
  void _navigateToFavorites() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Приватный метод для навигации к выбору категории объявления.
  void _navigateToCategorySelection() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Приватный метод для навигации к добавлению объявления.
  void _navigateToAddListing() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Приватный метод для навигации к Моим покупкам.
  void _navigateToMyPurchases() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Приватный метод для навигации к сообщениям.
  void _navigateToMessages() {
    // Навигация будет выполнена в UI через BlocListener
  }

  /// Метод для выполнения навигации с учетом контекста.
  /// [context] - BuildContext для выполнения навигации.
  void executeNavigation(BuildContext context) {
    if (state is NavigationToProfile) {
      _executeProfileNavigation(context);
    } else if (state is NavigationToHome) {
      _executeHomeNavigation(context);
    } else if (state is NavigationToFavorites) {
      _executeFavoritesNavigation(context);
    } else if (state is NavigationToAddListing) {
      _executeAddListingNavigation(context);
    } else if (state is NavigationToCategorySelection) {
      _executeCategorySelectionNavigation(context);
    } else if (state is NavigationToMyPurchases) {
      _executeMyPurchasesNavigation(context); // Handle MyPurchases navigation
    } else if (state is NavigationToMessages) {
      _executeMessagesNavigation(context);
    } else if (state is NavigationToSignIn) {
      _executeSignInNavigation(context);
    }
  }

  /// Выполняет навигацию к профилю или странице входа.
  Future<void> _executeProfileNavigation(BuildContext context) async {
    final token = TokenService.currentToken;
    if (!context.mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushNamed(ProfileDashboard.routeName);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        SignInScreen.routeName,
        (route) => route.settings.name == '/' || route.isFirst,
      );
    }
  }

  /// Выполняет навигацию к домашней странице.
  void _executeHomeNavigation(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/');
  }

  /// Выполняет навигацию к избранному.
  void _executeFavoritesNavigation(BuildContext context) {
    Navigator.of(context).pushNamed(FavoritesScreen.routeName);
  }

  /// Выполняет навигацию к экрану входа.
  void _executeSignInNavigation(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      SignInScreen.routeName,
      (route) => route.settings.name == '/' || route.isFirst,
    );
  }

  /// Выполняет навигацию к добавлению объявления.
  void _executeAddListingNavigation(BuildContext context) {
    Navigator.of(context).pushNamed(AddListingScreen.routeName);
  }

  /// Выполняет навигацию к выбору категории объявления.
  void _executeCategorySelectionNavigation(BuildContext context) {
    Navigator.of(context).pushNamed(CategorySelectionScreen.routeName);
  }

  /// Выполняет навигацию к Моим покупкам.
  void _executeMyPurchasesNavigation(BuildContext context) {
    Navigator.of(context).pushNamed(MyPurchasesScreen.routeName);
  }

  /// Выполняет навигацию к сообщениям.
  void _executeMessagesNavigation(BuildContext context) {
    Navigator.of(context).pushNamed(MessagesPage.routeName);
  }
}
