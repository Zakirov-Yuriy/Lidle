part of '../library_vkid.dart';

/// A class that provides the ability to work with VKID SDK.
class VKID {
  static final _lock = Lock();
  static VKID? _instance;
  static const _platform = MethodChannel('com.vk.id/vkid');

  /// Provides an instance of this class.
  static Future<VKID> getInstance() async {
    if (_instance == null) {
      return _lock.synchronized(() async {
        _instance ??= VKID();
        return _instance!;
      });
    }
    return _instance!;
  }

  /// Whether logs are enabled. Currently works only on Android.
  Future<bool> get logsEnabled async {
    return (await _platform.invokeMethod("areLogsEnabled")) as bool;
  }

  setLogsEnabled(bool value) async {
    _platform.invokeMethod("setLogsEnabled", value);
  }

  /// An instance of current auth parameters, including token and user.
  Future<AuthData?> get currentAuthData async {
    final List<Object?> result =
        await _platform.invokeMethod("currentAuthData");
    if (result[0] == null) return null;
    return _parseAuthData(result);
  }

  static _defaultOnAuth(AuthData data) {}
  static _defaultOnError(AuthError error) {}
  static _defaultOnAuthCode(AuthCodeData data, bool isCompletion) {}

  /// Initiates the authorization process with optional [params].
  ///
  /// Authorization process launches ui which can be either WebView with auth flow
  /// or auth provider (another app from VK ecosystem).
  ///
  /// In case [AuthParams.authFlowData] as set to [PublicFlowData] in the end of successful
  /// auth process calls [onAuth]. In case it was set to [ConfidentialFlowData] calls [onAuthCode].
  /// The second parameter of [onAuthCode], isCompletion is always true for now.
  /// In case of any error during auth, always calls [onError].
  ///
  /// Usage example:
  /// ```
  /// final vkid = await VKID.getInstance();
  /// vkid.authorize(
  ///     onAuth: (data) => print(data.token),
  ///     onError: (error) => print(error),
  ///     params: AuthParamsBuilder().withLocale(AuthLocale.en).build()
  /// );
  /// ```
  void authorize({
    Function(AuthData authData) onAuth = _defaultOnAuth,
    Function(AuthCodeData authCodeData, bool isCompletion) onAuthCode =
        _defaultOnAuthCode,
    Function(AuthError error) onError = _defaultOnError,
    AuthParams params = const AuthParams(),
  }) async {
    try {
      String? state;
      String? codeChallenge;
      switch (params._authFlowData) {
        case PublicFlowData(state: var actualState):
          state = actualState;
          codeChallenge = null;
          break;
        case ConfidentialFlowData(
            state: var actualState,
            codeChallenge: var actualCodeChallange
          ):
          state = actualState;
          codeChallenge = actualCodeChallange;
          break;
      }
      final List<Object?> result = await _platform.invokeMethod("authorize", [
        // ignore: sdk_version_since
        params._locale?.name,
        // ignore: sdk_version_since
        params._theme?.name,
        params._useOAuthProviderIfPossible,
        // ignore: sdk_version_since
        params._oAuth?.name,
        state,
        codeChallenge,
        params._scopes.toList(),
      ]);
      if (result[0] == "onAuth") {
        onAuth(_parseAuthData(result));
      } else if (result[0] == "onAuthCode") {
        onAuthCode(_parseAuthCodeData(result), true);
      }
    } on PlatformException catch (e) {
      onError(e.code == "cancelled"
          ? const AuthCancelledError._()
          : AuthOtherError._(e.message ?? ""));
    } catch (e) {
      onError(const AuthOtherError._("unknown error"));
    }
  }

  static _defaultOnTokenRefreshed(RefreshTokenData refreshTokenData) {}
  static _defaultOnRefreshTokenError(RefreshTokenError refreshTokenError) {}

