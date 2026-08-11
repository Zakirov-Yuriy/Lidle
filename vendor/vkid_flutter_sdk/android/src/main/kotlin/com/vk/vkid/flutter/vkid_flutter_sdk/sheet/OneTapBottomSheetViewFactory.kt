package com.vk.vkid.flutter.vkid_flutter_sdk.sheet

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class OneTapBottomSheetViewFactory(
    private val binaryMessenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val methodChannel = MethodChannel(binaryMessenger, "com.vk.id/sheet-$viewId")
        return OneTapBottomSheetPlatformView(context, methodChannel, args as List<Any?>)
    }
}
