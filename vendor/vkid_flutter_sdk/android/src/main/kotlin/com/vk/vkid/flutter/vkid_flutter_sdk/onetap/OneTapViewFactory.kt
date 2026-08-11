package com.vk.vkid.flutter.vkid_flutter_sdk.onetap

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class OneTapViewFactory(
    private val binaryMessenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val methodChannel = MethodChannel(binaryMessenger, "com.vk.id/onetap-$viewId")
        return OneTapPlatformView(context, methodChannel, args as List<Any?>)
    }
}
