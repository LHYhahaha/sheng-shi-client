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
//        }Performing hot restart...
//Syncing files to device 24117RK2CC...
//Restarted application in 2,104ms.
//D/WmSystemUiDebug(11095): set navigation bar color,Alpha=1.0, RGB:0,0,0 caller:io.flutter.plugin.platform.PlatformPlugin.setSystemChromeSystemUIOverlayStyle:514 io.flutter.plugin.platform.PlatformPlugin.access$700:36 io.flutter.plugin.platform.PlatformPlugin$1.setSystemUiOverlayStyle:123 io.flutter.embedding.engine.systemchannels.PlatformChannel$1.onMethodCall:130 io.flutter.plugin.common.MethodChannel$IncomingMethodCallHandler.onMessage:267 io.flutter.embedding.engine.dart.DartMessenger.invokeHandler:286 io.flutter.embedding.engine.dart.DartMessenger.lambda$dispatchMessageToQueue$0$io-flutter-embedding-engine-dart-DartMessenger:313 io.flutter.embedding.engine.dart.DartMessenger$$ExternalSyntheticLambda0.run:0 android.os.Handler.handleCallback:1029 android.os.Handler.dispatchMessage:107
//D/WmSystemUiDebug(11095): set navigation bar color,Alpha=1.0, RGB:10,0,20 caller:io.flutter.plugin.platform.PlatformPlugin.setSystemChromeSystemUIOverlayStyle:514 io.flutter.plugin.platform.PlatformPlugin.access$700:36 io.flutter.plugin.platform.PlatformPlugin$1.setSystemUiOverlayStyle:123 io.flutter.embedding.engine.systemchannels.PlatformChannel$1.onMethodCall:130 io.flutter.plugin.common.MethodChannel$IncomingMethodCallHandler.onMessage:267 io.flutter.embedding.engine.dart.DartMessenger.invokeHandler:286 io.flutter.embedding.engine.dart.DartMessenger.lambda$dispatchMessageToQueue$0$io-flutter-embedding-engine-dart-DartMessenger:313 io.flutter.embedding.engine.dart.DartMessenger$$ExternalSyntheticLambda0.run:0 android.os.Handler.handleCallback:1029 android.os.Handler.dispatchMessage:107
//I/FLTFireMsgService(11095): FlutterFirebaseMessagingBackgroundService started!
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//W/WindowOnBackDispatcher(11095): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@755779e
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302779024, downTime=302779024, phoneEventTime=1787919823111 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302779089, downTime=302779024, phoneEventTime=1787919823176 } moveCount:0
//I/flutter (11095): [StartupLoading] app-loading start: network config confirmed
//I/flutter (11095): [ChannelConfigService] 开始读取渠道配置...
//I/flutter (11095): [ChannelConfigService] MethodChannel 名称: com.yushi.drama/channel_config
//I/flutter (11095): [TokenInit] Starting token initialization...
//I/flutter (11095): [StartupLoading] auth start elapsedMs=427
//I/flutter (11095): [StartupSdk] MediaKit initialize start
//I/flutter (11095): [StartupSdk] MediaKit initialize end elapsedMs=23
//I/flutter (11095): [ChannelConfigService] MethodChannel 返回原始结果: {channel_flag: tiktok, merchant_id: 319, vest_pkg_id: 1001}
//I/flutter (11095): [ChannelConfigService] 返回结果类型: _Map<Object?, Object?>
//I/flutter (11095): [ChannelConfigService] result 包含的键: [channel_flag, merchant_id, vest_pkg_id]
//I/flutter (11095): [ChannelConfigService]   channel_flag = tiktok (类型: String)
//I/flutter (11095): [ChannelConfigService]   merchant_id = 319 (类型: String)
//I/flutter (11095): [ChannelConfigService]   vest_pkg_id = 1001 (类型: String)
//I/flutter (11095): [ChannelConfigService] 解析结果:
//I/flutter (11095): [ChannelConfigService]   channel_flag = tiktok
//I/flutter (11095): [ChannelConfigService]   merchant_id = 319
//I/flutter (11095): [ChannelConfigService]   vest_pkg_id = 1001
//I/flutter (11095): [ChannelConfigService] 解析后的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ChannelConfigService] hasConfig: true
//I/flutter (11095): media_kit: NativeReferenceHolder: Located -5476376616612765984
//D/WmSystemUiDebug(11095): set navigation bar color,Alpha=1.0, RGB:0,0,0 caller:io.flutter.plugin.platform.PlatformPlugin.setSystemChromeSystemUIOverlayStyle:514 io.flutter.plugin.platform.PlatformPlugin.access$700:36 io.flutter.plugin.platform.PlatformPlugin$1.setSystemUiOverlayStyle:123 io.flutter.embedding.engine.systemchannels.PlatformChannel$1.onMethodCall:130 io.flutter.plugin.common.MethodChannel$IncomingMethodCallHandler.onMessage:267 io.flutter.embedding.engine.dart.DartMessenger.invokeHandler:286 io.flutter.embedding.engine.dart.DartMessenger.lambda$dispatchMessageToQueue$0$io-flutter-embedding-engine-dart-DartMessenger:313 io.flutter.embedding.engine.dart.DartMessenger$$ExternalSyntheticLambda0.run:0 android.os.Handler.handleCallback:1029 android.os.Handler.dispatchMessage:107
//I/flutter (11095): [StartupSdk] Adjust device-id ready elapsedMs=486
//I/flutter (11095): [Adjust] SDK initialization requested: environment=sandbox, sessionConfirmed=false.
//I/flutter (11095): [Adjust] Pending event recovery requested at startup.
//I/flutter (11095): [Adjust] SDK initialization already requested; sessionConfirmed=false.
//I/flutter (11095): [StartupSdk] Adjust init request end elapsedMs=498
//I/flutter (11095): [Adjust] Pending event dispatch started: count=0, sessionConfirmed=false.
//I/flutter (11095): [Adjust] No locally pending events to dispatch.
//I/flutter (11095): [StartupAuth] token read end elapsedMs=1
//I/flutter (11095): [AuthController.load] Found existing token, checking expiration...
//I/flutter (11095): [AuthController.load] Access token expired: false, Refresh token expired: false
//I/flutter (11095): [AuthController.load] ✅ Access token still valid, using existing token
//I/flutter (11095): [UserInfoManager] No user info available, returning guest session
//I/flutter (11095): [TokenInit] AuthController.load() completed
//I/flutter (11095): [StartupLoading] auth end elapsedMs=638
//I/flutter (11095): [StartupLoading] bottom-tabs start elapsedMs=646
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/entitlements will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/entitlements
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/popup will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/popup
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/popup
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {placement_code: home_enter}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/config/bottom-tabs will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/config/bottom-tabs
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/config/bottom-tabs
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//W/Adjust  (11095): SANDBOX: Adjust is running in Sandbox mode. Use this setting for testing. Don't forget to set the environment to `production` before publishing!
//E/Adjust  (11095): Adjust already initialized
//I/flutter (11095): [I18n] Remote strings updated, 563 keys loaded
//I/flutter (11095): [I18n] Language package initialization completed
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: en}
//I/flutter (11095): [ApiClient] ==============================
//D/Adjust  (11095): GoogleAdId read 68e161be-f819-498f-8f67-f5d34203ab28
//I/flutter (11095): [Adjust] Device identifiers: adjust_adid=99ff86507afac5463ab612345da187d2, gps_adid=68e161be-f819-498f-8f67-f5d34203ab28.
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/device/adjust will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/device/adjust
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/device/adjust
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {adjustAdid: 99ff86507afac5463ab612345da187d2, gpsAdid: 68e161be-f819-498f-8f67-f5d34203ab28}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: en, language_name: 英文, version: 1787624036, content_url: /api/i18n/en.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {membership: {isMember: false, membershipExpiresAt: }, playback: {autoUnlockEnabled: true, pendingOperationId: , unlockedEpisodeNos: []}, point: {totalPointBalance: 0}, userInfo: {avatar: , isGuest: true, language: en, nickname: 游客4163, showId: 509484163, status: 1, userId: 2093224561016311808}, wallet: {bonusBalance: 0, coinBalance: 0}}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "app_launch",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_7jx9SYM3rM8gZ3jR4MYYi0-x",
//I/flutter (11095):     "event_time": 1787919825320,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "launch_type": "cold"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [I18n] Remote strings updated, 563 keys loaded
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/device/adjust
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {attributionMatched: true, bound: true, userBound: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/config/bottom-tabs
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {tabs: []}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [StartupLoading] bottom-tabs end elapsedMs=2067
//I/flutter (11095): [Adjust] Device identifiers reported.
//I/flutter (11095): [StartupLoading] app-shell visible; app-loading end elapsedMs=2220
//I/flutter (11095): 2026-08-28T20:23:45.497418 feed controller load start session=for-you-tab mode=forYou dramaId=null episodeId=null
//I/flutter (11095): 2026-08-28T20:23:45.500286 feed repository listForYou page start session=for-you-tab page=1
//I/flutter (11095): [StartupSdk] FCM initialize start: app shell visible
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_E-7Evi6PJcvmDS_GAa5blK0q",
//I/flutter (11095):     "event_time": 1787919825514,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/play/recommend will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/play/recommend
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/play/recommend
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 1, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/search/hot will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/search/hot
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/config/home-banner will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/config/home-banner
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/config/home-banner
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//W/FLTFireMsgService(11095): Attempted to start a duplicate background isolate. Returning...
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/popup
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: [{id: 90, name: 抖音 - 短剧副本, placement_code: home_enter, priority: 4, content_mode: 2, popup_image: https://cdn.pixabay.com/user/2025/12/16/06-16-12-556_96x96.jpeg, show_close_button: 1, jump_type: 3, h5_url: , h5_open_type: 1, page_code: , short_jump_mode: 2, short_drama_id: 497, front_popup_limit: 0}]}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/active/report will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/active/report
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body: {channelSource: tiktok, region: CN, timezone: Asia/Shanghai}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [FCM] Android notification state: enabled=true, channel=default_notification_channel, importance=high
//I/flutter (11095): [FCM] Token: fHCP0Xz6RlyGVEgjh06dpw:APA91bFRoTe1JQeu_kCYFfmQpclDQAiZQq1ijbNkd4CP4b5ZvbCTtGxOUjUYb77hctF8CTStfDvCjHIz1eEi8FH9bJK5aGVBax9zzzXlFMJSHG7xIVJZWNM
//I/flutter (11095): [StartupSdk] FCM initialize end elapsedMs=177
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/config/home-banner
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {banners: [{banner_id: home_banner_001, image_url: https://cdn.nq1st.cc/image/poster/20260820/faea163937db7c30599b7ad5f853b3c7.png, jump_type: external_h5, jump_param: http://wwww.baidu.com}, {banner_id: home_banner_0011, image_url: https://cdn.nq1st.cc/image/poster/20260820/e91a50f4b5a8c4b28b15aab3c1ad2f78.png, jump_type: internal_h5, jump_param: https://wwww.baidu.com}, {banner_id: home_banner_002, image_url: https://cdn.nq1st.cc/image/poster/20260820/b2b164c624b1a2be05c1ab57fa9df64e.png, jump_type: drama, jump_param: 4153}, {banner_id: home_banner_003, image_url: https://cdn.nq1st.cc/image/poster/20260820/c47f7c32bb7228d772d8530e1d37e21c.png, jump_type: app_page, jump_param: recommend_tab}, {banner_id: home_banner_004, image_url: https://cdn.nq1st.cc/image/poster/20260820/8899132367c2c645d1b44dfdeb96fc1a.png, jump_type: app_page, jump_param: home}, {banner_id: home_banner_005, image_url: https://cdn.nq1st.cc/image/poster/20260820/faea163937db7c30599b7ad5
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/active/report will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/active/report
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body: {channelSource: tiktok, region: CN, timezone: Asia/Shanghai, pushToken: fHCP0Xz6RlyGVEgjh06dpw:APA91bFRoTe1JQeu_kCYFfmQpclDQAiZQq1ijbNkd4CP4b5ZvbCTtGxOUjUYb77hctF8CTStfDvCjHIz1eEi8FH9bJK5aGVBax9zzzXlFMJSHG7xIVJZWNM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {limit: 10, dramas: [{id: 823, sort: 1, cover_url: https://cdn.pixabay.com/video/2025/05/27/282086_tiny.jpg, title: handmade_vinegar_brewer_823, summary: A brewer makes vinegar with ancient methods and inherits traditional skills., tags_name: [workplace, real_actor_drama, urban, comic, anime], search_count: 8642000, hot_value: 8689968, trailer_episode_num: 11, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, watch_progress: {watch_episode_id: 8604, watch_episode_no: 1, watch_second: 2, progress_percent: 2, duration_second: 78}, is_favorited: 0}, {id: 822, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260821/a647920820ebb6d79e1ad21152c74017.jpg, title: Board Game Designer_822, summary: Designers create interesting board games to enrich people's leisure time., tags_name: [period_drama, sweet_romance, movie, workplace, mind_reading], search_count: 1250000, hot_value: 1297941, trailer_episode_num: 10
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/play/recommend
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {page: 1, page_size: 20, total: 1911, dramas: [{id: 487, sort: 1, cover_url: https://cdn.pixabay.com/video/2026/04/21/348057_tiny.jpg, title: legitimate_daughter_poison_consort_487, summary: A noble daughter becomes a poison consort and gains power., tags_name: [revenge, mother_in_law_conflict], play_count: 50982, favorite_count: 4589, is_favorited: 0, trailer_episode_num: 1, is_vip_only: 0, status: 1, episode_total: 4, episode_id: 0, episode_no: 1, watch_second: 0, duration_second: 0, progress_percent: 0, episodes: [{id: 10023, episode_no: 1, video_name: EP01, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=10023&expires=1787931825&verify=53783e7f3fb1bab21968d428529654b6a38b90da45c6a5107354572acbe7bf67, source_type: 1, duration_sec: 60, is_vip_only: 0, is_unlocked: 1, unlock_type: 0, status: 1, published_at: , subtitles: []}], watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, dur
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:23:46.308194 feed repository listForYou page end elapsed=807ms session=for-you-tab page=1 items=20 hasMore=true
//I/flutter (11095): 2026-08-28T20:23:46.308984 feed controller load end session=for-you-tab mode=forYou items=20 initialIndex=0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "home_banner_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_o0V6UnJU3mz2XmWJZt8dO-Ha",
//I/flutter (11095):     "event_time": 1787919826928,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "banner_id": "home_banner_001",
//I/flutter (11095):     "banner_target_type": "external_h5"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [PopupEntryOverlay] Popup image preload failed for 90: https://cdn.pixabay.com/user/2025/12/16/06-16-12-556_96x96.jpeg, error: HttpException: Invalid statusCode: 403, uri = https://cdn.pixabay.com/user/2025/12/16/06-16-12-556_96x96.jpeg
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: Hot, flag: hot, sort: 1, status: 1, page: 1, page_size: 20, drama_total: 24, dramas: [{id: 1513, sort: 1, cover_url: https://cdn.pixabay.com/photo/2017/10/07/16/22/river-2826927_1280.jpg, title: General Video_1513, summary: , play_count: 9700, favorite_count: 680, trailer_episode_num: 1, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 998, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, duration_second: 0}}, {id: 825, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260819/551b8e747c306a648ecf4c74c2417c1a.jpg, title: mountain_herb_collector_825, summary: 【Start】A herb collector treks through rolling mountains to gather wild plants, drawing nourishment from natural flora to sustain the age-old practice of traditional health preservation—a timeless tradi
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=1513 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=start candidate dramaId=1513 trigger=home_visible_candidate
//I/flutter (11095): 2026-08-28T20:23:48.471635 session=startup-preload startup preload request item=1513 sourceLabel=none dramaId=1513
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=1513 elapsedMs=0 dramaId=1513
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 1513}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_TYkAjsJN-29Ly4x5ei7Y-o4n",
//I/flutter (11095):     "event_time": 1787919829004,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "1513",
//I/flutter (11095):     "position": 1,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_MlZ0YTEgHucRt5wL0Bq-zNpL",
//I/flutter (11095):     "event_time": 1787919829018,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "825",
//I/flutter (11095):     "position": 2,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_cXZWxKaLB0SHF8SMjlmxPZuU",
//I/flutter (11095):     "event_time": 1787919829020,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "1508",
//I/flutter (11095):     "position": 3,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_fO9vQF7fNGgVGvBT_E99ypbb",
//I/flutter (11095):     "event_time": 1787919829021,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "1507",
//I/flutter (11095):     "position": 4,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_LeNXvKEVhtFcEy8IK64kjbRx",
//I/flutter (11095):     "event_time": 1787919829023,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12187",
//I/flutter (11095):     "position": 5,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_wccTjKLM_-wwnANHgr8ZK6iH",
//I/flutter (11095):     "event_time": 1787919829023,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12186",
//I/flutter (11095):     "position": 6,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 1513, cover_url: https://cdn.pixabay.com/photo/2017/10/07/16/22/river-2826927_1280.jpg, title: General Video_1513, summary: , category_ids: [5], trailer_episode_num: 1, price_per_episode: 70, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 9700, favorite_count: 680, episode_total: 998, episodes: [{id: 8560, episode_no: 3, video_name: , source_url: , source_type: 1, duration_sec: 0, is_vip_only: 0, is_unlocked: 0, unlock_type: 0, viewing_entitlement_type: locked, status: 1, published_at: , subtitles: []}, {id: 8561, episode_no: 4, video_name: , source_url: , source_type: 1, duration_sec: 0, is_vip_only: 0, is_unlocked: 0, unlock_type: 0, viewing_entitlement_type: locked, status: 1, published_at: , subtitles: []}, {id: 14915, episode_no: 5, video_name: , source_url: , source_type: 1, duration_sec: 0, is_vip_only: 0, is_unlocked: 0, unlock_type: 0, viewing_entitlement_type: locked, status: 1
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:23:49.722091 session=startup-preload startup preload cancelled item=1513 sourceLabel=none reason=no_playable_item
//I/flutter (11095): [player-entry-preload] startup=startup preload cancelled itemId=1513 elapsedMs=0 reason=no_playable_item
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "home_banner_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_TwaazDkK1ND4BIGqMzraN7E9",
//I/flutter (11095):     "event_time": 1787919830041,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "banner_id": "home_banner_0011",
//I/flutter (11095):     "banner_target_type": "internal_h5"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302788278, downTime=302788278, phoneEventTime=1787919832365 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302788446, downTime=302788278, phoneEventTime=1787919832533 } moveCount:5
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302788785, downTime=302788785, phoneEventTime=1787919832872 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302788843, downTime=302788785, phoneEventTime=1787919832930 } moveCount:5
//I/flutter (11095): [player-entry-preload] candidate dramaId=12185 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12185 trigger=home_visible_candidate previousDramaId=1513
//I/flutter (11095): 2026-08-28T20:23:53.085378 session=startup-preload startup preload request item=12185 sourceLabel=none dramaId=12185
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12185 elapsedMs=0 dramaId=12185
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 12185}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302789138, downTime=302789138, phoneEventTime=1787919833225 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302789211, downTime=302789138, phoneEventTime=1787919833298 } moveCount:5
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302789528, downTime=302789528, phoneEventTime=1787919833615 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 2, tab_id: 26, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302789601, downTime=302789528, phoneEventTime=1787919833688 } moveCount:5
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 12185, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/41000123212/41000123212_en_cover.jpg, title: Don't Mess With The XXL Heiress, summary: XXL Claire is about to become Lucas's bride, filled with anticipation. However, on her wedding day, she suffers multiple betrayals and humiliations from her fiancé Lucas and her best friend Stella. Devastated by these blows, Claire is finally found by her biological father, Victor, the billionaire, and becomes the heiress. Determined to completely change herself, she undergoes a thorough metamorphosis. Six months later, a radiantly new Claire appears at a banquet., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 3500, favorite_count: 245, episode_total: 50, episodes: [{id: 635944, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvd
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=12185 episodeId=635944 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:23:53.952302 session=startup-preload startup preload start item=single:12185:635944 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=635944&expires=1787931833&verify=f6a04e63f1281c4e68a18f366a89fac070ae8e53b1c455bea2852866a0f34f66 dramaId=12185 episodeId=635944
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12185:635944 elapsedMs=0 dramaId=12185 episodeId=635944
//I/flutter (11095): 2026-08-28T20:23:53.968625 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=635944
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: Hot, flag: hot, sort: 1, status: 1, page: 2, page_size: 20, drama_total: 24, dramas: [{id: 12148, sort: 21, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000003828/42000003828_en_cover.jpg, title: The Bride They Feared, The Queen They Crowned, summary: Bella Elmer's half-sister, Lisa Elmer, steals her wedding gift and marriage. Her fiancé wants to take Lisa as his main wife and Bella as his concubine. To change her fate, Bella volunteers to marry the 80-year-old King of Bexar. On her wedding night, she defends herself with a knife, only to realize that the bridegroom is Marcus Keagan, the god of war. From then on, Princess Bella and Prince Marcus join hands to quash their enemies and rule over their dominion., play_count: 2609, favorite_count: 157, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status:
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_1sug8SyFFH5_oaMIYh-StTtm",
//I/flutter (11095):     "event_time": 1787919834636,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12154",
//I/flutter (11095):     "position": 18,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_riLPAKNEms6nTWicHY7JSdJG",
//I/flutter (11095):     "event_time": 1787919834637,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12153",
//I/flutter (11095):     "position": 19,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_tNr5ZMSPM7T2CfS3ryqQ3ZkL",
//I/flutter (11095):     "event_time": 1787919834637,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12150",
//I/flutter (11095):     "position": 20,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302790566, downTime=302790566, phoneEventTime=1787919834653 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302790655, downTime=302790566, phoneEventTime=1787919834741 } moveCount:6
//I/flutter (11095): [player-entry-preload] candidate dramaId=12148 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12148 trigger=home_visible_candidate previousDramaId=12185
//I/flutter (11095): 2026-08-28T20:23:54.846346 session=startup-preload startup preload retained item=single:12185:635944 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=635944&expires=1787931833&verify=f6a04e63f1281c4e68a18f366a89fac070ae8e53b1c455bea2852866a0f34f66 dramaId=12185 reason=visible_candidate_replaced status=cancelled retainedCount=1
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12185:635944 elapsedMs=0 dramaId=12185 reason=visible_candidate_replaced status=cancelled retainedCount=1
//I/flutter (11095): 2026-08-28T20:23:54.846694 session=startup-preload startup preload request item=12148 sourceLabel=none dramaId=12148
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12148 elapsedMs=0 dramaId=12148
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 12148}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302790942, downTime=302790942, phoneEventTime=1787919835029 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302791000, downTime=302790942, phoneEventTime=1787919835087 } moveCount:5
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 12148, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000003828/42000003828_en_cover.jpg, title: The Bride They Feared, The Queen They Crowned, summary: Bella Elmer's half-sister, Lisa Elmer, steals her wedding gift and marriage. Her fiancé wants to take Lisa as his main wife and Bella as his concubine. To change her fate, Bella volunteers to marry the 80-year-old King of Bexar. On her wedding night, she defends herself with a knife, only to realize that the bridegroom is Marcus Keagan, the god of war. From then on, Princess Bella and Prince Marcus join hands to quash their enemies and rule over their dominion., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2609, favorite_count: 157, episode_total: 66, episodes: [{id: 633425, episode_no: 1, video_name: Episode 1, source_url: https://master-ap
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=12148 episodeId=633425 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:23:55.302088 session=startup-preload startup preload start item=single:12148:633425 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633425&expires=1787931834&verify=eb0275fa647af4921bd14e0fb96afe9eda455bf7074b1f42df3ca4dbcc5b4f32 dramaId=12148 episodeId=633425
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12148:633425 elapsedMs=0 dramaId=12148 episodeId=633425
//I/flutter (11095): 2026-08-28T20:23:55.302957 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633425
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_s7Muez96Dh6vps5HpvjFbhdY",
//I/flutter (11095):     "event_time": 1787919835404,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12145",
//I/flutter (11095):     "position": 22,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_w9LkmWa4WsEezKCLZdfo_ctO",
//I/flutter (11095):     "event_time": 1787919835405,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12144",
//I/flutter (11095):     "position": 23,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [player-entry-preload] candidate dramaId=12143 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12143 trigger=home_visible_candidate previousDramaId=12148
//I/flutter (11095): 2026-08-28T20:23:55.485303 session=startup-preload startup preload retained item=single:12148:633425 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633425&expires=1787931834&verify=eb0275fa647af4921bd14e0fb96afe9eda455bf7074b1f42df3ca4dbcc5b4f32 dramaId=12148 reason=visible_candidate_replaced status=cancelled retainedCount=2
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12148:633425 elapsedMs=0 dramaId=12148 reason=visible_candidate_replaced status=cancelled retainedCount=2
//I/flutter (11095): 2026-08-28T20:23:55.485692 session=startup-preload startup preload request item=12143 sourceLabel=none dramaId=12143
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12143 elapsedMs=0 dramaId=12143
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 12143}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 12143, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/41000120429/41000120429_en_cover.jpg, title: Runaway Bride, Billionaire's Catch, summary: To escape a forced marriage to the ruthless billionaire heir Frank Reed, Kate Smith bolts from the altar and impulsively weds a man she believes is a poor driver—only to discover he is Frank himself. As secrets unravel and sparks fly under one roof, a runaway bride finds herself in a twist-filled romance of mistaken identity, sweet revenge, and unexpected love., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 3700, favorite_count: 333, episode_total: 57, episodes: [{id: 633061, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=12143 episodeId=633061 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:23:55.848065 session=startup-preload startup preload start item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 episodeId=633061
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12143:633061 elapsedMs=0 dramaId=12143 episodeId=633061
//I/flutter (11095): 2026-08-28T20:23:55.848870 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_L_CWdDGnj72R0armX_mwTpq0",
//I/flutter (11095):     "event_time": 1787919835980,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12143",
//I/flutter (11095):     "position": 24,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): 2026-08-28T20:23:56.141493 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/41000120429/599294262/1080/1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302792064, downTime=302792064, phoneEventTime=1787919836151 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302792241, downTime=302792064, phoneEventTime=1787919836328 } moveCount:1
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_xzFGysSCCre0rAqAUHkFDZBD",
//I/flutter (11095):     "event_time": 1787919836351,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 10836
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_VZXIdsGLAtFA1BeyQtHDSuhW",
//I/flutter (11095):     "event_time": 1787919836476,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/entitlements will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/entitlements
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {membership: {isMember: false, membershipExpiresAt: }, playback: {autoUnlockEnabled: true, pendingOperationId: , unlockedEpisodeNos: []}, point: {totalPointBalance: 0}, userInfo: {avatar: , isGuest: true, language: en, nickname: 游客4163, showId: 509484163, status: 1, userId: 2093224561016311808}, wallet: {bonusBalance: 0, coinBalance: 0}}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302792930, downTime=302792930, phoneEventTime=1787919837016 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302793011, downTime=302792930, phoneEventTime=1787919837098 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_7BNj4HVkXldsbWF1GIEp0DG2",
//I/flutter (11095):     "event_time": 1787919837180,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 704
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/language/global will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/language/global
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_Z2_ES_dFPo19APhNH9S961GX",
//I/flutter (11095):     "event_time": 1787919837196,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919837211, Track-Sign: ae91402cb23b23ab8dfe2416ebfeb2a652c83d6342c025166f37bc61e1632959, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"app_launch","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_7jx9SYM3rM8gZ3jR4MYYi0-x","eventTime":1787919825320,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"","platform":"android","previousPage":"","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"launch_type\":\"cold\"}"},{"eventName":"page_view","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_E-7Evi6PJcvmDS_GAa5blK0q","eventTime":1787919825514,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"","regionCode":"CN","userId":"2093224561016311808"},"eventParams":""},{"eventName":"home_banner_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_o0V6UnJU3mz2XmWJZt8dO-Ha","eventTime":1787919826928,"h5VisitorId":"","language":"en
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302793349, downTime=302793349, phoneEventTime=1787919837436 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302793400, downTime=302793349, phoneEventTime=1787919837487 } moveCount:0
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {English: en, língua: pt, 简体中文: zh, 繁體中文: zh-Hant}}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302794342, downTime=302794342, phoneEventTime=1787919838429 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302794422, downTime=302794342, phoneEventTime=1787919838508 } moveCount:0
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302794908, downTime=302794908, phoneEventTime=1787919838995 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302794988, downTime=302794908, phoneEventTime=1787919839075 } moveCount:0
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: zh}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: zh, language_name: 简体中文, version: 1787624036, content_url: /api/i18n/zh.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [I18n] Remote strings updated, 556 keys loaded
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: en}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/search/hot will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/search/hot
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/active/report will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/active/report
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body: {channelSource: tiktok, region: CN, timezone: Asia/Shanghai, pushToken: fHCP0Xz6RlyGVEgjh06dpw:APA91bFRoTe1JQeu_kCYFfmQpclDQAiZQq1ijbNkd4CP4b5ZvbCTtGxOUjUYb77hctF8CTStfDvCjHIz1eEi8FH9bJK5aGVBax9zzzXlFMJSHG7xIVJZWNM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_RVBygk12d3iVcsZzUzX0_ccF",
//I/flutter (11095):     "event_time": 1787919839523,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 2326
//I/flutter (11095):   }
//I/flutter (11095): }
//W/WindowOnBackDispatcher(11095): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@755779e
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_IEYZ0FhfxzrJZtSpKn1V2GkB",
//I/flutter (11095):     "event_time": 1787919839551,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: en, language_name: 英文, version: 1787624036, content_url: /api/i18n/en.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [I18n] Remote strings updated, 563 keys loaded
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {limit: 10, dramas: [{id: 822, sort: 1, cover_url: https://cdn.nq1st.cc/image/poster/20260821/f644ccee4c4f6424287e06f1b8b623ff.jpg, title: 趣味桌游设计师_822, summary: 设计师创作有趣的桌游，丰富人们的闲暇时光。, tags_name: [年代剧, 甜宠, 电影, 职场, 读心术], search_count: 1250000, hot_value: 1297941, trailer_episode_num: 10, is_vip_only: 1, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, watch_progress: {watch_episode_id: 8575, watch_episode_no: 1, watch_second: 3, progress_percent: 1, duration_second: 171}, is_favorited: 0}, {id: 1508, sort: 2, cover_url: https://cdn.pixabay.com/photo/2015/08/15/11/09/aster-889447_1280.jpg, title: 视频模板勿删 _1508, summary: 标准测试视频模板，请勿删除，用于播放器、字幕相关功能验收测试, tags_name: [追妻火葬场], search_count: 9999, hot_value: 52686, trailer_episode_num: 100, is_vip_only: 0, trial: {trial_ena
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: 成功}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302796162, downTime=302796162, phoneEventTime=1787919840249 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302796220, downTime=302796162, phoneEventTime=1787919840307 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_KUR_7K4onKml0vGpFr4ylU6N",
//I/flutter (11095):     "event_time": 1787919840312,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 761
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_8Ko5sCxn9rkmk_3pJhhuI5NY",
//I/flutter (11095):     "event_time": 1787919840368,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: 热门, flag: hot, sort: 1, status: 1, page: 1, page_size: 20, drama_total: 4, dramas: [{id: 1513, sort: 1, cover_url: https://cdn.pixabay.com/photo/2017/10/07/16/22/river-2826927_1280.jpg, title: 通用视频_1513, summary: , play_count: 9700, favorite_count: 680, trailer_episode_num: 1, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 998, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, duration_second: 0}}, {id: 825, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260819/f61eacfb9882035086908ef7e31517d3.jpg, title: 山间采药客_825, summary: 【开始】采药人踏遍群山，采撷百草，以草木本源滋养传统养生之道，这是流淌在华夏土地上绵延千年的生活图景，也是中医药文化最朴素、最鲜活的传承载体。�
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=1513 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=1513 trigger=home_visible_candidate previousDramaId=12143
//I/flutter (11095): 2026-08-28T20:24:00.908037 session=startup-preload startup preload retained item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12143:633061 elapsedMs=0 dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:00.908808 session=startup-preload startup preload request item=1513 sourceLabel=none dramaId=1513
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=1513 elapsedMs=0 dramaId=1513
//I/flutter (11095): 2026-08-28T20:24:00.921479 session=startup-preload startup preload cancelled item=1513 sourceLabel=none reason=no_playable_item
//I/flutter (11095): [player-entry-preload] startup=startup preload cancelled itemId=1513 elapsedMs=0 reason=no_playable_item
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302796949, downTime=302796949, phoneEventTime=1787919841036 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302797030, downTime=302796949, phoneEventTime=1787919841117 } moveCount:5
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302797703, downTime=302797703, phoneEventTime=1787919841789 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302797775, downTime=302797703, phoneEventTime=1787919841862 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_dm-KRsu92vuirv_BDqXIpueW",
//I/flutter (11095):     "event_time": 1787919841866,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 1497
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_l8qmQaeQ2IAMVc7PtV_UFeZl",
//I/flutter (11095):     "event_time": 1787919841875,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/entitlements will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/entitlements
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "home_banner_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_al45_ZsHJGPNoWxnb4XF2DAf",
//I/flutter (11095):     "event_time": 1787919841995,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "banner_id": "home_banner_005",
//I/flutter (11095):     "banner_target_type": "app_page"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {membership: {isMember: false, membershipExpiresAt: }, playback: {autoUnlockEnabled: true, pendingOperationId: , unlockedEpisodeNos: []}, point: {totalPointBalance: 0}, userInfo: {avatar: , isGuest: true, language: en, nickname: 游客4163, showId: 509484163, status: 1, userId: 2093224561016311808}, wallet: {bonusBalance: 0, coinBalance: 0}}, message: 成功}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302798332, downTime=302798332, phoneEventTime=1787919842418 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302798404, downTime=302798332, phoneEventTime=1787919842491 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_8BhFsbkmXEzDOu6HCiN1LZ15",
//I/flutter (11095):     "event_time": 1787919842560,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 684
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/language/global will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/language/global
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_JXXFbFe8hgZd33xwmRNyxBKu",
//I/flutter (11095):     "event_time": 1787919842571,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {English: en, língua: pt, 简体中文: zh, 繁體中文: zh-Hant}}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302799224, downTime=302799224, phoneEventTime=1787919843311 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302799275, downTime=302799224, phoneEventTime=1787919843362 } moveCount:0
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302799666, downTime=302799666, phoneEventTime=1787919843753 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302799724, downTime=302799666, phoneEventTime=1787919843811 } moveCount:0
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: en}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: en, language_name: 英文, version: 1787624036, content_url: /api/i18n/en.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [I18n] Remote strings updated, 563 keys loaded
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/search/hot will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/search/hot
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_vrDOfYYRt3JokS-d0oj1liar",
//I/flutter (11095):     "event_time": 1787919844115,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 1543
//I/flutter (11095):   }
//I/flutter (11095): }
//W/WindowOnBackDispatcher(11095): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@755779e
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_SxageSpub9HHcGmIJm2QZLbW",
//I/flutter (11095):     "event_time": 1787919844142,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/active/report will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/active/report
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body: {channelSource: tiktok, region: CN, timezone: Asia/Shanghai, pushToken: fHCP0Xz6RlyGVEgjh06dpw:APA91bFRoTe1JQeu_kCYFfmQpclDQAiZQq1ijbNkd4CP4b5ZvbCTtGxOUjUYb77hctF8CTStfDvCjHIz1eEi8FH9bJK5aGVBax9zzzXlFMJSHG7xIVJZWNM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {limit: 10, dramas: [{id: 823, sort: 1, cover_url: https://cdn.pixabay.com/video/2025/05/27/282086_tiny.jpg, title: handmade_vinegar_brewer_823, summary: A brewer makes vinegar with ancient methods and inherits traditional skills., tags_name: [workplace, real_actor_drama, urban, comic, anime], search_count: 8642000, hot_value: 8689968, trailer_episode_num: 11, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, watch_progress: {watch_episode_id: 8604, watch_episode_no: 1, watch_second: 2, progress_percent: 2, duration_second: 78}, is_favorited: 0}, {id: 822, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260821/a647920820ebb6d79e1ad21152c74017.jpg, title: Board Game Designer_822, summary: Designers create interesting board games to enrich people's leisure time., tags_name: [period_drama, sweet_romance, movie, workplace, mind_reading], search_count: 1250000, hot_value: 1297941, trailer_episode_num: 10
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302800546, downTime=302800546, phoneEventTime=1787919844633 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302800604, downTime=302800546, phoneEventTime=1787919844690 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_PpojPucKtto6dNgpS4l435Ic",
//I/flutter (11095):     "event_time": 1787919844699,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 556
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_PW-PcZ_Fo9sqob_MybZRC93H",
//I/flutter (11095):     "event_time": 1787919844757,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: Hot, flag: hot, sort: 1, status: 1, page: 1, page_size: 20, drama_total: 24, dramas: [{id: 1513, sort: 1, cover_url: https://cdn.pixabay.com/photo/2017/10/07/16/22/river-2826927_1280.jpg, title: General Video_1513, summary: , play_count: 9700, favorite_count: 680, trailer_episode_num: 1, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 998, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, duration_second: 0}}, {id: 825, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260819/551b8e747c306a648ecf4c74c2417c1a.jpg, title: mountain_herb_collector_825, summary: 【Start】A herb collector treks through rolling mountains to gather wild plants, drawing nourishment from natural flora to sustain the age-old practice of traditional health preservation—a timeless tradi
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302801518, downTime=302801518, phoneEventTime=1787919845605 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302801561, downTime=302801518, phoneEventTime=1787919845648 } moveCount:5
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302801951, downTime=302801951, phoneEventTime=1787919846038 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302802017, downTime=302801951, phoneEventTime=1787919846104 } moveCount:4
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 2, tab_id: 26, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302802467, downTime=302802467, phoneEventTime=1787919846554 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302802540, downTime=302802467, phoneEventTime=1787919846627 } moveCount:4
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: Hot, flag: hot, sort: 1, status: 1, page: 2, page_size: 20, drama_total: 24, dramas: [{id: 12148, sort: 21, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000003828/42000003828_en_cover.jpg, title: The Bride They Feared, The Queen They Crowned, summary: Bella Elmer's half-sister, Lisa Elmer, steals her wedding gift and marriage. Her fiancé wants to take Lisa as his main wife and Bella as his concubine. To change her fate, Bella volunteers to marry the 80-year-old King of Bexar. On her wedding night, she defends herself with a knife, only to realize that the bridegroom is Marcus Keagan, the god of war. From then on, Princess Bella and Prince Marcus join hands to quash their enemies and rule over their dominion., play_count: 2609, favorite_count: 157, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status:
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302802922, downTime=302802922, phoneEventTime=1787919847009 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302802996, downTime=302802922, phoneEventTime=1787919847083 } moveCount:2
//I/flutter (11095): [player-entry-preload] candidate dramaId=12145 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12145 trigger=home_visible_candidate previousDramaId=1513
//I/flutter (11095): 2026-08-28T20:24:07.162992 session=startup-preload startup preload request item=12145 sourceLabel=none dramaId=12145
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12145 elapsedMs=0 dramaId=12145
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 12145}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 12145, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000011673/42000011673_en_cover.jpg, title: He's Just a Househusband, Until the World Kneels, summary: After a cultivation accident leaves Elliot Judd in need of the energy of a woman with a Lunar Constitution to survive, he marries Xenia Klein. Believing him to be useless, she refuses to consummate the marriage for three years and repeatedly demands a divorce. On the 300th time she asks for one, Elliot finally agrees and goes on to marry her idol, Sadie Wood. Only then does Xenia realize—too late—that she has feelings for him. But once Elliot walks away, he never looks back., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 1230, favorite_count: 100, episode_total: 101, episodes: [{id: 633199, episode_no: 1, video_name: Episode 1, source_u
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=12145 episodeId=633199 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:07.445453 session=startup-preload startup preload start item=single:12145:633199 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633199&expires=1787931847&verify=3fac3d0a7957b4ed9670918b396bccebb4357c81747f92ed7dca380eacc40f67 dramaId=12145 episodeId=633199
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12145:633199 elapsedMs=0 dramaId=12145 episodeId=633199
//I/flutter (11095): 2026-08-28T20:24:07.447417 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633199
//I/flutter (11095): [player-entry-preload] candidate dramaId=12143 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12143 trigger=home_visible_candidate previousDramaId=12145
//I/flutter (11095): 2026-08-28T20:24:07.657972 session=startup-preload startup preload retained item=single:12145:633199 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633199&expires=1787931847&verify=3fac3d0a7957b4ed9670918b396bccebb4357c81747f92ed7dca380eacc40f67 dramaId=12145 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12145:633199 elapsedMs=0 dramaId=12145 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:07.658981 session=startup-preload startup preload request item=12143 sourceLabel=none dramaId=12143
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12143 elapsedMs=0 dramaId=12143
//I/flutter (11095): [player-entry-preload] selection dramaId=12143 episodeId=633061 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:07.662207 session=startup-preload startup preload start item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 episodeId=633061
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12143:633061 elapsedMs=0 dramaId=12143 episodeId=633061
//I/flutter (11095): 2026-08-28T20:24:07.663865 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_Yva_Y8_qHFYwCRy56OGFH5Lf",
//I/flutter (11095):     "event_time": 1787919847721,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12148",
//I/flutter (11095):     "position": 21,
//I/flutter (11095):     "category_id": "26"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302803862, downTime=302803862, phoneEventTime=1787919847949 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302804236, downTime=302803862, phoneEventTime=1787919848323 } moveCount:46
//I/flutter (11095): 2026-08-28T20:24:08.464674 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/41000120429/599294262/1080/1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302804595, downTime=302804595, phoneEventTime=1787919848681 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302804874, downTime=302804595, phoneEventTime=1787919848961 } moveCount:23
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302805161, downTime=302805161, phoneEventTime=1787919849248 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302805227, downTime=302805161, phoneEventTime=1787919849313 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "element_click",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_63fRHrz5B4zXorIkTuL0qJKy",
//I/flutter (11095):     "event_time": 1787919849333,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "element_name": "home_category_tab",
//I/flutter (11095):     "category_id": "27",
//I/flutter (11095):     "position": 5
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [player-entry-preload] candidate dramaId=4157 visiblePercent=71
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4157 trigger=home_visible_candidate previousDramaId=12143
//I/flutter (11095): 2026-08-28T20:24:09.857997 session=startup-preload startup preload retained item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12143:633061 elapsedMs=0 dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:09.859366 session=startup-preload startup preload request item=4157 sourceLabel=none dramaId=4157
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4157 elapsedMs=0 dramaId=4157
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4157}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302805798, downTime=302805798, phoneEventTime=1787919849885 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302805871, downTime=302805798, phoneEventTime=1787919849958 } moveCount:6
//I/flutter (11095): [player-entry-preload] candidate dramaId=4154 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4154 trigger=home_visible_candidate previousDramaId=4157
//I/flutter (11095): 2026-08-28T20:24:09.987309 session=startup-preload startup preload retained item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12143:633061 elapsedMs=0 dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:09.987678 session=startup-preload startup preload request item=4154 sourceLabel=none dramaId=4154
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4154 elapsedMs=0 dramaId=4154
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4154}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302806136, downTime=302806136, phoneEventTime=1787919850223 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302806232, downTime=302806136, phoneEventTime=1787919850319 } moveCount:7
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302806541, downTime=302806541, phoneEventTime=1787919850628 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302806673, downTime=302806541, phoneEventTime=1787919850759 } moveCount:8
//I/flutter (11095): [player-entry-preload] candidate dramaId=4079 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4079 trigger=home_visible_candidate previousDramaId=4154
//I/flutter (11095): 2026-08-28T20:24:10.897109 session=startup-preload startup preload retained item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12143:633061 elapsedMs=0 dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:10.897329 session=startup-preload startup preload request item=4079 sourceLabel=none dramaId=4079
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4079 elapsedMs=0 dramaId=4079
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4079}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302806923, downTime=302806923, phoneEventTime=1787919851010 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302806989, downTime=302806923, phoneEventTime=1787919851076 } moveCount:5
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 2, tab_id: 27, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302807232, downTime=302807232, phoneEventTime=1787919851319 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302807291, downTime=302807232, phoneEventTime=1787919851378 } moveCount:4
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302807519, downTime=302807519, phoneEventTime=1787919851606 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302807607, downTime=302807519, phoneEventTime=1787919851694 } moveCount:7
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_WeFPQa97zJ3e07FJRmUYj9ny",
//I/flutter (11095):     "event_time": 1787919852142,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12165",
//I/flutter (11095):     "position": 17,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_dv4IMuSn_hYoQCszw8-97GI1",
//I/flutter (11095):     "event_time": 1787919852142,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4121",
//I/flutter (11095):     "position": 18,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_QlW7PR-iYZ62Gf2KYFyLckBF",
//I/flutter (11095):     "event_time": 1787919852225,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4124",
//I/flutter (11095):     "position": 19,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt__AD8PWGLcEKKn7Rdtd1w7T_j",
//I/flutter (11095):     "event_time": 1787919852228,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4114",
//I/flutter (11095):     "position": 20,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4157, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000012338/42000012338_en_cover.jpg, title: Lingering Scent: The CEO's Obsession, summary: Victor Ford, a cold and low-profile business elite, falls for Claire Reed at first sight. Known for his ruthless nature, he unexpectedly lowers his boundaries and resorts to every means just to capture her attention. As he tirelessly pursues her, Claire begins to see the hidden tenderness beneath his icy facade. Confronted by such intense and persistent devotion, she finds her own heart slowly melting into a passionate romance., category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 6200, favorite_count: 434, episode_total: 79, episodes: [{id: 155847, episode_no: 1, video_name: master.m3u8, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=12165 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12165 trigger=home_visible_candidate previousDramaId=4079
//I/flutter (11095): 2026-08-28T20:24:13.071561 session=startup-preload startup preload retained item=single:12143:633061 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633061&expires=1787931835&verify=d3ce5312ad0a777010b1510401a52417a0fb0d2548c2c8e37c200aba2c18e75f dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12143:633061 elapsedMs=0 dramaId=12143 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:13.072298 session=startup-preload startup preload request item=12165 sourceLabel=none dramaId=12165
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12165 elapsedMs=0 dramaId=12165
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 12165}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 12165, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/41000122600/41000122600_en_cover.jpg, title: The Mistaken First Love, summary: When a proud heiress is forced to marry in her stepsister’s place, she discovers shocking betrayals and vows revenge. But as her bodyguard’s secret identity and their twisted past unravel, love, lies, and fate collide in a storm of passion and deception., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 3400, favorite_count: 238, episode_total: 52, episodes: [{id: 634633, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=634633&expires=1787931853&verify=c536bc7bf7af2389b3a9f9a86edaea3322249eb36652ec7ad63268a44ba4f96c, source_type: 1, duration_sec: 0, is_vip_only: 0, is_unlocked: 1, unlock_type: 0,
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=12165 episodeId=634633 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:13.739423 session=startup-preload startup preload start item=single:12165:634633 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=634633&expires=1787931853&verify=c536bc7bf7af2389b3a9f9a86edaea3322249eb36652ec7ad63268a44ba4f96c dramaId=12165 episodeId=634633
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12165:634633 elapsedMs=0 dramaId=12165 episodeId=634633
//I/flutter (11095): 2026-08-28T20:24:13.740609 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=634633
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 27, name: selected, flag: selected, sort: 5, status: 1, page: 2, page_size: 20, drama_total: 1000, dramas: [{id: 11918, sort: 21, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/41000114490/41000114490_en_cover.jpg, title: My Husband Has a Secret Name, summary: Stella Swain, the CEO of Swain Corp, is determined to prevent her stepmother, Luna Ashton, from seizing control of the company. In a desperate move, she plans to marry a man at random, hoping to claim the ten percent of shares her grandfather left to her future husband. But when she discovers that one of her suitors is a spy, she rejects all of them, choosing instead Eric Green—the strikingly handsome but seemingly penniless man she encounters outside City Hall., play_count: 3300, favorite_count: 264, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1,
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:24:14.491566 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/41000122600/602239840/1080/1080p_000.ts?
//I/flutter (11095): [player-entry-preload] candidate dramaId=11918 visiblePercent=78
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=11918 trigger=home_visible_candidate previousDramaId=12165
//I/flutter (11095): 2026-08-28T20:24:14.704597 session=startup-preload startup preload retained item=single:12165:634633 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=634633&expires=1787931853&verify=c536bc7bf7af2389b3a9f9a86edaea3322249eb36652ec7ad63268a44ba4f96c dramaId=12165 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12165:634633 elapsedMs=0 dramaId=12165 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:14.705764 session=startup-preload startup preload request item=11918 sourceLabel=none dramaId=11918
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=11918 elapsedMs=0 dramaId=11918
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 11918}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4154, cover_url: https://cdn.nq1st.cc/test-cover/drama-4154/4154.jpg, title: The Unwanted Wife Strikes Back, summary: When a housewife discovers her fashion mogul husband is cheating, and stealing her designs, she files for divorce and wages a scorched-earth revenge campaign to reclaim the empire she secretly helped build. But exposing his lies means going to war with his scheming mistress, his icy sister - and allying herself with Cyrus Voss, her husband's biggest rival., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 8150, favorite_count: 652, episode_total: 49, episodes: [{id: 155848, episode_no: 1, video_name: 700976878.1080p.m3u8, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=155848&expires=1787931854&verify=6f7e99865d1a3465ad02e6261bd90f8cab2bd389ff83b395f56da8b093a840a2, source_ty
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4079, cover_url: https://cdn.nq1st.cc/test-cover/drama-4079/4079.jpg, title: My Teenage Mother（DUBBED）, summary: 24-year-old Kim Ha-rim dies in a car accident and discovers that she is the first love of Yu Jun-hyeok, the male lead of a novel. After her death, her children lead miserable lives. Reborn as her 18-year-old self, Ha-rim is determined to change her family's fate. She reclaims the stolen villa, guides her son to change his ways, and protects her daughter. With Jun-hyeok's support, the broken family reconciles and finds their happily ever after., category_ids: [564], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 3600, favorite_count: 324, episode_total: 61, episodes: [{id: 150574, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=150574&expires=1787931854&verif
//I/flutter (11095): [ApiClient] ==============================
//V/Adjust  (11095): Foreground timer fired
//D/Adjust  (11095): Wrote Activity state: ec:5 sc:1 ssc:8 sl:1505.6 ts:1354.2 la:11:12:13 uuid:188ea34e-d453-4806-ba3b-a02c8e205564
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302810987, downTime=302810987, phoneEventTime=1787919855074 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 11918, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/41000114490/41000114490_en_cover.jpg, title: My Husband Has a Secret Name, summary: Stella Swain, the CEO of Swain Corp, is determined to prevent her stepmother, Luna Ashton, from seizing control of the company. In a desperate move, she plans to marry a man at random, hoping to claim the ten percent of shares her grandfather left to her future husband. But when she discovers that one of her suitors is a spy, she rejects all of them, choosing instead Eric Green—the strikingly handsome but seemingly penniless man she encounters outside City Hall., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 3300, favorite_count: 264, episode_total: 80, episodes: [{id: 618461, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=11918 episodeId=618461 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:15.123926 session=startup-preload startup preload start item=single:11918:618461 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=618461&expires=1787931854&verify=947d2c28a415835cbd308e003e553eaa75b45652537fd5d23f9dc4fc1322e3f3 dramaId=11918 episodeId=618461
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:11918:618461 elapsedMs=0 dramaId=11918 episodeId=618461
//I/flutter (11095): 2026-08-28T20:24:15.124745 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=618461
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302811088, downTime=302810987, phoneEventTime=1787919855175 } moveCount:9
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_tt4sDOygxpP5UcocDC8KZSHf",
//I/flutter (11095):     "event_time": 1787919855287,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11918",
//I/flutter (11095):     "position": 21,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_80ih1SxbJYxQANns2rdQ1IaI",
//I/flutter (11095):     "event_time": 1787919855288,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11902",
//I/flutter (11095):     "position": 22,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919855307, Track-Sign: 3a205aaa1b5e18286514f414d523bcc14e542d823e5268e9f97065089d622161, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"page_leave","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_RVBygk12d3iVcsZzUzX0_ccF","eventTime":1787919839523,"h5VisitorId":"","language":"zh","merchantId":"319","pageName":"language_settings_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"stay_duration_ms\":2326}"},{"eventName":"page_view","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_IEYZ0FhfxzrJZtSpKn1V2GkB","eventTime":1787919839551,"h5VisitorId":"","language":"zh","merchantId":"319","pageName":"my_page","platform":"android","previousPage":"language_settings_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":""},{"eventName":"page_leave","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_KUR_7K4onKml0vGpFr4ylU6N","eventTime":17879
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302811338, downTime=302811338, phoneEventTime=1787919855425 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): 2026-08-28T20:24:15.497966 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/41000114490/591652037/1080/1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302811426, downTime=302811338, phoneEventTime=1787919855513 } moveCount:6
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919855626, Track-Sign: e153949238e0502ff4ecf17bb22647c780f443801639fda150d5446736322609, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_80ih1SxbJYxQANns2rdQ1IaI","eventTime":1787919855288,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"11902\",\"position\":22,\"category_id\":\"27\"}"}]}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302811669, downTime=302811669, phoneEventTime=1787919855756 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302811735, downTime=302811669, phoneEventTime=1787919855822 } moveCount:7
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 3, tab_id: 27, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302812228, downTime=302812228, phoneEventTime=1787919856315 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302812302, downTime=302812228, phoneEventTime=1787919856389 } moveCount:7
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 27, name: selected, flag: selected, sort: 5, status: 1, page: 3, page_size: 20, drama_total: 1000, dramas: [{id: 3976, sort: 41, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000023107/42000023107_en_cover.jpg, title: The Fake Fortune That Exposed My Marriage, summary: Claire Blair has supported her husband Evan Carter and his family for three years, only to discover they never loved her—they wanted her wealth. When a fake scratch-off convinces Evan that he's won $100 million, he demands a divorce and his family forces Claire out. Their greed exposes their true faces, and Claire walks away for good. Now, she vows to make the man who betrayed her regret every choice he made., play_count: 2990, favorite_count: 179, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 60, is_favorited: 0, watch_pr
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_pfjFTQC4PlS612fnHOONsu_P",
//I/flutter (11095):     "event_time": 1787919857050,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3587",
//I/flutter (11095):     "position": 37,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_JmwVxNZY90z7dwikwtqo7LVw",
//I/flutter (11095):     "event_time": 1787919857051,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11805",
//I/flutter (11095):     "position": 38,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_eULK2ddCW5zPw2B3bq59rL_m",
//I/flutter (11095):     "event_time": 1787919857180,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3906",
//I/flutter (11095):     "position": 39,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_gNbwQ31te8QG7pOCF_JzdxXe",
//I/flutter (11095):     "event_time": 1787919857201,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3909",
//I/flutter (11095):     "position": 40,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [player-entry-preload] candidate dramaId=3976 visiblePercent=75
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=3976 trigger=home_visible_candidate previousDramaId=11918
//I/flutter (11095): 2026-08-28T20:24:17.306544 session=startup-preload startup preload retained item=single:11918:618461 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=618461&expires=1787931854&verify=947d2c28a415835cbd308e003e553eaa75b45652537fd5d23f9dc4fc1322e3f3 dramaId=11918 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:11918:618461 elapsedMs=0 dramaId=11918 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:17.307583 session=startup-preload startup preload request item=3976 sourceLabel=none dramaId=3976
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=3976 elapsedMs=0 dramaId=3976
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 3976}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302813292, downTime=302813292, phoneEventTime=1787919857379 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302813380, downTime=302813292, phoneEventTime=1787919857467 } moveCount:6
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 3976, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000023107/42000023107_en_cover.jpg, title: The Fake Fortune That Exposed My Marriage, summary: Claire Blair has supported her husband Evan Carter and his family for three years, only to discover they never loved her—they wanted her wealth. When a fake scratch-off convinces Evan that he's won $100 million, he demands a divorce and his family forces Claire out. Their greed exposes their true faces, and Claire walks away for good. Now, she vows to make the man who betrayed her regret every choice he made., category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2990, favorite_count: 179, episode_total: 60, episodes: [{id: 143918, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=143918&exp
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=3976 episodeId=143918 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:17.718652 session=startup-preload startup preload start item=single:3976:143918 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=143918&expires=1787931857&verify=346ae55362cab324dde10e4337927ca18f34b2ba43541cb456291e707f6af122 dramaId=3976 episodeId=143918
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:3976:143918 elapsedMs=0 dramaId=3976 episodeId=143918
//I/flutter (11095): 2026-08-28T20:24:17.719330 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=143918
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302813682, downTime=302813682, phoneEventTime=1787919857769 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302813748, downTime=302813682, phoneEventTime=1787919857835 } moveCount:6
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302814013, downTime=302814013, phoneEventTime=1787919858099 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): 2026-08-28T20:24:18.177349 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000023107/701403702/701403702.1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302814086, downTime=302814013, phoneEventTime=1787919858172 } moveCount:3
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 4, tab_id: 27, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 27, name: selected, flag: selected, sort: 5, status: 1, page: 4, page_size: 20, drama_total: 1000, dramas: [{id: 3651, sort: 61, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000009462/42000009462_en_cover.jpg, title: When Lies Speak Again (DUBBED), summary: Framed by his adopted brother Shawn Warner, who uses his mind-reading ability to manipulate others, Howard Warner loses all connections and his reputation, ultimately falling victim to betrayal by his own family. Reborn and hardened, Howard no longer desires familial affection. Cutting all ties, he takes the first step toward revenge without hesitation. The moment he hears Shawn's familiar voice trying to slander and manipulate him once more, he knows it's time to act., play_count: 2952, favorite_count: 266, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status:
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302815143, downTime=302815143, phoneEventTime=1787919859230 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_3RLh9xkTtTogYO7zwcxg0QvI",
//I/flutter (11095):     "event_time": 1787919859285,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11640",
//I/flutter (11095):     "position": 57,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302815231, downTime=302815143, phoneEventTime=1787919859318 } moveCount:8
//I/flutter (11095): [player-entry-preload] candidate dramaId=3651 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=3651 trigger=home_visible_candidate previousDramaId=3976
//I/flutter (11095): 2026-08-28T20:24:19.336007 session=startup-preload startup preload retained item=single:3976:143918 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=143918&expires=1787931857&verify=346ae55362cab324dde10e4337927ca18f34b2ba43541cb456291e707f6af122 dramaId=3976 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:3976:143918 elapsedMs=0 dramaId=3976 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:19.336379 session=startup-preload startup preload request item=3651 sourceLabel=none dramaId=3651
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=3651 elapsedMs=0 dramaId=3651
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_WKEOPeCZnHo2d3Hzs8jk4e3n",
//I/flutter (11095):     "event_time": 1787919859334,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3610",
//I/flutter (11095):     "position": 58,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 3651}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_N9EwebboHddBX_7eE1oK_cnO",
//I/flutter (11095):     "event_time": 1787919859413,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4047",
//I/flutter (11095):     "position": 59,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302815532, downTime=302815532, phoneEventTime=1787919859619 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302815606, downTime=302815532, phoneEventTime=1787919859693 } moveCount:4
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 3651, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000009462/42000009462_en_cover.jpg, title: When Lies Speak Again (DUBBED), summary: Framed by his adopted brother Shawn Warner, who uses his mind-reading ability to manipulate others, Howard Warner loses all connections and his reputation, ultimately falling victim to betrayal by his own family. Reborn and hardened, Howard no longer desires familial affection. Cutting all ties, he takes the first step toward revenge without hesitation. The moment he hears Shawn's familiar voice trying to slander and manipulate him once more, he knows it's time to act., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2952, favorite_count: 266, episode_total: 88, episodes: [{id: 123477, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdf
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=3651 episodeId=123477 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:19.791716 session=startup-preload startup preload start item=single:3651:123477 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=123477&expires=1787931859&verify=1aba7cf741d4d5e876a7c319cd3e421f0c6a8ca8bca8c944bb8bfa1ed2e6266e dramaId=3651 episodeId=123477
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:3651:123477 elapsedMs=0 dramaId=3651 episodeId=123477
//I/flutter (11095): 2026-08-28T20:24:19.792344 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=123477
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302815864, downTime=302815864, phoneEventTime=1787919859951 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302815930, downTime=302815864, phoneEventTime=1787919860017 } moveCount:5
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302816209, downTime=302816209, phoneEventTime=1787919860296 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): 2026-08-28T20:24:20.348856 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000009462/700607239/700607239.1080p_000.ts?
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 5, tab_id: 27, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302816283, downTime=302816209, phoneEventTime=1787919860370 } moveCount:3
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 27, name: selected, flag: selected, sort: 5, status: 1, page: 5, page_size: 20, drama_total: 1000, dramas: [{id: 4117, sort: 81, cover_url: https://cdn.nq1st.cc/test-cover/drama-4117/4117.jpg, title: The Bride They Feared, The Queen They Crowned, summary: Bella Elmer's half-sister, Lisa Elmer, steals her wedding gift and marriage. Her fiancé wants to take Lisa as his main wife and Bella as his concubine. To change her fate, Bella volunteers to marry the 80-year-old King of Bexar. On her wedding night, she defends herself with a knife, only to realize that the bridegroom is Marcus Keagan, the god of war. From then on, Princess Bella and Prince Marcus join hands to quash their enemies and rule over their dominion., play_count: 2914, favorite_count: 204, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 66, is_favorite
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=11866 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=11866 trigger=home_visible_candidate previousDramaId=3651
//I/flutter (11095): 2026-08-28T20:24:20.949351 session=startup-preload startup preload retained item=single:3651:123477 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=123477&expires=1787931859&verify=1aba7cf741d4d5e876a7c319cd3e421f0c6a8ca8bca8c944bb8bfa1ed2e6266e dramaId=3651 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:3651:123477 elapsedMs=0 dramaId=3651 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:20.949791 session=startup-preload startup preload request item=11866 sourceLabel=none dramaId=11866
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=11866 elapsedMs=0 dramaId=11866
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 11866}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_Kssby31WmjjwotIHx4q_oDGt",
//I/flutter (11095):     "event_time": 1787919861104,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12051",
//I/flutter (11095):     "position": 77,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302817030, downTime=302817030, phoneEventTime=1787919861117 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [player-entry-preload] candidate dramaId=4117 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4117 trigger=home_visible_candidate previousDramaId=11866
//I/flutter (11095): 2026-08-28T20:24:21.147289 session=startup-preload startup preload retained item=single:3651:123477 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=123477&expires=1787931859&verify=1aba7cf741d4d5e876a7c319cd3e421f0c6a8ca8bca8c944bb8bfa1ed2e6266e dramaId=3651 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:3651:123477 elapsedMs=0 dramaId=3651 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:21.147684 session=startup-preload startup preload request item=4117 sourceLabel=none dramaId=4117
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4117 elapsedMs=0 dramaId=4117
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_hwLyzJEYi4WVFYzIxRMk3Qx9",
//I/flutter (11095):     "event_time": 1787919861149,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11866",
//I/flutter (11095):     "position": 78,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4117}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 11866, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000018787/42000018787_en_cover.jpg, title: My Tavern, My Fortune, My Empire (DUBBED), summary: Calvin Sawyer, a diner owner and history enthusiast from the 21st century, suddenly transmigrates into another world as the long-lost eldest son of the Sawyer family. After being reunited with his family, he faces constant scorn from his relatives, especially his jealous half-brother, who eventually drives him out of the household. Refusing to give up, Calvin opens a tavern of his own and unexpectedly befriends Empress Xena Layton, who is traveling incognito., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2919, favorite_count: 234, episode_total: 75, episodes: [{id: 615217, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2
//I/flutter (11095): [ApiClient] ==============================
//I/MiInputConsumer(11095): optimized resample latency: 11020323 ns
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302817118, downTime=302817030, phoneEventTime=1787919861205 } moveCount:6
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_iGgW6m6RyVi1T4DBSpg2sii8",
//I/flutter (11095):     "event_time": 1787919861250,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11675",
//I/flutter (11095):     "position": 79,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_Sa74WTC5xVbXDzIfDluXCFKU",
//I/flutter (11095):     "event_time": 1787919861282,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12050",
//I/flutter (11095):     "position": 80,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4117, cover_url: https://cdn.nq1st.cc/test-cover/drama-4117/4117.jpg, title: The Bride They Feared, The Queen They Crowned, summary: Bella Elmer's half-sister, Lisa Elmer, steals her wedding gift and marriage. Her fiancé wants to take Lisa as his main wife and Bella as his concubine. To change her fate, Bella volunteers to marry the 80-year-old King of Bexar. On her wedding night, she defends herself with a knife, only to realize that the bridegroom is Marcus Keagan, the god of war. From then on, Princess Bella and Prince Marcus join hands to quash their enemies and rule over their dominion., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2914, favorite_count: 204, episode_total: 66, episodes: [{id: 153097, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=4117 episodeId=153097 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:21.468154 session=startup-preload startup preload start item=single:4117:153097 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=153097&expires=1787931861&verify=64a227c62376fec6b5cfbc93c85b4bcb9c9ddfdad918d3c1f27b9562b33a3f5d dramaId=4117 episodeId=153097
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:4117:153097 elapsedMs=0 dramaId=4117 episodeId=153097
//I/flutter (11095): 2026-08-28T20:24:21.468813 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=153097
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302817391, downTime=302817391, phoneEventTime=1787919861478 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_rb6Z3FwcdAxLeN_6IvZw8OTo",
//I/flutter (11095):     "event_time": 1787919861714,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4117",
//I/flutter (11095):     "position": 81,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_Eid7hg7CZRpkzV6epKLJ-4VF",
//I/flutter (11095):     "event_time": 1787919861715,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4004",
//I/flutter (11095):     "position": 82,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302817464, downTime=302817391, phoneEventTime=1787919861551 } moveCount:3
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302817714, downTime=302817714, phoneEventTime=1787919861801 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302817773, downTime=302817714, phoneEventTime=1787919861859 } moveCount:3
//I/flutter (11095): 2026-08-28T20:24:21.869894 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000003828/700237737/700237737.1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302818045, downTime=302818045, phoneEventTime=1787919862132 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302818112, downTime=302818045, phoneEventTime=1787919862199 } moveCount:4
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302818384, downTime=302818384, phoneEventTime=1787919862471 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302818457, downTime=302818384, phoneEventTime=1787919862544 } moveCount:3
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 6, tab_id: 27, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=3729 visiblePercent=83
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=3729 trigger=home_visible_candidate previousDramaId=4117
//I/flutter (11095): 2026-08-28T20:24:22.927775 session=startup-preload startup preload retained item=single:4117:153097 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=153097&expires=1787931861&verify=64a227c62376fec6b5cfbc93c85b4bcb9c9ddfdad918d3c1f27b9562b33a3f5d dramaId=4117 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:4117:153097 elapsedMs=0 dramaId=4117 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:22.928035 session=startup-preload startup preload request item=3729 sourceLabel=none dramaId=3729
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=3729 elapsedMs=0 dramaId=3729
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 3729}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302818913, downTime=302818913, phoneEventTime=1787919863000 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302818965, downTime=302818913, phoneEventTime=1787919863052 } moveCount:2
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 27, name: selected, flag: selected, sort: 5, status: 1, page: 6, page_size: 20, drama_total: 1000, dramas: [{id: 12152, sort: 101, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000020570/42000020570_en_cover.jpg, title: Zombie Evolution: Rise of the Undead, summary: After his girlfriend turns against him, Victor Graves is betrayed by his best friend and thrown into a horde of zombies. Instead of dying, he awakens a Zombie Evolution System. Starting as the weakest undead, he evolves by devouring stronger zombies, growing more powerful with every kill. Along the way, he gains a loyal ally, Vera Vale, and joins forces with Emma Wells to build a thriving survivor stronghold., play_count: 2877, favorite_count: 173, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 70, is_favorited: 0, watch_prog
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_OIeJvWdcXct3aVDbyv4T-GPV",
//I/flutter (11095):     "event_time": 1787919863483,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3729",
//I/flutter (11095):     "position": 97,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_cvFZzizuT74PaMW2mVP4lBJF",
//I/flutter (11095):     "event_time": 1787919863531,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11654",
//I/flutter (11095):     "position": 98,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [player-entry-preload] candidate dramaId=12152 visiblePercent=84
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=12152 trigger=home_visible_candidate previousDramaId=3729
//I/flutter (11095): 2026-08-28T20:24:23.657825 session=startup-preload startup preload retained item=single:4117:153097 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=153097&expires=1787931861&verify=64a227c62376fec6b5cfbc93c85b4bcb9c9ddfdad918d3c1f27b9562b33a3f5d dramaId=4117 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:4117:153097 elapsedMs=0 dramaId=4117 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:23.658265 session=startup-preload startup preload request item=12152 sourceLabel=none dramaId=12152
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=12152 elapsedMs=0 dramaId=12152
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 12152}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_z8aZ6vZvCzVqZuRvoJhBJeg5",
//I/flutter (11095):     "event_time": 1787919863716,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11764",
//I/flutter (11095):     "position": 100,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302819634, downTime=302819634, phoneEventTime=1787919863721 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_D9kyJ5tRPO85Q65md5el3Jnc",
//I/flutter (11095):     "event_time": 1787919863752,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11635",
//I/flutter (11095):     "position": 99,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 3729, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000009874/42000009874_en_cover.jpg, title: How to Survive When Your Beast Mates Want You Dead(DUBBED), summary: Aurora Fowler transmigrates to a beastman world and becomes a 300-pound villainess, hated by her S-rank beast mates—especially a snake who even went so far as to push her off a cliff. However, she gains an affection system that allows her to earn useful rewards to improve herself. Over time, her mates gradually shift from utter disgust to devoted affection. But one day, her snake beast mate, who once tried to kill her, corners her..., category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2882, favorite_count: 202, episode_total: 75, episodes: [{id: 128332, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302819730, downTime=302819634, phoneEventTime=1787919863816 } moveCount:4
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 12152, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000020570/42000020570_en_cover.jpg, title: Zombie Evolution: Rise of the Undead, summary: After his girlfriend turns against him, Victor Graves is betrayed by his best friend and thrown into a horde of zombies. Instead of dying, he awakens a Zombie Evolution System. Starting as the weakest undead, he evolves by devouring stronger zombies, growing more powerful with every kill. Along the way, he gains a loyal ally, Vera Vale, and joins forces with Emma Wells to build a thriving survivor stronghold., category_ids: [564], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2877, favorite_count: 173, episode_total: 70, episodes: [{id: 633733, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633733&expire
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=12152 episodeId=633733 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:23.913644 session=startup-preload startup preload start item=single:12152:633733 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633733&expires=1787931863&verify=bc7651e9492e4c7da5e0a47e0ed1849bc112263eb3a8bcdea0ca655b4aced54f dramaId=12152 episodeId=633733
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:12152:633733 elapsedMs=0 dramaId=12152 episodeId=633733
//I/flutter (11095): 2026-08-28T20:24:23.914261 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633733
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302820024, downTime=302820024, phoneEventTime=1787919864110 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302820112, downTime=302820024, phoneEventTime=1787919864199 } moveCount:4
//I/flutter (11095): 2026-08-28T20:24:24.315375 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000020570/701268560/1080/1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302820362, downTime=302820362, phoneEventTime=1787919864449 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302820436, downTime=302820362, phoneEventTime=1787919864523 } moveCount:1
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302820701, downTime=302820701, phoneEventTime=1787919864788 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302820752, downTime=302820701, phoneEventTime=1787919864839 } moveCount:3
//I/flutter (11095): [player-entry-preload] candidate dramaId=4017 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4017 trigger=home_visible_candidate previousDramaId=12152
//I/flutter (11095): 2026-08-28T20:24:24.959466 session=startup-preload startup preload retained item=single:12152:633733 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=633733&expires=1787931863&verify=bc7651e9492e4c7da5e0a47e0ed1849bc112263eb3a8bcdea0ca655b4aced54f dramaId=12152 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:12152:633733 elapsedMs=0 dramaId=12152 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:24.959809 session=startup-preload startup preload request item=4017 sourceLabel=none dramaId=4017
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4017 elapsedMs=0 dramaId=4017
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4017}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4017, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/41000122897/41000122897_en_cover.jpg, title: Anything, and Everything to Win Her Back, summary: For the sake of her family, Yelena Summers weds Landon Palmer—the man she's loved for years. But what begins as a dream turns into a cage of desire and mistrust. Misunderstandings tear them apart, ending in a divorce. Only when she's gone does Landon realize his true feelings—and this time, he's willing to fight the world to win her back., category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2863, favorite_count: 200, episode_total: 80, episodes: [{id: 146468, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=146468&expires=1787931865&verify=b276a97b36ccbe20fe026bd068f37fa003dfcf2dfea042de
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=4017 episodeId=146468 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:25.147134 session=startup-preload startup preload start item=single:4017:146468 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=146468&expires=1787931865&verify=b276a97b36ccbe20fe026bd068f37fa003dfcf2dfea042de26e12fb6263bd6ee dramaId=4017 episodeId=146468
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:4017:146468 elapsedMs=0 dramaId=4017 episodeId=146468
//I/flutter (11095): 2026-08-28T20:24:25.147883 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=146468
//I/flutter (11095): [player-entry-preload] candidate dramaId=4007 visiblePercent=85
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4007 trigger=home_visible_candidate previousDramaId=4017
//I/flutter (11095): 2026-08-28T20:24:25.237166 session=startup-preload startup preload retained item=single:4017:146468 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=146468&expires=1787931865&verify=b276a97b36ccbe20fe026bd068f37fa003dfcf2dfea042de26e12fb6263bd6ee dramaId=4017 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:4017:146468 elapsedMs=0 dramaId=4017 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:25.237548 session=startup-preload startup preload request item=4007 sourceLabel=none dramaId=4007
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4007 elapsedMs=0 dramaId=4007
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4007}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4007, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000008179/42000008179_en_cover.jpg, title: I Survived Death, Now I Hunt the Apocalypse (DUBBED), summary: A university student, Elio Conway, transmigrates to a world where people can summon Eidolons. The one who summoned him promptly breaks their pact, leaving him to die without a care. On the brink of death, Elio awakens the Predation Evolution System, which allows him to evolve into increasingly powerful forms. When an apocalyptic wave of monsters arrives, Elio stands with humanity to defend it., category_ids: [564], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2860, favorite_count: 257, episode_total: 95, episodes: [{id: 145857, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=145857&expires=17
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=4007 episodeId=145857 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:25.412053 session=startup-preload startup preload start item=single:4007:145857 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=145857&expires=1787931865&verify=fb07bedb92920ce9c7c74b19d9f55e49851c565712561cb89bd966cc58df55f9 dramaId=4007 episodeId=145857
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:4007:145857 elapsedMs=0 dramaId=4007 episodeId=145857
//I/flutter (11095): 2026-08-28T20:24:25.412723 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=145857
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 7, tab_id: 27, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302821831, downTime=302821831, phoneEventTime=1787919865918 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 27, name: selected, flag: selected, sort: 5, status: 1, page: 7, page_size: 20, drama_total: 1000, dramas: [{id: 11982, sort: 121, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000008176/42000008176_en_cover.jpg, title: Trapped in Your Senses, Stuck on You, summary: Ordinary office worker Felix Kirk accidentally saves the CEO, Ellie Rowe. After that incident, the two somehow swap senses, leading to bizarre situations in their daily lives. At first, life goes on as usual. But one day, Ellie locks Felix in her office and grabs his tie, forcing him to look into her eyes, determined to uncover the truth behind their strange connection., play_count: 2849, favorite_count: 228, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 60, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episod
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_0zCX4t_yTChUJZj-dMP8_4TY",
//I/flutter (11095):     "event_time": 1787919866110,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3656",
//I/flutter (11095):     "position": 117,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): 2026-08-28T20:24:26.138251 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000008179/700523692/700523692.1080p_000.ts?
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_IebOKYKaE5gO_viws5jD7c31",
//I/flutter (11095):     "event_time": 1787919866150,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11970",
//I/flutter (11095):     "position": 118,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_QqxTJ1yXnDYZ1SbnKgiIax1x",
//I/flutter (11095):     "event_time": 1787919866244,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11732",
//I/flutter (11095):     "position": 119,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919866259, Track-Sign: 1a3c3aab1f4066583629c4e7e47a6740a220027b1c1c13a7786f35419de855d0, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_pfjFTQC4PlS612fnHOONsu_P","eventTime":1787919857050,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"3587\",\"position\":37,\"category_id\":\"27\"}"},{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_JmwVxNZY90z7dwikwtqo7LVw","eventTime":1787919857051,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"11805\",\"position\":38,\"category_id\":\"27\"}"},{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302822228, downTime=302821831, phoneEventTime=1787919866315 } moveCount:24
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_NTSsOiN4bYjHAyGaRC3I6iyx",
//I/flutter (11095):     "event_time": 1787919866319,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 21562
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/entitlements will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/entitlements
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=11970 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=11970 trigger=home_visible_candidate previousDramaId=4007
//I/flutter (11095): 2026-08-28T20:24:26.358092 session=startup-preload startup preload retained item=single:4007:145857 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=145857&expires=1787931865&verify=fb07bedb92920ce9c7c74b19d9f55e49851c565712561cb89bd966cc58df55f9 dramaId=4007 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:4007:145857 elapsedMs=0 dramaId=4007 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:26.358457 session=startup-preload startup preload request item=11970 sourceLabel=none dramaId=11970
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=11970 elapsedMs=0 dramaId=11970
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 11970}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=11982 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=11982 trigger=home_visible_candidate previousDramaId=11970
//I/flutter (11095): 2026-08-28T20:24:26.436881 session=startup-preload startup preload retained item=single:4007:145857 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=145857&expires=1787931865&verify=fb07bedb92920ce9c7c74b19d9f55e49851c565712561cb89bd966cc58df55f9 dramaId=4007 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:4007:145857 elapsedMs=0 dramaId=4007 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:26.437178 session=startup-preload startup preload request item=11982 sourceLabel=none dramaId=11982
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=11982 elapsedMs=0 dramaId=11982
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 11982}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919866476, Track-Sign: f6af05df89a078c4870a8e68fb19cc8ae9f564b3e6b1d2208e03408d4a0bedbf, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"page_leave","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_NTSsOiN4bYjHAyGaRC3I6iyx","eventTime":1787919866319,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"stay_duration_ms\":21562}"}]}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_f6UiQsVE4iewz2rqlUgidT3E",
//I/flutter (11095):     "event_time": 1787919866491,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3576",
//I/flutter (11095):     "position": 120,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {membership: {isMember: false, membershipExpiresAt: }, playback: {autoUnlockEnabled: true, pendingOperationId: , unlockedEpisodeNos: []}, point: {totalPointBalance: 0}, userInfo: {avatar: , isGuest: true, language: en, nickname: 游客4163, showId: 509484163, status: 1, userId: 2093224561016311808}, wallet: {bonusBalance: 0, coinBalance: 0}}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919866681, Track-Sign: e3191a8c820df4939ac14b83d8fee6f43c2bd67a392101740a732abc52042ac8, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_f6UiQsVE4iewz2rqlUgidT3E","eventTime":1787919866491,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"3576\",\"position\":120,\"category_id\":\"27\"}"}]}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_4HIHKGMKsAHy5Bx3juil6YpF",
//I/flutter (11095):     "event_time": 1787919866872,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302822826, downTime=302822826, phoneEventTime=1787919866913 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 11982, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000008176/42000008176_en_cover.jpg, title: Trapped in Your Senses, Stuck on You, summary: Ordinary office worker Felix Kirk accidentally saves the CEO, Ellie Rowe. After that incident, the two somehow swap senses, leading to bizarre situations in their daily lives. At first, life goes on as usual. But one day, Ellie locks Felix in her office and grabs his tie, forcing him to look into her eyes, determined to uncover the truth behind their strange connection., category_ids: [563], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2849, favorite_count: 228, episode_total: 60, episodes: [{id: 622664, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=622664&expires=1787931866&verify=ff6fe2585f02276d093a
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=11982 episodeId=622664 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:26.979752 session=startup-preload startup preload start item=single:11982:622664 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=622664&expires=1787931866&verify=ff6fe2585f02276d093a11c7dc8c6c77a3a82b2ef98f7c495631a3dda8c41b98 dramaId=11982 episodeId=622664
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:11982:622664 elapsedMs=0 dramaId=11982 episodeId=622664
//I/flutter (11095): 2026-08-28T20:24:26.980396 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=622664
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 11970, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000010542/42000010542_en_cover.jpg, title: He Killed Our Love, I Claimed Dominion, summary: Three years after Luna Vale saves Joel Shaw and contracts the Frost Poison, he returns—only to dote on a mortal woman, Lily Marsh, who stole her credit. Betrayed and humiliated, Luna cuts ties, destroys their bond, and turns to Oblivion Art. She rises along the path of cultivation, while he is left to drown in devastating regret after uncovering the truth., category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2853, favorite_count: 228, episode_total: 50, episodes: [{id: 621861, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=621861&expires=1787931866&verify=49cf828c10fd29cbea791d30003dfe
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_VBlIPXNOjm9U3cGNi5_n7iEt",
//I/flutter (11095):     "event_time": 1787919867000,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11982",
//I/flutter (11095):     "position": 121,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_qaZTRnBWErryaRJBrad2gm_g",
//I/flutter (11095):     "event_time": 1787919867000,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "4056",
//I/flutter (11095):     "position": 122,
//I/flutter (11095):     "category_id": "27"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302822935, downTime=302822826, phoneEventTime=1787919867022 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_MI9WW7PjohIoQjA-h4-Taglz",
//I/flutter (11095):     "event_time": 1787919867053,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 180
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/language/global will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/language/global
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_v4_DKJvJ3_ysg9Hm_2GZDV2_",
//I/flutter (11095):     "event_time": 1787919867069,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {English: en, língua: pt, 简体中文: zh, 繁體中文: zh-Hant}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:24:27.287075 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000008176/700519912/1080/1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302823641, downTime=302823641, phoneEventTime=1787919867728 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302823729, downTime=302823641, phoneEventTime=1787919867816 } moveCount:0
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302824120, downTime=302824120, phoneEventTime=1787919868207 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302824193, downTime=302824120, phoneEventTime=1787919868280 } moveCount:0
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: zh}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: zh, language_name: 简体中文, version: 1787624036, content_url: /api/i18n/zh.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [I18n] Remote strings updated, 556 keys loaded
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: en}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/search/hot will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/search/hot
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_SQdpHX_sYYZHS2Ppm3xBa1lM",
//I/flutter (11095):     "event_time": 1787919868591,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 1521
//I/flutter (11095):   }
//I/flutter (11095): }
//W/WindowOnBackDispatcher(11095): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@755779e
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_99qMdM3i6vPUbLoeOqDv9bUx",
//I/flutter (11095):     "event_time": 1787919868604,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/active/report will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/active/report
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body: {channelSource: tiktok, region: CN, timezone: Asia/Shanghai, pushToken: fHCP0Xz6RlyGVEgjh06dpw:APA91bFRoTe1JQeu_kCYFfmQpclDQAiZQq1ijbNkd4CP4b5ZvbCTtGxOUjUYb77hctF8CTStfDvCjHIz1eEi8FH9bJK5aGVBax9zzzXlFMJSHG7xIVJZWNM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: en, language_name: 英文, version: 1787624036, content_url: /api/i18n/en.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [I18n] Remote strings updated, 563 keys loaded
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: 热门, flag: hot, sort: 1, status: 1, page: 1, page_size: 20, drama_total: 4, dramas: [{id: 1513, sort: 1, cover_url: https://cdn.pixabay.com/photo/2017/10/07/16/22/river-2826927_1280.jpg, title: 通用视频_1513, summary: , play_count: 9700, favorite_count: 680, trailer_episode_num: 1, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 998, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, duration_second: 0}}, {id: 825, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260819/f61eacfb9882035086908ef7e31517d3.jpg, title: 山间采药客_825, summary: 【开始】采药人踏遍群山，采撷百草，以草木本源滋养传统养生之道，这是流淌在华夏土地上绵延千年的生活图景，也是中医药文化最朴素、最鲜活的传承载体。�
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {limit: 10, dramas: [{id: 822, sort: 1, cover_url: https://cdn.nq1st.cc/image/poster/20260821/f644ccee4c4f6424287e06f1b8b623ff.jpg, title: 趣味桌游设计师_822, summary: 设计师创作有趣的桌游，丰富人们的闲暇时光。, tags_name: [年代剧, 甜宠, 电影, 职场, 读心术], search_count: 1250000, hot_value: 1297941, trailer_episode_num: 10, is_vip_only: 1, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, watch_progress: {watch_episode_id: 8575, watch_episode_no: 1, watch_second: 3, progress_percent: 1, duration_second: 171}, is_favorited: 0}, {id: 1508, sort: 2, cover_url: https://cdn.pixabay.com/photo/2015/08/15/11/09/aster-889447_1280.jpg, title: 视频模板勿删 _1508, summary: 标准测试视频模板，请勿删除，用于播放器、字幕相关功能验收测试, tags_name: [追妻火葬场], search_count: 9999, hot_value: 52686, trailer_episode_num: 100, is_vip_only: 0, trial: {trial_ena
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:24:28.975135 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000008176/700519912/1080/1080p_001.ts?
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: 成功}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302825244, downTime=302825244, phoneEventTime=1787919869331 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302825288, downTime=302825244, phoneEventTime=1787919869375 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_cqi9nKJbjql_FnzrkUy3I-w_",
//I/flutter (11095):     "event_time": 1787919869383,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 778
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_VMCgG_UZkWyeVup8w81wZR8l",
//I/flutter (11095):     "event_time": 1787919869454,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302826102, downTime=302826102, phoneEventTime=1787919870189 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302826190, downTime=302826102, phoneEventTime=1787919870277 } moveCount:10
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "home_banner_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_Xg6_aZd6Mqcg2paeVq1fRION",
//I/flutter (11095):     "event_time": 1787919870577,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "banner_id": "home_banner_002",
//I/flutter (11095):     "banner_target_type": "drama",
//I/flutter (11095):     "target_drama_id": "4153"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302827111, downTime=302827111, phoneEventTime=1787919871198 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302827183, downTime=302827111, phoneEventTime=1787919871270 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "element_click",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_F2dPXuf6E1YacfxDUCj7sKSz",
//I/flutter (11095):     "event_time": 1787919871278,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "element_name": "home_category_tab",
//I/flutter (11095):     "category_id": "42",
//I/flutter (11095):     "position": 7
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "home_banner_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_fVhdmy3P8lPVMRNr_dsSyRlw",
//I/flutter (11095):     "event_time": 1787919871992,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "banner_id": "home_banner_003",
//I/flutter (11095):     "banner_target_type": "app_page"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302828033, downTime=302828033, phoneEventTime=1787919872120 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302828090, downTime=302828033, phoneEventTime=1787919872177 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_YOMqegmMgCGGE0ZHrRASC1WY",
//I/flutter (11095):     "event_time": 1787919872185,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 2731
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_14RrYy2bCCfLmghgXhGb_8e6",
//I/flutter (11095):     "event_time": 1787919872211,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/entitlements will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/entitlements
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/entitlements
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {membership: {isMember: false, membershipExpiresAt: }, playback: {autoUnlockEnabled: true, pendingOperationId: , unlockedEpisodeNos: []}, point: {totalPointBalance: 0}, userInfo: {avatar: , isGuest: true, language: en, nickname: 游客4163, showId: 509484163, status: 1, userId: 2093224561016311808}, wallet: {bonusBalance: 0, coinBalance: 0}}, message: 成功}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302828645, downTime=302828645, phoneEventTime=1787919872732 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302828711, downTime=302828645, phoneEventTime=1787919872798 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_6_sNxRLVv3qx_dcKLeL0LSCH",
//I/flutter (11095):     "event_time": 1787919872840,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "home_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 629
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/language/global will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/language/global
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_pI_5TK-qKyVTU77EB5xrEhZt",
//I/flutter (11095):     "event_time": 1787919872858,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "zh",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/language/global
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {English: en, língua: pt, 简体中文: zh, 繁體中文: zh-Hant}}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302829356, downTime=302829356, phoneEventTime=1787919873443 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302829429, downTime=302829356, phoneEventTime=1787919873516 } moveCount:0
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302829834, downTime=302829834, phoneEventTime=1787919873921 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302829907, downTime=302829834, phoneEventTime=1787919873994 } moveCount:0
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/i18n/version will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/i18n/version
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: zh, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {language_code: en}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/i18n/version
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {language_code: en, language_name: 英文, version: 1787624036, content_url: /api/i18n/en.json, updated_at: 2026-08-25 02:13:56}}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [I18n] Remote strings updated, 563 keys loaded
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/search/hot will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/search/hot
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/user/active/report will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/user/active/report
//I/flutter (11095): [ApiClient] Headers: {content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body: {channelSource: tiktok, region: CN, timezone: Asia/Shanghai, pushToken: fHCP0Xz6RlyGVEgjh06dpw:APA91bFRoTe1JQeu_kCYFfmQpclDQAiZQq1ijbNkd4CP4b5ZvbCTtGxOUjUYb77hctF8CTStfDvCjHIz1eEi8FH9bJK5aGVBax9zzzXlFMJSHG7xIVJZWNM}
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_3Y_sCYoNY4o-Y-EIszBQkzDe",
//I/flutter (11095):     "event_time": 1787919874308,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "language_settings_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 1450
//I/flutter (11095):   }
//I/flutter (11095): }
//W/WindowOnBackDispatcher(11095): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@755779e
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_HasrGb_FkFv3qQcSf69qQNUc",
//I/flutter (11095):     "event_time": 1787919874328,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/search/hot
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {limit: 10, dramas: [{id: 823, sort: 1, cover_url: https://cdn.pixabay.com/video/2025/05/27/282086_tiny.jpg, title: handmade_vinegar_brewer_823, summary: A brewer makes vinegar with ancient methods and inherits traditional skills., tags_name: [workplace, real_actor_drama, urban, comic, anime], search_count: 8642000, hot_value: 8689968, trailer_episode_num: 11, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, watch_progress: {watch_episode_id: 8604, watch_episode_no: 1, watch_second: 2, progress_percent: 2, duration_second: 78}, is_favorited: 0}, {id: 822, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260821/a647920820ebb6d79e1ad21152c74017.jpg, title: Board Game Designer_822, summary: Designers create interesting board games to enrich people's leisure time., tags_name: [period_drama, sweet_romance, movie, workplace, mind_reading], search_count: 1250000, hot_value: 1297941, trailer_episode_num: 10
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:24:34.913479 session=startup-preload startup preload success item=single:11982:622664 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=622664&expires=1787931866&verify=ff6fe2585f02276d093a11c7dc8c6c77a3a82b2ef98f7c495631a3dda8c41b98 elapsed=7933ms hls master playlist fetch start | hls master playlist fetch end 306ms | hls segment 1 preheat start | hls segment 1 preheat end 1688ms bytes=2029272 | hls segment 2 preheat start | hls segment 2 preheat end 5937ms bytes=1927000 | segment preheat max bytes reached | segment preheat bytes=3956272
//I/flutter (11095): [player-entry-preload] startup=startup preload success itemId=single:11982:622664 elapsedMs=7933 hls master playlist fetch start | hls master playlist fetch end 306ms | hls segment 1 preheat start | hls segment 1 preheat end 1688ms bytes=2029272 | hls segment 2 preheat start | hls segment 2 preheat end 5937ms bytes=1927000 | segment preheat max bytes reached | segment preheat bytes=3956272
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/user/active/report
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302830924, downTime=302830924, phoneEventTime=1787919875010 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302830968, downTime=302830924, phoneEventTime=1787919875055 } moveCount:0
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_leave",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_NAAkDCr5wLEQwiB3zbDhCFsS",
//I/flutter (11095):     "event_time": 1787919875060,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "my_page",
//I/flutter (11095):     "previous_page": "language_settings_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "stay_duration_ms": 732
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "page_view",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_UeMnF6TuFivkiTGbD7bv7OfV",
//I/flutter (11095):     "event_time": 1787919875096,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {}
//I/flutter (11095): }
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919875107, Track-Sign: 5370b3337ccc4db9bb57e26edaa21187f4dc5b67b77c30fc732ba612ddba0564, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"page_view","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_4HIHKGMKsAHy5Bx3juil6YpF","eventTime":1787919866872,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"my_page","platform":"android","previousPage":"home_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":""},{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_VBlIPXNOjm9U3cGNi5_n7iEt","eventTime":1787919867000,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"my_page","platform":"android","previousPage":"home_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"11982\",\"position\":121,\"category_id\":\"27\"}"},{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_qaZTRnBWErryaR
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 26, name: Hot, flag: hot, sort: 1, status: 1, page: 1, page_size: 20, drama_total: 24, dramas: [{id: 1513, sort: 1, cover_url: https://cdn.pixabay.com/photo/2017/10/07/16/22/river-2826927_1280.jpg, title: General Video_1513, summary: , play_count: 9700, favorite_count: 680, trailer_episode_num: 1, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 998, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, duration_second: 0}}, {id: 825, sort: 2, cover_url: https://cdn.nq1st.cc/image/poster/20260819/551b8e747c306a648ecf4c74c2417c1a.jpg, title: mountain_herb_collector_825, summary: 【Start】A herb collector treks through rolling mountains to gather wild plants, drawing nourishment from natural flora to sustain the age-old practice of traditional health preservation—a timeless tradi
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] candidate dramaId=4156 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=4156 trigger=home_visible_candidate previousDramaId=11982
//I/flutter (11095): 2026-08-28T20:24:35.639782 session=startup-preload startup preload retained item=single:11982:622664 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=622664&expires=1787931866&verify=ff6fe2585f02276d093a11c7dc8c6c77a3a82b2ef98f7c495631a3dda8c41b98 dramaId=11982 reason=visible_candidate_replaced status=success retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:11982:622664 elapsedMs=0 dramaId=11982 reason=visible_candidate_replaced status=success retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:35.640831 session=startup-preload startup preload request item=4156 sourceLabel=none dramaId=4156
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=4156 elapsedMs=0 dramaId=4156
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 4156}
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302831641, downTime=302831641, phoneEventTime=1787919875728 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302831706, downTime=302831641, phoneEventTime=1787919875792 } moveCount:6
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 4156, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000010862/42000010862_en_cover.jpg, title: The Shape of Temptation & Surrender, summary: Framed by her stepmother and stepsister, Jane Zimmer loses everything and is cast out by her own father. Years later, she returns, determined to reclaim it all. When she sees her stepsister with her fiancé, Jim Wade, she knows the perfect moment for revenge has finally arrived., category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 6650, favorite_count: 399, episode_total: 82, episodes: [{id: 155846, episode_no: 1, video_name: 700976878.1080p.m3u8, source_url: https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=155846&expires=1787931875&verify=4ccf176bd7ae8a8826c31ef2cee4e5dc87854b72f441ddec3a398e56f9bb65ac, source_type: 1, duration_sec: 0, is_vip_o
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=4156 episodeId=155846 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:36.059991 session=startup-preload startup preload start item=single:4156:155846 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=155846&expires=1787931875&verify=4ccf176bd7ae8a8826c31ef2cee4e5dc87854b72f441ddec3a398e56f9bb65ac dramaId=4156 episodeId=155846
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:4156:155846 elapsedMs=0 dramaId=4156 episodeId=155846
//I/flutter (11095): 2026-08-28T20:24:36.060722 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=155846
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302832008, downTime=302832008, phoneEventTime=1787919876095 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302832059, downTime=302832008, phoneEventTime=1787919876146 } moveCount:4
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302832339, downTime=302832339, phoneEventTime=1787919876426 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302832397, downTime=302832339, phoneEventTime=1787919876484 } moveCount:6
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {page: 2, tab_id: 42, page_size: 20}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:24:36.593425 session=hls-network-singleflight stream start priority=preload key=https://cdn.nq1st.cc/db/m3u8/42000015527/700976878/700976878.1080p_000.ts?
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302832670, downTime=302832670, phoneEventTime=1787919876757 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302832744, downTime=302832670, phoneEventTime=1787919876831 } moveCount:6
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 19, name: tiktok模板, status: 1, tabs: [{id: 42, name: Romance, flag: home.category.romance, sort: 7, status: 1, page: 2, page_size: 20, drama_total: 316, dramas: [{id: 3796, sort: 21, cover_url: https://cdn.nq1st.cc/test-cover/drama-3796/3796.jpg, title: Goodbye, My Dad's Best Friend, summary: Lena falls in love with Elijah, her dad’s best friend, who has always kept her at a distance for some reason. Accidentally carrying his child, Lena plans to leave him for good but their tangled love traps her., play_count: 2875, favorite_count: 173, trailer_episode_num: 10, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, episode_total: 50, is_favorited: 0, watch_progress: {watch_episode_id: 0, watch_episode_no: 1, watch_second: 0, progress_percent: 0, duration_second: 0}}, {id: 3899, sort: 22, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/42000000952/42000000952_en_cover.jpg, title: W
//I/flutter (11095): [ApiClient] ==============================
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302833060, downTime=302833060, phoneEventTime=1787919877147 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302833126, downTime=302833060, phoneEventTime=1787919877212 } moveCount:6
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302833406, downTime=302833406, phoneEventTime=1787919877492 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302833479, downTime=302833406, phoneEventTime=1787919877565 } moveCount:5
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302833729, downTime=302833729, phoneEventTime=1787919877816 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302833795, downTime=302833729, phoneEventTime=1787919877882 } moveCount:8
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302834067, downTime=302834067, phoneEventTime=1787919878153 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302834141, downTime=302834067, phoneEventTime=1787919878228 } moveCount:5
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_j90f8Lc94Eah3_SgOUcsQbmJ",
//I/flutter (11095):     "event_time": 1787919878844,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11648",
//I/flutter (11095):     "position": 37,
//I/flutter (11095):     "category_id": "42"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_mBtImnzAyRjImAAL_I5QD4LX",
//I/flutter (11095):     "event_time": 1787919878868,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "12128",
//I/flutter (11095):     "position": 38,
//I/flutter (11095):     "category_id": "42"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_tGZTJy5fEAcTZ1cpHuVdJnrW",
//I/flutter (11095):     "event_time": 1787919878877,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "11678",
//I/flutter (11095):     "position": 39,
//I/flutter (11095):     "category_id": "42"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): [Analytics] {
//I/flutter (11095):   "event_name": "drama_card_exposure",
//I/flutter (11095):   "common_params": {
//I/flutter (11095):     "event_id": "evt_MehuYOK7qt_eKXgFGxQm8Npp",
//I/flutter (11095):     "event_time": 1787919878881,
//I/flutter (11095):     "platform": "android",
//I/flutter (11095):     "app_version": "1.0.3",
//I/flutter (11095):     "language": "en",
//I/flutter (11095):     "user_id": "2093224561016311808",
//I/flutter (11095):     "channel_id": "tiktok",
//I/flutter (11095):     "merchant_id": "319",
//I/flutter (11095):     "region_code": "CN",
//I/flutter (11095):     "page_name": "home_page",
//I/flutter (11095):     "previous_page": "my_page",
//I/flutter (11095):     "entry_source_type": "",
//I/flutter (11095):     "entry_source_id": "",
//I/flutter (11095):     "h5_visitor_id": ""
//I/flutter (11095):   },
//I/flutter (11095):   "event_params": {
//I/flutter (11095):     "drama_id": "3735",
//I/flutter (11095):     "position": 40,
//I/flutter (11095):     "category_id": "42"
//I/flutter (11095):   }
//I/flutter (11095): }
//I/flutter (11095): 2026-08-28T20:24:39.261650 session=hls-network-singleflight stream start priority=preload key=https://cdn.nq1st.cc/db/m3u8/42000015527/700976878/700976878.1080p_001.ts?
//I/flutter (11095): [player-entry-preload] candidate dramaId=11648 visiblePercent=100
//I/flutter (11095): [player-entry-preload] coordinator=replace candidate dramaId=11648 trigger=home_visible_candidate previousDramaId=4156
//I/flutter (11095): 2026-08-28T20:24:39.559045 session=startup-preload startup preload retained item=single:4156:155846 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=155846&expires=1787931875&verify=4ccf176bd7ae8a8826c31ef2cee4e5dc87854b72f441ddec3a398e56f9bb65ac dramaId=4156 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): [player-entry-preload] startup=startup preload retained itemId=single:4156:155846 elapsedMs=0 dramaId=4156 reason=visible_candidate_replaced status=cancelled retainedCount=3
//I/flutter (11095): 2026-08-28T20:24:39.559642 session=startup-preload startup preload request item=11648 sourceLabel=none dramaId=11648
//I/flutter (11095): [player-entry-preload] startup=startup preload request itemId=11648 elapsedMs=0 dramaId=11648
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/home/detail will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/home/detail
//I/flutter (11095): [ApiClient] Headers: {Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001, Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdXRoX3Byb3ZpZGVyIjoiZGV2aWNlIiwiZGV2aWNlSWQiOiJmYjEwZGI4OTYxZDczMGM4IiwiZXhwIjoxNzg4NTIzMTQ5LCJpYXQiOjE3ODc5MTgzNDksImp0aSI6IjgxYmU4NDE0M2Y1MGIwY2Y2ZTg3MGU4NzMxYzgwMTg1IiwibG9naW5fbW9kZSI6ImRldmljZSIsInNob3dJZCI6IjUwOTQ4NDE2MyIsInNob3dfaWQiOiI1MDk0ODQxNjMiLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoyMDkzMjI0NTYxMDE2MzExODA4LCJ1c2VyX2lkIjoyMDkzMjI0NTYxMDE2MzExODA4fQ.nD92uIDR8JB8wNYiyN_TA7QDSg6reJzWSYKlseLbBMM}
//I/flutter (11095): [ApiClient] Body queryParameters: {id: 11648}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: GET https://gateway-api.8y4w2vxvdffmd83.xyz/api/home/detail
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, message: success, data: {id: 11648, cover_url: https://prod-holy-base-4042.h1h9-dreambox.workers.dev/cover/42000015264/42000015264_en_cover.jpg, title: No Escape as the Dragon King's Mate, summary: On a rainy Valentine's night, Lydia, a human nurse, saves a bleeding stranger, only to discover he's Soren—the ruthless Dragon King. His ultimatum is brutal: become his fated mate or die. Dragged into a lethal supernatural world, Lydia finds her defiance melting into burning desire as she glimpses the vulnerable heart beneath the tyrant's scales. With the 30-day contract ending, will she claim her freedom, or surrender to the Dragon King forever?, category_ids: [560], trailer_episode_num: 10, price_per_episode: 30, is_vip_only: 0, trial: {trial_enabled: 1, trial_episode_num: 15, trial_duration_sec: 15}, status: 1, play_count: 2797, favorite_count: 168, episode_total: 52, episodes: [{id: 601743, episode_no: 1, video_name: Episode 1, source_url: https://master-api.8y4w2vxvdffmd83.xyz/ap
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [player-entry-preload] selection dramaId=11648 episodeId=601743 reason=first_playable positionMs=0
//I/flutter (11095): 2026-08-28T20:24:39.949088 session=startup-preload startup preload start item=single:11648:601743 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=601743&expires=1787931879&verify=71f3fc78c2495b2b99384a58ab79aee91f8f8776059d398ec25ce38959cd3508 dramaId=11648 episodeId=601743
//I/flutter (11095): [player-entry-preload] startup=startup preload start itemId=single:11648:601743 elapsedMs=0 dramaId=11648 episodeId=601743
//I/flutter (11095): 2026-08-28T20:24:39.949636 session=hls-network-singleflight stream start priority=preload key=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=601743
//I/flutter (11095): 2026-08-28T20:24:40.358364 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000015264/700955250/1080/1080p_000.ts?
//I/flutter (11095): [ApiClient] ⚠️ Device-Id might be invalid: "fb10db8961d730c8". Expected UUID format. Request to /api/analytics/event/batch-upload will proceed but may cause issues.
//I/flutter (11095): [ChannelConfigService] 使用缓存的配置: ChannelConfig(channelFlag: tiktok, merchantId: 319, vestPkgId: 1001)
//I/flutter (11095): [ApiClient] ========== REQUEST ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Base URL: https://gateway-api.8y4w2vxvdffmd83.xyz
//I/flutter (11095): [ApiClient] Path: /api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Headers: {Track-Timestamp: 1787919883890, Track-Sign: de326bf6551e806813911156b2fa85925faf08d8e8f775815a5891be146929a5, content-type: application/json, Device-Id: fb10db8961d730c8, Lang: en, Platform: android, App-Version: 1.0.3, Region-Code: CN, Accept: application/json, Session-Id: sess-eyJhbGciOiJIUzI1, Guest-Id: guest-eyJhbGciOiJIUzI1, Channel-Flag: tiktok, Merchant-Id: 319, Vest-Pkg-Id: 1001}
//I/flutter (11095): [ApiClient] Body: {"events":[{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_j90f8Lc94Eah3_SgOUcsQbmJ","eventTime":1787919878844,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"11648\",\"position\":37,\"category_id\":\"42\"}"},{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tiktok","entrySourceId":"","entrySourceType":"","eventId":"evt_mBtImnzAyRjImAAL_I5QD4LX","eventTime":1787919878868,"h5VisitorId":"","language":"en","merchantId":"319","pageName":"home_page","platform":"android","previousPage":"my_page","regionCode":"CN","userId":"2093224561016311808"},"eventParams":"{\"drama_id\":\"12128\",\"position\":38,\"category_id\":\"42\"}"},{"eventName":"drama_card_exposure","commonParams":{"appVersion":"1.0.3","channelId":"tikto
//I/flutter (11095): [ApiClient] Body queryParameters: {}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): [ApiClient] ========== RESPONSE ==========
//I/flutter (11095): [ApiClient] Full URL: POST https://gateway-api.8y4w2vxvdffmd83.xyz/api/analytics/event/batch-upload
//I/flutter (11095): [ApiClient] Status Code: 200
//I/flutter (11095): [ApiClient] Data: {code: 0, data: {success: true}, message: Success}
//I/flutter (11095): [ApiClient] ==============================
//I/flutter (11095): 2026-08-28T20:24:44.744722 session=hls-network-singleflight stream start priority=preload key=https://prod-holy-base-4042.h1h9-dreambox.workers.dev/db/m3u8/42000015264/700955250/1080/1080p_001.ts?
//I/flutter (11095): 2026-08-28T20:24:47.955644 session=startup-preload startup preload failed item=single:11648:601743 sourceLabel=unknown-hls source=https://master-api.8y4w2vxvdffmd83.xyz/api/video/source?episode_id=601743&expires=1787931879&verify=71f3fc78c2495b2b99384a58ab79aee91f8f8776059d398ec25ce38959cd3508 elapsed=8006ms error=TimeoutException after 0:00:08.000000: HLS preload exceeded its wait budget.
//I/flutter (11095): [player-entry-preload] startup=startup preload failed itemId=single:11648:601743 elapsedMs=8006  error=TimeoutException after 0:00:08.000000: HLS preload exceeded its wait budget.
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=302846589, downTime=302846589, phoneEventTime=1787919890676 } moveCount:0
//D/VRI[MainActivity](11095): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
//I/MIUIInput(11095): [MotionEvent] ViewRootImpl windowName 'com.novashort.shortdrama/com.novashort.shortdrama.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=302846765, downTime=302846589, phoneEventTime=1787919890852 } moveCount:15
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
    implementation("com.adjust.sdk:adjust-android-meta-referrer:5.7.0")
}

flutter {
    source = "../.."
}
