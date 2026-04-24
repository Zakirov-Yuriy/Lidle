// ============================================================
// "BLoC States: Состояния для управления избранным"
// ============================================================

part of 'wishlist_bloc.dart';

abstract class WishlistState extends Equatable {
  const WishlistState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние при создании BLoC.
class WishlistInitial extends WishlistState {
  const WishlistInitial();

  @override
  List<Object?> get props => [];
}

/// Состояние загрузки избранного с сервера.
class WishlistLoading extends WishlistState {
  const WishlistLoading();

  @override
  List<Object?> get props => [];
}

/// Состояние успешной загрузки или синхронизации избранного.
///
/// [wishlistIds] - множество ID объявлений в избранном
/// [listings]   - полные объекты объявлений (из wishable, только для авторизованных)
/// [syncedAt]   - время последней синхронизации
/// [isLocal]    - true если это локальное избранное (неавторизованный пользователь)
class WishlistLoaded extends WishlistState {
  /// IDs избранных объявлений
  final Set<int> wishlistIds;

  /// Полные объекты объявлений из API /me/wishlist (поле wishable).
  /// Пустой список для неавторизованных пользователей — тогда
  /// FavoritesScreen фильтрует по wishlistIds из ListingsBloc (старое поведение).
  final List<Listing> listings;

  /// Время последней синхронизации
  final DateTime syncedAt;

  /// Флаг локального/серверного состояния
  final bool isLocal;

  const WishlistLoaded({
    required this.wishlistIds,
    this.listings = const [],
    required this.syncedAt,
    this.isLocal = false,
  });

  @override
  List<Object?> get props => [wishlistIds, listings, syncedAt, isLocal];
}

/// Состояние ошибки при работе с wishlist.
///
/// [message] - описание ошибки для отображения пользователю
/// [code] - код ошибки для логирования ('auth', 'network', 'server' и т.д.)
class WishlistError extends WishlistState {
  /// Сообщение об ошибке
  final String message;

  /// Код ошибки для категоризации
  final String code;

  const WishlistError({
    required this.message,
    this.code = 'unknown',
  });

  @override
  List<Object?> get props => [message, code];
}

/// Состояние для операции добавления в избранное (optimistic).
///
/// Эмитится сразу после пользовательского действия.
/// Локальное хранилище уже обновлено.
class WishlistItemAdded extends WishlistState {
  final int listingId;

  const WishlistItemAdded({required this.listingId});

  @override
  List<Object?> get props => [listingId];
}

/// Состояние для операции удаления из избранного (optimistic).
///
/// Эмитится сразу после пользовательского действия.
/// Локальное хранилище уже обновлено.
class WishlistItemRemoved extends WishlistState {
  final int listingId;

  const WishlistItemRemoved({required this.listingId});

  @override
  List<Object?> get props => [listingId];
}

/// Состояние после успешной синхронизации.
///
/// Используется для уведомления UI об успешном обновлении
/// состояния на сервере.
class WishlistSynced extends WishlistState {
  final Set<int> wishlistIds;

  const WishlistSynced({required this.wishlistIds});

  @override
  List<Object?> get props => [wishlistIds];
}
