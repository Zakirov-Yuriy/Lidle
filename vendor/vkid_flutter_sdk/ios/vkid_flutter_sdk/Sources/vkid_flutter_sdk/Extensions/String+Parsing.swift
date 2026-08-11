import Flutter
import VKID

extension String {
    var oAuthProvider: OAuthProvider {
        return  switch self {
        case "vk": .vkid
        case "mail": .mail
        case "ok": .ok
        default: .vkid
        }
    }

    var oneTapHeight: OneTapButton.Layout.Height {
        return switch self {
        case "standard": OneTapButton.Layout.Height.medium()
        case "small32": OneTapButton.Layout.Height.small(.h32)
        case "small34": OneTapButton.Layout.Height.small(.h34)
        case "small36": OneTapButton.Layout.Height.small(.h36)
        case "small38": OneTapButton.Layout.Height.small(.h38)
        case "medium40": OneTapButton.Layout.Height.medium(.h40)
        case "medium42": OneTapButton.Layout.Height.medium(.h42)
        case "medium44": OneTapButton.Layout.Height.medium(.h44)
        case "medium46": OneTapButton.Layout.Height.medium(.h46)
        case "large48": OneTapButton.Layout.Height.large(.h48)
        case "large50": OneTapButton.Layout.Height.large(.h50)
        case "large52": OneTapButton.Layout.Height.large(.h52)
        case "large54": OneTapButton.Layout.Height.large(.h54)
        case "large56": OneTapButton.Layout.Height.large(.h56)
        default: OneTapButton.Layout.Height.medium()
        }
    }

    func oneTapCornerRadius(customRadius: CGFloat, height: CGFloat) -> CGFloat {
        return switch self {
        case "OneTapCornersDefault": LayoutConstants.defaultCornerRadius
        case "OneTapCornersNone": CGFloat.zero
        case "OneTapCornersRounded": LayoutConstants.defaultCornerRadius
        case "OneTapCornersRound": height / 2 
        case "OneTapCornersCustom": customRadius
        default:
            LayoutConstants.defaultCornerRadius
        }
    }
}

extension String? {
    func getFlow(withState state: String?, methodChannel: FlutterMethodChannel) -> AuthConfiguration.Flow {
        if let codeChallenge = self {
            return .confidentialClientFlow(
                codeExchanger: AuthCodeExchanger { authCodeData in
                    methodChannel.invokeMethod(
                        "onAuthCode",
                        arguments: authCodeData.flutterChannelArgs
                    )
                },
                pkce: .init(
                    codeChallenge: codeChallenge,
                    state: state ?? UUID().uuidString
                )
            )
        } else {
            do {
                var pkce = try PKCESecrets.init()
                if let state = state {
                    pkce.state = state
                }
                return .publicClientFlow(pkce: pkce)
            } catch {
                return .publicClientFlow()
            }
        }
    }
}
