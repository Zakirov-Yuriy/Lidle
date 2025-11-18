/// Состояния навигации в приложении.
abstract class NavigationState {
  final int selectedIndex;

  const NavigationState(this.selectedIndex);
}

/// Начальное состояние навигации.
/// Домашняя страница выбрана по умолчанию.
class NavigationInitial extends NavigationState {
  const NavigationInitial() : super(0);
}

/// Состояние с выбранным индексом навигации.
/// [selectedIndex] - индекс выбранного элемента.
class NavigationIndexChanged extends NavigationState {
  const NavigationIndexChanged(int selectedIndex) : super(selectedIndex);
}

/// Состояние навигации к профилю.
/// Требует проверки авторизации.
class NavigationToProfile extends NavigationState {
  const NavigationToProfile() : super(4);
}

/// Состояние навигации к домашней странице.
class NavigationToHome extends NavigationState {
  const NavigationToHome() : super(0);
}

/// Состояние навигации к избранному.
class NavigationToFavorites extends NavigationState {
  const NavigationToFavorites() : super(1);
}
