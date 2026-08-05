/// Конфиг соцвхода на стороне приложения.
///
/// Здесь только ПУБЛИЧНЫЕ данные (App ID и redirect) — это НЕ секреты.
/// Секретные ключи (client secret, service key) хранятся только на бэке;
/// обмен authorization code на токены делает сервер (POST /v1/auth/social).
///
/// App ID берётся в кабинете приложения VK / Одноклассников (у Александра),
/// redirect — один из зарегистрированных доменов Лидле.
class SocialAuthConfig {
  // TODO: подставить числовой App ID из кабинета ВКонтакте.
  static const String vkAppId = '';

  // TODO: подставить числовой App ID из кабинета Одноклассников.
  static const String okAppId = '';

  /// Redirect, зарегистрированный в настройках приложений VK/ОК.
  /// Должен совпадать на стороне провайдера и в запросе к нашему бэку.
  static const String redirectUri = 'https://lidle.ru';

  /// Настроен ли провайдер (задан ли App ID).
  static bool isConfigured(String provider) {
    switch (provider) {
      case 'vk':
        return vkAppId.isNotEmpty;
      case 'ok':
        return okAppId.isNotEmpty;
      default:
        return false;
    }
  }

  /// URL страницы авторизации провайдера (открывается в WebView).
  static String? authorizeUrl(String provider) {
    final redirect = Uri.encodeComponent(redirectUri);
    switch (provider) {
      case 'vk':
        return 'https://oauth.vk.com/authorize'
            '?client_id=$vkAppId'
            '&redirect_uri=$redirect'
            '&response_type=code'
            '&scope=email'
            '&v=5.199';
      case 'ok':
        return 'https://connect.ok.ru/oauth/authorize'
            '?client_id=$okAppId'
            '&scope=GET_EMAIL;VALUABLE_ACCESS'
            '&response_type=code'
            '&redirect_uri=$redirect';
      default:
        return null;
    }
  }
}
