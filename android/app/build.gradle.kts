import java.io.FileInputStream
import java.util.*

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Загрузка параметров подписи из key.properties
val keyPropertiesFile = rootProject.file("app/key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "io.lidle.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Java 8 desugaring для поддержки flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "io.lidle.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Настройка подписи для release build
    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile", "keystore.jks"))
                storePassword = keyProperties.getProperty("storePassword", "")
                keyAlias = keyProperties.getProperty("keyAlias", "")
                keyPassword = keyProperties.getProperty("keyPassword", "")
            }
        }
    }

    buildTypes {
        debug {
            // Debug версия - встроенная подпись
            isDebuggable = true
            applicationIdSuffix = ".debug"
        }

        release {
            // Release версия для RuStore
            if (keyPropertiesFile.exists() && signingConfigs.findByName("release") != null) {
                signingConfig = signingConfigs.getByName("release")
                //signingConfig = signingConfigs.getByName("debug")
            }

            // Включаем R8 минификацию для продакшена
            isMinifyEnabled = true
            isShrinkResources = true

            // ProGuard конфиг с safe набором для Flutter плагинов
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    // Java 8 desugaring для поддержки flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.0")
}

flutter {
    source = "../.."
}
