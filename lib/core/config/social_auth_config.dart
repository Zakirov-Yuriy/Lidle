/// Конфиг соцвхода (VK ID) на стороне приложения.
///
/// Здесь только ПУБЛИЧНЫЕ данные (App ID и redirect). Секретов нет: обмен кода
/// на токены делает бэк (POST /v1/auth/social). Вход единый VK ID: одно
/// приложение закрывает ВК, ОК и Mail (виджет «3 в 1»), поэтому App ID один.
class SocialAuthConfig {
  /// App ID приложения VK ID (прислал Александр 05.08).
  static const String vkAppId = '54685113';

  /// Redirect, зарегистрированный в кабинете VK ID (доверенные redirect).
  /// Должен совпадать в запросе авторизации и при обмене кода на бэке.
  static const String redirectUri = 'https://lidle.ru';

  /// Настроен ли вход (задан ли App ID).
  static bool get isConfigured => vkAppId.isNotEmpty;

  /// URL авторизации VK ID (OAuth 2.1 + PKCE). Внутри пользователь выбирает
  /// ВК / ОК / Mail. `codeChallenge` = base64url(sha256(code_verifier)),
  /// `state` для защиты от подмены.
  static String authorizeUrl({
    required String codeChallenge,
    required String state,
  }) {
    final redirect = Uri.encodeComponent(redirectUri);
    return 'https://id.vk.ru/authorize'
        '?response_type=code'
        '&client_id=$vkAppId'
        '&code_challenge=$codeChallenge'
        '&code_challenge_method=S256'
        '&redirect_uri=$redirect'
        '&state=$state'
        '&scope=email';
  }
}
