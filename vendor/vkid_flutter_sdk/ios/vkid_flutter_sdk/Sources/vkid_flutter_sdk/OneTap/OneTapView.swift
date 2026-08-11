import Flutter
import UIKit
import VKID

class UIViewWrapper: UIView {
    var oneTapHeight: CGFloat
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(methodChannel: FlutterMethodChannel, oneTapHeight: CGFloat) {
        self.methodChannel = methodChannel
        self.oneTapHeight = oneTapHeight
        super.init(frame: .zero)
    }

    public var methodChannel: FlutterMethodChannel
    override func layoutSubviews() {
        super.layoutSubviews()
        self.methodChannel.invokeMethod(
            "onHeight",
            arguments: self.calculateHeight()
        )
    }

    private func calculateHeight() -> Int {
        let textHeight = subviews[0].subviews.reduce(CGFloat.zero) { result, view in
            result + self.oneTapButtonWidgetTextHeight(view: view)
        }
        return Int(15 * 2 + textHeight + oneTapHeight * 2)
    }

    private func oneTapButtonWidgetTextHeight(view: UIView) -> CGFloat {
        if let label = (view as? UILabel),
           let boundingBox = label.text?.boundingRect(
            with: CGSize(
                width: view.frame.width,
                height: .greatestFiniteMagnitude
            ),
            options: .usesLineFragmentOrigin,
            attributes: [NSAttributedString.Key.font: label.font ?? .systemFont(ofSize: 16)],
            context: nil
           ) {
            return boundingBox.height
        }
        return .zero
    }
}

class OneTapView: NSObject, PlatformView {
    private var _view: UIView?
    private var methodChannel: FlutterMethodChannel
    private var oneTapHeight: OneTapButton.Layout.Height = .medium(.h44)

    func view() -> UIView {
        return self._view ?? UIView()
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
            let oneTapView = VkidFlutterSdkPlugin.vkid.ui(
                for: self.createOneTapConfig(args: args)
            ).uiView()
            if let alternativeOAuths = args[0] as? [String], !alternativeOAuths.isEmpty {
                let wrapperView = UIViewWrapper(
                    methodChannel: methodChannel,
                    oneTapHeight: self.oneTapHeight.rawValue
                )
                oneTapView.translatesAutoresizingMaskIntoConstraints = false
                wrapperView.addSubview(oneTapView)
                NSLayoutConstraint.activate([
                    wrapperView.topAnchor.constraint(equalTo: oneTapView.topAnchor),
                    wrapperView.bottomAnchor.constraint(equalTo: oneTapView.bottomAnchor),
                    wrapperView.leadingAnchor.constraint(equalTo: oneTapView.leadingAnchor),
                    wrapperView.trailingAnchor.constraint(equalTo: oneTapView.trailingAnchor)
                ])
                self._view = wrapperView
            } else {
                self._view = oneTapView
            }
        } else {
            preconditionFailure("Arguments Invalid Type")
        }
    }

    private func createOneTapConfig(args: [Any?]) -> OneTapButton {
        guard
            let alternativeOAuths = args[0] as? [String],
            let style = args[1] as? String,
            let cornersStyle = args[2] as? String,
            let height = args[4] as? String,
            let title = args[10] as? String
        else {
            preconditionFailure("Arguments Invalid Type")
        }
        let (theme, oneTapStyle, kind) = style.themeStyleKindFromFlutter
        oneTapHeight = height.oneTapHeight
        self.methodChannel.invokeMethod("onHeight", arguments: Int(UIScreen.main.scale * oneTapHeight.rawValue))
        let cornerRadius = cornersStyle.oneTapCornerRadius(
            customRadius: (args[3] as? CGFloat) ?? .zero,
            height: oneTapHeight.rawValue
        )
        let scope = Set((args[9] as? Array<String> ?? []).map {$0})
        let flow = (args[8] as? String).getFlow(
            withState: (args[7] as? String),
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
                if args[8] != nil, error == .authCodeExchangedOnYourBackend {
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
        if alternativeOAuths.isEmpty {
            return OneTapButton(
                appearance: OneTapButton.Appearance(
                    title: title.titleFromFlutter,
                    style: oneTapStyle,
                    theme: theme
                ),
                layout: .init(
                    kind: kind,
                    height: oneTapHeight,
                    cornerRadius: cornerRadius
                ),
                presenter: .newUIWindow,
                authConfiguration: .init(
                    flow: flow,
                    scope: Scope(scope)),
                onCompleteAuth: resultHandler
            )
        }

        return OneTapButton(
            title: title.titleFromFlutter,
            height: oneTapHeight,
            cornerRadius: cornerRadius,
            theme: theme,
            authConfiguration: .init(
                flow: flow,
                scope: Scope(scope)
            ),
            oAuthProviderConfiguration: .init(
                alternativeProviders: alternativeOAuths.map {$0.oAuthProvider}
            ),
            onCompleteAuth: resultHandler
        )
    }
}

fileprivate extension String {
    var titleFromFlutter: OneTapButton.Appearance.Title {
        return switch self {
        case "signIn": .vkid
        case "signUp": .signUp
        case "get": .get
        case "open": .open
        case "calculate": .calculate
        case "order": .order
        case "placeOrder": .makeOrder
        case "sendRequest": .submitRequest
        case "participate" : .participate
        default: .vkid
        }
    }
}

fileprivate extension String {
    var themeStyleKindFromFlutter: (
        OneTapButton.Appearance.Theme,
        OneTapButton.Appearance.Style,
        OneTapButton.Layout.Kind
    ) {
        var theme = OneTapButton.Appearance.Theme.matchingColorScheme(.light)
        var style = OneTapButton.Appearance.Style.primary()
        var kind = OneTapButton.Layout.Kind.regular
        switch self {
        case "light":
            theme = .matchingColorScheme(.light)
        case "dark":
            theme = .matchingColorScheme(.dark)
        case "system":
            theme = .matchingColorScheme(.system)
        case "transparentLight":
            theme = .matchingColorScheme(.light)
            style = .secondary()
        case "transparentDark" :
            theme = .matchingColorScheme(.dark)
            style = .secondary()
        case "transparentSystem":
            theme = .matchingColorScheme(.system)
            style = .secondary()
        case "icon":
            kind = .logoOnly
        default:
            kind = .regular
        }
        return (theme, style, kind)
    }
}
