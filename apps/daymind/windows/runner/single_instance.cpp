#include "single_instance.h"
#include <sddl.h>
#include <cwchar>
#include <string>
#include <vector>

DayMindSingleInstance::~DayMindSingleInstance() {
  if (owned_) ReleaseMutex(mutex_);
  if (mutex_) CloseHandle(mutex_);
}

DayMindSingleInstance::Result DayMindSingleInstance::Acquire() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return Result::failed;
  DWORD length = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &length);
  std::vector<BYTE> bytes(length);
  const bool read = length && GetTokenInformation(token, TokenUser, bytes.data(), length, &length);
  CloseHandle(token);
  if (!read) return Result::failed;
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(bytes.data())->User.Sid, &sid)) return Result::failed;
  const std::wstring name = std::wstring(L"Global\\DayMindSMART.") + sid;
  LocalFree(sid);
  SetLastError(ERROR_SUCCESS);
  mutex_ = CreateMutexW(nullptr, TRUE, name.c_str());
  if (!mutex_) return Result::failed;
  if (GetLastError() == ERROR_ALREADY_EXISTS) return Result::existing;
  owned_ = true;
  return Result::primary;
}

namespace {
BOOL CALLBACK OpenDayMind(HWND window, LPARAM parameter) {
  wchar_t klass[128]{}, title[128]{};
  GetClassNameW(window, klass, 128); GetWindowTextW(window, title, 128);
  if (wcscmp(klass, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0 || wcscmp(title, L"DayMind SMART") != 0) return TRUE;
  DWORD pid = 0; GetWindowThreadProcessId(window, &pid);
  AllowSetForegroundWindow(pid);
  PostMessageW(window, WM_COMMAND, 801, 0); // Existing tray Open command.
  *reinterpret_cast<bool*>(parameter) = true;
  return FALSE;
}
}
void DayMindSingleInstance::OpenExisting() {
  // Also cover double-clicks during the first process's early initialization.
  for (int i = 0; i < 100; i++) {
    bool found = false;
    EnumWindows(OpenDayMind, reinterpret_cast<LPARAM>(&found));
    if (found) return;
    Sleep(50);
  }
}
