import VKID

extension AuthorizationCode {
    var flutterChannelArgs: Array<Any> {
        [
            "onAuthCode",
            self.code,
            self.deviceId,
            self.redirectURI
        ]
    }
}
