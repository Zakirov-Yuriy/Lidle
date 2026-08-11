part of '../../library_vkid.dart';

/// A builder for [UIAuthParams].
class UIAuthParamsBuilder {
  /// The specified auth flow.
  AuthFlowData authFlowData = const PublicFlowData(null);

  /// The specified auth scopes.
  Set<String> scopes = const {};

  /// Specifies an auth flow which you want to use. See [AuthFlowData] for more info.
  UIAuthParamsBuilder withAuthFlow(AuthFlowData authFlowData) {
    this.authFlowData = authFlowData;
    return this;
  }

  /// Specifies a set of scopes which will be requested from user.
  ///
  /// Not all of them may be granted.
  /// You have to specify a subset a scopes that you request for your app in Self Service.
  /// If you keep the scopes empty, only the default scope will be requested from user.
  /// You can view the list of available scopes here: https://dev.vk.ru/ru/reference/access-rights.
  /// The user will see a screen where he may grant some of this scopes during authorization process.
  UIAuthParamsBuilder withScopes(Set<String> scopes) {
    this.scopes = scopes;
    return this;
  }

  /// Builds a [UIAuthParams] with previously specified values.
  UIAuthParams build() {
    return UIAuthParams._(
      authFlowData: authFlowData,
      scopes: scopes,
    );
  }
}
