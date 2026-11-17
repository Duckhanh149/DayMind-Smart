import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var reminderChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    reminderChannel = FlutterMethodChannel(name: "daymind/ios-reminders", binaryMessenger: messenger)
    reminderChannel?.setMethodCallHandler { call, result in
      guard call.method == "openSettings" else { result(FlutterMethodNotImplemented); return }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(code: "settings_unavailable", message: nil, details: nil)); return
      }
      UIApplication.shared.open(url) { opened in
        if opened { result(nil) } else {
          result(FlutterError(code: "settings_unavailable", message: nil, details: nil))
        }
      }
    }
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if let payload = notification.request.content.userInfo["payload"] as? String {
      reminderChannel?.invokeMethod("foreground", arguments: payload)
    }
    // Plugin's present* flags are all false: foreground is an in-app cue only.
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
}
