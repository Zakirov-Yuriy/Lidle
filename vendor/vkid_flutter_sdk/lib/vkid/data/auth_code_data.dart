part of '../../library_vkid.dart';

/// A data received during auth process with [ConfidentialFlowData].
class AuthCodeData {
  /// An authorization code which can be exchanged for tokens with /oauth2/auth method.
  final String code;

  /// The current device ID which must be passed to /oauth2/auth along with code.
  final String deviceID;

  /// A redirect uri which must be passed to /oauth2/auth along with code.
  final String redirectUri;

  AuthCodeData._(this.code, this.deviceID, this.redirectUri);
}
