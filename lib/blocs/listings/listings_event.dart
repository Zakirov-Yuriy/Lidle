/// События для управления данными объявлений.
/// Определяют различные действия, которые могут выполняться с объявлениями.
abstract class ListingsEvent {
  const ListingsEvent();
}

/// Событие загрузки объявлений.
/// Используется для инициализации или обновления списка объявлений.
class LoadListingsEvent extends ListingsEvent {
  /// Если true, всегда загружает данные заново (игнорирует кеш).
  /// Используется при pull-to-refresh.
  final bool forceRefresh;

  const LoadListingsEvent({this.forceRefresh = false});
}

/// Событие загрузки категорий.
/// Используется для получения списка доступных категорий.
class LoadCategoriesEvent extends ListingsEvent {
  const LoadCategoriesEvent();
}

/// Событие поиска объявлений.
/// Содержит поисковый запрос для фильтрации объявлений.
class SearchListingsEvent extends ListingsEvent {
  final String query;

  SearchListingsEvent({required this.query});
}

/// Событие фильтрации объявлений по категории.
/// Содержит идентификатор категории для фильтрации.
class FilterListingsByCategoryEvent extends ListingsEvent {
  final String categoryId;

  FilterListingsByCategoryEvent({required this.categoryId});
}

/// Событие сброса фильтров.
/// Возвращает полный список объявлений без фильтрации.
class ResetFiltersEvent extends ListingsEvent {}

/// Событие загрузки одного объявления по ID.
/// Содержит ID объявления для загрузки полных данных.
class LoadAdvertEvent extends ListingsEvent {
  final String advertId;

  LoadAdvertEvent({required this.advertId});
}

/// Событие загрузки следующей страницы объявлений.
/// Используется для пагинации - загружает следующую страницу результатов.
class LoadNextPageEvent extends ListingsEvent {
  const LoadNextPageEvent();
}

/// Событие загрузки конкретной страницы объявлений.
/// Содержит номер страницы для загрузки.
class LoadSpecificPageEvent extends ListingsEvent {
  final int pageNumber;

  LoadSpecificPageEvent({required this.pageNumber});
}
