/// Конфигурация приложения для работы с разными окружениями (dev/prod)
/// 
/// Поддерживает переключение между:
/// - Dev сервер: dev-api.lidle.io, dev-img.lidle.io
/// - Prod сервер: api.lidle.io, img.lidle.io

import 'package:logger/logger.dart';

final _logger = Logger();

/// Тип окружения приложения
enum AppEnvironment {
  development('dev'),
  production('prod');

  final String value;
  const AppEnvironment(this.value);
}

/// Конфигурация приложения
/// 
/// Централизованное управление всеми конфигурациями:
/// - API endpoints
/// - WebSocket endpoints
/// - Image CDN endpoints
/// - Документация URLs
/// 
/// Используется во всех местах где нужны endpoints.
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  
  late AppEnvironment _environment;
  late String _apiBaseUrl;
  late String _wsUrl;
  late String _imageBaseUrl;
  late String _documentDomain;

  factory AppConfig() {
    return _instance;
  }

  AppConfig._internal();

  /// Инициализировать конфигурацию по значению environment переменной
  /// 
  /// Это должно быть вызвано в main() перед runApp()
  /// 
  /// Параметры:
  /// - environmentValue: Значение из .env файла
  ///   'dev' - разработка (dev-api.lidle.io)
  ///   'prod' - production (api.lidle.io)
  static Future<void> initialize({required String environmentValue}) async {
    _instance._setEnvironment(environmentValue);
    // _logger.i('🔧 AppConfig инициализирован: ${_instance._environment.value}');
    // _logger.i('   API: ${_instance._apiBaseUrl}');
    // _logger.i('   WS: ${_instance._wsUrl}');
    // _logger.i('   Images: ${_instance._imageBaseUrl}');
  }

  /// Установить окружение и все связанные URLs
  void _setEnvironment(String environmentValue) {
    final isDev = environmentValue.toLowerCase().contains('dev');
    
    _environment = isDev ? AppEnvironment.development : AppEnvironment.production;
    
    if (isDev) {
      _apiBaseUrl = 'https://dev-api.lidle.io/v1';
      _wsUrl = 'wss://dev-api.lidle.io/ws';
      _imageBaseUrl = 'https://dev-img.lidle.io';
      _documentDomain = 'https://dev-lidle.io';
    } else {
      _apiBaseUrl = 'https://api.lidle.io/v1';
      _wsUrl = 'wss://api.lidle.io/ws';
      _imageBaseUrl = 'https://img.lidle.io';
      _documentDomain = 'https://lidle.io';
    }
  }

  /// Текущее окружение
  AppEnvironment get environment => _instance._environment;
  
  /// Base URL для API запросов (включает /v1)
  /// Пример: https://api.lidle.io/v1
  String get apiBaseUrl => _instance._apiBaseUrl;
  
  /// Base URL для WebSocket подключения
  /// Пример: wss://api.lidle.io/ws
  String get wsUrl => _instance._wsUrl;
  
  /// Base URL для изображений на CDN
  /// Пример: https://img.lidle.io
  String get imageBaseUrl => _instance._imageBaseUrl;
  
  /// Домен для документов (политики, согласия, лицензии)
  /// Пример: https://lidle.io
  String get documentDomain => _instance._documentDomain;
  
  /// URL документов
  String get userAgreementUrl => '$documentDomain/documents/user-agreement.pdf';
  String get publicOfferUrl => '$documentDomain/documents/public-offer.pdf';
  String get consentUrl => '$documentDomain/documents/consent.pdf';
  String get privacyPolicyUrl => '$documentDomain/documents/privacy-policy.pdf';
  String get mailingUrl => '$documentDomain/documents/mailing.pdf';
  
  /// Веб сайт приложения
  String get websiteUrl => '$documentDomain/ru';
  
  /// Проверить есть ли dev переменная окружения
  bool get isDevelopment => _environment == AppEnvironment.development;
  bool get isProduction => _environment == AppEnvironment.production;

  @override
  String toString() => '''
AppConfig {
  environment: ${_environment.value}
  apiBaseUrl: $_apiBaseUrl
  wsUrl: $_wsUrl
  imageBaseUrl: $_imageBaseUrl
  documentDomain: $_documentDomain
}''';
}
