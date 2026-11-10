// A real Win32/GDI+ fixture using the production window class, with controlled
// notification-state inputs. No Flutter engine or app-channel override exists.
#include "floating_companion.h"
#include <windows.h>
#include <psapi.h>
#include <algorithm>
#include <cstdlib>
#include <cwchar>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <set>
#include <string>

namespace {
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
int64_t Number(const M& map, const char* key) {
  const auto found = map.find(V(key));
  if (found == map.end()) return -1;
  if (const auto* n = std::get_if<int32_t>(&found->second)) return *n;
  if (const auto* n = std::get_if<int64_t>(&found->second)) return *n;
  return -1;
}
bool Flag(const M& map, const char* key) {
  const auto found = map.find(V(key));
  if (found == map.end()) return false;
  const auto* value = std::get_if<bool>(&found->second);
  return value && *value;
}
uint64_t WorkingSet() {
  PROCESS_MEMORY_COUNTERS memory{}; memory.cb = static_cast<DWORD>(sizeof(memory));
  return GetProcessMemoryInfo(GetCurrentProcess(), &memory, memory.cb)
      ? static_cast<uint64_t>(memory.WorkingSetSize) : 0;
}
void Pump(DWORD milliseconds) {
  const ULONGLONG end = GetTickCount64() + milliseconds;
  do {
    MSG msg{};
    while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&msg); DispatchMessageW(&msg);
    }
    if (GetTickCount64() >= end) break;
    MsgWaitForMultipleObjects(0, nullptr, FALSE, 10, QS_ALLINPUT);
  } while (true);
}
bool Until(const std::function<bool()>& predicate) {
  const ULONGLONG end = GetTickCount64() + 6000;
  while (GetTickCount64() < end) {
    Pump(20);
    if (predicate()) return true;
  }
  return false;
}
LRESULT CALLBACK MainProc(HWND w, UINT m, WPARAM p, LPARAM l) {
  return DefWindowProcW(w, m, p, l);
}
int WindowProbe(const std::filesystem::path& executable, bool click) {
  std::wstring command = L"\"" + executable.wstring() + L"\" " +
      std::to_wstring(GetCurrentProcessId()) + L" component" +
      (click ? L" click-through" : L"");
  STARTUPINFOW startup{}; startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  PROCESS_INFORMATION child{};
  if (!CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, TRUE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &child)) return 1;
  const ULONGLONG end = GetTickCount64() + 30000;
  while (WaitForSingleObject(child.hProcess, 0) == WAIT_TIMEOUT && GetTickCount64() < end) Pump(20);
  DWORD code = 1;
  if (WaitForSingleObject(child.hProcess, 0) == WAIT_TIMEOUT) {
    TerminateProcess(child.hProcess, 1); WaitForSingleObject(child.hProcess, 3000);
    std::cerr << "FAIL: native component child probe timed out\n";
  } else GetExitCodeProcess(child.hProcess, &code);
  CloseHandle(child.hThread); CloseHandle(child.hProcess);
  return static_cast<int>(code);
}
struct Parent { DWORD pid; HWND window = nullptr; };
BOOL CALLBACK FindParent(HWND w, LPARAM data) {
  auto* parent = reinterpret_cast<Parent*>(data);
  DWORD pid = 0; GetWindowThreadProcessId(w, &pid);
  wchar_t name[128]{}; GetClassNameW(w, name, 128);
  if (pid == parent->pid && wcscmp(name, L"FLUTTER_RUNNER_WIN32_WINDOW") == 0) parent->window = w;
  return TRUE;
}
}

