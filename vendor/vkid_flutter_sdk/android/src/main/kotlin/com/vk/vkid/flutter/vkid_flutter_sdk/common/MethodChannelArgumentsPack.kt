package com.vk.vkid.flutter.vkid_flutter_sdk.common

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.pm.PackageManager.ComponentInfoFlags
import android.os.Build
import android.os.Bundle
import com.vk.id.AccessToken
import com.vk.id.auth.AuthCodeData

internal inline fun AccessToken.pack(onNoIdToken: () -> Unit): List<Any?>? {
    return listOf(
        "onAuth",
        token,
        idToken ?: run {
            onNoIdToken()
            return null
        },
        userID,
        expireTime,
        userData.firstName,
        userData.lastName,
        userData.phone,
        userData.photo200 ?: userData.photo100 ?: userData.photo50.orEmpty(),
        userData.email,
        scopes?.toList() ?: emptyList<String>()
    )
}

internal fun AuthCodeData.pack(context: Context): List<Any?> {
    return listOf(
        "onAuthCode",
        code,
        deviceId,
        getRedirectUri(context),
    )
}

@SuppressLint("WrongConstant")
private fun getActivityInfo(context: Context): ActivityInfo {
    val componentName = ComponentName(context, Class.forName("com.vk.id.internal.auth.AuthActivity"))
    val flags = PackageManager.GET_META_DATA or PackageManager.GET_ACTIVITIES
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        context.packageManager.getActivityInfo(componentName, ComponentInfoFlags.of(flags.toLong()))
    } else {
        context.packageManager.getActivityInfo(componentName, flags)
    }
}

private fun Bundle.getStringOrThrow(key: String): String {
    return getString(key) ?: error("No string for key: $key")
}

private fun getRedirectUri(context: Context): String {
    val ai = getActivityInfo(context)
    val redirectScheme = ai.metaData.getStringOrThrow("VKIDRedirectScheme")
    val redirectHost = ai.metaData.getStringOrThrow("VKIDRedirectHost")
    return "$redirectScheme://$redirectHost/blank.html"
}
