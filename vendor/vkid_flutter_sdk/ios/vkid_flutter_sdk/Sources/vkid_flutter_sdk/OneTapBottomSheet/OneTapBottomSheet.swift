import Flutter
import UIKit
import VKID

class OneTapBottomSheetView: NSObject, PlatformView {
    private var _view: UIView
    private var methodChannel: FlutterMethodChannel
    private var oneTapBottomSheetViewController: UIViewController?

    func view() -> UIView {
        return self._view
    }

    required init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        methodChannel: FlutterMethodChannel
    ) {
        self._view = UIView(frame: .zero)
        self.methodChannel = methodChannel
        super.init()
        self.setMethodCallHandler()
        self.oneTapBottomSheetViewController = self.makeBottomSheetViewController(arguments: args)
    }

    private func makeBottomSheetViewController(arguments args: Any?) -> UIViewController {
        if let args = args as? [Any?] {
            guard
                let serviceName = args[0] as? String,
                let scenario = args[1] as? String,
                let autoHideOnSuccess = args[2] as? Bool,
                let alternativeOAuths = args[3] as? [String],
                let theme = args[4] as? String,
                let cornersStyle = args[5] as? String,
                let height = args[7] as? String,
                let scopeArray = args[10] as? Array<String>
            else {
                preconditionFailure("Arguments Invalid Type")
            }
            let scope = Set((scopeArray).map {$0})
            let oneTapHeight = height.oneTapHeight
            let cornerRadius = cornersStyle.oneTapCornerRadius(
                customRadius: (args[6] as? CGFloat) ?? .zero,
                height: oneTapHeight.rawValue
            )
            let flow: AuthConfiguration.Flow = (args[9] as? String).getFlow(
                withState: (args[8] as? String),
                methodChannel: self.methodChannel
            )
            let oneTapBottomSheetConfig = OneTapBottomSheet(
                serviceName: serviceName,
                targetActionText: scenario.targetActionText(serviceName: serviceName),
                oneTapButton: .init(
                    height: oneTapHeight,
                    cornerRadius: cornerRadius
                ),
                authConfiguration: .init(
                    flow: flow,
                    scope: Scope(scope)
                ),
                oAuthProviderConfiguration: .init(
                    alternativeProviders: alternativeOAuths.map {$0.oAuthProvider}
                ),
                theme: theme.theme,
                autoDismissOnSuccess: autoHideOnSuccess
            ) { result in
                switch result {
                case .success(let session):
                    session.fetchUser { _ in
                        self.methodChannel.invokeMethod(
                            "onAuth",
                            arguments: session.flutterChannelArgs
                        )
                    }
                case .failure(let error):
                    if args[9] != nil, error == .authCodeExchangedOnYourBackend {
                        return
                    }
                    let code = error == .cancelled ? "cancelled" : String(describing: error)
                    self.methodChannel.invokeMethod(
                        "onError",
                        arguments: [
                            code,
                            error.localizedDescription,
                            "vk"
                        ]
                    )
                }
            }

            return VkidFlutterSdkPlugin.vkid.ui(
                for: oneTapBottomSheetConfig
            ).uiViewController()
        } else {
            preconditionFailure("Arguments Invalid Type")
        }
    }

    private func setMethodCallHandler() {
        self.methodChannel.setMethodCallHandler { [weak self] call, result in
            if let controller: FlutterViewController =
                UIApplication.shared.windows.first?.rootViewController as? FlutterViewController,
               let oneTapBottomSheetViewController = self?.oneTapBottomSheetViewController {
                switch call.method {
                case "show":
                    controller.present(oneTapBottomSheetViewController, animated: true)
                case "hide":
                    controller.presentedViewController?.dismiss(animated: true)
                case "isVisible":
                    result(controller.presentedViewController != nil)
                default:
                    self?.methodChannel.invokeMethod(
                        "error",
                        arguments: FlutterError(
                            code: "notImplemented",
                            message: "Bottom sheet method not implemented",
                            details: nil
                        )
                    )
                }
            }
        }
    }
}

fileprivate extension String {
    func targetActionText(serviceName: String) -> OneTapBottomSheet.TargetActionText {
        return switch self {
        case "enterService": .signInToService(serviceName)
        case "registrationForTheEvent": .registerForEvent
        case "application": .applyFor
        case "orderInService": .orderCheckoutAtService(serviceName)
        case "order": .orderCheckout
        case "enterToAccount": .signIn
        default: .signIn
        }
    }
typealias Theme = OneTapBottomSheet.Theme
    var theme: OneTapBottomSheet.Theme {
        OneTapBottomSheet.Theme.matchingColorScheme(Appearance.ColorScheme(rawValue: self) ?? .light)
    }
}
