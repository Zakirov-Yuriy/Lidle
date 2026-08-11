import Flutter
import UIKit

protocol PlatformView: NSObject, FlutterPlatformView {
    init(frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        methodChannel: FlutterMethodChannel)
}

class PlatformViewFactory<T: PlatformView>: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private var channelName: String

    init(messenger: FlutterBinaryMessenger, channelName: String) {
        self.messenger = messenger
        self.channelName = channelName
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let methodChannel = FlutterMethodChannel(
            name: "\(self.channelName)-\(viewId)",
            binaryMessenger: self.messenger
        )
        return T(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            methodChannel: methodChannel)
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

typealias OneTapViewFactory = PlatformViewFactory<OneTapView>
typealias OneTapBottomSheetViewFactory = PlatformViewFactory<OneTapBottomSheetView>
typealias OAuthWidgetViewFactory = PlatformViewFactory<OAuthWidgetView>
