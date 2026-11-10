#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <algorithm>
#include <cstdlib>
#include <cwchar>
#include <iostream>
#include <string>

namespace {
struct Windows { DWORD pid; HWND pet=nullptr,main=nullptr; int flutter_views=0; };
BOOL CALLBACK Child(HWND w,LPARAM data) {
  auto* windows=reinterpret_cast<Windows*>(data);wchar_t name[128]{};
  GetClassNameW(w,name,128);
  if (wcsstr(name,L"FLUTTERVIEW")) windows->flutter_views++;
  return TRUE;
}
BOOL CALLBACK Find(HWND w,LPARAM data) {
  auto* windows=reinterpret_cast<Windows*>(data);DWORD pid=0;GetWindowThreadProcessId(w,&pid);
  if(pid!=windows->pid) return TRUE;
  wchar_t name[128]{};GetClassNameW(w,name,128);
  if(wcscmp(name,L"DayMindCompanionWindow")==0) windows->pet=w;
  if(wcscmp(name,L"FLUTTER_RUNNER_WIN32_WINDOW")==0) windows->main=w;
  EnumChildWindows(w,Child,data);return TRUE;
}
bool WaitVisible(HWND w,bool visible) {
  const ULONGLONG until=GetTickCount64()+4000;
  while(GetTickCount64()<until) {
    MSG m{};while(PeekMessageW(&m,nullptr,0,0,PM_REMOVE)) { TranslateMessage(&m);DispatchMessageW(&m); }
    if((IsWindowVisible(w)!=FALSE)==visible) return true;
    Sleep(30);
  }
  return false;
}
LRESULT CALLBACK Probe(HWND w,UINT m,WPARAM p,LPARAM l) {
  return DefWindowProcW(w,m,p,l);
}
}

int main(int argc,char** argv) {
  if(argc<2) return 2;
  Windows windows{static_cast<DWORD>(std::strtoul(argv[1],nullptr,10))};
  EnumWindows(Find,reinterpret_cast<LPARAM>(&windows));
  int checks=0,failures=0;
  auto check=[&](bool value,const char* name) { ++checks;if(!value) { ++failures;std::cerr<<"FAIL: "<<name<<"\n"; } };
  check(windows.pet!=nullptr && windows.main!=nullptr,"main and companion windows belong to app process");
  if(!windows.pet || !windows.main) return 1;
  check(windows.flutter_views==1,"exactly one Flutter view");
  const LONG_PTR styles=GetWindowLongPtrW(windows.pet,GWL_EXSTYLE);
  check((styles&WS_EX_NOACTIVATE)!=0 && (styles&WS_EX_TOOLWINDOW)!=0 && (styles&WS_EX_LAYERED)!=0,"no-activate layered tool window");
  const bool click=argc>2 && std::string(argv[2])=="click-through";
  check(((styles&WS_EX_TRANSPARENT)!=0)==click,"click-through matches explicit setting");
  check((styles&WS_EX_TOPMOST)==0,"topmost stays off by default");
  check(SendMessageW(windows.pet,WM_MOUSEACTIVATE,reinterpret_cast<WPARAM>(windows.main),MAKELPARAM(HTCLIENT,WM_LBUTTONDOWN))==MA_NOACTIVATE,"mouse activation refused");
  if(click) {
    RECT r{};GetWindowRect(windows.pet,&r);
    check(SendMessageW(windows.pet,WM_NCHITTEST,0,MAKELPARAM(r.left+20,r.top+20))==HTTRANSPARENT,"click-through hit test");
  } else {
    check(WaitVisible(windows.pet,true),"companion visible in available desktop session");
    const HWND foreground=GetForegroundWindow();
    ShowWindow(windows.pet,SW_SHOWNOACTIVATE);
    check(GetForegroundWindow()==foreground,"showing companion preserves keyboard focus");
    RECT before{};GetWindowRect(windows.pet,&before);
    MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);
    GetMonitorInfoW(MonitorFromWindow(windows.pet,MONITOR_DEFAULTTONEAREST),&monitor);
    POINT cursor{};GetCursorPos(&cursor);
    const int center_x=static_cast<int>((before.left+before.right)/2),center_y=static_cast<int>((before.top+before.bottom)/2);
    SetCursorPos(center_x,center_y);
    SendMessageW(windows.pet,WM_LBUTTONDOWN,MK_LBUTTON,0);
    SetCursorPos(center_x-60,center_y-60);
    SendMessageW(windows.pet,WM_MOUSEMOVE,MK_LBUTTON,0);
    SendMessageW(windows.pet,WM_LBUTTONUP,0,0);
    Sleep(250);
    RECT moved{};GetWindowRect(windows.pet,&moved);
    check(moved.left!=before.left || moved.top!=before.top,"drag changes position");
    const int width=static_cast<int>(moved.right-moved.left);
    SetCursorPos(moved.right-5,moved.bottom-5);
    SendMessageW(windows.pet,WM_LBUTTONDOWN,MK_LBUTTON,0);
    SetCursorPos(moved.right+35,moved.bottom+35);
    SendMessageW(windows.pet,WM_MOUSEMOVE,MK_LBUTTON,0);
    SendMessageW(windows.pet,WM_LBUTTONUP,0,0);
    Sleep(250);
    RECT resized{};GetWindowRect(windows.pet,&resized);
    check(resized.right-resized.left>width,"resize grip changes size");
    SetCursorPos(cursor.x,cursor.y);
    SetWindowPos(windows.pet,nullptr,-100000,-100000,0,0,SWP_NOSIZE|SWP_NOACTIVATE|SWP_NOZORDER);
    SendMessageW(windows.pet,WM_DISPLAYCHANGE,0,0);
    RECT clamped{};GetWindowRect(windows.pet,&clamped);
    MONITORINFO target{};target.cbSize=sizeof(target);
    GetMonitorInfoW(MonitorFromWindow(windows.pet,MONITOR_DEFAULTTONEAREST),&target);
    check(clamped.left>=target.rcWork.left && clamped.top>=target.rcWork.top && clamped.right<=target.rcWork.right && clamped.bottom<=target.rcWork.bottom,"offscreen position clamped to work area");
    WNDCLASSW wc{};wc.hInstance=GetModuleHandleW(nullptr);wc.lpfnWndProc=Probe;wc.lpszClassName=L"DayMindFullscreenProbe";
    RegisterClassW(&wc);
    const RECT full=monitor.rcMonitor;
    HWND full_window=CreateWindowExW(WS_EX_TOPMOST,wc.lpszClassName,L"DayMind fullscreen test",WS_POPUP,full.left,full.top,full.right-full.left,full.bottom-full.top,nullptr,nullptr,wc.hInstance,nullptr);
    check(full_window!=nullptr,"fullscreen fixture created");
    if(full_window) {
      ShowWindow(full_window,SW_SHOW);SetForegroundWindow(full_window);
      check(GetForegroundWindow()==full_window,"fullscreen fixture owns foreground");
      check(WaitVisible(windows.pet,false),"real foreground fullscreen hides companion");
      DestroyWindow(full_window);SetForegroundWindow(windows.main);
      check(WaitVisible(windows.pet,true),"leaving fullscreen restores companion without focus stealing");
    }
  }
  std::cout<<"COMPANION_WINDOW: "<<checks<<" checks, "<<failures<<" failures\n";
  return failures?1:0;
}
