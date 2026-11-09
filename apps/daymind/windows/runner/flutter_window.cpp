#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {
constexpr UINT kTrayCallback = WM_APP + 71;
constexpr UINT kOpenDayMind = 801;
constexpr UINT kQuitDayMind = 802;
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
          {flutter::EncodableValue("iconReady"), flutter::EncodableValue(tray_added_)}};
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
