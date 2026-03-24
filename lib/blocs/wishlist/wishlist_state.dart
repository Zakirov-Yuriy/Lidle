// ============================================================
// "BLoC States: Состояния для управления избранным"
// ============================================================

part of 'wishlist_bloc.dart';

/// Базовый класс для всех состояний WishlistBloc.
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
/// [wishlistIds] - множество ID объявлений в избранном на сервере
/// [syncedAt] - время последней синхронизации
class WishlistLoaded extends WishlistState {
  /// IDs избранных объявлений с сервера
  final Set<int> wishlistIds;

  /// Время последней синхронизации
  final DateTime syncedAt;

  const WishlistLoaded({
    required this.wishlistIds,
    required this.syncedAt,
  });

  @override
  List<Object?> get props => [wishlistIds, syncedAt];
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
