import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_event.dart';
import 'package:lidle/blocs/catalog/catalog_state.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc() : super(CatalogInitial()) {
    on<LoadCatalogs>(_onLoadCatalogs);
    on<LoadCatalog>(_onLoadCatalog);
    on<LoadCategory>(_onLoadCategory);
  }

  Future<void> _onLoadCatalogs(
    LoadCatalogs event,
    Emitter<CatalogState> emit,
  ) async {
    emit(CatalogLoading());
    try {
      final token = await HiveService.getUserData('token');
      final response = await ApiService.getCatalogs(token: token);
      emit(CatalogsLoaded(response.data));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onLoadCatalog(
    LoadCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    emit(CatalogLoading());
    try {
      final token = await HiveService.getUserData('token');
      final catalog = await ApiService.getCatalog(
        event.catalogId,
        token: token,
      );
      emit(CatalogLoaded(catalog));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onLoadCategory(
    LoadCategory event,
    Emitter<CatalogState> emit,
  ) async {
    emit(CatalogLoading());
    try {
      final token = await HiveService.getUserData('token');
      final category = await ApiService.getCategory(
        event.categoryId,
        token: token,
      );
      emit(CategoryLoaded(category));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }
}
