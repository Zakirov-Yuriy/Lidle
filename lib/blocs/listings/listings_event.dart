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

  /// Это наша собственная повторная попытка после неудачи (16.09.2026).
  ///
  /// Такая попытка не попадает под десятисекундную защиту от частых
  /// обновлений: защита придумана против человека, который дёргает экран
  /// пальцем, а здесь паузу мы и так выдерживаем сами, и она растёт с каждой
  /// неудачей.
  final bool isRetry;

  const LoadListingsEvent({this.forceRefresh = false, this.isRetry = false});
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

/// Переключить ленту главной между своим городом и всей страной (задача 70,
/// переделано 24.09.2026).
///
/// Город из профиля задаёт приоритет выдачи на главной. Человек мог указать его
/// когда-то и забыть, поэтому переключатель стоит там же, где виден результат.
/// Раньше кнопка СТИРАЛА город в профиле: человек терял свой адрес, а лента не
/// менялась, если город записан у его компании. Теперь профиль не трогаем, а
/// просим у сервера ленту без городского приоритета.
class ResetFeedCityEvent extends ListingsEvent {
  /// true — показать объявления всех городов, false — вернуть свой город.
  /// Город в профиле не трогаем ни в том, ни в другом случае (24.09.2026).
  final bool allCities;

  const ResetFeedCityEvent({this.allCities = true});
}
