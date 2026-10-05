// Плагин VK ID SDK ДОЛЖЕН применяться и настраиваться в корневом проекте
// (это требование самого плагина), в модуле app он тоже применяется.
plugins {
    id("vkid.manifest.placeholders") version "1.1.0"
}

// Публичные значения VK ID. Секрет не используется (confidential flow, обмен
// кода на бэке по PKCE), поэтому заглушка. ВАЖНО: секрет ДОЛЖЕН содержать
// буквы, иначе Android запишет его в манифест как число, а SDK читает секрет
// как строку и падает с «Missing VKIDClientSecret». Поэтому не только цифры.
// Схема возврата vk54714701://vk.ru.
vkidManifestPlaceholders {
    init(
        clientId = "54714701",
        clientSecret = "vkidnosecretneeded",
    )
    vkidRedirectHost = "vk.ru"
    vkidRedirectScheme = "vk54714701"
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Репозитории VK ID SDK (нужны для зависимости com.vk.id)
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/vkid-sdk-android/") }
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/vk-id-captcha/android/") }
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/maven/") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    
    tasks.withType<JavaCompile> {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
        options.compilerArgs.add("-Xlint:-options")
    }

    // Старым плагинам Flutter поднимаем версию Android, под которую они
    // собираются (05.10.2026).
    //
    // ЗАЧЕМ. Плагин приносит с собой свой модуль Android со своей версией
    // compileSdk. У давно не обновлявшихся она бывает старой: у `app_links`
    // версии 3.5.1 это 31. Пока проверка была мягкой, это сходило с рук, а на
    // плагине Android 8.13 сборка встала с двадцатью claims вида «зависимость
    // требует собираться против 34 или новее, а модуль собирается против 31».
    //
    // Поднимаем всем, у кого меньше 36. Это не меняет ни minSdk, ни targetSdk,
    // то есть ни на каких телефонах приложение не перестанет ставиться и ни
    // одно новое поведение системы не включится: compileSdk говорит только о
    // том, какие API доступны компилятору.
    //
    // Через рефлексию намеренно: типы плагина Android в корневом файле сборки
    // не подключены, а тащить их сюда ради одной строки значит усложнять файл,
    // который и так читают редко.
    afterEvaluate {
        val androidExtension = extensions.findByName("android")

        if (androidExtension != null) {
            runCatching {
                val current = androidExtension.javaClass
                    .getMethod("getCompileSdkVersion")
                    .invoke(androidExtension) as? String

                val level = current?.removePrefix("android-")?.toIntOrNull() ?: 0

                if (level < 36) {
                    androidExtension.javaClass
                        .getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(androidExtension, 36)

                    logger.lifecycle("Модулю ${project.name} поднята версия сборки: было $current, стало android-36")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
