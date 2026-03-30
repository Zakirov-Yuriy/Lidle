// ============================================================
// "BLoC для управления соединением с интернетом"
// Слушает изменения статуса сети и уведомляет UI слой
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_event.dart';
import 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity;
  late Stream<List<ConnectivityResult>> _connectivityStream;

  ConnectivityBloc({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const ConnectivityInitial()) {
    // Регистрируем обработчики событий
    on<CheckConnectivityEvent>(_onCheckConnectivity);
    on<ConnectedEvent>(_onConnected);
    on<DisconnectedEvent>(_onDisconnected);

    // Инициализируем слушание изменений сети
    _initConnectivityListener();
  }

  /// Инициализируем слушание потока изменений сети
  void _initConnectivityListener() {
    _connectivityStream = _connectivity.onConnectivityChanged;

    _connectivityStream.listen((results) {
      // Проверяем есть ли хоть одно активное соединение
      final hasConnection = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);

      if (hasConnection) {
        add(const ConnectedEvent());
      } else {
        add(const DisconnectedEvent());
      }
    });
  }

  /// Проверяем текущий статус сети
  Future<void> _onCheckConnectivity(
    CheckConnectivityEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    try {
      final result = await _connectivity.checkConnectivity();

      final hasConnection = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);

      if (hasConnection) {
        emit(const ConnectedState());
      } else {
        emit(const DisconnectedState());
      }
    } catch (e) {
      // По умолчанию считаем что есть соединение при ошибке
      emit(const ConnectedState());
    }
  }

  /// Обработчик события подключения
  Future<void> _onConnected(
    ConnectedEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    emit(const ConnectedState());
  }

  /// Обработчик события отключения
  Future<void> _onDisconnected(
    DisconnectedEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    emit(const DisconnectedState());
  }
}
