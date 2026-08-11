part of '../../library_vkid.dart';

/// A data received during token refreshing.
class RefreshTokenData {
  /// An access token which can be used to access VK API.
  final String accessToken;

  RefreshTokenData._(this.accessToken);
}
