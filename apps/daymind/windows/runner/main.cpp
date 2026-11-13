#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"
#include "single_instance.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  DayMindSingleInstance single_instance;
  const auto instance_result = single_instance.Acquire();
  if (instance_result == DayMindSingleInstance::Result::existing) {
    DayMindSingleInstance::OpenExisting();
    return EXIT_SUCCESS;
  }
  if (instance_result == DayMindSingleInstance::Result::failed) {
    MessageBoxW(nullptr, L"Kh\u00f4ng m\u1edf \u0111\u01b0\u1ee3c DayMind. H\u00e3y ki\u1ec3m tra quy\u1ec1n t\u00e0i kho\u1ea3n Windows v\u00e0 th\u1eed l\u1ea1i.", L"DayMind SMART", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  // Match the desktop notifier and registry identity before creating windows.
  ::SetCurrentProcessExplicitAppUserModelID(L"dev.daymind.DayMindSMART");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"DayMind SMART", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
