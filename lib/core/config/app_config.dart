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

  // ── Reverb (WebSocket, протокол Pusher) ──────────────────────────────
  late String _reverbKey; // публичный REVERB_APP_KEY
  late String _reverbHost; // домен WS (nginx проксирует /app/ на Reverb)
  late int _reverbPort; // 443
  late bool _reverbTls; // true (wss)
  late String _broadcastAuthUrl; // авторизация приватных каналов (Bearer Sanctum)

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
      _documentDomain = 'https://dev.lidle.io';
      // Reverb dev (значения из .env dev-сервера; путь наружу — /app/).
      _reverbKey = 'm0ufb6oybyx6usr93zq3';
      _reverbHost = 'dev-api.lidle.io';
      _reverbPort = 443;
      _reverbTls = true;
      _broadcastAuthUrl = 'https://dev-api.lidle.io/v1/broadcasting/auth';
    } else {
      _apiBaseUrl = 'https://api.lidle.io/v1';
      _wsUrl = 'wss://api.lidle.io/ws';
      _imageBaseUrl = 'https://img.lidle.io';
      _documentDomain = 'https://lidle.io';
      // Reverb prod: TODO — подставить REVERB_APP_KEY с прод-сервера (10.10.10.20).
      _reverbKey = 'PROD_REVERB_APP_KEY';
      _reverbHost = 'api.lidle.io';
      _reverbPort = 443;
      _reverbTls = true;
      _broadcastAuthUrl = 'https://api.lidle.io/v1/broadcasting/auth';
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

  /// Параметры Reverb (WebSocket, протокол Pusher).
  String get reverbKey => _instance._reverbKey;
  String get reverbHost => _instance._reverbHost;
  int get reverbPort => _instance._reverbPort;
  bool get reverbTls => _instance._reverbTls;
  String get broadcastAuthUrl => _instance._broadcastAuthUrl;
  
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
