import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'listings_event.dart';
import 'listings_state.dart';
import '../../models/home_models.dart';

/// Bloc для управления состоянием данных объявлений.
/// Обрабатывает события загрузки, поиска и фильтрации объявлений.
class ListingsBloc extends Bloc<ListingsEvent, ListingsState> {
  /// Задержка имитации загрузки данных (в миллисекундах).
  static const int _loadingDelayMs = 500;

  /// Задержка имитации поиска (в миллисекундах).
  static const int _searchDelayMs = 300;

  /// Задержка имитации фильтрации (в миллисекундах).
  static const int _filterDelayMs = 200;

  /// Конструктор ListingsBloc.
  /// Инициализирует Bloc с начальным состоянием ListingsInitial.
  ListingsBloc() : super(ListingsInitial()) {
    on<LoadListingsEvent>(_onLoadListings);
    on<LoadCategoriesEvent>(_onLoadCategories);
    on<SearchListingsEvent>(_onSearchListings);
    on<FilterListingsByCategoryEvent>(_onFilterListingsByCategory);
    on<ResetFiltersEvent>(_onResetFilters);
  }

  /// Статические данные объявлений.
  /// В будущем можно заменить на загрузку из API.
  static final List<Listing> staticListings = [
    const Listing(
      id: 'listing_1',
      imagePath: 'assets/apartment1.png',
      title: '4-к. квартира, 169,5 м²...',
      price: '78 970 000 ₽',
      location: 'Москва, ул. Кусинена, 21А',
      date: 'Сегодня',
    ),
    const Listing(
      id: 'listing_2',
      imagePath: 'assets/acura_mdx.png',
      title: 'Acura MDX 3.5 AT, 20...',
      price: '2 399 999 ₽',
      location: 'Брянск, Авиационная ул., 34',
      date: '29.08.2024',
    ),
    const Listing(
      id: 'listing_3',
      imagePath: 'assets/acura_rdx.png',
      title: 'Acura RDX 2.3 AT, 2007...',
      price: '2 780 000 ₽',
      location: 'Москва, Отрадная ул., 11',
      date: '29.08.2024',
    ),
    const Listing(
      id: 'listing_4',
      imagePath: 'assets/studio.png',
      title: 'Студия, 35,7 м², 2/6 эт...',
      price: '6 500 000 ₽',
      location: 'Москва, Варшавское ш., 125',
      date: '11.05.2024',
    ),
  ];

  /// Статические данные категорий.
  /// В будущем можно заменить на загрузку из API.
  static final List<Category> _staticCategories = [
    const Category(
      title: 'Недвижи-\nмость',
      color: Colors.blue,
      imagePath: 'assets/14.png',
    ),
    const Category(
      title: 'Авто\nи мото',
      color: Colors.purple,
      imagePath: 'assets/15.png',
    ),
    const Category(
      title: 'Работа',
      color: Colors.orange,
      imagePath: 'assets/16.png',
    ),
    const Category(
      title: 'Подработка',
      color: Colors.teal,
      imagePath: 'assets/17.png',
    ),
  ];

  /// Обработчик события загрузки объявлений.
  /// Загружает статические данные объявлений и категорий.
  Future<void> _onLoadListings(LoadListingsEvent event, Emitter<ListingsState> emit) async {
    emit(ListingsLoading());
    try {
      // Имитация задержки загрузки данных
      await Future.delayed(const Duration(milliseconds: _loadingDelayMs));

      // В будущем здесь будет вызов API
      // final listings = await ApiService.getListings();
      // final categories = await ApiService.getCategories();

      emit(ListingsLoaded(
        listings: staticListings,
        categories: _staticCategories,
      ));
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события загрузки категорий.
  /// Загружает статические данные категорий.
  Future<void> _onLoadCategories(LoadCategoriesEvent event, Emitter<ListingsState> emit) async {
    emit(ListingsLoading());
    try {
      // Имитация задержки загрузки данных
      await Future.delayed(const Duration(milliseconds: _searchDelayMs));

      // В будущем здесь будет вызов API
      // final categories = await ApiService.getCategories();

      emit(ListingsLoaded(
        listings: staticListings,
        categories: _staticCategories,
      ));
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события поиска объявлений.
  /// Выполняет поиск по заголовку и описанию объявлений.
  Future<void> _onSearchListings(SearchListingsEvent event, Emitter<ListingsState> emit) async {
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    emit(ListingsLoading());

    try {
      // Имитация задержки поиска
      await Future.delayed(const Duration(milliseconds: _searchDelayMs));

      final query = event.query.toLowerCase();
      final searchResults = currentState.listings.where((listing) {
        return listing.title.toLowerCase().contains(query) ||
               listing.location.toLowerCase().contains(query);
      }).toList();

      emit(ListingsSearchResults(
        searchResults: searchResults,
        query: event.query,
      ));
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события фильтрации объявлений по категории.
  /// Фильтрует объявления на основе выбранной категории.
  Future<void> _onFilterListingsByCategory(FilterListingsByCategoryEvent event, Emitter<ListingsState> emit) async {
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    emit(ListingsLoading());

    try {
      // Имитация задержки фильтрации
      await Future.delayed(const Duration(milliseconds: _filterDelayMs));

      // Для демонстрации фильтрации используем простую логику
      // В будущем можно реализовать более сложную фильтрацию по API
      List<Listing> filteredListings;
      switch (event.categoryId) {
        case 'real-estate':
          filteredListings = currentState.listings.where((listing) =>
            listing.title.contains('квартира') ||
            listing.title.contains('студия') ||
            listing.imagePath.contains('apartment') ||
            listing.imagePath.contains('studio')
          ).toList();
          break;
        case 'auto':
          filteredListings = currentState.listings.where((listing) =>
            listing.title.contains('Acura') ||
            listing.imagePath.contains('acura')
          ).toList();
          break;
        default:
          filteredListings = currentState.listings;
      }

      emit(ListingsFiltered(
        filteredListings: filteredListings,
        categoryId: event.categoryId,
      ));
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события сброса фильтров.
  /// Возвращает полный список объявлений без фильтрации.
  Future<void> _onResetFilters(ResetFiltersEvent event, Emitter<ListingsState> emit) async {
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    emit(ListingsLoading());

    try {
      // Имитация задержки сброса фильтров
      await Future.delayed(const Duration(milliseconds: _filterDelayMs));

      emit(ListingsLoaded(
        listings: currentState.listings,
        categories: currentState.categories,
      ));
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }
}
