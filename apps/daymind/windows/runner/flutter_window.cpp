#include "flutter_window.h"

#include <optional>
#include <roapi.h>
#include <shellapi.h>
#include <winrt/Windows.UI.Notifications.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "secure_store.h"

namespace {
thread_local HRESULT toast_query_error = S_OK;
int ToastPermission() noexcept {
  toast_query_error = S_OK;
  const HRESULT initialized = RoInitialize(RO_INIT_SINGLETHREADED);
  int setting = -1;
  try {
    const auto notifier = winrt::Windows::UI::Notifications::ToastNotificationManager::CreateToastNotifier(L"dev.daymind.DayMindSMART");
    setting = static_cast<int>(notifier.Setting());
  } catch (const winrt::hresult_error& error) {
    toast_query_error = static_cast<HRESULT>(error.code());
  } catch (...) { toast_query_error = E_FAIL; }
  if (SUCCEEDED(initialized)) RoUninitialize();
  return setting;
}
int NotificationState() noexcept {
  QUERY_USER_NOTIFICATION_STATE state = QUNS_NOT_PRESENT;
  return SUCCEEDED(SHQueryUserNotificationState(&state)) ? static_cast<int>(state) : -1;
}
constexpr UINT kTrayCallback = WM_APP + 71;
constexpr UINT kOpenDayMind = 801;
constexpr UINT kQuitDayMind = 802;
constexpr UINT kRecoverCompanion = 803;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  secure_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "daymind/secure",
      &flutter::StandardMethodCodec::GetInstance());
  secure_channel_->SetMethodCallHandler(HandleSecureCall);
  companion_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "daymind/companion",
      &flutter::StandardMethodCodec::GetInstance());
  companion_ = std::make_unique<FloatingCompanionWindow>(GetHandle(),
      [this](const std::string& method, const flutter::EncodableValue& value) {
        if (companion_channel_) companion_channel_->InvokeMethod(method,
            std::make_unique<flutter::EncodableValue>(value));
      });
  companion_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "configure") {
      const auto* value = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
      std::string error;
      if (!value || !companion_->Configure(*value, &error)) {
        companion_->Close();
        result->Error("INVALID_COMPANION", error.empty() ? "A configuration map is required." : error);
      } else result->Success();
    } else if (call.method_name() == "close") {
      companion_->Close(); result->Success();
    } else if (call.method_name() == "recover") {
      companion_->Recover(); result->Success();
    } else if (call.method_name() == "state") {
      result->Success(flutter::EncodableValue(companion_->State()));
    } else result->NotImplemented();
  });
  taskbar_created_ = RegisterWindowMessageW(L"TaskbarCreated");
  lifecycle_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "daymind/window",
      &flutter::StandardMethodCodec::GetInstance());
  lifecycle_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "configure") {
      const bool* enabled = call.arguments() ? std::get_if<bool>(call.arguments()) : nullptr;
      if (!enabled) { result->Error("INVALID_ARGUMENT", "A boolean is required."); return; }
      if (!*enabled && IsWindowVisible(GetHandle()) == FALSE) RestoreFromTray();
      ConfigureTray(*enabled);
      result->Success(flutter::EncodableValue(WindowState()));
    } else if (call.method_name() == "state") {
      result->Success(flutter::EncodableValue(WindowState()));
    } else if (call.method_name() == "hide") {
      if (!tray_added_ || !tray_enabled_) { result->Error("TRAY_UNAVAILABLE", "Tray icon is not available; keeping the window accessible."); return; }
      SendMessageW(GetHandle(), WM_CLOSE, 0, 0);
      result->Success(flutter::EncodableValue(WindowState()));
    } else if (call.method_name() == "show") {
      RestoreFromTray();result->Success(flutter::EncodableValue(WindowState()));
    } else if (call.method_name() == "openNotificationSettings") {
      const auto launched = reinterpret_cast<INT_PTR>(ShellExecuteW(GetHandle(), L"open", L"ms-settings:notifications", nullptr, nullptr, SW_SHOWNORMAL));
      if (launched <= 32) { result->Error("SETTINGS_UNAVAILABLE", "Cannot open notification settings."); }
      else { result->Success(); }
    } else if (call.method_name() == "quit") {
      tray_enabled_ = false;result->Success();PostMessageW(GetHandle(), WM_CLOSE, 0, 0);
    } else { result->NotImplemented(); }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  companion_.reset();
  if (companion_channel_) {
    companion_channel_->SetMethodCallHandler(nullptr);
    companion_channel_ = nullptr;
  }
  if (secure_channel_) {
    secure_channel_->SetMethodCallHandler(nullptr);
    secure_channel_ = nullptr;
  }
  ConfigureTray(false);
  if (lifecycle_channel_) {
    lifecycle_channel_->SetMethodCallHandler(nullptr);
    lifecycle_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

flutter::EncodableMap FlutterWindow::WindowState() {
  return {{flutter::EncodableValue("visible"), flutter::EncodableValue(IsWindowVisible(GetHandle()) != FALSE)},
          {flutter::EncodableValue("trayEnabled"), flutter::EncodableValue(tray_enabled_)},
          {flutter::EncodableValue("iconReady"), flutter::EncodableValue(tray_added_)},
          {flutter::EncodableValue("notificationSetting"), flutter::EncodableValue(ToastPermission())},
          {flutter::EncodableValue("notificationQueryError"), flutter::EncodableValue(static_cast<int64_t>(toast_query_error))},
          {flutter::EncodableValue("notificationState"), flutter::EncodableValue(NotificationState())},
          {flutter::EncodableValue("deliveryAfterExit"), flutter::EncodableValue(false)}};
}

bool FlutterWindow::ConfigureTray(bool enabled) {
  if (!enabled) {
    if (tray_added_) Shell_NotifyIconW(NIM_DELETE, &tray_);
    tray_added_ = false;tray_enabled_ = false;
    return true;
  }
  if (tray_added_) { tray_enabled_ = true;return true; }
  tray_ = {};
  tray_.cbSize = static_cast<DWORD>(sizeof(tray_));tray_.hWnd = GetHandle();tray_.uID = 1;
  tray_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  tray_.uCallbackMessage = kTrayCallback;
  tray_.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(tray_.szTip, L"DayMind SMART");
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &tray_) != FALSE;
  tray_enabled_ = tray_added_;
  if (tray_added_) { tray_.uVersion = NOTIFYICON_VERSION_4;Shell_NotifyIconW(NIM_SETVERSION, &tray_); }
  return tray_added_;
}

