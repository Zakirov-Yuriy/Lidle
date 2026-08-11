part of '../../library_vkid.dart';

/// An error encountered during token refreshing.
sealed class RefreshTokenError {
  const RefreshTokenError._();
}

/// A error due to refresh token expiration.
///
/// If you received this error you should let the user authorize again.
class RefreshTokenExpiredError extends RefreshTokenError {
  const RefreshTokenExpiredError._() : super._();
}

/// Any other error encountered during logout.
class RefreshTokenOtherError extends RefreshTokenError {
  /// Details about the error.
  final String description;

  const RefreshTokenOtherError._(this.description) : super._();
}
