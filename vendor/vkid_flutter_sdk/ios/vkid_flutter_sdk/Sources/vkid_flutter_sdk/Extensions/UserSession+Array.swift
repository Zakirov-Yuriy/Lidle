import VKID

extension UserSession {
    var flutterChannelArgs: Array<Any> {
        let scope = Array(self.accessToken.scope.value)
        let result: Array<Any> = [
            "onAuth",
            self.accessToken.value,
            self.idToken.value,
            self.userId.value,
            Int64((
                self.accessToken.expirationDate.timeIntervalSince1970 * 1000.0).rounded()
            ),
            self.user?.firstName ?? "",
            self.user?.lastName ?? "",
            self.user?.phone ?? "",
            self.user?.avatarURL?.absoluteString ?? "",
            self.user?.email ?? "",
            scope,
            {
                switch self.oAuthProvider {
                case OAuthProvider.vkid: "vk"
                case OAuthProvider.mail: "mail"
                case OAuthProvider.ok: "ok"
                default:
                    "vk"
                }
            }()
        ]
        return result
    }
}
