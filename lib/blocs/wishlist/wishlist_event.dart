// ============================================================
// "BLoC Events: События для управления избранным"
// ============================================================

part of 'wishlist_bloc.dart';

/// Базовый класс для всех событий WishlistBloc.
abstract class WishlistEvent extends Equatable {
  const WishlistEvent();

  @override
  List<Object?> get props => [];
}

/// События для загрузки избранного с сервера.
///
/// Синхронизирует локальное хранилище с серверным состоянием.
/// Обычно вызывается при старте приложения.
class LoadWishlistEvent extends WishlistEvent {
  const LoadWishlistEvent();

  @override
  List<Object?> get props => [];
}

/// Событие для добавления объявления в избранное на сервере.
///
/// Инициирует запрос к API для добавления в wishlist.
/// Локальное хранилище уже обновлено (оптимистичное обновление).
class AddToWishlistEvent extends WishlistEvent {
  /// ID объявления для добавления
  final int listingId;

  const AddToWishlistEvent({required this.listingId});

  @override
  List<Object?> get props => [listingId];
}

/// Событие для удаления объявления из избранного на сервере.
///
/// Инициирует запрос к API для удаления из wishlist.
/// Локальное хранилище уже обновлено (оптимистичное обновление).
class RemoveFromWishlistEvent extends WishlistEvent {
  /// ID объявления в wishlist для удаления
  final int listingId;

  const RemoveFromWishlistEvent({required this.listingId});

  @override
  List<Object?> get props => [listingId];
}

/// Событие для синхронизации избранного с сервером.
///
/// Может быть использовано для периодической синхронизации
/// или при возвращении в приложение после фонового режима.
class SyncWishlistEvent extends WishlistEvent {
  /// Если true, загружает полный список с сервера
  /// Если false, только проверяет статус последних операций
  final bool fullSync;

  const SyncWishlistEvent({this.fullSync = false});

  @override
  List<Object?> get props => [fullSync];
}

/// Событие для синхронизации локального избранного при авторизации.
///
/// Вызывается автоматически когда пользователь авторизуется.
/// Синхронизирует локальное избранное (из Hive) с серверным.
class SyncLocalWishlistOnAuthEvent extends WishlistEvent {
  const SyncLocalWishlistOnAuthEvent();

  @override
  List<Object?> get props => [];
}
