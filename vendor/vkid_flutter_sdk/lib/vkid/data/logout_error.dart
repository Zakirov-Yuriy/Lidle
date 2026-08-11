part of '../../library_vkid.dart';

/// An error encountered during logout.
sealed class LogoutError {
  const LogoutError._();
}

/// A error due to access token expiration.
///
/// If you received this error you should refresh tokens.
class LogoutAccessTokenExpiredError extends LogoutError {
  const LogoutAccessTokenExpiredError._() : super._();
}

/// Any other error encountered during logout.
class LogoutOtherError extends LogoutError {
  /// Details about the error.
  final String description;

  const LogoutOtherError._(this.description) : super._();
}
