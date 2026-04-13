/// ============================================================
/// Service для управления выбранным городом на экране filters_screen
/// ============================================================
/// Сохраняет выбранный город в памяти и позволяет получить его
/// на других экранах при потоке навигации из filters_screen
/// 
/// Используется для передачи города между экранами без необходимости
/// передавать параметр через каждый конструктор

class SelectedCityService {
  static final SelectedCityService _instance = SelectedCityService._internal();

  /// Приватный конструктор для Singleton паттерна
  SelectedCityService._internal();

  /// Фабрика для получения одного экземпляра Service
  factory SelectedCityService() {
    return _instance;
  }

  /// Выбранный город
  String? _selectedCity;

  /// Флаг: пришли ли мы с экрана filters_screen
  bool _isFromFiltersScreen = false;

  /// Возвращает выбранный город
  String? get selectedCity => _selectedCity;

  /// Возвращает флаг о том, пришли ли мы с filters_screen
  bool get isFromFiltersScreen => _isFromFiltersScreen;

  /// Сохраняет выбранный город и флаг
  void setSelectedCity(String city, {bool isFromFiltersScreen = false}) {
    _selectedCity = city;
    _isFromFiltersScreen = isFromFiltersScreen;
  }

  /// Очищает данные о выбранном городе
  void clear() {
    _selectedCity = null;
    _isFromFiltersScreen = false;
  }
}
