package io.lidle.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.NotificationCompat
import android.app.NotificationManager
import android.content.Context

// VK ID SDK требует, чтобы host-активити была FragmentActivity, поэтому
// MainActivity наследуется от FlutterFragmentActivity (а не FlutterActivity).
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.lidle.app/badge"
    private val BADGE_CHANNEL_ID = "badge_notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Method Channel для управления бейджами ──────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBadgeCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        try {
                            updateBadgeCount(count)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BADGE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Обновить бейдж на иконке приложения
    /// Использует broadcast для различных лаунчеров И notification badge для совместимости
    private fun updateBadgeCount(count: Int) {
        try {
            // 1. Отправляем broadcasts для лаунчеров, которые их поддерживают
            sendBadgeBroadcast(count)
            
            // 2. Обновляем Notification Badge (работает везде, включая эмулятор)
            updateNotificationBadge(count)
        } catch (e: Exception) {
            android.util.Log.e("BadgeService", "Error updating badge: ${e.message}", e)
        }
    }

    /// Отправляем broadcast для различных лаунчеров (Nova, Apex, Samsung, Xiaomi и т.д.)
    private fun sendBadgeBroadcast(count: Int) {
        try {
            // Для Nova Launcher
            val novaIntent = android.content.Intent("com.teslacoilsw.externalapi.SET_BADGE")
            novaIntent.putExtra("com.teslacoilsw.externalapi.badges.PACKAGE_NAME", packageName)
            novaIntent.putExtra("com.teslacoilsw.externalapi.badges.ACTIVITY_NAME", "io.lidle.app.MainActivity")
            novaIntent.putExtra("com.teslacoilsw.externalapi.badges.MESSAGE_COUNT", count)
            sendBroadcast(novaIntent)
            android.util.Log.d("BadgeService", "✅ Nova Launcher broadcast sent (count=$count)")

            // Для Apex Launcher
            val apexIntent = android.content.Intent("com.sonyericsson.home.action.UPDATE_BADGE")
            apexIntent.putExtra("com.sonyericsson.home.intent.extra.badge.SHOW_MESSAGE", true)
            apexIntent.putExtra("com.sonyericsson.home.intent.extra.badge.MESSAGE_NUMBER", count)
            apexIntent.putExtra("com.sonyericsson.home.intent.extra.badge.PACKAGE_NAME", packageName)
            apexIntent.putExtra("com.sonyericsson.home.intent.extra.badge.ACTIVITY_NAME", "io.lidle.app.MainActivity")
            sendBroadcast(apexIntent)
            android.util.Log.d("BadgeService", "✅ Apex Launcher broadcast sent (count=$count)")

            // Для Huawei Badge
            val huaweiIntent = android.content.Intent("android.intent.action.BADGE_COUNT_UPDATE")
            huaweiIntent.putExtra("badge_count", count)
            huaweiIntent.putExtra("badge_count_package_name", packageName)
            huaweiIntent.putExtra("badge_count_class_name", "io.lidle.app.MainActivity")
            sendBroadcast(huaweiIntent)
            android.util.Log.d("BadgeService", "✅ Huawei Badge broadcast sent (count=$count)")

            // Для Samsung Experience
            val samsungIntent = android.content.Intent("android.intent.action.BADGE_COUNT_UPDATE")
            samsungIntent.putExtra("badge_count", count)
            samsungIntent.putExtra("badge_count_package_name", packageName)
            samsungIntent.putExtra("badge_count_class_name", "io.lidle.app.MainActivity")
            sendBroadcast(samsungIntent)
            android.util.Log.d("BadgeService", "✅ Samsung badge broadcast sent (count=$count)")

            // Для Xiaomi / MIUI
            val xiaomiIntent = android.content.Intent("android.intent.action.BADGE_COUNT_UPDATE")
            xiaomiIntent.putExtra("badge_count", count)
            xiaomiIntent.putExtra("badge_count_package_name", packageName)
            xiaomiIntent.putExtra("badge_count_class_name", "io.lidle.app.MainActivity")
            sendBroadcast(xiaomiIntent)
            android.util.Log.d("BadgeService", "✅ Xiaomi badge broadcast sent (count=$count)")
        } catch (e: Exception) {
            android.util.Log.d("BadgeService", "⚠️  Broadcast failed (launcher may not support): ${e.message}")
        }
    }

    /// «1 новое сообщение», «2 новых сообщения», «5 новых сообщений».
    ///
    /// Согласуем слово с числом: «7 новое сообщение» читается как недоделка,
    /// даже если смысл понятен. Одиннадцать-четырнадцать это исключение из
    /// правила единиц, поэтому проверяются первыми.
    private fun newMessagesWord(count: Int): String {
        val tens = count % 100
        val ones = count % 10

        return when {
            tens in 11..14 -> "новых сообщений"
            ones == 1 -> "новое сообщение"
            ones in 2..4 -> "новых сообщения"
            else -> "новых сообщений"
        }
    }

    /// Обновляем Notification Badge (работает везде, включая эмулятор)
    /// Это делает бейдж видимым в уведомлениях и в некоторых лаунчерах
    private fun updateNotificationBadge(count: Int) {
        try {
            if (count > 0) {
                // Создаём небольшое уведомление с бейджем (скрытое, только для значка)
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                
                // Создаём канал, если его нет (Android 8.0+)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    val channel = android.app.NotificationChannel(
                        BADGE_CHANNEL_ID,
                        "Значок непрочитанных",
                        NotificationManager.IMPORTANCE_LOW
                    )
                    channel.setShowBadge(true)
                    notificationManager.createNotificationChannel(channel)
                }

                // Создаём уведомление только для бейджа (не показывается пользователю)
                val notification = NotificationCompat.Builder(this, BADGE_CHANNEL_ID)
                    // Текст по-русски и с согласованным окончанием.
                    //
                    // Так было: «New messages. You have 7 new messages» в
                    // русском приложении. Уведомление задумывалось как
                    // невидимое, ради одного значка на иконке, но в шторке
                    // его прекрасно видно, и человек читал английскую строку
                    // непонятного происхождения.
                    .setContentTitle("Непрочитанные сообщения")
                    .setContentText("У вас " + count + " " + newMessagesWord(count))
                    .setSmallIcon(android.R.drawable.ic_notification_overlay) // ⭐ Встроенная иконка Android
                    .setAutoCancel(false) // ⭐ НЕ закрывать уведомление, иначе исчезнет бейдж!
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // ⭐ ПУБЛИЧНЫЙ для видимости бейджа
                    .setSilent(true) // Не издаём звук при обновлении бейджа
                    .setNumber(count) // Это устанавливает бейдж (работает в Android 7.1+)
                    .build()

                // Отправляем уведомление с ID 999 (для бейджа)
                notificationManager.notify(999, notification)
                android.util.Log.d("BadgeService", "✅ Notification Badge updated (count=$count, visible in system UI)")
            } else {
                // Очищаем бейдж
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(999)
                android.util.Log.d("BadgeService", "✅ Notification Badge cleared (count=0)")
            }
        } catch (e: Exception) {
            android.util.Log.d("BadgeService", "⚠️  Notification Badge failed: ${e.message}")
        }
    }
}
