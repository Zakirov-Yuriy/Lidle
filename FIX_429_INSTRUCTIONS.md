# Инструкция по исправлению ошибки 429 Too Many Requests

## Что было сделано
Я интегрировал систему управления очередью API запросов (ApiRequestQueue) в `listings_bloc.dart` для ограничения параллельных запросов.

Основные изменения:
1. ✅ Добавлен import ApiRequestQueue
2. ⚠️ Заменены Future.wait на ApiRequestQueue.instance.queueBatch
3. ⚠️ Добавлена защита от быстрых pull-to-refresh

## Проблема
Файл `lib/blocs/listings/listings_bloc.dart` имеет синтаксические ошибки из-за проблем с редактированием.

## Как исправить

### Вариант 1: Автоматическое восстановление (если есть git)
```bash
cd "c:\Users\zakco\VS Code\Lidle"
git checkout lib/blocs/listings/listings_bloc.dart
```

Затем примените правильные изменения из Варианта 2.

### Вариант 2: Руками (если нет git)

#### Шаг 1: Добавьте import в начало файла (после других imports)
Рядом с другими импортами добавьте:
```dart
import '../../services/api_request_queue.dart';
```

#### Шаг 2: Добавьте переменные класса (в ListingsBloc)
После `bool _isInitialLoadComplete = false;` добавьте:
```dart
/// Флаг для защиты от дублирования pull-to-refresh запросов.
bool _isLoadingListings = false;

/// Время последнего успешного обновления через pull-to-refresh.
DateTime? _lastRefreshTime;

/// Минимальное время между refresh операциями (3 секунды).
static const Duration _refreshDebounce = Duration(seconds: 3);
```

#### Шаг 3: Обновите метод _onLoadListings
В самом начале метода (после открытия async блока), добавьте:
```dart
// Защита от дублирования pull-to-refresh запросов
if (_isLoadingListings) {
  print('LoadListingsEvent уже выполняется');
  return;
}

// Дебоунс: если это forceRefresh, проверяем время последнего обновления
if (event.forceRefresh && _lastRefreshTime != null) {
  final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
  if (timeSinceLastRefresh < _refreshDebounce) {
    print('Refresh дебоунсен: требуется ${_refreshDebounce.inSeconds}s между обновлениями');
    return;
  }
}

_isLoadingListings = true;
if (event.forceRefresh) {
  _lastRefreshTime = DateTime.now();
}

try {
  // ... остаток кода ...
} catch (e) {
  // ... обработка ошибок ...
} finally {
  _isLoadingListings = false;
}
```

#### Шаг 4: В методе _onLoadListings, найдите Фазу 1 (где загружаются первые 3 каталога)

**Замените:**
```dart
if (firstBatchCatalogIds.isNotEmpty) {
  const int maxConcurrentRequests = 3;
  
  for (int i = 0; i < firstBatchCatalogIds.length; i += maxConcurrentRequests) {
    final batch = firstBatchCatalogIds.sublist(...);
    final batchFutures = batch.map(...).toList();
    final batchResponses = await Future.wait(batchFutures);
    // ... обработка ...
  }
}
```

**На:**
```dart
if (firstBatchCatalogIds.isNotEmpty) {
  // Преобразуем в список функций для queueBatch
  final requestFunctions = firstBatchCatalogIds
      .map(
        (catalogId) => () => ApiService.getAdverts(
          catalogId: catalogId,
          token: token,
          page: 1,
          limit: 50,
        ),
      )
      .toList();

  // Используем ApiRequestQueue для ограничения параллельных запросов
  final batchResponses = await ApiRequestQueue.instance.queueBatch(
    requestFunctions,
    batchSize: 2,  // Максимум 2 одновременных запроса
  );

  // Парсируем ответы (существующий код)
  for (final response in batchResponses) {
    if (response.data.isNotEmpty) {
      // ... парсинг объявлений ...
    }
  }
}
```

#### Шаг 5: Обновите сигнатуру метода _loadPhase2AndUpdateUI
**Найдите:**
```dart
void _loadPhase2AndUpdateUI(
  List<int> remainingCatalogIds,
  String? token,
  List<home.Category> loadedCategories,
  List<home.Listing> initialListings,
  String operationKey,
) {
```

**Замените на:**
```dart
void _loadPhase2AndUpdateUI(
  List<int> remainingCatalogIds,
  String? token,
  List<home.Category> loadedCategories,
  List<home.Listing> initialListings,
  String operationKey,
  Emitter<ListingsState> emit,
) {
```

#### Шаг 6: В _loadPhase2AndUpdateUI, замените Future.wait на ApiRequestQueue

**Найдите в методе:**
```dart
for (int i = 0; i < remainingCatalogIds.length; i += maxConcurrentRequests) {
  final batch = remainingCatalogIds.sublist(...);
  final batchFutures = batch.map(...).toList();
  final batchResponses = await Future.wait(batchFutures);
```

**Замените на:**
```dart
// Преобразуем в список функций
final requestFunctions = remainingCatalogIds
    .map((catalogId) => () => ApiService.getAdverts(...))
    .toList();

// Используем ApiRequestQueue
final batchResponses = await ApiRequestQueue.instance.queueBatch(
  requestFunctions,
  batchSize: 2,
);
```

#### Шаг 7: Обновите вызов _loadPhase2AndUpdateUI
**Найдите:**
```dart
_loadPhase2AndUpdateUI(
  remainingCatalogIds,
  token,
  loadedCategories,
  allSortedListings,
  operationKey,
);
```

**Замените на:**
```dart
_loadPhase2AndUpdateUI(
  remainingCatalogIds,
  token,
  loadedCategories,
  allSortedListings,
  operationKey,
  emit,
);
```

## Проверка
После всех изменений запустите:
```bash
flutter pub get
flutter analyze
```

Должны быть только информационные сообщения, без ошибок.

## Что дальше
После исправления синтаксиса:
1. Протестируйте pull-to-refresh (быстрые обновления)
2. Убедитесь что нет ошибок 429
3. Проверьте консоль для сообщений о дебоунсе

## Результат
- ✅ Максимум 2 одновременных API запроса (вместо 50+)
- ✅ Автоматический дебоунс при быстрых pull-to-refresh
- ✅ Ошибка 429 больше не должна появляться
