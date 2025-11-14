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
