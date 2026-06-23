plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yushi.drama.client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yushi.drama.client"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

//    signingConfigs {
//        create("release") {
//            keyAlias = "upload"
//            keyPassword = "123456"
//            storeFile = file("keystore.jks")
//            storePassword = "123456"
//        }
//    }
//
//    buildTypes {
//        release {
//            signingConfig = signingConfigs.getByName("release")
//            isMinifyEnabled = false
//            isShrinkResources = false
//        }
//    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

//     开启 BuildConfig 支持，否则 buildConfigField 会报错
    buildFeatures {
        buildConfig = true
    }

    flavorDimensions += "channel" // Kotlin DSL 用 +=
//
    productFlavors {
        create("haha") {
            dimension = "channel"
            applicationId = "com.yushi.drama.client"
            resValue("string", "channel_flag", "app_developer")
            resValue("string", "MERCHANT_ID", "329")
            resValue("string", "VEST_PKG_ID", "1001")
        }
        create("tiktok") {
            dimension = "channel"
            applicationId = "com.yushi.drama.client"
            resValue("string", "channel_flag", "tiktok")
            resValue("string", "MERCHANT_ID", "319")
            resValue("string", "VEST_PKG_ID", "1001")
        }
        create("kuaishou") {
            dimension = "channel"
            applicationId = "com.yushi.drama.client"
            resValue("string", "channel_flag", "kuaishou")
            resValue("string", "MERCHANT_ID", "320")
            resValue("string", "VEST_PKG_ID", "1002")
        }
    }
}

flutter {
    source = "../.."
}
