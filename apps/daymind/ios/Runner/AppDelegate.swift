import Flutter
import UIKit
import Security
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureChannel: FlutterMethodChannel?
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
    secureChannel = FlutterMethodChannel(name: "daymind/secure", binaryMessenger: messenger)
    secureChannel?.setMethodCallHandler(DayMindKeychain.handle)
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

/// OS Keychain only: no UserDefaults/file fallback and no synchronizable items.
final class DayMindKeychain {
  static let service = "dev.daymind.daymindSmart.secure.v1"
  static func validKey(_ key: String) -> Bool {
    if ["session", "installation", "test_probe"].contains(key) { return true }
    return key.range(of: "^(offline\\.(session|installation)|production\\.[a-z][a-z0-9-]{4,28}[a-z0-9]\\.(session|installation))\\z", options: .regularExpression) != nil
  }
  private static func query(_ key: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service, kSecAttrAccount as String: key,
     kSecAttrSynchronizable as String: false]
  }
  static func read(_ key: String) throws -> String? {
    var q = query(key)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data,
      data.count <= 65536, let value = String(data: data, encoding: .utf8) else {
      throw StoreError.unavailable
    }
    return value
  }
  static func write(_ key: String, _ value: String) throws {
    let data = Data(value.utf8)
    guard data.count <= 65536 else { throw StoreError.invalid }
    let attrs: [String: Any] = [kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
    var status = SecItemUpdate(query(key) as CFDictionary, attrs as CFDictionary)
    if status == errSecItemNotFound {
      var q = query(key); attrs.forEach { q[$0.key] = $0.value }
      status = SecItemAdd(q as CFDictionary, nil)
      if status == errSecDuplicateItem {
        status = SecItemUpdate(query(key) as CFDictionary, attrs as CFDictionary)
      }
    }
    guard status == errSecSuccess else { throw StoreError.unavailable }
  }
  static func delete(_ key: String) throws {
    let status = SecItemDelete(query(key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.unavailable }
  }
  enum StoreError: Error { case invalid, unavailable }
  static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard ["read", "write", "delete"].contains(call.method) else {
      result(FlutterMethodNotImplemented); return
    }
    guard let args = call.arguments as? [String: Any],
      let key = args["key"] as? String, validKey(key) else {
      result(FlutterError(code: "invalid_key", message: nil, details: nil)); return
    }
    do {
      switch call.method {
      case "read": result(try read(key))
      case "delete": try delete(key); result(nil)
      case "write":
        guard let value = args["value"] as? String, value.utf8.count <= 65536 else {
          result(FlutterError(code: "invalid_value", message: nil, details: nil)); return
        }
        try write(key, value); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      // Never include key, token, OS error description or session content.
      result(FlutterError(code: "secure_store_unavailable", message: nil, details: nil))
    }
  }
}
