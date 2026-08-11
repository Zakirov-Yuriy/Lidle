package com.vk.vkid.flutter.vkid_flutter_sdk.common

import com.vk.id.onetap.common.OneTapOAuth
import com.vk.id.onetap.common.button.style.OneTapButtonCornersStyle
import com.vk.id.onetap.common.button.style.OneTapButtonSizeStyle

internal fun parseCornersStyle(typeArg: String, radiusArg: Double?) = when (typeArg) {
    "OneTapCornersDefault" -> OneTapButtonCornersStyle.Default
    "OneTapCornersNone" -> OneTapButtonCornersStyle.None
    "OneTapCornersRounded" -> OneTapButtonCornersStyle.Rounded
    "OneTapCornersRound" -> OneTapButtonCornersStyle.Round
    "OneTapCornersCustom" -> OneTapButtonCornersStyle.Custom(radiusArg?.toFloat() ?: 0f)
    else -> null
}

internal fun parseSize(arg: String) = when (arg) {
    "standard" -> OneTapButtonSizeStyle.DEFAULT
    "small32" -> OneTapButtonSizeStyle.SMALL_32
    "small34" -> OneTapButtonSizeStyle.SMALL_34
    "small36" -> OneTapButtonSizeStyle.SMALL_36
    "small38" -> OneTapButtonSizeStyle.SMALL_38
    "medium40" -> OneTapButtonSizeStyle.MEDIUM_40
    "medium42" -> OneTapButtonSizeStyle.MEDIUM_42
    "medium44" -> OneTapButtonSizeStyle.MEDIUM_44
    "medium46" -> OneTapButtonSizeStyle.MEDIUM_46
    "large48" -> OneTapButtonSizeStyle.LARGE_48
    "large50" -> OneTapButtonSizeStyle.LARGE_50
    "large52" -> OneTapButtonSizeStyle.LARGE_52
    "large54" -> OneTapButtonSizeStyle.LARGE_54
    "large56" -> OneTapButtonSizeStyle.LARGE_56
    else -> null
}

internal fun parseOneTapOAuths(arg: List<String>) = arg.map { OneTapOAuth.valueOf(it.uppercase()) }.toSet()

internal fun String.capitalize() = replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }