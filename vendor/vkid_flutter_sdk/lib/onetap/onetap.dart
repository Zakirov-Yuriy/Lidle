part of '../library_vkid.dart';

/// A One Tap button that provides VKID login interface.
///
/// Example usage:
/// ```
/// final key = GlobalKey();
/// OneTap(
///   key: key,
///   onAuth: (oAuth, data) => print(data.token),
///   onError: (oAuth, error) => print(error),
///   oAuths: const {OneTapOAuth.ok, OneTapOAuth.mail},
///   style: const OneTapStyle(type: OneTapType.system),
///   fastAuthEnabled: false,
///   signInToAnotherAccountButtonEnabled: false,
///   authParams: UIAuthParamsBuilder().withScopes(const {"phone", "email"}).build(),
///   scenario: OneTapTitleScenario.order,
/// );
/// ```
class OneTap extends StatefulWidget {
  final Function(OneTapOAuth? oAuth, AuthData accessToken) _onAuth;
  final Function(AuthCodeData data, bool isCompletion) _onAuthCode;
  final Function(OneTapOAuth? oAuth, AuthError error) _onError;
  final Set<OneTapOAuth> _alternativeOAuths;
  final OneTapStyle _style;
  final bool _fastAuthEnabled;
  final bool _signInToAnotherAccountButtonEnabled;
  final UIAuthParams _authParams;
  final OneTapTitleScenario _scenario;

  static _defaultOnAuthCode(AuthCodeData data, bool isCompletion) {}
  static _defaultOnError(OneTapOAuth? oAuth, AuthError error) {}

  /// Constructs a [OneTap] without alternative [OAuth]s.
  ///
  /// There are some parameters, that you can provide. [key] can be used to retrieve [State] of the widget.
  /// [onAuth] will be called after successful auth if you passed [PublicFlowData] to [authParams].
  /// [onAuthCode] will be called if you passed [ConfidentialFlowData] to [authParams].
  /// [onError] will be called if any error was encountered during auth.
  /// [style] allows to style the widget.
  /// [fastAuthEnabled] allows to disable user fetching on Android.
  /// [signInToAnotherAccountButtonEnabled] allows to hide a button for changing account.
  /// [authParams] specify auth flow and scopes. Read more about them in [UIAuthParamsBuilder].
  /// [scenario] allows to change text on the button.
  const OneTap({
    required Key key,
    required Function(OneTapOAuth? oAuth, AuthData accessToken) onAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode =
        _defaultOnAuthCode,
    Function(OneTapOAuth? oAuth, AuthError error) onError = _defaultOnError,
    OneTapStyle style = const OneTapStyle(),
    bool fastAuthEnabled = true,
    bool signInToAnotherAccountButtonEnabled = true,
    UIAuthParams authParams = const UIAuthParams._(),
    OneTapTitleScenario scenario = OneTapTitleScenario.signIn,
  })  : _onAuth = onAuth,
        _onAuthCode = onAuthCode,
        _onError = onError,
        _alternativeOAuths = const {},
        _style = style,
        _fastAuthEnabled = fastAuthEnabled,
        _signInToAnotherAccountButtonEnabled =
            signInToAnotherAccountButtonEnabled,
        _authParams = authParams,
        _scenario = scenario,
        super(key: key);

  /// Constructs a [OneTap] with alternative [OAuth]s.
  /// The styling in this case is limited.
  ///
  /// There are some parameters, that you can provide. [key] can be used to retrieve [State] of the widget.
  /// [onAuth] will be called after successful auth if you passed [PublicFlowData] to [authParams].
  /// [onAuthCode] will be called if you passed [ConfidentialFlowData] to [authParams].
  /// [onError] will be called if any error was encountered during auth.
  /// [style] allows to style the widget.
  /// [fastAuthEnabled] allows to disable user fetching on Android.
  /// [signInToAnotherAccountButtonEnabled] allows to hide a button for changing account.
  /// [authParams] specify auth flow and scopes. Read more about them in [UIAuthParamsBuilder].
  /// [scenario] allows to change text on the button.
  OneTap.withOAuths({
    required Key key,
    required Function(OneTapOAuth? oAuth, AuthData accessToken) onAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode =
        _defaultOnAuthCode,
    Function(OneTapOAuth? oAuth, AuthError error) onError = _defaultOnError,
    Set<OneTapOAuth> alternativeOAuths = const {},
    OneTapWithOAuthsStyle style = const OneTapWithOAuthsStyle(),
    bool fastAuthEnabled = true,
    bool signInToAnotherAccountButtonEnabled = true,
    UIAuthParams authParams = const UIAuthParams._(),
    OneTapTitleScenario scenario = OneTapTitleScenario.signIn,
  })  : _onAuth = onAuth,
        _onAuthCode = onAuthCode,
        _onError = onError,
        _alternativeOAuths = alternativeOAuths,
        _style = style.toOneTapStyle(),
        _fastAuthEnabled = fastAuthEnabled,
        _signInToAnotherAccountButtonEnabled =
            signInToAnotherAccountButtonEnabled,
        _authParams = authParams,
        _scenario = scenario,
        super(key: key);

  @override
  State<StatefulWidget> createState() => _OneTapState();
}

class _OneTapState extends State<OneTap> {
  int nativeHeight = 0;

  @override
  Widget build(BuildContext context) {
    double height;
    final creationParams = [
      // ignore: sdk_version_since
      widget._alternativeOAuths.map((item) => item.name).toList(),
      // ignore: sdk_version_since
      widget._style.type.name,
      widget._style.cornersStyle._type,
      widget._style.cornersStyle is OneTapCornersCustom
          ? (widget._style.cornersStyle as OneTapCornersCustom).radius
          : 0.0,
      // ignore: sdk_version_since
      widget._style.size.name,
      widget._fastAuthEnabled,
      widget._signInToAnotherAccountButtonEnabled,
      widget._authParams._authFlowData is PublicFlowData
          ? (widget._authParams._authFlowData as PublicFlowData).state
          : (widget._authParams._authFlowData as ConfidentialFlowData).state,
      widget._authParams._authFlowData is PublicFlowData
          ? null
          : (widget._authParams._authFlowData as ConfidentialFlowData)
              .codeChallenge,
      widget._authParams._scopes.toList(),
      // ignore: sdk_version_since
      widget._scenario.name,
    ];
    StatefulWidget view;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        view = UiKitView(
          viewType: "OneTap",
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _setCallback(id),
        );
        if (widget._alternativeOAuths.isEmpty) {
          height = widget._style.size.value.toDouble();
        } else {
          height = nativeHeight == 0 ? 1.0 : nativeHeight.toDouble();
        }
      case TargetPlatform.android:
        view = AndroidView(
          viewType: 'OneTap',
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _setCallback(id),
        );
        if (widget._alternativeOAuths.isEmpty &&
            !widget._signInToAnotherAccountButtonEnabled) {
          height = widget._style.size.value.toDouble();
        } else {
          height = nativeHeight == 0
              ? 1000.0
              : nativeHeight.toDouble() /
                  MediaQuery.of(context).devicePixelRatio;
        }
      default:
        throw UnsupportedError('Unsupported platform');
    }
    return SizedBox(height: height, child: view);
  }

  void _setCallback(int id) async {
    MethodChannel channel = MethodChannel("com.vk.id/onetap-$id");
    channel.setMethodCallHandler((call) async {
      if (call.method == "onHeight") {
        setState(() {
          nativeHeight = call.arguments as int;
        });
      } else {
        _handleMethod(
            widget._onAuth, widget._onAuthCode, widget._onError, call);
      }
      return null;
    });
  }
}
