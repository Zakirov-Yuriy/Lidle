import 'package:equatable/equatable.dart';
import 'package:lidle/models/catalog_model.dart';

abstract class CatalogState extends Equatable {
  const CatalogState();

  @override
  List<Object?> get props => [];
}

class CatalogInitial extends CatalogState {}

class CatalogLoading extends CatalogState {}

class CatalogsLoaded extends CatalogState {
  final List<Catalog> catalogs;

  const CatalogsLoaded(this.catalogs);

  @override
  List<Object?> get props => [catalogs];
}

class CatalogLoaded extends CatalogState {
  final CatalogWithCategories catalog;

  const CatalogLoaded(this.catalog);

  @override
  List<Object?> get props => [catalog];
}

class CategoryLoaded extends CatalogState {
  final Category category;

  const CategoryLoaded(this.category);

  @override
  List<Object?> get props => [category];
}

class CatalogError extends CatalogState {
  final String message;

  const CatalogError(this.message);

  @override
  List<Object?> get props => [message];
}
