part of '../library_vkid.dart';

/// A OAuth Widget provides VKID login interface.
///
/// Example usage:
/// ```
/// final key = GlobalKey();
/// OAuthWidget(
///   key: key,
///   onAuth: (oAuth, data) => print(data.token),
///   onError: (oAuth, error) => print(error),
///   oAuths: const {OAuth.ok, OAuth.mail},
///   buttonConfig: const OAuthButtonConfiguration(cornersStyle: OneTapCornersDefault(), size: OneTapSize.standard),
///   theme: OAuthWidgetTheme.system,
///   authParams: UIAuthParamsBuilder().withScopes(const {"phone", "email"}).build(),
/// );
/// ```
class OAuthWidget extends StatefulWidget {
  final Function(OAuth? oAuth, AuthData accessToken) _onAuth;
  final Function(AuthCodeData data, bool isCompletion) _onAuthCode;
  final Function(OAuth? oAuth, AuthError error) _onError;
  final Set<OAuth> _oAuths;
  final OAuthButtonConfiguration _buttonConfig;
  final OAuthWidgetTheme _theme;
  final UIAuthParams _authParams;

  static _defaultOnAuth(OAuth? oAuth, AuthData accessToken) {}
  static _defaultOnAuthCode(AuthCodeData data, bool isCompletion) {}
  static _defaultOnError(OAuth? oAuth, AuthError error) {}

  /// Constructs a [OAuthWidget] with [OAuth]s.
  ///
  /// There are some parameters, that you can provide. [key] can be used to retrieve [State] of the widget.
  /// [onAuth] will be called after successful auth if you passed [PublicFlowData] to [authParams].
  /// [onAuthCode] will be called if you passed [ConfidentialFlowData] to [authParams] instead of [PublicFlowData]. This function provides [AuthCodeData] that should be used on your server side to get AccessToken and RefreshToken. [isCompletion] indicates that the method [onAuth] won't be called.
  /// [onError] will be called if any error was encountered during auth.
  /// [oAuths] specifies OAuth providers. By default, all providers will be shown.
  /// [buttonConfig] allows to configure OAuth buttons.
  /// [theme] allows to configure widget theme.
  /// [authParams] specify auth flow and scopes. Read more about them in [UIAuthParamsBuilder].
  const OAuthWidget({
    required Key key,
    Function(OAuth? oAuth, AuthData accessToken) onAuth = _defaultOnAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode =
        _defaultOnAuthCode,
    Function(OAuth? oAuth, AuthError error) onError = _defaultOnError,
    Set<OAuth> oAuths = const {...OAuth.values},
    OAuthButtonConfiguration buttonConfig = const OAuthButtonConfiguration(),
    OAuthWidgetTheme theme = OAuthWidgetTheme.system,
    UIAuthParams authParams = const UIAuthParams._(),
  })  : _onAuth = onAuth,
        _onAuthCode = onAuthCode,
        _onError = onError,
        _oAuths = oAuths,
        _buttonConfig = buttonConfig,
        _theme = theme,
        _authParams = authParams,
        super(key: key);

  @override
  State<StatefulWidget> createState() => _OAuthWidgetState();
}

class _OAuthWidgetState extends State<OAuthWidget> {
  int nativeHeight = 0;

  @override
  Widget build(BuildContext context) {
    double height;
    final creationParams = [
      // ignore: sdk_version_since
      widget._oAuths.map((item) => item.name).toList(),
      widget._buttonConfig.cornersStyle._type,
      widget._buttonConfig.cornersStyle is OneTapCornersCustom
          ? (widget._buttonConfig.cornersStyle as OneTapCornersCustom).radius
          : 0.0,
      widget._buttonConfig.size.name,
      widget._theme.name,
      // ignore: sdk_version_since
      widget._authParams._authFlowData is PublicFlowData
          ? (widget._authParams._authFlowData as PublicFlowData).state
          : (widget._authParams._authFlowData as ConfidentialFlowData).state,
      widget._authParams._authFlowData is PublicFlowData
          ? null
          : (widget._authParams._authFlowData as ConfidentialFlowData)
              .codeChallenge,
      widget._authParams._scopes.toList()
    ];
    StatefulWidget view;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        view = UiKitView(
          viewType: "OAuthWidget",
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _setCallback(id),
        );
        if (widget._oAuths.isEmpty) {
          height = 0;
        } else {
          height = widget._buttonConfig.size.value.toDouble();
        }
      case TargetPlatform.android:
        view = AndroidView(
          viewType: 'OAuthWidget',
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _setCallback(id),
        );
        height = nativeHeight == 0
            ? 1000.0
            : nativeHeight.toDouble() / MediaQuery.of(context).devicePixelRatio;
      default:
        throw UnsupportedError('Unsupported platform');
    }
    return SizedBox(height: height, child: view);
  }

  void _setCallback(int id) async {
    MethodChannel channel = MethodChannel("com.vk.id/oauthwidget-$id");
    channel.setMethodCallHandler((call) async {
      if (call.method == "onHeight") {
        setState(() {
          nativeHeight = call.arguments as int;
        });
      } else {
        _handleMethodForWidget(
            widget._onAuth, widget._onAuthCode, widget._onError, call);
        return null;
      }
    });
  }
}
