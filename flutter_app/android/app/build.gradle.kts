plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun loadKakaoNativeAppKey(): String {
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        val fromLocal = localProps.readLines()
            .map { it.trim() }
            .firstOrNull { it.startsWith("kakao.nativeAppKey=") }
            ?.substringAfter("=")
            ?.trim()
            .orEmpty()
        if (fromLocal.isNotEmpty()) {
            return fromLocal
        }
    }

    val envFile = rootProject.file("../../.env.local")
    if (envFile.exists()) {
        val fromEnv = envFile.readLines()
            .map { it.trim() }
            .firstOrNull { it.startsWith("KAKAO_NATIVE_APP_KEY=") }
            ?.substringAfter("=")
            ?.trim()
            ?.trim('"')
            .orEmpty()
        if (fromEnv.isNotEmpty()) {
            return fromEnv
        }
    }

    return ""
}

val kakaoNativeAppKey = loadKakaoNativeAppKey()
val kakaoRedirectScheme =
    if (kakaoNativeAppKey.isNotEmpty()) "kakao$kakaoNativeAppKey" else "kakao_not_configured"

android {
    namespace = "com.neoproject.study"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    flavorDimensions += "app"
    productFlavors {
        create("full") {
            dimension = "app"
            applicationId = "com.neoproject.study"
        }
        create("lite") {
            dimension = "app"
            applicationId = "com.neoproject.study.lite"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.neoproject.study"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["KAKAO_APP_SCHEME"] = kakaoRedirectScheme
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
