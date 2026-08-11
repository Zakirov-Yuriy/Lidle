part of '../../library_vkid.dart';

/// Parameters to be passed to auth process from a widget.
/// Can be constructed with [UIAuthParamsBuilder].
class UIAuthParams {
  final AuthFlowData _authFlowData;
  final Set<String> _scopes;
  const UIAuthParams._(
      {AuthFlowData authFlowData = const PublicFlowData(null),
      Set<String> scopes = const {}})
      : _authFlowData = authFlowData,
        _scopes = scopes;
}
