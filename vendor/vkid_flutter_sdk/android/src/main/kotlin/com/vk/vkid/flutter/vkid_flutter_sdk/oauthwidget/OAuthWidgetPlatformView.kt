package com.vk.vkid.flutter.vkid_flutter_sdk.oauthwidget

import android.content.Context
import android.view.View
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.ComposeView
import com.vk.id.OAuth
import com.vk.id.VKIDAuthFail
import com.vk.id.auth.VKIDAuthUiParams
import com.vk.id.multibranding.OAuthListWidget
import com.vk.id.multibranding.common.style.OAuthListWidgetCornersStyle
import com.vk.id.multibranding.common.style.OAuthListWidgetSizeStyle
import com.vk.id.multibranding.common.style.OAuthListWidgetStyle
import com.vk.vkid.flutter.vkid_flutter_sdk.common.pack
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

internal class OAuthWidgetPlatformView(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val arguments: List<Any?>,
) : PlatformView {
    private val composeView = ComposeView(context)

    private var hasParams = mutableStateOf(false)

    private lateinit var oAuths: Set<OAuth>
    private lateinit var style: OAuthListWidgetStyle
    private var state: String? = null
    private var codeChallenge: String? = null
    private lateinit var scopes: Set<String>

    init {
        initParams()
    }

    private fun initParams() {
        @Suppress("UNCHECKED_CAST")
        oAuths = parseOAuths(arguments[0] as List<String>)
        val cornersStyle = parseCornersStyle(arguments[1] as String, arguments[2] as Double?) ?: return
        val sizeStyle = parseSize(arguments[3] as String) ?: return
        style = when (arguments[4]) {
            "light" -> OAuthListWidgetStyle.Light(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "dark" -> OAuthListWidgetStyle.Dark(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "system" -> OAuthListWidgetStyle.system(
                context,
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            else -> return
        }
        state = arguments[5] as String?
        codeChallenge = arguments[6] as String?
        scopes = (arguments[7] as List<String>).toSet()
        hasParams.value = true
    }

    @Suppress("NonSkippableComposable")
    @Composable
    private fun Content() {
        if (!hasParams.value) return
        OAuthListWidget(
            modifier = Modifier.wrapContentHeight().onGloballyPositioned {
                methodChannel.invokeMethod("onHeight", it.size.height)
            },
            onAuth = { oAuth, token ->
                methodChannel.invokeMethod("onAuth", token.pack { error("No id token") }?.let { it + listOf(oAuth.name.lowercase()) })
            },
            onAuthCode = { data, isCompletion ->
                if (isCompletion) methodChannel.invokeMethod("onAuthCode", data.pack(context))
            },
            onFail = { oAuth, fail ->
                val code = if (fail is VKIDAuthFail.Canceled) "cancelled" else fail::class.java.name
                methodChannel.invokeMethod("onError", listOf(code, fail.description, oAuth.name.lowercase()))
            },
            oAuths = oAuths,
            style = style,
            authParams = VKIDAuthUiParams {
                state = this@OAuthWidgetPlatformView.state
                codeChallenge = this@OAuthWidgetPlatformView.codeChallenge
                scopes = this@OAuthWidgetPlatformView.scopes
            },
        )
    }

    override fun getView(): View {
        composeView.setContent { Content() }
        return composeView
    }

    override fun dispose() {}

    private fun parseCornersStyle(typeArg: String, radiusArg: Double?) = when (typeArg) {
        "OneTapCornersDefault" -> OAuthListWidgetCornersStyle.Default
        "OneTapCornersNone" -> OAuthListWidgetCornersStyle.None
        "OneTapCornersRounded" -> OAuthListWidgetCornersStyle.Rounded
        "OneTapCornersRound" -> OAuthListWidgetCornersStyle.Round
        "OneTapCornersCustom" -> OAuthListWidgetCornersStyle.Custom(radiusArg?.toFloat() ?: 0f)
        else -> null
    }

    private fun parseSize(arg: String) = when (arg) {
        "standard" -> OAuthListWidgetSizeStyle.DEFAULT
        "small32" -> OAuthListWidgetSizeStyle.SMALL_32
        "small34" -> OAuthListWidgetSizeStyle.SMALL_34
        "small36" -> OAuthListWidgetSizeStyle.SMALL_36
        "small38" -> OAuthListWidgetSizeStyle.SMALL_38
        "medium40" -> OAuthListWidgetSizeStyle.MEDIUM_40
        "medium42" -> OAuthListWidgetSizeStyle.MEDIUM_42
        "medium44" -> OAuthListWidgetSizeStyle.MEDIUM_44
        "medium46" -> OAuthListWidgetSizeStyle.MEDIUM_46
        "large48" -> OAuthListWidgetSizeStyle.LARGE_48
        "large50" -> OAuthListWidgetSizeStyle.LARGE_50
        "large52" -> OAuthListWidgetSizeStyle.LARGE_52
        "large54" -> OAuthListWidgetSizeStyle.LARGE_54
        "large56" -> OAuthListWidgetSizeStyle.LARGE_56
        else -> null
    }

    private fun parseOAuths(arg: List<String>) = arg.map { OAuth.valueOf(it.uppercase()) }.toSet()
}