  /// Initiates token refreshing with optional [params].
  ///
  /// [onSuccess] is called upon successful token refreshing with the new token.
  /// If any error was encountered during refreshing, calls [onError] instead.
  ///
  /// Usage example:
  /// ```
  /// final vkid = await VKID.getInstance();
  /// vkid.refreshTooken(
  /// .   onSuccess: (data) => print(data.token),
  ///     onError: (error) => print(error),
  ///     params: RefreshTokenParamsBuilder().withState("some state").build()
  /// );
  /// ```
  void refreshToken({
    Function(RefreshTokenData data) onSuccess = _defaultOnTokenRefreshed,
    Function(RefreshTokenError refreshTokenError) onError =
        _defaultOnRefreshTokenError,
    RefreshTokenParams params = const RefreshTokenParams._(),
  }) async {
    try {
      final List<Object?> result =
          await _platform.invokeMethod("refreshToken", []);
      onSuccess(RefreshTokenData._(result[0] as String));
    } on PlatformException catch (e) {
      onError(e.code == "expired"
          ? const RefreshTokenExpiredError._()
          : RefreshTokenOtherError._(e.message ?? ""));
    } catch (e) {
      onError(const RefreshTokenOtherError._("unknown error"));
    }
  }

  static _defaultOnUserFetched(User user) {}
  static _defaultOnUserFetchError(FetchUserError fetchUserError) {}

  /// Fetches user data.
  ///
  /// Calls [onSuccess] with [User] data after fetching. In case any error was encountered during
  /// fetching calls [onError] instead.
  ///
  /// [params] are added for backwards compatibility and for now are always empty.
  ///
  /// Usage example:
  /// ```
  /// final vkid = await VKID.getInstance();
  /// vkid.fetchUser(
  /// .   onSuccess: (user) => print(user.firstName),
  ///     onError: (error) => print(error),
  /// );
  /// ```
  void fetchUser({
    Function(User user) onSuccess = _defaultOnUserFetched,
    Function(FetchUserError user) onError = _defaultOnUserFetchError,
    FetchUserParams params = const FetchUserParams._(),
  }) async {
    try {
      final List<Object?> result =
          await _platform.invokeMethod("fetchUser", []);
      onSuccess(User(
        result[0] as String,
        result[1] as String,
        result[2] as String? ?? "",
        result[3] as String? ?? "",
        result[4] as String? ?? "",
      ));
    } on PlatformException catch (e) {
      onError(e.code == "expired"
          ? const FetchUserTokenExpiredError._()
          : FetchUserOtherError._(e.message ?? ""));
    } catch (e) {
      onError(const FetchUserOtherError._("unknown error"));
    }
  }

  static _defaultOnLogout() {}
  static _defaultOnLogoutError(LogoutError error) {}

  /// Logs out the current user.
  ///
  /// Calls [onSuccess] after logout. In case any error was encountered during
  /// logout calls [onError] instead.
  ///
  /// [params] are added for backwards compatibility and for now are always empty.
  ///
  /// Usage example:
  /// ```
  /// final vkid = await VKID.getInstance();
  /// vkid.logout(
  /// .   onSuccess: () => print("success"),
  ///     onError: (error) => print(error),
  /// );
  /// ```
  void logout({
    Function() onSuccess = _defaultOnLogout,
    Function(LogoutError error) onError = _defaultOnLogoutError,
    LogoutParams params = const LogoutParams._(),
  }) async {
    try {
      await _platform.invokeMethod("logout", []);
      onSuccess();
    } on PlatformException catch (e) {
      onError(e.code == "expired"
          ? const LogoutAccessTokenExpiredError._()
          : LogoutOtherError._(e.message ?? ""));
    } catch (e) {
      onError(const LogoutOtherError._("unknown error"));
    }
  }

  AuthData _parseAuthData(List<Object?> result) {
    return AuthData(
        result[1] as String,
        result[2] as String,
        result[3] as int,
        result[4] as int,
        User(
          result[5] as String,
          result[6] as String,
          result[7] as String? ?? "",
          result[8] as String? ?? "",
          result[9] as String? ?? "",
        ),
        (result[10] as List<Object?>).map((item) => item as String).toSet());
  }

  AuthCodeData _parseAuthCodeData(List<Object?> result) {
    return AuthCodeData._(
      result[1] as String,
      result[2] as String,
      result[3] as String,
    );
  }
}
