package com.vk.vkid.flutter.vkid_flutter_sdk.sheet

import android.content.Context
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import com.vk.id.VKIDAuthFail
import com.vk.id.auth.VKIDAuthUiParams
import com.vk.id.onetap.common.OneTapOAuth
import com.vk.id.onetap.compose.onetap.sheet.OneTapBottomSheet
import com.vk.id.onetap.compose.onetap.sheet.OneTapBottomSheetState
import com.vk.id.onetap.compose.onetap.sheet.OneTapScenario
import com.vk.id.onetap.compose.onetap.sheet.rememberOneTapBottomSheetState
import com.vk.id.onetap.compose.onetap.sheet.style.OneTapBottomSheetStyle
import com.vk.vkid.flutter.vkid_flutter_sdk.common.capitalize
import com.vk.vkid.flutter.vkid_flutter_sdk.common.pack
import com.vk.vkid.flutter.vkid_flutter_sdk.common.parseCornersStyle
import com.vk.vkid.flutter.vkid_flutter_sdk.common.parseOneTapOAuths
import com.vk.vkid.flutter.vkid_flutter_sdk.common.parseSize
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

internal class OneTapBottomSheetPlatformView(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val arguments: List<Any?>,
) : PlatformView {
    private val composeView = ComposeView(context)

    private var hasParams = mutableStateOf(false)

    private lateinit var serviceName: String
    private lateinit var scenario: OneTapScenario
    private var autoHideOnSuccess = true
    private lateinit var oAuths: Set<OneTapOAuth>
    private lateinit var style: OneTapBottomSheetStyle
    private var fastAuthEnabled = true
    private var state: String? = null
    private var codeChallenge: String? = null
    private lateinit var scopes: Set<String>
    private lateinit var sheetState: OneTapBottomSheetState

    init {
        initParams()
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    sheetState.show()
                    result.success(null)
                }

                "hide" -> {
                    sheetState.hide()
                    result.success(null)
                }

                "isVisible" -> result.success(sheetState.isVisible)
                else -> result.error("unsupported method", null, null)
            }
        }
    }

    private fun initParams() {
        serviceName = arguments[0] as String
        scenario = OneTapScenario.valueOf((arguments[1] as String).capitalize())
        autoHideOnSuccess = arguments[2] as Boolean
        oAuths = parseOneTapOAuths(arguments[3] as List<String>)
        val cornersStyle = parseCornersStyle(arguments[5] as String, arguments[6] as Double?) ?: return
        val sizeStyle = parseSize(arguments[7] as String) ?: return
        style = when (arguments[4]) {
            "light" -> OneTapBottomSheetStyle.Light(
                buttonsCornersStyle = cornersStyle,
                buttonsSizeStyle = sizeStyle,
            )

            "dark" -> OneTapBottomSheetStyle.Dark(
                buttonsCornersStyle = cornersStyle,
                buttonsSizeStyle = sizeStyle,
            )

            "system" -> OneTapBottomSheetStyle.system(
                context,
                buttonsCornersStyle = cornersStyle,
                buttonsSizeStyle = sizeStyle,
            )

            else -> return
        }
        state = arguments[8] as String?
        codeChallenge = arguments[9] as String?
        scopes = (arguments[10] as List<String>).toSet()
        fastAuthEnabled = arguments[11] as Boolean
        hasParams.value = true
    }

    @Composable
    private fun Content() {
        if (!hasParams.value) return
        OneTapBottomSheet(
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
            oAuths = oAuths,
            style = style,
            fastAuthEnabled = fastAuthEnabled,
            autoHideOnSuccess = autoHideOnSuccess,
            authParams = VKIDAuthUiParams {
                state = this@OneTapBottomSheetPlatformView.state
                codeChallenge = this@OneTapBottomSheetPlatformView.codeChallenge
                scopes = this@OneTapBottomSheetPlatformView.scopes
            },
            serviceName = serviceName,
            scenario = scenario,
            state = rememberOneTapBottomSheetState().also { sheetState = it },
        )
    }

    override fun getView(): View {
        composeView.setContent { Content() }
        return composeView
    }

    override fun dispose() {}
}