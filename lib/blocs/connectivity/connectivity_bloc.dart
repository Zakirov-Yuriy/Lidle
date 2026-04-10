// ============================================================
// "BLoC для управления соединением с интернетом"
// Слушает изменения статуса сети и уведомляет UI слой
// Учитывает предпочтения пользователя по типу подключения
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lidle/hive_service.dart';
import 'connectivity_event.dart';
import 'connectivity_state.dart';
import 'package:lidle/core/logger.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity;
  late Stream<List<ConnectivityResult>> _connectivityStream;
  
  /// Предпочтение пользователя: 'wifi', 'mobile', 'any'
  late String _userPreference;

  ConnectivityBloc({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const ConnectivityInitial()) {
    // ВАЖНО: Инициализируем предпочтение ПЕРВЫМ
    _userPreference = HiveService.getSetting('network_preference', defaultValue: 'any') ?? 'any';
    
    // log.d('📱 ConnectivityBloc: Инициализирована с предпочтением: $_userPreference');
    
    // ПОТОМ регистрируем обработчики
    on<CheckConnectivityEvent>(_onCheckConnectivity);
    on<ConnectedEvent>(_onConnected);
    on<DisconnectedEvent>(_onDisconnected);
    on<SetNetworkPreferenceEvent>(_onSetNetworkPreference);

    // ПОТОМ инициализируем слушание (теперь _userPreference уже готов)
    _initConnectivityListener();
    
    // И наконец проверяем текущий статус
    add(const CheckConnectivityEvent());
  }

  /// Инициализируем слушание потока изменений сети
  void _initConnectivityListener() {
    _connectivityStream = _connectivity.onConnectivityChanged;

    _connectivityStream.listen((results) {
      // Определяем доступные типы подключения
      final availableTypes = _getAvailableTypes(results);
      
      // Проверяем есть ли хоть одно активное соединение
      final hasConnection = availableTypes.isNotEmpty;

      if (hasConnection) {
        add(const ConnectedEvent());
      } else {
        add(const DisconnectedEvent());
      }
    });
  }

  /// Получаем ФИЛЬТРОВАННЫЕ доступные типы подключения
  /// В зависимости от предпочтения пользователя:
  /// - Если 'mobile' -> возвращаем только мобильный (Wi-Fi ИГНОРИРУЕМ)
  /// - Если 'wifi' -> возвращаем только Wi-Fi (мобильный ИГНОРИРУЕМ)
  /// - Если 'any' -> возвращаем все доступные типы
  List<String> _getAvailableTypes(List<ConnectivityResult> results) {
    final types = <String>[];
    final hasWifi = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    final hasMobile = results.contains(ConnectivityResult.mobile);

    // log.d('📡 _getAvailableTypes():');
    // log.d('   Результаты от системы: $results');
    // log.d('   Есть Wi-Fi: $hasWifi');
    // log.d('   Есть мобильный: $hasMobile');
    // log.d('   Предпочтение пользователя: $_userPreference');

    // Фильтруем в зависимости от предпочтения пользователя
    if (_userPreference == 'mobile') {
      // Пользователь выбрал мобильный -> игнорируем Wi-Fi
      // log.d('   🎯 Режим: ТОЛЬКО МОБИЛЬНЫЙ (Wi-Fi ИГНОРИРУЕМ)');
      if (hasMobile) {
        types.add('mobile');
        // log.d('   ✅ Добавлен: mobile');
      } else {
        // log.d('   ❌ Мобильный НЕ ДОСТУПЕН!');
      }
    } else if (_userPreference == 'wifi') {
      // Пользователь выбрал Wi-Fi -> игнорируем мобильный
      // log.d('   🎯 Режим: ТОЛЬКО WI-FI (мобильный ИГНОРИРУЕМ)');
      if (hasWifi) {
        types.add('wifi');
        // log.d('   ✅ Добавлен: wifi');
      } else {
        // log.d('   ❌ Wi-Fi НЕ ДОСТУПЕН!');
      }
    } else {
      // Пользователь выбрал 'any' -> берем все доступные, Wi-Fi в приоритете
      // log.d('   🎯 Режим: ЛЮБОЙ (Wi-Fi имеет приоритет)');
      if (hasWifi) {
        types.add('wifi');
        // log.d('   ✅ Добавлен: wifi');
      }
      if (hasMobile) {
        types.add('mobile');
        // log.d('   ✅ Добавлен: mobile');
      }
    }

    // log.d('   👉 Результат _getAvailableTypes: $types');
    return types;
  }

  /// Получаем АКТИВНО ИСПОЛЬЗУЕМЫЙ тип подключения
  /// Если оба доступны, система будет использовать Wi-Fi (выше приоритет)
  String _getActiveConnectionType(List<String> availableTypes) {
    if (availableTypes.isEmpty) return '';
    return availableTypes.first;
  }

  /// Проверяем наличие соединения
  /// Поскольку _getAvailableTypes уже фильтрует по предпочтениям,
  /// просто проверяем есть ли доступные типы подключения
  bool _isConnectionAllowed(List<String> availableTypes) {
    return availableTypes.isNotEmpty;
  }

  /// Проверяем текущий статус сети
  Future<void> _onCheckConnectivity(
    CheckConnectivityEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    try {
      final result = await _connectivity.checkConnectivity();
      final availableTypes = _getAvailableTypes(result);
      final hasConnection = availableTypes.isNotEmpty;

      // 📱 Отладочная информация
      // log.d('🔍 ConnectivityBloc: Проверка соединения');
      // log.d('   Доступные типы: $availableTypes');
      // log.d('   Предпочтение пользователя: $_userPreference');
      // log.d('   Соединение есть: $hasConnection');

      if (!hasConnection) {
        // Нет соединения вообще
        // log.d('   ❌ Соединения нет');
        emit(
          DisconnectedState(
            reason: 'no_internet',
            preferredType: _userPreference,
            availableTypes: availableTypes,
          ),
        );
        return;
      }

      // Есть соединение, но проверяем соответствует ли оно предпочтениям
      if (_isConnectionAllowed(availableTypes)) {
        // log.d('   ✅ Соединение доступно и соответствует предпочтениям');
        emit(
          ConnectedState(
            availableTypes: availableTypes,
            preferredType: _userPreference,
          ),
        );
      } else {
        // Соединение есть, но не того типа что выбрал пользователь
        final activeType = _getActiveConnectionType(availableTypes);
        // log.d('   ❌ Соединение есть ($activeType), но не соответствует предпочтению ($_userPreference)');
        emit(
          DisconnectedState(
            reason: 'preference_not_met',
            preferredType: _userPreference,
            availableTypes: availableTypes,
          ),
        );
      }
    } catch (e) {
      // По умолчанию считаем что есть соединение при ошибке
      // log.d('⚠️  Ошибка при проверке соединения: $e');
      emit(
        const ConnectedState(
          availableTypes: ['wifi', 'mobile'],
          preferredType: 'any',
        ),
      );
    }
  }

  /// Обработчик события подключения
  Future<void> _onConnected(
    ConnectedEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    // Переполучаем текущий статус чтобы узнать доступные типы
    try {
      final result = await _connectivity.checkConnectivity();
      final availableTypes = _getAvailableTypes(result);

      // log.d('🔄 ConnectivityBloc: Событие подключения');
      // log.d('   Доступные типы: $availableTypes');
      // log.d('   Предпочтение пользователя: $_userPreference');

      if (_isConnectionAllowed(availableTypes)) {
        // log.d('   ✅ Подключение OK');
        emit(
          ConnectedState(
            availableTypes: availableTypes,
            preferredType: _userPreference,
          ),
        );
      } else {
        // log.d('   ❌ Подключение не соответствует предпочтению');
        emit(
          DisconnectedState(
            reason: 'preference_not_met',
            preferredType: _userPreference,
            availableTypes: availableTypes,
          ),
        );
      }
    } catch (e) {
      // log.d('⚠️  Ошибка при обработке подключения: $e');
      emit(
        const ConnectedState(
          availableTypes: ['wifi', 'mobile'],
          preferredType: 'any',
        ),
      );
    }
  }

  /// Обработчик события отключения
  Future<void> _onDisconnected(
    DisconnectedEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    emit(
      DisconnectedState(
        reason: 'no_internet',
        preferredType: _userPreference,
        availableTypes: const [],
      ),
    );
  }

  /// Обработчик для изменения предпочтения сети
  Future<void> _onSetNetworkPreference(
    SetNetworkPreferenceEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    // log.d('⚙️ _onSetNetworkPreference: Изменение предпочтения');
    // log.d('   Старое значение: $_userPreference');
    // log.d('   Новое значение: ${event.preference}');
    
    _userPreference = event.preference;
    
    // Сохраняем предпочтение в хранилище
    await HiveService.saveSetting('network_preference', _userPreference);
    // log.d('   ✅ Сохранено в HiveService');
    
    // Переоценяем текущий статус с новым предпочтением
    // log.d('   🔄 Переоценка статуса с новым предпочтением...');
    add(const CheckConnectivityEvent());
  }
}

