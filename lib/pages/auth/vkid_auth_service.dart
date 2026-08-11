import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:vkid_flutter_sdk/library_vkid.dart';

/// Результат авторизации VK ID через нативный SDK (confidential flow).
///
/// SDK сам НЕ меняет код на токены: он возвращает authorization code, device_id
/// и redirect_uri, которые мы отдаём на бэк (`POST /v1/auth/social`), а бэк
/// делает обмен по PKCE (без client_secret). code_verifier генерируем здесь и
/// храним, чтобы приложить к запросу на бэк.
class VkIdAuthResult {
  final String code;
  final String deviceId;
  final String codeVerifier;

  /// redirect_uri, который вернул SDK. Его ОБЯЗАТЕЛЬНО передать на бэк тем же
  /// значением, иначе обмен кода на токены не пройдёт. Это НЕ https://lidle.ru,
  /// а служебная схема SDK (vk<appid>://...).
  final String redirectUri;

  const VkIdAuthResult({
    required this.code,
    required this.deviceId,
    required this.codeVerifier,
    required this.redirectUri,
  });
}

/// Вход через VK ID нативным SDK. Если на телефоне установлено и залогинено
/// приложение VK (ОК/Mail), авторизация проходит через него в один тап
/// (app-to-app). Иначе SDK открывает системный браузер и подхватывает сессию
/// оттуда. Полный вход (телефон + SMS) остаётся только когда сессии нет нигде.
class VkIdAuthService {
  /// Причина последнего неуспеха авторизации. authorize() при ошибке возвращает
  /// null, а сюда кладёт короткое описание (отмена пользователем либо текст
  /// ошибки SDK). UI по нему решает, показывать ли пользователю уведомление.
  static String? lastError;

  static const String _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Алфавит специально для `state`: VK ID допускает только a-z,A-Z,0-9,_,-
  /// (БЕЗ точки и тильды). Раньше state брался из `_chars`, где есть `.` и `~`,
  /// и когда они случайно попадали в state, VK возвращал «Invalid state».
  /// Отсюда был плавающий сбой (вход срабатывал примерно 1 раз из 3).
  static const String _stateChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';

  static String _randomString(int len) {
    final r = Random.secure();
    return List.generate(len, (_) => _chars[r.nextInt(_chars.length)]).join();
  }

  /// Случайный `state` из разрешённого VK ID алфавита (без `.` и `~`).
  static String _randomState(int len) {
    final r = Random.secure();
    return List.generate(len, (_) => _stateChars[r.nextInt(_stateChars.length)]).join();
  }

  /// PKCE code_challenge = base64url(sha256(code_verifier)) без паддинга.
  static String _codeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Маппинг наших меток провайдера на провайдера VK ID SDK.
  /// Флоу единый VK ID, метка влияет только на то, какой вход подсветить.
  static OAuth _mapProvider(String provider) {
    switch (provider) {
      case 'ok':
        return OAuth.ok;
      case 'mail_ru':
        return OAuth.mail;
      case 'vk':
      default:
        return OAuth.vk;
    }
  }

  /// Запускает авторизацию VK ID. Возвращает [VkIdAuthResult] при успехе или
  /// null, если пользователь отменил вход или произошла ошибка.
  static Future<VkIdAuthResult?> authorize(String provider) async {
    lastError = null;
    final codeVerifier = _randomString(64);
    final state = _randomState(32);
    final challenge = _codeChallenge(codeVerifier);

    final VKID vkid;
    try {
      vkid = await VKID.getInstance();
    } catch (e) {
      // Ошибка инициализации SDK (например, проблема с манифест-плейсхолдерами).
      lastError = 'init: $e';
      return null;
    }
    final completer = Completer<VkIdAuthResult?>();

    vkid.authorize(
      params: AuthParamsBuilder()
          // confidential flow: SDK возвращает code, обмен делаем на бэке.
          .withAuthFlow(ConfidentialFlowData(state, challenge))
          .withOAuth(_mapProvider(provider))
          .withScopes({'email'})
          .build(),
      onAuthCode: (AuthCodeData data, bool isCompletion) {
        // isCompletion сейчас всегда true, но проверяем на будущее.
        if (!isCompletion) return;
        if (completer.isCompleted) return;
        completer.complete(
          VkIdAuthResult(
            code: data.code,
            deviceId: data.deviceID,
            codeVerifier: codeVerifier,
            redirectUri: data.redirectUri,
          ),
        );
      },
      // В confidential flow не вызывается, но перестрахуемся.
      onAuth: (AuthData _) {
        lastError = 'onAuth (неожиданно для confidential flow)';
        if (!completer.isCompleted) completer.complete(null);
      },
      onError: (AuthError error) {
        // Достаём причину: отмена или конкретная ошибка с описанием.
        if (error is AuthOtherError) {
          lastError = 'SDK: ${error.description}';
        } else {
          lastError = 'SDK: отмена/возврат без кода (AuthCancelledError)';
        }
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }
}
