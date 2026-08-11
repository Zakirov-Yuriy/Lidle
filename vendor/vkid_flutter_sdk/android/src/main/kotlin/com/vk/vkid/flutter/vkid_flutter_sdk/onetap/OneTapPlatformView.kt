package com.vk.vkid.flutter.vkid_flutter_sdk.onetap

import android.content.Context
import android.view.View
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.ComposeView
import com.vk.id.VKIDAuthFail
import com.vk.id.auth.VKIDAuthUiParams
import com.vk.id.onetap.common.OneTapOAuth
import com.vk.id.onetap.common.OneTapStyle
import com.vk.id.onetap.compose.onetap.OneTap
import com.vk.id.onetap.compose.onetap.OneTapTitleScenario
import com.vk.vkid.flutter.vkid_flutter_sdk.common.capitalize
import com.vk.vkid.flutter.vkid_flutter_sdk.common.parseCornersStyle
import com.vk.vkid.flutter.vkid_flutter_sdk.common.parseOneTapOAuths
import com.vk.vkid.flutter.vkid_flutter_sdk.common.parseSize
import com.vk.vkid.flutter.vkid_flutter_sdk.common.pack
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

internal class OneTapPlatformView(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val arguments: List<Any?>,
) : PlatformView {
    private val composeView = ComposeView(context)

    private var hasParams = mutableStateOf(false)

    private lateinit var oAuths: Set<OneTapOAuth>
    private lateinit var style: OneTapStyle
    private var fastAuthEnabled = true
    private var signInToAnotherAccountEnabled = false
    private var state: String? = null
    private var codeChallenge: String? = null
    private lateinit var scopes: Set<String>
    private lateinit var scenario: OneTapTitleScenario

    init {
        initParams()
    }

    private fun initParams() {
        oAuths = parseOneTapOAuths(arguments[0] as List<String>)
        val cornersStyle = parseCornersStyle(arguments[2] as String, arguments[3] as Double?) ?: return
        val sizeStyle = parseSize(arguments[4] as String) ?: return
        style = when (arguments[1]) {
            "light" -> OneTapStyle.Light(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "dark" -> OneTapStyle.Dark(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "transparentLight" -> OneTapStyle.TransparentLight(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "transparentDark" -> OneTapStyle.TransparentDark(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "icon" -> OneTapStyle.Icon(
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "system" -> OneTapStyle.system(
                context,
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            "transparentSystem" -> OneTapStyle.transparentSystem(
                context,
                cornersStyle = cornersStyle,
                sizeStyle = sizeStyle,
            )

            else -> return
        }
        fastAuthEnabled = arguments[5] as Boolean
        signInToAnotherAccountEnabled = arguments[6] as Boolean
        state = arguments[7] as String?
        codeChallenge = arguments[8] as String?
        scopes = (arguments[9] as List<String>).toSet()
        scenario = OneTapTitleScenario.valueOf((arguments[10] as String).capitalize())
        hasParams.value = true
    }

    @Composable
    private fun Content() {
        if (!hasParams.value) return
        OneTap(
            modifier = Modifier.wrapContentHeight().onGloballyPositioned {
                methodChannel.invokeMethod("onHeight", it.size.height)
            },
            onAuth = { oAuth, token ->
                methodChannel.invokeMethod("onAuth", token.pack { error("No id token") }?.let { it + listOf(oAuth?.name?.lowercase()) })
            },
            onAuthCode = { data, isCompletion ->
                if (isCompletion) methodChannel.invokeMethod("onAuthCode", data.pack(context))
            },
            onFail = { oAuth, fail ->
                val code = if (fail is VKIDAuthFail.Canceled) "cancelled" else fail::class.java.name
                methodChannel.invokeMethod("onError", listOf(code, fail.description, oAuth?.name?.lowercase()))
            },
            signInAnotherAccountButtonEnabled = signInToAnotherAccountEnabled,
            oAuths = oAuths,
            style = style,
            fastAuthEnabled = fastAuthEnabled,
            authParams = VKIDAuthUiParams {
                state = this@OneTapPlatformView.state
                codeChallenge = this@OneTapPlatformView.codeChallenge
                scopes = this@OneTapPlatformView.scopes
            },
            scenario = scenario,
        )
    }

    override fun getView(): View {
        composeView.setContent { Content() }
        return composeView
    }

    override fun dispose() {}
}