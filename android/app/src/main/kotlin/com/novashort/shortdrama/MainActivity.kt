package com.novashort.shortdrama

import android.app.Activity
import android.app.Application
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.URI
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yushi.drama/channel_config"
    private val DEVICE_UUID_CHANNEL = "com.yushi.drama/device_uuid"
    private val SYSTEM_PROXY_CHANNEL = "com.yushi.drama/system_proxy"
    private val SYSTEM_INFO_CHANNEL = "com.yushi.drama/system_info"
    private val FACEBOOK_AUTH_RECOVERY_CHANNEL = "com.yushi.drama/facebook_auth_recovery"
    private var facebookActivity: WeakReference<Activity>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: android.os.Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) = Unit

            override fun onActivityResumed(activity: Activity) {
                if (activity.javaClass.name == "com.facebook.FacebookActivity") {
                    facebookActivity = WeakReference(activity)
                }
            }

            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: android.os.Bundle) = Unit

            override fun onActivityDestroyed(activity: Activity) {
                if (facebookActivity?.get() === activity) {
                    facebookActivity = null
                }
            }
        })
    }
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getChannelConfig" -> {
                        result.success(getChannelConfig())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_UUID_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceSeed" -> result.success(getDeviceSeed())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_PROXY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSystemProxy" -> result.success(getSystemProxy())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSystemInfo" -> result.success(getSystemInfo())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACEBOOK_AUTH_RECOVERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "finishFacebookActivity" -> {
                        val activity = facebookActivity?.get()
                        val wasFinished = activity != null && !activity.isFinishing
                        if (wasFinished) {
                            activity?.finish()
                        }
                        result.success(wasFinished)
                    }
                    else -> result.notImplemented()
                }
            }

    }

    private fun getSystemInfo(): Map<String, String> {
        return mapOf(
            "region" to Locale.getDefault().country,
            "timezone" to TimeZone.getDefault().id,
        )
    }

    private fun getChannelConfig(): Map<String, String?> {
        return mapOf(
            "channel_flag" to getStringRes("channel_flag"),
            "merchant_id" to getStringRes("MERCHANT_ID"),
            "vest_pkg_id" to getStringRes("VEST_PKG_ID"),
        )
    }

    private fun getStringRes(name: String): String? {
        return try {
            val resId = resources.getIdentifier(name, "string", packageName)
            if (resId != 0) resources.getString(resId) else null
        } catch (e: Exception) {
            null
        }
    }

    private fun getDeviceSeed(): String? {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        } catch (e: Exception) {
            null
        }
    }

    private fun getSystemProxy(): Map<String, Any>? {
        if (BuildConfig.BUILD_TYPE == "release") {
            return null
        }

        return getProxyFromSystemProperties() ?: getProxyFromProxySelector()
    }

    private fun getProxyFromSystemProperties(): Map<String, Any>? {
        val host = System.getProperty("http.proxyHost")?.trim()
        val port = System.getProperty("http.proxyPort")?.toIntOrNull()
        if (host.isNullOrEmpty() || port == null || port <= 0) {
            return null
        }

        return mapOf(
            "host" to host,
            "port" to port,
            "source" to "system_properties",
            "buildType" to BuildConfig.BUILD_TYPE,
        )
    }

    private fun getProxyFromProxySelector(): Map<String, Any>? {
        return try {
            val proxies = ProxySelector.getDefault()
                ?.select(URI("https://gateway-api.8y4w2vxvdffmd83.xyz"))
                ?: return null
            val proxy = proxies.firstOrNull { it.type() == Proxy.Type.HTTP }
                ?: return null
            val address = proxy.address() as? InetSocketAddress ?: return null
            val host = address.hostString
            val port = address.port
            if (host.isBlank() || port <= 0) {
                return null
            }

            mapOf(
                "host" to host,
                "port" to port,
                "source" to "proxy_selector",
                "buildType" to BuildConfig.BUILD_TYPE,
            )
        } catch (e: Exception) {
            null
        }
    }
}
