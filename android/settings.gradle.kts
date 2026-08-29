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
    // API 36 официально поддерживается начиная с AGP 8.10; AGP 8.10 требует
    // Gradle 8.11.1+, в wrapper стоит 8.12 — связка сходится.
    id("com.android.application") version "8.10.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
