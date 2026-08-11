part of '../../library_vkid.dart';

/// A data for the chosen auth flow.
sealed class AuthFlowData {
  const AuthFlowData._();
}

/// A data for the public auth flow which exchanges auth code for tokens inside this SDK.
class PublicFlowData extends AuthFlowData {
  /// An optional state to be passed to auth.
  /// This parameter is used to protect against XSRF.
  /// Should be a 32 byte string from the alphabet a-z,A-Z,0-9,_,-
  final String? state;

  /// Constructs an instance of public flow data with [state].
  const PublicFlowData(this.state) : super._();
}

/// A data for the confidential auth flow which requires you to exchange auth code for
/// access token manually.
class ConfidentialFlowData extends AuthFlowData {
  /// An optional state to be passed to auth.
  /// This parameter is used to protect against XSRF.
  /// Should be a 32 byte string from the alphabet a-z,A-Z,0-9,_,-
  final String? state;

  /// A code challenge to be used for auth. You can find the details in the [RFC](https://datatracker.ietf.org/doc/html/rfc7636#section-4.2).
  final String codeChallenge;

  /// Constructs an instance of confidential flow data with [state] and [codeChallenge].
  const ConfidentialFlowData(this.state, this.codeChallenge) : super._();
}
