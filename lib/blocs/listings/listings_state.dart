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

  ListingsLoaded({
    required this.listings,
    required this.categories,
    List<Listing>? filteredListings,
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
