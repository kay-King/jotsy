import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")

if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val amapWebApiKey = localProperties.getProperty("amap.web.api.key", "")
val escapedAmapWebApiKey = amapWebApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val qWeatherCredentialId = localProperties.getProperty("qweather.credential_id", "")
val escapedQWeatherCredentialId = qWeatherCredentialId
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val qWeatherApiKey = localProperties.getProperty("qweather.api_key", "")
val escapedQWeatherApiKey = qWeatherApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val qWeatherApiHost = localProperties.getProperty("qweather.api_host", "")
val escapedQWeatherApiHost = qWeatherApiHost
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")

android {
    namespace = "com.jotsy.diary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.jotsy.diary"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "AMAP_WEB_API_KEY", "\"$escapedAmapWebApiKey\"")
        buildConfigField("String", "QWEATHER_CREDENTIAL_ID", "\"$escapedQWeatherCredentialId\"")
        buildConfigField("String", "QWEATHER_API_KEY", "\"$escapedQWeatherApiKey\"")
        buildConfigField("String", "QWEATHER_API_HOST", "\"$escapedQWeatherApiHost\"")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            // minSdk ≥ 24 时 AGP 默认只签 v2、不签 v1，但鸿蒙与部分华为机型的
            // 安装器只认 META-INF 里的 v1 证书，缺了就报“该安装包未包含任何证书”。
            // 显式打开三种方案；证书不变，已安装的版本照常覆盖升级。
            // （上游 PR #207，2026-11-09 改造着合）
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    packaging {
        jniLibs {
            // 原生库在 APK 里压缩存放，安装时再解压到应用目录。minSdk ≥ 23 时 AGP 默认
            // 原样存放（安装后直接映射、不另占一份），但安装包主要经 GitHub 直接下载，
            // 不像应用商店那样传输时再压缩：Dart 机器码 libapp.so、引擎 libflutter.so、
            // 扫码与 SQLite 的 .so 原样合计约 50MB，压缩后约 22MB，arm64 包由约 74MB
            // 降到约 46MB。代价是装机后多占一份解压出的原生库空间、首次安装略慢。
            // （上游 PR #306，2026-11-17 改造着合；上游 docs/rules/release_website.md
            // 在 fork 不存在，那一段未合）
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        getByName("profile") {
            // A profile install must retain the installed release package's
            // signer, or Android rejects the replacement before touching data.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
