@file:OptIn(InternalVKIDApi::class)

package com.vk.vkid.flutter.vkid_flutter_sdk

import android.content.Context
import android.content.res.Configuration
import com.vk.id.AccessToken
import com.vk.id.OAuth
import com.vk.id.VKID
import com.vk.id.VKIDAuthFail
import com.vk.id.VKIDUser
import com.vk.id.auth.AuthCodeData
import com.vk.id.auth.VKIDAuthCallback
import com.vk.id.auth.VKIDAuthParams
import com.vk.id.auth.VKIDAuthParams.Theme.Dark
import com.vk.id.auth.VKIDAuthParams.Theme.Light
import com.vk.id.common.InternalVKIDApi
import com.vk.id.groupsubscription.GroupSubscriptionLimit
import com.vk.id.logout.VKIDLogoutCallback
import com.vk.id.logout.VKIDLogoutFail
import com.vk.id.logout.VKIDLogoutParams
import com.vk.id.refresh.VKIDRefreshTokenCallback
import com.vk.id.refresh.VKIDRefreshTokenFail
import com.vk.id.refresh.VKIDRefreshTokenParams
import com.vk.id.refreshuser.VKIDGetUserCallback
import com.vk.id.refreshuser.VKIDGetUserFail
import com.vk.id.refreshuser.VKIDGetUserParams
import com.vk.vkid.flutter.vkid_flutter_sdk.common.pack
import com.vk.vkid.flutter.vkid_flutter_sdk.oauthwidget.OAuthWidgetViewFactory
import com.vk.vkid.flutter.vkid_flutter_sdk.onetap.OneTapViewFactory
import com.vk.vkid.flutter.vkid_flutter_sdk.sheet.OneTapBottomSheetViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicReference

