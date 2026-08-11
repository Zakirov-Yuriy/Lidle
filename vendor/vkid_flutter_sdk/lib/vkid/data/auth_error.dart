part of '../../library_vkid.dart';

/// An error encountered during auth.
sealed class AuthError {
  const AuthError._();
}

/// A cancellation error which happens which user returns to your app without completing auth process.
class AuthCancelledError extends AuthError {
  const AuthCancelledError._() : super._();
}

/// Any other error encountered during auth process.
class AuthOtherError extends AuthError {
  /// Details about the error.
  final String description;

  const AuthOtherError._(this.description) : super._();
}
