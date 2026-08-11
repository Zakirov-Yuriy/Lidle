import Flutter
import UIKit
import VKID

final class OAuthWidgetView: NSObject, PlatformView {
    private var widgetView: UIView?
    private var methodChannel: FlutterMethodChannel

    func view() -> UIView {
        widgetView ?? UIView()
    }

    required init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        methodChannel: FlutterMethodChannel
    ) {
        self.methodChannel = methodChannel
        super.init()
        if let args = args as? [Any?] {
            let oAuthWidgetView = VkidFlutterSdkPlugin.vkid.ui(
                for: self.createOAuthWidgetConfig(args: args)
            ).uiView()
            self.widgetView = oAuthWidgetView
        } else {
            preconditionFailure("Arguments Invalid Type")
        }
    }

    private func createOAuthWidgetConfig(args: [Any?]) -> OAuthListWidget {
        guard
            let oAuths = args[0] as? [String],
            let cornersStyle = args[1] as? String,
            let height = args[3] as? String,
            let theme = args[4] as? String
        else {
            preconditionFailure("Arguments Invalid Type")
        }
        let scopes = Set((args[7] as? Array<String> ?? []).map {$0})
        let cornerRadius = cornersStyle.oneTapCornerRadius(
            customRadius: (args[2] as? CGFloat) ?? .zero,
            height: height.oneTapHeight.rawValue
        )
        let flow = (args[6] as? String).getFlow(
            withState: (args[5] as? String),
            methodChannel: self.methodChannel
        )
        let resultHandler: (AuthResult) -> Void = { result in
            switch result {
            case .success(let session):
                session.fetchUser { _ in
                    self.methodChannel.invokeMethod(
                        "onAuth",
                        arguments: session.flutterChannelArgs
                    )
                }
            case .failure(let error):
                if args[6] != nil, error == .authCodeExchangedOnYourBackend {
                    return
                }
                let code = error == .cancelled ? "cancelled" : String(describing: error)
                self.methodChannel.invokeMethod(
                    "onError",
                    arguments: [
                        code,
                        error.localizedDescription,
                        nil
                    ]
                )
            }
        }
        return OAuthListWidget(
            oAuthProviders: oAuths.map {$0.oAuthProvider},
            authConfiguration: .init(
                flow: flow,
                scope: Scope(scopes)
            ),
            buttonConfiguration: .init(
                height: height.oneTapHeight,
                cornerRadius: cornerRadius
            ),
            theme: theme.oAuthListTheme,
            onCompleteAuth: resultHandler
        )
    }
}
fileprivate extension String {
    var oAuthListTheme: OAuthListWidget.Theme {
        OAuthListWidget.Theme.matchingColorScheme(Appearance.ColorScheme(rawValue: self) ?? .light)
    }
}
