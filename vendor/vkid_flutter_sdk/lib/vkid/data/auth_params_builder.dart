part of '../../library_vkid.dart';

/// A builder for [AuthParams].
class AuthParamsBuilder {
  AuthLocale? _locale;
  AuthTheme? _theme;
  bool _useOAuthProviderIfPossible = true;
  OAuth? _oAuth;
  AuthFlowData _authFlowData = const PublicFlowData(null);
  Set<String> _scopes = const {};

  /// Specifies a language which will be used during auth process.
  AuthParamsBuilder withLocale(AuthLocale? locale) {
    _locale = locale;
    return this;
  }

  /// Specifies a theme which will be used during auth process.
  AuthParamsBuilder withTheme(AuthTheme? theme) {
    _theme = theme;
    return this;
  }

  /// Specifies whether to use auth providers (other apps from VK ecosystem) to get auth credentials from.
  ///
  /// Works only on Android.
  AuthParamsBuilder withUseOAuthProviderIfPossible(
      bool useOAuthProviderIfPossible) {
    _useOAuthProviderIfPossible = useOAuthProviderIfPossible;
    return this;
  }

  /// Specifies the [OAuth] to be used for auth.
  AuthParamsBuilder withOAuth(OAuth? oAuth) {
    _oAuth = oAuth;
    return this;
  }

  /// Specifies an auth flow which you want to use. See [AuthFlowData] for more info.
  AuthParamsBuilder withAuthFlow(AuthFlowData authFlowData) {
    _authFlowData = authFlowData;
    return this;
  }

  /// Specifies a set of scopes which will be requested from user.
  ///
  /// Not all of them may be granted.
  /// You have to specify a subset a scopes that you request for your app in Self Service.
  /// If you keep the scopes empty, only the default scope will be requested from user.
  /// You can view the list of available scopes here: https://dev.vk.ru/ru/reference/access-rights.
  /// The user will see a screen where he may grant some of this scopes during authorization process.
  AuthParamsBuilder withScopes(Set<String> scopes) {
    _scopes = scopes;
    return this;
  }

  /// Builds [AuthParams] instance with values provided earlier.
  AuthParams build() {
    return AuthParams(
      locale: _locale,
      theme: _theme,
      useOAuthProviderIfPossible: _useOAuthProviderIfPossible,
      oAuth: _oAuth,
      authFlowData: _authFlowData,
      scopes: _scopes,
    );
  }
}