/** VkidFlutterSdkPlugin */
internal class VkidFlutterSdkPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private val context = AtomicReference<Context>(null)

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.vk.id/vkid")
        channel.setMethodCallHandler(this)
        VKID.init(
            context = flutterPluginBinding.applicationContext,
            isFlutter = true,
            groupSubscriptionLimit = GroupSubscriptionLimit(),
            captchaRedirectUri = null,
            forceError14 = false,
            forceHitmanChallenge = false,
        )
        context.set(flutterPluginBinding.applicationContext)
        // Дублируем контекст в процесс-глобальный holder, чтобы requireContext()
        // не падал, если onAuthCode прилетит после пересоздания процесса.
        VkidContextHolder.appContext = flutterPluginBinding.applicationContext
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "OneTap",
            OneTapViewFactory(flutterPluginBinding.binaryMessenger)
        )
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "OneTapBottomSheet",
            OneTapBottomSheetViewFactory(flutterPluginBinding.binaryMessenger)
        )
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "OAuthWidget",
            OAuthWidgetViewFactory(flutterPluginBinding.binaryMessenger)
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "currentAuthData" -> result.success(VKID.instance.accessToken?.pack { return result.error("No id token", null, null) }
                ?: listOf(null))

            "refreshToken" -> refreshToken(result)
            "fetchUser" -> fetchUser(result)
            "logout" -> logout(result)
            "authorize" -> authorize(call, result)
            "areLogsEnabled" -> result.success(VKID.logsEnabled)
            "setLogsEnabled" -> {
                VKID.logsEnabled = call.arguments as Boolean
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun refreshToken(result: Result) {
        CoroutineScope(Dispatchers.Main).launch {
            VKID.instance.refreshToken(
                object : VKIDRefreshTokenCallback {
                    override fun onSuccess(token: AccessToken) {
                        result.success(listOf(token.token))
                    }

                    override fun onFail(fail: VKIDRefreshTokenFail) {
                        val code = if (fail is VKIDRefreshTokenFail.RefreshTokenExpired) "expired" else fail::class.java.name
                        result.error(code, fail.description, null)
                    }
                },
                VKIDRefreshTokenParams {}
            )
        }
    }

    private fun fetchUser(result: Result) {
        CoroutineScope(Dispatchers.Main).launch {
            VKID.instance.getUserData(
                object : VKIDGetUserCallback {
                    override fun onSuccess(user: VKIDUser) {
                        result.success(
                            listOf(
                                user.firstName,
                                user.lastName,
                                user.phone,
                                user.photo200 ?: user.photo100 ?: user.photo50.orEmpty(),
                                user.email,
                            )
                        )
                    }

                    override fun onFail(fail: VKIDGetUserFail) {
                        val code = if (fail is VKIDGetUserFail.IdTokenTokenExpired) "expired" else fail::class.java.name
                        result.error(code, fail.description, null)
                    }
                },
                VKIDGetUserParams {
                }
            )
        }
    }

    private fun logout(result: Result) {
        CoroutineScope(Dispatchers.Main).launch {
            VKID.instance.logout(
                object : VKIDLogoutCallback {
                    override fun onSuccess() {
                        result.success(emptyList<String>())
                    }

                    override fun onFail(fail: VKIDLogoutFail) {
                        val code = if (fail is VKIDLogoutFail.AccessTokenTokenExpired) "expired" else fail::class.java.name
                        result.error(code, fail.description, null)
                    }
                },
                VKIDLogoutParams {
                }
            )
        }
    }

    private fun authorize(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<Any?>
        CoroutineScope(Dispatchers.Main).launch {
            VKID.instance.authorize(
                object : VKIDAuthCallback {
                    override fun onAuth(accessToken: AccessToken) = with(accessToken) {
                        result.success(accessToken.pack { return@with result.error("No id token", null, null) })
                    }

                    override fun onAuthCode(data: AuthCodeData, isCompletion: Boolean) {
                        if (isCompletion) result.success(data.pack(requireContext()))
                    }

                    override fun onFail(fail: VKIDAuthFail) {
                        val code = if (fail is VKIDAuthFail.Canceled) "cancelled" else fail::class.java.name
                        result.error(code, fail.description, null)
                    }
                },
                VKIDAuthParams {
                    locale = when (arguments[0]) {
                        "ru" -> VKIDAuthParams.Locale.RUS
                        "uk" -> VKIDAuthParams.Locale.UKR
                        "en" -> VKIDAuthParams.Locale.ENG
                        "es" -> VKIDAuthParams.Locale.SPA
                        "de" -> VKIDAuthParams.Locale.GERMAN
                        "pl" -> VKIDAuthParams.Locale.POL
                        "fr" -> VKIDAuthParams.Locale.FRA
                        "tr" -> VKIDAuthParams.Locale.TURKEY
                        null -> null
                        else -> return@launch result.error("unsupported locale ${arguments[0]}", null, null)
                    }
                    theme = when (arguments[1]) {
                        "light" -> VKIDAuthParams.Theme.Light
                        "dark" -> VKIDAuthParams.Theme.Dark
                        "system" -> when (requireContext().resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
                            Configuration.UI_MODE_NIGHT_NO -> Light
                            Configuration.UI_MODE_NIGHT_YES -> Dark
                            else -> null
                        }

                        null -> null
                        else -> return@launch result.error("unsupported theme ${arguments[1]}", null, null)
                    }
                    useOAuthProviderIfPossible = arguments[2] as Boolean
                    oAuth = when (arguments[3]) {
                        "vk" -> OAuth.VK
                        "mail" -> OAuth.MAIL
                        "ok" -> OAuth.OK
                        null -> null
                        else -> return@launch result.error("unsupported oauth: ${arguments[3]}", null, null)
                    }
                    state = arguments[4] as String?
                    codeChallenge = arguments[5] as String?
                    @Suppress("UNCHECKED_CAST")
                    scopes = (arguments[6] as? List<String>)?.toSet() ?: emptySet()
                }
            )
        }
    }

    // Сначала контекст текущего инстанса плагина, затем процесс-глобальный
    // fallback из VkidContextProvider. error(...) остаётся только на совсем
    // невозможный случай, когда не отработал даже ContentProvider.
    private fun requireContext() = context.get()
        ?: VkidContextHolder.appContext
        ?: error("onAttachedToEngine wasn't called")

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
