import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerApplicationChannels(with: engineBridge.applicationRegistrar.messenger())
  }

  private func registerApplicationChannels(with messenger: FlutterBinaryMessenger) {
    let channelConfigChannel = FlutterMethodChannel(
      name: "com.yushi.drama/channel_config",
      binaryMessenger: messenger
    )
    channelConfigChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getChannelConfig":
        result([
          "channel_flag": Self.infoValue("CHANNEL_FLAG"),
          "merchant_id": Self.infoValue("MERCHANT_ID"),
          "vest_pkg_id": Self.infoValue("VEST_PKG_ID"),
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let deviceUuidChannel = FlutterMethodChannel(
      name: "com.yushi.drama/device_uuid",
      binaryMessenger: messenger
    )
    deviceUuidChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getDeviceSeed":
        result(UIDevice.current.identifierForVendor?.uuidString)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let systemInfoChannel = FlutterMethodChannel(
      name: "com.yushi.drama/system_info",
      binaryMessenger: messenger
    )
    systemInfoChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getSystemInfo":
        result([
          "region": Locale.current.regionCode ?? "",
          "timezone": TimeZone.current.identifier,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func infoValue(_ key: String) -> String {
    (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
