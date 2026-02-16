import 'package:equatable/equatable.dart';

abstract class CatalogEvent extends Equatable {
  const CatalogEvent();

  @override
  List<Object?> get props => [];
}

class LoadCatalogs extends CatalogEvent {
  /// Если true, всегда загружает данные заново (игнорирует кеш).
  final bool forceRefresh;

  const LoadCatalogs({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class LoadCatalog extends CatalogEvent {
  final int catalogId;

  const LoadCatalog(this.catalogId);

  @override
  List<Object?> get props => [catalogId];
}

class LoadCategory extends CatalogEvent {
  final int categoryId;

  const LoadCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}
