import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

android {
    namespace = "com.novashort.shortdrama"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.novashort.shortdrama"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let(::file)
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

//     开启 BuildConfig 支持，否则 buildConfigField 会报错
    buildFeatures {
        buildConfig = true
    }

    flavorDimensions += "channel" // Kotlin DSL 用 +=

    productFlavors {

        create("GF") {
            dimension = "channel"
            applicationId = "com.novashort.shortdrama"
            resValue("string", "channel_flag", "GF_001")
            resValue("string", "MERCHANT_ID", "333")
            resValue("string", "VEST_PKG_ID", "1001")
        }

        create("haha") {
            dimension = "channel"
            applicationId = "com.novashort.shortdrama"
            resValue("string", "channel_flag", "app_developer")
            resValue("string", "MERCHANT_ID", "329")
            resValue("string", "VEST_PKG_ID", "1001")
        }
//        create("GF_test") {
//            dimension = "channel"
//            applicationId = "com.novashort.shortdrama"
//            resValue("string", "channel_flag", "GF_test")
//            resValue("string", "MERCHANT_ID", "pm_test")
//            resValue("string", "VEST_PKG_ID", "1001")
//        }
//
//        create("douyin_pro") {
//            dimension = "channel"
//            applicationId = "com.novashort.shortdrama"
//            resValue("string", "channel_flag", "douyin")
//            resValue("string", "MERCHANT_ID", "331")
//            resValue("string", "VEST_PKG_ID", "1002")
//        }
//        create("kuaishou_pro") {
//            dimension = "channel"
//            applicationId = "com.novashort.shortdrama"
//            resValue("string", "channel_flag", "kuaishou")
//            resValue("string", "MERCHANT_ID", "332")
//            resValue("string", "VEST_PKG_ID", "1001")
//        }
        create("tiktok_dev") {
            dimension = "channel"
            applicationId = "com.novashort.shortdrama"
            resValue("string", "channel_flag", "tiktok")
            resValue("string", "MERCHANT_ID", "319")
            resValue("string", "VEST_PKG_ID", "1001")
        }
        create("kuaishou_dev") {
            dimension = "channel"
            applicationId = "com.novashort.shortdrama"
            resValue("string", "channel_flag", "kuaishou")
            resValue("string", "MERCHANT_ID", "320")
            resValue("string", "VEST_PKG_ID", "1002")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.gms:play-services-ads-identifier:18.1.0")
    implementation("com.android.installreferrer:installreferrer:2.2")
}

flutter {
    source = "../.."
}
