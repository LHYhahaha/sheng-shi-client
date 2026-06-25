package com.yushi.drama.client

import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yushi.drama/channel_config"
    private val DEVICE_UUID_CHANNEL = "com.yushi.drama/device_uuid"

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
}
