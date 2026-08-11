part of '../../library_vkid.dart';

/// Parameters to be passed to auth process.
/// Can be constructed with [AuthParamsBuilder].
class AuthParams {
  final AuthLocale? _locale;
  final AuthTheme? _theme;
  final bool _useOAuthProviderIfPossible;
  final OAuth? _oAuth;
  final AuthFlowData _authFlowData;
  final Set<String> _scopes;

  /// Constructs an [AuthParams] instance.
  const AuthParams({
    AuthLocale? locale,
    AuthTheme? theme,
    bool useOAuthProviderIfPossible = true,
    OAuth? oAuth = OAuth.vk,
    AuthFlowData authFlowData = const PublicFlowData(null),
    Set<String> scopes = const {},
  })  : _locale = locale,
        _theme = theme,
        _useOAuthProviderIfPossible = useOAuthProviderIfPossible,
        _oAuth = oAuth,
        _authFlowData = authFlowData,
        _scopes = scopes;
}
