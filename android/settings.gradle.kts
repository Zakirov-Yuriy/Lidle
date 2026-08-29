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
    // 8.10 — первая версия плагина Android, которая умеет собирать под
    // API 36. С 8.9.1 сборка с compileSdk = 36 ругается на неизвестную
    // версию платформы. Gradle в wrapper 8.12, ему этого плагина хватает.
    id("com.android.application") version "8.10.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Плагин Google Services читает android/app/google-services.json и
    // подставляет ключи проекта Firebase в сборку. Без него приложение не
    // знает, к какому проекту подключаться, и уведомления не работают.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
