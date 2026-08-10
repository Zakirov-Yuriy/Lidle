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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
