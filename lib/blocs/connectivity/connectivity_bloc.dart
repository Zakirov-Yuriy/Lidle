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
    
    print('📱 ConnectivityBloc: Инициализирована с предпочтением: $_userPreference');
    
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

    print('📡 _getAvailableTypes():');
    print('   Результаты от системы: $results');
    print('   Есть Wi-Fi: $hasWifi');
    print('   Есть мобильный: $hasMobile');
    print('   Предпочтение пользователя: $_userPreference');

    // Фильтруем в зависимости от предпочтения пользователя
    if (_userPreference == 'mobile') {
      // Пользователь выбрал мобильный -> игнорируем Wi-Fi
      print('   🎯 Режим: ТОЛЬКО МОБИЛЬНЫЙ (Wi-Fi ИГНОРИРУЕМ)');
      if (hasMobile) {
        types.add('mobile');
        print('   ✅ Добавлен: mobile');
      } else {
        print('   ❌ Мобильный НЕ ДОСТУПЕН!');
      }
    } else if (_userPreference == 'wifi') {
      // Пользователь выбрал Wi-Fi -> игнорируем мобильный
      print('   🎯 Режим: ТОЛЬКО WI-FI (мобильный ИГНОРИРУЕМ)');
      if (hasWifi) {
        types.add('wifi');
        print('   ✅ Добавлен: wifi');
      } else {
        print('   ❌ Wi-Fi НЕ ДОСТУПЕН!');
      }
    } else {
      // Пользователь выбрал 'any' -> берем все доступные, Wi-Fi в приоритете
      print('   🎯 Режим: ЛЮБОЙ (Wi-Fi имеет приоритет)');
      if (hasWifi) {
        types.add('wifi');
        print('   ✅ Добавлен: wifi');
      }
      if (hasMobile) {
        types.add('mobile');
        print('   ✅ Добавлен: mobile');
      }
    }

    print('   👉 Результат _getAvailableTypes: $types');
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
      print('🔍 ConnectivityBloc: Проверка соединения');
      print('   Доступные типы: $availableTypes');
      print('   Предпочтение пользователя: $_userPreference');
      print('   Соединение есть: $hasConnection');

      if (!hasConnection) {
        // Нет соединения вообще
        print('   ❌ Соединения нет');
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
        print('   ✅ Соединение доступно и соответствует предпочтениям');
        emit(
          ConnectedState(
            availableTypes: availableTypes,
            preferredType: _userPreference,
          ),
        );
      } else {
        // Соединение есть, но не того типа что выбрал пользователь
        final activeType = _getActiveConnectionType(availableTypes);
        print('   ❌ Соединение есть ($activeType), но не соответствует предпочтению ($_userPreference)');
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
      print('⚠️  Ошибка при проверке соединения: $e');
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

      print('🔄 ConnectivityBloc: Событие подключения');
      print('   Доступные типы: $availableTypes');
      print('   Предпочтение пользователя: $_userPreference');

      if (_isConnectionAllowed(availableTypes)) {
        print('   ✅ Подключение OK');
        emit(
          ConnectedState(
            availableTypes: availableTypes,
            preferredType: _userPreference,
          ),
        );
      } else {
        print('   ❌ Подключение не соответствует предпочтению');
        emit(
          DisconnectedState(
            reason: 'preference_not_met',
            preferredType: _userPreference,
            availableTypes: availableTypes,
          ),
        );
      }
    } catch (e) {
      print('⚠️  Ошибка при обработке подключения: $e');
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
    print('⚙️ _onSetNetworkPreference: Изменение предпочтения');
    print('   Старое значение: $_userPreference');
    print('   Новое значение: ${event.preference}');
    
    _userPreference = event.preference;
    
    // Сохраняем предпочтение в хранилище
    await HiveService.saveSetting('network_preference', _userPreference);
    print('   ✅ Сохранено в HiveService');
    
    // Переоценяем текущий статус с новым предпочтением
    print('   🔄 Переоценка статуса с новым предпочтением...');
    add(const CheckConnectivityEvent());
  }
}