int wmain(int argc, wchar_t** argv) {
  if (argc != 3) return 2;
  std::ifstream file(std::filesystem::path(argv[1]), std::ios::binary | std::ios::ate);
  if (!file) return 2;
  const auto length = file.tellg();
  if (length <= 0 || length > 8 * 1024 * 1024) return 2;
  std::vector<uint8_t> image(static_cast<size_t>(length));
  file.seekg(0); file.read(reinterpret_cast<char*>(image.data()), static_cast<std::streamsize>(length));
  if (!file) return 2;
  file.close();
  WNDCLASSW wc{}; wc.hInstance = GetModuleHandleW(nullptr); wc.lpfnWndProc = MainProc;
  wc.lpszClassName = L"DayMindCompanionTestMain"; RegisterClassW(&wc);
  HWND main = CreateWindowExW(0, wc.lpszClassName, L"DayMind native test fixture", WS_OVERLAPPEDWINDOW,
      80, 80, 420, 320, nullptr, nullptr, wc.hInstance, nullptr);
  if (!main) return 2;
  ShowWindow(main, SW_SHOW); SetForegroundWindow(main);
  QUERY_USER_NOTIFICATION_STATE notification = QUNS_ACCEPTS_NOTIFICATIONS;
  int checks = 0, failures = 0, moved = 0;
  auto check = [&](bool ok, const char* label) {
    ++checks; if (!ok) { ++failures; std::cerr << "FAIL: " << label << "\n"; }
  };
  const uint64_t rss_before = WorkingSet(); uint64_t rss_peak = rss_before;
  check(rss_before != 0, "native fixture RSS can be measured");
  {
    FloatingCompanionWindow pet(main,
        [&](const std::string& event, const V&) { if (event == "moved") ++moved; },
        [&](QUERY_USER_NOTIFICATION_STATE* state) { *state = notification; return S_OK; });
    flutter::EncodableList frames;
    for (int i = 0; i < 3; i++) frames.emplace_back(M{
        {V("x"),V(i*128)},{V("y"),V(0)},{V("width"),V(128)},{V("height"),V(128)},
        {V("durationMs"),V(i == 0 ? 125 : i == 1 ? 84 : 200)}});
    M config{{V("size"),V(112)},{V("artKey"),V("synthetic-component-atlas")},
        {V("expression"),V("neutral")},{V("frames"),V(frames)},
        {V("sequence"),V(flutter::EncodableList{V(0),V(1),V(2)})},
        {V("loop"),V(true)},{V("image"),V(image)},{V("topmost"),V(false)},
        {V("clickThrough"),V(false)},{V("quiet"),V(false)},{V("lowResource"),V(false)}};
    std::string error;
    check(pet.Configure(config, &error), "bounded fixture atlas configures");
    check(Until([&] { return Flag(pet.State(), "visible"); }), "controlled accepting state is visible");
    check(Number(pet.State(), "atlasWidth") == 2048 && Number(pet.State(), "atlasHeight") == 1024,
        "native GDI+ owns the maximum eight-MiB normalized atlas");
    rss_peak = std::max(rss_peak,WorkingSet());
    wchar_t module[MAX_PATH]{}; GetModuleFileNameW(nullptr, module, MAX_PATH);
    const auto probe = std::filesystem::path(module).parent_path() / L"daymind_companion_window_probe.exe";
    check(WindowProbe(probe, false) == 0, "real drag resize clamp focus and fullscreen component checks");
    check(moved >= 2, "real move and resize events are emitted");
    config[V("clickThrough")] = V(true);
    check(pet.Configure(config, &error), "click-through enables explicitly");
    check(WindowProbe(probe, true) == 0, "real native click-through hit test");
    config[V("clickThrough")] = V(false);
    check(pet.Configure(config, &error), "click-through disables explicitly");
    const auto before = pet.State(); const ULONGLONG start = GetTickCount64();
    std::set<int64_t> observed;
    for (int i = 0; i < 24; i++) { Pump(100); observed.insert(Number(pet.State(), "frame")); }
    const auto after = pet.State();
    const auto renders = Number(after,"renders") - Number(before,"renders");
    check(observed.size() >= 2, "native timer advances distinct frames");
    check(renders >= 2, "real layered-window updates succeed for multiple frames");
    check(renders <= static_cast<int64_t>((GetTickCount64()-start)/84+4), "native cadence stays below twelve updates per second");
    for (const auto state : {QUNS_NOT_PRESENT,QUNS_BUSY,QUNS_RUNNING_D3D_FULL_SCREEN,QUNS_PRESENTATION_MODE,QUNS_QUIET_TIME}) {
      notification = state;
      check(Until([&] { return !Flag(pet.State(), "visible"); }), "notification fixture hides the real window");
      const auto hidden = pet.State();
      Pump(300);
      check(Number(hidden,"surfaceBytes") == 0 && Number(hidden,"renders") == Number(pet.State(),"renders"),
          "blocked state releases DIB and stops rendering");
      notification = QUNS_ACCEPTS_NOTIFICATIONS;
      check(Until([&] { return Flag(pet.State(),"visible"); }), "accepting fixture restores without changing app policy");
    }
    config[V("quiet")] = V(true); check(pet.Configure(config,&error), "quiet config accepted");
    check(!Flag(pet.State(),"visible") && Number(pet.State(),"surfaceBytes") == 0, "app quiet setting hides real fixture");
    config[V("quiet")] = V(false); check(pet.Configure(config,&error), "quiet setting clears");
    const auto baseline = pet.State();
    for (int i = 0; i < 20; i++) {
      pet.Close(); check(!Flag(pet.State(),"exists"), "close destroys native fixture window");
      check(pet.Configure(config,&error), "fresh fixture reopens");
      check(Until([&] { return Flag(pet.State(),"visible"); }), "reopened fixture becomes visible");
      rss_peak = std::max(rss_peak,WorkingSet());
    }
    const auto end = pet.State();
    check(Number(end,"gdiObjects") <= Number(baseline,"gdiObjects")+8, "GDI objects remain bounded over twenty cycles");
    check(Number(end,"surfaceBytes") <= 2048*2048*4, "native surface has a bounded allocation");
    check(rss_peak-rss_before < 128*1024*1024, "maximum native atlas stays within the extra-RSS guard across twenty cycles");
    std::cout << "COMPONENT_FLOATING_RESOURCE_POC: {\"cycles\":20,\"observedFrames\":" << observed.size()
        << ",\"gdiBefore\":" << Number(baseline,"gdiObjects") << ",\"gdiAfter\":" << Number(end,"gdiObjects")
        << ",\"surfaceBytes\":" << Number(end,"surfaceBytes") << ",\"rendersDuringObservation\":" << renders
        << ",\"atlasWidth\":2048,\"atlasHeight\":1024,\"rssBefore\":" << rss_before << ",\"rssSamplePeak\":" << rss_peak << "}\n";
    pet.Close();
    check(!Flag(pet.State(),"exists") && Number(pet.State(),"atlasWidth") == 0 && Number(pet.State(),"surfaceBytes") == 0,
        "close releases the bitmap and native surface");
  }
  DestroyWindow(main);
  Parent parent{static_cast<DWORD>(std::wcstoul(argv[2], nullptr, 10))};
  EnumWindows(FindParent,reinterpret_cast<LPARAM>(&parent));
  if (parent.window) SetForegroundWindow(parent.window);
  std::cout << "COMPANION_COMPONENT: " << checks << " checks, " << failures << " failures; controlled notification reader, real Win32/GDI+\n";
  return failures ? 1 : 0;
}
