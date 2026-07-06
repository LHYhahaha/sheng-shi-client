import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.yushi.drama/device_uuid",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getDeviceSeed":
          result(UIDevice.current.identifierForVendor?.uuidString)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let systemInfoChannel = FlutterMethodChannel(
        name: "com.yushi.drama/system_info",
        binaryMessenger: controller.binaryMessenger
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
