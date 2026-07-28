# Мобильное приложение: использование wishlist_id из объявлений

Бэкенд теперь отдаёт `wishlist_id` в каждом объявлении. Приложение научено брать
его напрямую и не зависеть от полной загрузки вишлиста ради снятия лайка.

## Что исправлено
Раньше при снятии лайка WishlistBloc брал id записи избранного из карты
`_wishlistIdMapping`, которая заполнялась ТОЛЬКО из полного `GET /v1/me/wishlist`.
Если пользователь снимал лайк с карточки/деталей, не заходя на экран «Избранное»,
карта могла быть пустой — и код падал на фолбэк «удалить по id объявления»
(неверный id → лайк не снимался). Теперь `wishlist_id` приходит прямо в
объявлении и передаётся в событие удаления.

## Изменённые файлы (9)
- lib/models/home_models.dart — в модель `Listing` добавлено поле `wishlistId`
  (парсинг `wishlist_id`); `isFavorited` теперь читает и `is_wishlisted`.
- lib/blocs/wishlist/wishlist_event.dart — `RemoveFromWishlistEvent` получил
  необязательный `wishlistId`.
- lib/blocs/wishlist/wishlist_bloc.dart — при удалении id берётся в порядке:
  событие (wishlist_id из объявления) → карта → фолбэк на id объявления;
  пришедший из объявления id кешируется в карту.
- Точки снятия лайка (передают `widget.listing.wishlistId`):
  - lib/widgets/components/product_card.dart
  - lib/widgets/cards/listing_card.dart
  - lib/pages/full_category_screen/property_details_screen.dart
  - lib/pages/full_category_screen/mini_property_details_screen.dart
  - lib/pages/full_category_screen/mini_property_filtered_details_screen.dart
  - lib/pages/profile_dashboard/my_listings/my_listings_property_details_screen.dart

## Совместимость
Аддитивно. Если бэк по какой-то причине не прислал `wishlist_id` (null) —
поведение прежнее (id берётся из карты вишлиста). Ничего не сломается.

## Осталось (не срочно)
Полную загрузку `GET /v1/me/wishlist` можно и дальше использовать для экрана
«Избранное», но карта id теперь дозаполняется и из обычных списков объявлений,
поэтому лишние запросы ради id для удаления больше не нужны.
