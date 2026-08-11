part of '../../library_vkid.dart';

/// A data received during auth process.
class AuthData {
  /// An access token which can be used to access VK API.
  final String token;

  /// An id token which can be used to access /oauth2/public_info.
  final String idToken;

  /// The id of the user account which was used for auth.
  final int userID;

  /// An expiration time of the token. Is a timestamp in milliseconds.
  /// If the value is -1 the token will never expire.
  final int expireTime;

  /// The data of the user account which was used for auth.
  final User userData;

  /// A set of scopes which were granted to [token].
  final Set<String> scopes;

  /// Constructs [AuthData] instance.
  AuthData(this.token, this.idToken, this.userID, this.expireTime,
      this.userData, this.scopes);
}
