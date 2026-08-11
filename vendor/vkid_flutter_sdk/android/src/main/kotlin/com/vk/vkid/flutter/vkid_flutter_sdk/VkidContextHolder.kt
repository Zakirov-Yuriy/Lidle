package com.vk.vkid.flutter.vkid_flutter_sdk

import android.content.Context

/**
 * Хранит applicationContext, захваченный при СТАРТЕ ПРОЦЕССА (через
 * [VkidContextProvider]). Нужен, чтобы упаковка кода в onAuthCode не зависела
 * от того, успел ли Flutter вызвать onAttachedToEngine после того, как система
 * выгрузила процесс во время авторизации VK и подняла его заново.
 */
internal object VkidContextHolder {
    @Volatile
    var appContext: Context? = null
}
