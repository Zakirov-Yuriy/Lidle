part of '../../library_vkid.dart';

/// An error encountered during auth.
sealed class FetchUserError {
  const FetchUserError._();
}

/// A error due to access token expiration.
///
/// If you received this error you should refresh tokens.
class FetchUserTokenExpiredError extends FetchUserError {
  const FetchUserTokenExpiredError._() : super._();
}

/// Any other error encountered during user fetching.
class FetchUserOtherError extends FetchUserError {
  /// Details about the error.
  final String description;

  const FetchUserOtherError._(this.description) : super._();
}
