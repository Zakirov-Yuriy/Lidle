/// События для управления навигацией в приложении.
abstract class NavigationEvent {}

/// Событие изменения выбранного индекса навигации.
/// [index] - новый индекс выбранного элемента.
class ChangeNavigationIndexEvent extends NavigationEvent {
  final int index;

  ChangeNavigationIndexEvent(this.index);
}

/// Событие навигации к профилю.
/// Проверяет авторизацию пользователя перед переходом.
class NavigateToProfileEvent extends NavigationEvent {}

/// Событие навигации к домашней странице.
class NavigateToHomeEvent extends NavigationEvent {}

/// Событие навигации к избранному.
class NavigateToFavoritesEvent extends NavigationEvent {}

/// Событие навигации к добавлению объявления.
class NavigateToAddListingEvent extends NavigationEvent {}

/// Событие навигации к Моим покупкам.
class NavigateToMyPurchasesEvent extends NavigationEvent {}

/// Событие выбора элемента навигации с проверкой авторизации.
/// Проверяет авторизацию и перенаправляет на sign_in если необходимо.
class SelectNavigationIndexEvent extends NavigationEvent {
  final int index;

  SelectNavigationIndexEvent(this.index);
}
