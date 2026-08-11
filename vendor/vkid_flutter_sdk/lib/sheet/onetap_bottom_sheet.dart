part of '../library_vkid.dart';

/// A modal bottom sheet that provides VKID One Tap login interface.
///
/// Example usage:
/// ```
/// final key = GlobalKey();
/// OneTapBottomSheet(
///   key: key,
///   onAuth: (oAuth, data) => print(data.token),
///   onError: (oAuth, error) => print(error),
///   serviceName: "my service",
///   scenario: OneTapBottomSheetScenario.order,
///   autoHideOnSuccess: false,
///   oAuths: const {OneTapOAuth.ok, OneTapOAuth.mail},
///   style: const OneTapBottomSheetStyle(type: OneTapBottomSheetType.system),
///   authParams: UIAuthParamsBuilder().withScopes(const {"phone", "email"}).build(),
///   fastAuthEnabled: false,
/// );
/// ```
class OneTapBottomSheet extends StatefulWidget {
  final Function(OneTapOAuth? oAuth, AuthData authData) _onAuth;
  final Function(AuthCodeData data, bool isCompletion) _onAuthCode;
  final Function(OneTapOAuth? oAuth, AuthError error) _onError;
  final String _serviceName;
  final OneTapBottomSheetScenario _scenario;
  final bool _autoHideOnSuccess;
  final Set<OneTapOAuth> _alternativeOAuths;
  final OneTapBottomSheetStyle _style;
  final UIAuthParams _authParams;
  final bool _fastAuthEnabled;

  static _defaultOnAuthCode(AuthCodeData data, bool isCompletion) {}
  static _defaultOnError(OneTapOAuth? oAuth, AuthError error) {}

  /// Constructs a modal bottom sheet.
  ///
  /// There are some parameters, that you can provide. [key] can be used to retrieve [State] of the widget.
  /// [onAuth] will be called after successful auth if you passed [PublicFlowData] to [authParams].
  /// [onAuthCode] will be called if you passed [ConfidentialFlowData] to [authParams].
  /// [onError] will be called if any error was encountered during auth.
  /// [alternativeOAuths] can be specified to allow login with other OAuth providers.
  /// [style] allows to style the widget. [fastAuthEnabled] allows to disable user fetching on Android.
  /// [authParams] specify auth flow and scopes. Read more about them in [UIAuthParamsBuilder].
  /// [scenario] allows to adjust text on a sheet for your specific usage scenario.
  /// [autoHideOnSuccess] allows to disable automatic sheet dismissing after successful auth.
  /// [serviceName] specifies what name will be displayed in the top left corner of a sheet.
  const OneTapBottomSheet({
    required Key key,
    required Function(OneTapOAuth? oAuth, AuthData authData) onAuth,
    Function(AuthCodeData data, bool isCompletion) onAuthCode =
        _defaultOnAuthCode,
    Function(OneTapOAuth? oAuth, AuthError error) onError = _defaultOnError,
    required String serviceName,
    OneTapBottomSheetScenario scenario = OneTapBottomSheetScenario.enterService,
    bool autoHideOnSuccess = true,
    Set<OneTapOAuth> alternativeOAuths = const {},
    OneTapBottomSheetStyle style = const OneTapBottomSheetStyle(
      type: OneTapBottomSheetType.light,
    ),
    UIAuthParams authParams = const UIAuthParams._(),
    bool fastAuthEnabled = true,
  })  : _onAuth = onAuth,
        _onAuthCode = onAuthCode,
        _onError = onError,
        _serviceName = serviceName,
        _scenario = scenario,
        _autoHideOnSuccess = autoHideOnSuccess,
        _alternativeOAuths = alternativeOAuths,
        _style = style,
        _authParams = authParams,
        _fastAuthEnabled = fastAuthEnabled,
        super(key: key);

  @override
  State<StatefulWidget> createState() => OneTapBottomSheetState();
}

/// A [State] of [OneTapBottomSheet].
class OneTapBottomSheetState extends State<OneTapBottomSheet> {
  GlobalKey key = GlobalKey();
  MethodChannel? _methodChannel;

  /// Makes the bottom sheet visible.
  void show() async {
    await _methodChannel!.invokeMethod("show");
  }

  /// Hides the bottom sheet.
  void hide() async {
    await _methodChannel!.invokeMethod("hide");
  }

  /// Whether the bottom sheet is visible.
  Future<bool> isVisible() async =>
      await _methodChannel!.invokeMethod("isVisible");

  @override
  Widget build(BuildContext context) {
    final creationParams = [
      widget._serviceName,
      // ignore: sdk_version_since
      widget._scenario.name,
      widget._autoHideOnSuccess,
      // ignore: sdk_version_since
      widget._alternativeOAuths.map((item) => item.name).toList(),
      // ignore: sdk_version_since
      widget._style.type.name,
      widget._style.buttonCornersStyle._type,
      widget._style.buttonCornersStyle is OneTapCornersCustom
          ? (widget._style.buttonCornersStyle as OneTapCornersCustom).radius
          : 0.0,
      // ignore: sdk_version_since
      widget._style.buttonSize.name,
      widget._authParams._authFlowData is PublicFlowData
          ? (widget._authParams._authFlowData as PublicFlowData).state
          : (widget._authParams._authFlowData as ConfidentialFlowData).state,
      widget._authParams._authFlowData is PublicFlowData
          ? null
          : (widget._authParams._authFlowData as ConfidentialFlowData)
              .codeChallenge,
      widget._authParams._scopes.toList(),
      widget._fastAuthEnabled,
    ];
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return SizedBox(
          width: 1,
          height: 1,
          child: UiKitView(
            viewType: "OneTapBottomSheet",
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) => _setCallback(id),
          ),
        );
      case TargetPlatform.android:
        return SizedBox(
          width: 1,
          height: 1,
          child: AndroidView(
            viewType: "OneTapBottomSheet",
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) => _setCallback(id),
          ),
        );
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  void _setCallback(int id) async {
    _methodChannel = MethodChannel("com.vk.id/sheet-$id");
    _methodChannel!.setMethodCallHandler((call) => _handleMethod(
        widget._onAuth, widget._onAuthCode, widget._onError, call));
  }
}