void FlutterWindow::RestoreFromTray() {
  ShowWindow(GetHandle(), SW_RESTORE);SetForegroundWindow(GetHandle());
  if (lifecycle_channel_) lifecycle_channel_->InvokeMethod("visibility", std::make_unique<flutter::EncodableValue>(true));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_SHOWWINDOW && lifecycle_channel_) {
    lifecycle_channel_->InvokeMethod("visibility", std::make_unique<flutter::EncodableValue>(wparam != 0));
  }
  if (message == WM_COMMAND && LOWORD(wparam) == kRecoverCompanion) {
    if (companion_) companion_->Recover();
    return 0;
  }
  if (message == WM_COMMAND && (LOWORD(wparam) == kOpenDayMind || LOWORD(wparam) == kQuitDayMind)) {
    if (LOWORD(wparam) == kOpenDayMind) RestoreFromTray();
    else { tray_enabled_ = false;PostMessageW(hwnd, WM_CLOSE, 0, 0); }
    return 0;
  }
  if (message == WM_CLOSE && tray_enabled_ && tray_added_) {
    ShowWindow(hwnd, SW_HIDE);
    if (lifecycle_channel_) lifecycle_channel_->InvokeMethod("visibility", std::make_unique<flutter::EncodableValue>(false));
    return 0;
  }
  if (message == taskbar_created_ && taskbar_created_ != 0 && tray_enabled_) {
    tray_added_ = false;
    if (!ConfigureTray(true)) RestoreFromTray();
    return 0;
  }
  if (message == kTrayCallback) {
    const UINT event = LOWORD(lparam);
    if (event == NIN_SELECT || event == NIN_KEYSELECT || event == WM_LBUTTONDBLCLK) {
      RestoreFromTray();
    } else if (event == WM_CONTEXTMENU || event == WM_RBUTTONUP) {
      POINT point{};GetCursorPos(&point);
      HMENU menu = CreatePopupMenu();
      if (menu) {
        AppendMenuW(menu, MF_STRING, kOpenDayMind, L"M\u1edf DayMind");
        AppendMenuW(menu, MF_STRING, kRecoverCompanion, L"Kh\u00f4i ph\u1ee5c Companion / nh\u1eadn chu\u1ed9t");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, kQuitDayMind, L"Tho\u00e1t h\u1eb3n");
        SetForegroundWindow(hwnd);
        const UINT command = static_cast<UINT>(TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY, point.x, point.y, 0, hwnd, nullptr));
        DestroyMenu(menu);PostMessageW(hwnd, WM_NULL, 0, 0);
        if (command != 0) PostMessageW(hwnd, WM_COMMAND, command, 0);
      }
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
