pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Репозитории VK ID SDK (для плагина vkid.manifest.placeholders)
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/vkid-sdk-android/") }
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/maven/") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 8.13, последняя версия восьмой ветки (05.10.2026).
    //
    // Подняли с 8.11.1 ради флага android.r8.optimizedResourceShrinking: он
    // работает с 8.12, а Google Play в рекомендациях пишет, что
    // оптимизированное удаление неиспользуемых ресурсов у нас не включено.
    //
    // Требует Gradle 8.13 и новее, в wrapper стоит 8.14.3, этого хватает.
    //
    // Девятая ветка пока не берётся намеренно: она требует перехода на
    // встроенную поддержку Kotlin вместо плагина kotlin-android, а это
    // отдельная работа с перепроверкой всей сборки, не перед отправкой в
    // Google. См. mob/mob_google-play-recommendations.md в вики.
    id("com.android.application") version "8.13.0" apply false    
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false    
    // Плагин Google Services читает android/app/google-services.json и
    // подставляет ключи проекта Firebase в сборку. Без него приложение не
    // знает, к какому проекту подключаться, и уведомления не работают.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
