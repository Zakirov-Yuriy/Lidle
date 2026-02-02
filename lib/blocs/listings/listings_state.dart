import '../../models/home_models.dart';

/// Состояния для управления данными объявлений.
/// Определяют различные состояния, в которых может находиться процесс загрузки объявлений.
abstract class ListingsState {}

/// Начальное состояние объявлений.
/// Используется при инициализации Bloc.
class ListingsInitial extends ListingsState {}

/// Состояние загрузки объявлений.
/// Показывает, что выполняется асинхронная операция загрузки данных.
class ListingsLoading extends ListingsState {}

/// Состояние успешной загрузки объявлений.
/// Содержит список объявлений и категорий.
class ListingsLoaded extends ListingsState {
  final List<Listing> listings;
  final List<Category> categories;
  final List<Listing> filteredListings;

  /// Текущая номер страницы (начинается с 1)
  final int currentPage;

  /// Общее количество страниц доступных на сервере
  final int totalPages;

  /// Количество объявлений на одной странице
  final int itemsPerPage;

  ListingsLoaded({
    required this.listings,
    required this.categories,
    List<Listing>? filteredListings,
    this.currentPage = 1,
    this.totalPages = 1,
    this.itemsPerPage = 10,
  }) : filteredListings = filteredListings ?? listings;
}

/// Состояние ошибки загрузки объявлений.
/// Содержит сообщение об ошибке.
class ListingsError extends ListingsState {
  final String message;

  ListingsError({required this.message});
}

/// Состояние поиска объявлений.
/// Содержит результаты поиска.
class ListingsSearchResults extends ListingsState {
  final List<Listing> searchResults;
  final String query;

  ListingsSearchResults({required this.searchResults, required this.query});
}

/// Состояние фильтрации объявлений по категории.
/// Содержит отфильтрованные объявления.
class ListingsFiltered extends ListingsState {
  final List<Listing> filteredListings;
  final String categoryId;

  ListingsFiltered({required this.filteredListings, required this.categoryId});
}

/// Состояние успешной загрузки одного объявления.
/// Содержит полные данные объявления.
class AdvertLoaded extends ListingsState {
  final Listing listing;

  AdvertLoaded({required this.listing});
}
