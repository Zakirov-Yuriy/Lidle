part of '../library_vkid.dart';

_handleMethod(
    Function(OneTapOAuth? oAuth, AuthData authData) onAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode,
    Function(OneTapOAuth? oAuth, AuthError error) onError,
    MethodCall call) {
  _handle<OneTapOAuth>(onAuth, onAuthCode, onError, call, OneTapOAuth.values);
}

_handleMethodForWidget(
    Function(OAuth? oAuth, AuthData authData) onAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode,
    Function(OAuth? oAuth, AuthError error) onError,
    MethodCall call) {
  _handle<OAuth>(onAuth, onAuthCode, onError, call, OAuth.values);
}

_handle<T extends Enum>(
    Function(T? oAuth, AuthData authData) onAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode,
    Function(T? oAuth, AuthError error) onError,
    MethodCall call,
    List<T> values) {
  switch (call.method) {
    case "onAuth":
      final data = _parseAuthData(call.arguments);
      final oAuth = _parseOAuth(call.arguments[11], values);
      onAuth(oAuth, data);
    case "onAuthCode":
      onAuthCode(_parseAuthCodeData(call.arguments), true);
    case "onError":
      final error = call.arguments[0] == "cancelled"
          ? const AuthCancelledError._()
          : AuthOtherError._(call.arguments[1] ?? "");
      onError(_parseOAuth(call.arguments[2], values), error);
  }
}

T? _parseOAuth<T extends Enum>(String? name, List<T> values) {
  // ignore: sdk_version_since
  return values.firstWhereOrNull((item) => item.name == name);
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
