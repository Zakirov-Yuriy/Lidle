// ============================================================
//  Cart Bloc
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/features/cart/domain/entities/cart_item_entity.dart';

// События
abstract class CartEvent {}

class AddToCartEvent extends CartEvent {
  final CartItem item;
  AddToCartEvent(this.item);
}

class RemoveFromCartEvent extends CartEvent {
  final String itemId;
  RemoveFromCartEvent(this.itemId);
}

class UpdateQuantityEvent extends CartEvent {
  final String itemId;
  final int quantity;
  UpdateQuantityEvent(this.itemId, this.quantity);
}

class ToggleItemSelectionEvent extends CartEvent {
  final String itemId;
  ToggleItemSelectionEvent(this.itemId);
}

class ToggleSelectAllEvent extends CartEvent {
  final bool selectAll;
  ToggleSelectAllEvent(this.selectAll);
}

class RemoveSelectedItemsEvent extends CartEvent {}

class IncrementQuantityEvent extends CartEvent {
  final String itemId;
  IncrementQuantityEvent(this.itemId);
}

class DecrementQuantityEvent extends CartEvent {
  final String itemId;
  DecrementQuantityEvent(this.itemId);
}

// Состояние
class CartState {
  final List<CartItem> items;
  final bool selectAll;

  CartState({
    required this.items,
    this.selectAll = false,
  });

  CartState copyWith({
    List<CartItem>? items,
    bool? selectAll,
  }) {
    return CartState(
      items: items ?? this.items,
      selectAll: selectAll ?? this.selectAll,
    );
  }

  // Вычисляемые свойства
  bool get hasSelectedItems => items.any((item) => item.quantity > 0); // Для примера
  int get totalItems => items.length;
}

// BLoC
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(CartState(items: [])) {
    on<AddToCartEvent>(_onAddToCart);
    on<RemoveFromCartEvent>(_onRemoveFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ToggleItemSelectionEvent>(_onToggleItemSelection);
    on<ToggleSelectAllEvent>(_onToggleSelectAll);
    on<RemoveSelectedItemsEvent>(_onRemoveSelectedItems);
    on<IncrementQuantityEvent>(_onIncrementQuantity);
    on<DecrementQuantityEvent>(_onDecrementQuantity);
  }

  void _onAddToCart(AddToCartEvent event, Emitter<CartState> emit) {
    final existingItemIndex = state.items.indexWhere((item) => item.id == event.item.id);

    if (existingItemIndex != -1) {
      // Товар уже в корзине, увеличиваем количество
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingItemIndex] = updatedItems[existingItemIndex].copyWith(
        quantity: updatedItems[existingItemIndex].quantity + 1,
      );
      emit(state.copyWith(items: updatedItems));
    } else {
      // Добавляем новый товар
      final updatedItems = List<CartItem>.from(state.items)..add(event.item);
      emit(state.copyWith(items: updatedItems));
    }
  }

  void _onRemoveFromCart(RemoveFromCartEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.where((item) => item.id != event.itemId).toList();
    emit(state.copyWith(items: updatedItems));
  }

  void _onUpdateQuantity(UpdateQuantityEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.map((item) {
      if (item.id == event.itemId) {
        return item.copyWith(quantity: event.quantity);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updatedItems));
  }

  void _onToggleItemSelection(ToggleItemSelectionEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.map((item) {
      if (item.id == event.itemId) {
        return CartItem(
          id: item.id,
          imagePath: item.imagePath,
          title: item.title,
          price: item.price,
          oldPrice: item.oldPrice,
          color: item.color,
          quantity: item.quantity,
          isSelected: !item.isSelected,
        );
      }
      return item;
    }).toList();

    // Проверяем, все ли товары выбраны для обновления selectAll
    final allSelected = updatedItems.every((item) => item.isSelected);
    emit(state.copyWith(items: updatedItems, selectAll: allSelected));
  }

  void _onToggleSelectAll(ToggleSelectAllEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.map((item) {
      return CartItem(
        id: item.id,
        imagePath: item.imagePath,
        title: item.title,
        price: item.price,
        oldPrice: item.oldPrice,
        color: item.color,
        quantity: item.quantity,
        isSelected: event.selectAll,
      );
    }).toList();
    emit(state.copyWith(items: updatedItems, selectAll: event.selectAll));
  }

  void _onIncrementQuantity(IncrementQuantityEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.map((item) {
      if (item.id == event.itemId) {
        return item.copyWith(quantity: item.quantity + 1);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updatedItems));
  }

  void _onRemoveSelectedItems(RemoveSelectedItemsEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.where((item) => !item.isSelected).toList();
    final newSelectAll = false; // После удаления сбрасываем selectAll
    emit(state.copyWith(items: updatedItems, selectAll: newSelectAll));
  }

  void _onDecrementQuantity(DecrementQuantityEvent event, Emitter<CartState> emit) {
    final updatedItems = state.items.map((item) {
      if (item.id == event.itemId && item.quantity > 1) {
        return item.copyWith(quantity: item.quantity - 1);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updatedItems));
  }
}
