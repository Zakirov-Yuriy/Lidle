import Flutter
import UIKit

@_spi(VKIDDebug) @_spi(VKIDPrivate) import VKID

public class VkidFlutterSdkPlugin: NSObject, FlutterPlugin {
    private static let clientId = {
        guard let infoPlistClientId = Bundle.main.infoDictionary?["VK_APP_CLIENT_ID"] as? String,
        !infoPlistClientId.isEmpty else {
            preconditionFailure("Info.plist does not contain correct value for VK_APP_CLIENT_ID key")
        }
        return infoPlistClientId
    }()

    public static let vkid: VKID = {
        print(VKID.sdkVersion)
        guard let clientSecret = Bundle.main.infoDictionary?["VK_APP_CLIENT_SECRET"] as? String,
              !clientSecret.isEmpty else {
            preconditionFailure("Info.plist does not contain correct value for VK_APP_CLIENT_SECRET key")
        }
        do {
            return try VKID(config:
                    .init(
                        appCredentials: AppCredentials(
                            clientId: VkidFlutterSdkPlugin.clientId,
                            clientSecret: clientSecret
                        ),
                        loggingEnabled: VkidFlutterSdkPlugin.loggingEnabled,
                        wrapperSDK: .flutter,
                        // Only for debug purposes
                        network: NetworkConfiguration(
                            isSSLPinningEnabled: VkidFlutterSdkPlugin.sslPinningEnabled
                        )
                    ))
        } catch { preconditionFailure("Failed to create VKID instance") }
    }()

    @_spi(VKIDFlutterDebug)
    public static var sslPinningEnabled = true

    private enum Keys: String {
        case loggingEnabled = "com.vkid.flutter.core.loggingEnabled"
    }

    @_spi(VKIDFlutterDebug)
    public static var loggingEnabled: Bool {
        get {
            (UserDefaults.standard.value(forKey: Keys.loggingEnabled.rawValue) as? Bool) ?? true
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: Keys.loggingEnabled.rawValue
            )
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.vk.id/vkid", binaryMessenger: registrar.messenger())
        let instance = VkidFlutterSdkPlugin()
        let oneTapFactory = OneTapViewFactory(
            messenger: registrar.messenger(),
            channelName: "com.vk.id/onetap"
        )
        let oneTapBottomSheetFactory = OneTapBottomSheetViewFactory(
            messenger: registrar.messenger(),
            channelName: "com.vk.id/sheet"
        )
        let oAuthWidgetFactory = OAuthWidgetViewFactory(
            messenger: registrar.messenger(),
            channelName: "com.vk.id/oauthwidget"
        )

        registrar.register(oneTapFactory, withId: "OneTap")
        registrar.register(oneTapBottomSheetFactory, withId: "OneTapBottomSheet")
        registrar.register(oAuthWidgetFactory, withId: "OAuthWidget")
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "areLogsEnabled":
            result(VkidFlutterSdkPlugin.loggingEnabled)
        case "setLogsEnabled":
            if let loggingEnabled = call.arguments as? Bool {
                VkidFlutterSdkPlugin.loggingEnabled = loggingEnabled
            }
        case "authorize":
            guard let arguments = call.arguments as? NSArray else {
                return result(FlutterError(
                    code: "invalidArguments",
                    message: "arguments casting issue",
                    details: nil
                ))
            }
            self.authorize(arguments: arguments, completion: result)
        default:
            self.requestSession(method: call.method, completion: result)
        }
    }

    private func requestSession(method: String, completion: @escaping FlutterResult) {
        guard let session = Self.vkid.currentAuthorizedSession else {
            completion([nil])
            return
        }
        switch method {
        case "currentAuthData":
            completion(session.flutterChannelArgs)
        case "refreshToken":
            self.refresh(for: session, completion: completion)
        case "fetchUser":
            self.fetchUser(using: session, completion: completion)
        case "logout":
            self.logout(using: session, completion: completion)
        default:
            completion(FlutterMethodNotImplemented)
        }
    }

    private func logout(using session: UserSession, completion: @escaping FlutterResult) {
        session.logout { result in
            switch result {
            case .success():
                completion([])
            case .failure(let error):
                let code = error == .invalidAccessToken ? "expired" : String(describing: error)
                completion(FlutterError(code: code, message: error.localizedDescription, details: nil))
            }
        }
    }

    private func fetchUser(using session: UserSession, completion: @escaping FlutterResult) {
        session.fetchUser { result in
            switch result {
            case .success(let user):
                completion([
                    user.firstName ?? "",
                    user.lastName ?? "",
                    user.phone ?? "",
                    user.avatarURL?.absoluteString ?? "",
                    user.email ?? ""
                ])
            case .failure(let error):
                let code = error == .invalidAccessToken ? "expired" : String(describing: error)
                completion(FlutterError(code: code, message: error.localizedDescription, details: nil))
            }
        }
    }

    private func refresh(for session: UserSession, completion: @escaping FlutterResult) {
        session.getFreshAccessToken(forceRefresh: true) { result in
            switch result {
            case .success((let accessToken, _)):
                completion([accessToken.value])
            case .failure(let error):
                completion(FlutterError(
                    code: error == .invalidRefreshToken ? "expired" : String(describing: error),
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }
    }

    private func authorize(arguments: NSArray, completion: @escaping FlutterResult) {
        let locale: Appearance.Locale = Appearance.Locale(
            rawValue: (arguments[0] as? String ?? "")
        ) ?? .system
        let theme: Appearance.ColorScheme = Appearance.ColorScheme(
            rawValue: (arguments[1] as? String ?? "")
        ) ?? .system
        let forceWebViewFlow = !(arguments[2] as? Bool ?? true)
        let provider: OAuthProvider = switch (arguments[3] as? String) {
        case "vk": .vkid
        case "mail": .mail
        case "ok": .ok
        default: .vkid
        }
        let flow: AuthConfiguration.Flow
        if let codeChallenge = arguments[5] as? String {
            let state = arguments[4] as? String ?? UUID().uuidString
            flow = .confidentialClientFlow(
                codeExchanger: AuthCodeExchanger { authCodeData in
                    completion(authCodeData.flutterChannelArgs)
                },
                pkce: .init(
                    codeChallenge: codeChallenge, state: state
                )
            )
        } else {
            if let state = arguments[4] as? String{
                guard var pkce = try? PKCESecrets() else {
                    completion("FailedPKCEGenerating")
                    return
                }
                pkce.state = state
                flow = .publicClientFlow(pkce: pkce)
            } else {
                flow = .publicClientFlow()
            }
        }
        let scope = Set((arguments[6] as? Array<String> ?? []).map {$0})
        Self.vkid.appearance.locale = locale
        Self.vkid.appearance.colorScheme = theme
        Self.vkid.authorize(
            with: .init(
                flow: flow,
                scope: Scope(scope),
                forceWebViewFlow: forceWebViewFlow
            ),
            oAuthProvider: provider,
            using: .newUIWindow
        ) { authResult in
            if let _ = arguments[5] as? String {
                // nothing to do
            } else {
                switch authResult {
                case .success(let session):
                    session.fetchUser { _ in
                        completion(session.flutterChannelArgs)
                    }
                case .failure(let authError):
                    if authError == .cancelled {
                        completion("cancelled")
                    } else {
                        completion(String(describing: authError))
                    }
                }
            }
        }
    }
}
