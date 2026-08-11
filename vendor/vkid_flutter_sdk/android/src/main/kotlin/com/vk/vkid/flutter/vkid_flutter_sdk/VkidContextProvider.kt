package com.vk.vkid.flutter.vkid_flutter_sdk

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/**
 * Пустой ContentProvider. Android создаёт провайдеры на старте процесса ДО
 * Application.onCreate и до любой Activity, поэтому здесь мы гарантированно
 * получаем applicationContext, даже если процесс пересоздан после выгрузки во
 * время входа через VK. Значение кладём в [VkidContextHolder], откуда его берёт
 * requireContext() как fallback.
 */
class VkidContextProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        context?.applicationContext?.let { VkidContextHolder.appContext = it }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0
}
