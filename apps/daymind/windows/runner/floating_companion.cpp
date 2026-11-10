#include "floating_companion.h"
#include "companion_policy.h"
#include <windowsx.h>
#include <algorithm>
#include <cmath>
#include <limits>
#include <climits>
#include <cstring>
#include <iterator>
#include <objidl.h>

namespace {
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
constexpr UINT_PTR kPolicy = 1, kFrame = 2;
const V* Field(const M& m, const char* name) {
  const auto it = m.find(V(name)); return it == m.end() ? nullptr : &it->second;
}
bool Bool(const M& m, const char* name, bool fallback = false) {
  const V* v = Field(m, name); const auto* b = v ? std::get_if<bool>(v) : nullptr;
  return b ? *b : fallback;
}
int Int(const M& m, const char* name, int fallback = 0) {
  const V* v = Field(m, name);
  if (v) {
    if (const auto* n = std::get_if<int32_t>(v)) return *n;
    if (const auto* n = std::get_if<int64_t>(v)) {
      if (*n >= INT_MIN && *n <= INT_MAX) return static_cast<int>(*n);
    }
  }
  return fallback;
}
std::string Text(const M& m, const char* name) {
  const V* v = Field(m, name); const auto* s = v ? std::get_if<std::string>(v) : nullptr;
  return s ? *s : "";
}
int Dpi(HWND w) { return static_cast<int>(GetDpiForWindow(w)); }
}

FloatingCompanionWindow::FloatingCompanionWindow(HWND main_window, Event event)
    : main_(main_window), event_(std::move(event)) {}
FloatingCompanionWindow::~FloatingCompanionWindow() {
  Close(); if (gdiplus_) Gdiplus::GdiplusShutdown(gdiplus_);
}

bool FloatingCompanionWindow::EnsureWindow() {
  if (window_) return true;
  if (!gdiplus_) {
    Gdiplus::GdiplusStartupInput input;
    if (Gdiplus::GdiplusStartup(&gdiplus_, &input, nullptr) != Gdiplus::Ok) return false;
  }
  WNDCLASSEXW wc{}; wc.cbSize = sizeof(wc); wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandleW(nullptr); wc.lpszClassName = L"DayMindCompanionWindow";
  wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;
  // A separate top-level tool window, with no owner, remains available when
  // the main window is hidden. It never creates another Flutter view/engine.
  window_ = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      wc.lpszClassName, L"DayMind Companion", WS_POPUP, 0, 0, 112, 112,
      nullptr, nullptr, wc.hInstance, this);
  if (!window_) return false;
  SetTimer(window_, kPolicy, 500, nullptr);
  return true;
}

bool FloatingCompanionWindow::LoadImage(const std::vector<uint8_t>& bytes,
    std::unique_ptr<Gdiplus::Bitmap>* image) {
  if (bytes.empty()) { image->reset(); return true; }
  constexpr uint8_t png[] = {137,80,78,71,13,10,26,10};
  if (bytes.size() > 8 * 1024 * 1024 || bytes.size() < 33 ||
      !std::equal(std::begin(png), std::end(png), bytes.begin())) return false;
  auto big = [&](size_t p) -> uint32_t {
    return (uint32_t(bytes[p]) << 24) | (uint32_t(bytes[p+1]) << 16) |
        (uint32_t(bytes[p+2]) << 8) | uint32_t(bytes[p+3]);
  };
  const uint32_t width = big(16), height = big(20);
  if (!width || !height || width > 2048 || height > 1024) return false;
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes.size());
  if (!memory) return false;
  void* target = GlobalLock(memory);
  if (!target) { GlobalFree(memory); return false; }
  memcpy(target, bytes.data(), bytes.size()); GlobalUnlock(memory);
  IStream* stream = nullptr;
  if (FAILED(CreateStreamOnHGlobal(memory, TRUE, &stream))) { GlobalFree(memory); return false; }
  bool ok = false;
  {
    Gdiplus::Bitmap encoded(stream, FALSE);
    if (encoded.GetLastStatus() == Gdiplus::Ok && encoded.GetWidth() == width && encoded.GetHeight() == height) {
      // Own pixels, not the stream or a file handle. Original source files never
      // enter GDI+, and deleting/switching an account cannot leave a locked file.
      auto copy = std::make_unique<Gdiplus::Bitmap>(width, height, PixelFormat32bppPARGB);
      Gdiplus::Graphics g(copy.get());
      if (copy->GetLastStatus() == Gdiplus::Ok &&
          g.DrawImage(&encoded, 0, 0, static_cast<INT>(width), static_cast<INT>(height)) == Gdiplus::Ok) {
        *image = std::move(copy); ok = true;
      }
    }
  }
  stream->Release(); return ok;
}

bool FloatingCompanionWindow::Configure(const M& value, std::string* error) {
  auto fail = [&]() { *error = "Invalid bounded companion configuration."; return false; };
  const int size = Int(value, "size", 112);
  const std::string art = Text(value, "artKey"), expression = Text(value, "expression");
  if (size < 80 || size > 256 || art.empty() || art.size() > 200 ||
      (expression != "neutral" && expression != "happy" && expression != "focused" && expression != "resting")) return fail();
  const auto* raw_frames = Field(value, "frames");
  const auto* frame_list = raw_frames ? std::get_if<flutter::EncodableList>(raw_frames) : nullptr;
  const auto* raw_sequence = Field(value, "sequence");
  const auto* sequence = raw_sequence ? std::get_if<flutter::EncodableList>(raw_sequence) : nullptr;
  if (!frame_list || !sequence || frame_list->size() > 120 || sequence->size() > 120) return fail();
  std::vector<Frame> frames;
  for (const auto& v : *frame_list) {
    const auto* f = std::get_if<M>(&v); if (!f) return fail();
    Frame frame{Int(*f,"x",-1), Int(*f,"y",-1), Int(*f,"width",-1), Int(*f,"height",-1), Int(*f,"durationMs",-1)};
    if (frame.x < 0 || frame.y < 0 || frame.width != 128 || frame.height != 128 ||
        frame.duration < 84 || frame.duration > 5000 || frame.x > 1920 || frame.y > 896) return fail();
    frames.push_back(frame);
  }
  std::vector<int> steps;
  int duration = 0;
  for (const auto& v : *sequence) {
    const auto* n = std::get_if<int32_t>(&v);
    if (!n || *n < 0 || static_cast<size_t>(*n) >= frames.size()) return fail();
    steps.push_back(*n); duration += frames[*n].duration;
  }
  if (duration > 60000 || frames.empty() != steps.empty()) return fail();
  const V* raw_image = Field(value, "image");
  const auto* bytes = raw_image ? std::get_if<std::vector<uint8_t>>(raw_image) : nullptr;
  if ((raw_image && !bytes) || (art != art_key_ && !bytes)) return fail();
  if (!EnsureWindow()) { *error = "Cannot create companion window."; return false; }
  std::unique_ptr<Gdiplus::Bitmap> next_image;
  if (bytes && !LoadImage(*bytes, &next_image)) return fail();
  Gdiplus::Bitmap* image = bytes ? next_image.get() : image_.get();
  if (!frames.empty()) {
    if (!image) return fail();
    for (const auto& f : frames) {
      if (f.x + f.width > static_cast<int>(image->GetWidth()) ||
          f.y + f.height > static_cast<int>(image->GetHeight())) return fail();
    }
  }
  const bool change_motion = art != art_key_ || expression != expression_ || steps != sequence_;
  if (bytes) image_ = std::move(next_image);
  art_key_ = art; expression_ = expression; frames_ = std::move(frames); sequence_ = std::move(steps);
  loop_ = Bool(value,"loop"); quiet_ = Bool(value,"quiet"); low_ = Bool(value,"lowResource");
  topmost_ = Bool(value,"topmost"); click_ = Bool(value,"clickThrough"); size_dp_ = size;
  if (change_motion) step_ = 0;
  LONG_PTR styles = WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
  if (click_) styles |= WS_EX_TRANSPARENT;
  SetWindowLongPtrW(window_, GWL_EXSTYLE, styles);
  RECT previous{}; GetWindowRect(window_, &previous);
  MONITORINFO monitor{}; monitor.cbSize = sizeof(monitor);
  GetMonitorInfoW(MonitorFromWindow(main_, MONITOR_DEFAULTTONEAREST), &monitor);
  const int x = Int(value,"x", art_key_.empty() ? monitor.rcWork.right - 160 : previous.left);
  const int y = Int(value,"y", previous.bottom > 0 ? previous.top : monitor.rcWork.bottom - 160);
  // Null geometry is an explicit recover-to-work-area request.
  const bool reset = !Field(value,"x") || !Field(value,"y");
  const int pixels = MulDiv(size_dp_, std::max(96,Dpi(window_)), 96);
  SetWindowPos(window_, topmost_ ? HWND_TOPMOST : HWND_NOTOPMOST,
      reset ? monitor.rcWork.right - pixels - 24 : x,
      reset ? monitor.rcWork.bottom - pixels - 24 : y,
      pixels, pixels, SWP_NOACTIVATE);
  ClampBounds(); KillTimer(window_, kFrame); Policy();
  if (!policy_hidden_) { Draw(); ScheduleFrame(); }
  return true;
}

void FloatingCompanionWindow::FreeSurface() {
  if (dc_ && previous_bitmap_) SelectObject(dc_, previous_bitmap_);
  if (dib_) DeleteObject(dib_);
  if (dc_) DeleteDC(dc_);
  dc_ = nullptr; dib_ = nullptr; previous_bitmap_ = nullptr; pixels_ = nullptr; surface_size_ = 0;
}

void FloatingCompanionWindow::Draw() {
  if (!window_ || policy_hidden_) return;
  RECT rect{}; GetWindowRect(window_, &rect); const int size = rect.right - rect.left;
  if (size <= 0 || size > 2048) return;
  if (size != surface_size_) {
    FreeSurface(); dc_ = CreateCompatibleDC(nullptr);
    BITMAPINFO info{}; info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = size; info.bmiHeader.biHeight = -size;
    info.bmiHeader.biPlanes = 1; info.bmiHeader.biBitCount = 32; info.bmiHeader.biCompression = BI_RGB;
    dib_ = CreateDIBSection(dc_, &info, DIB_RGB_COLORS, &pixels_, nullptr, 0);
    if (!dc_ || !dib_ || !pixels_) { FreeSurface(); return; }
    previous_bitmap_ = SelectObject(dc_, dib_); surface_size_ = size;
  }
  {
    Gdiplus::Bitmap surface(size, size, size * 4, PixelFormat32bppPARGB, static_cast<BYTE*>(pixels_));
    Gdiplus::Graphics g(&surface);
    g.SetCompositingMode(Gdiplus::CompositingModeSourceCopy); g.Clear(Gdiplus::Color(0,0,0,0));
    g.SetCompositingMode(Gdiplus::CompositingModeSourceOver);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    if (image_) {
      const Frame f = frames_.empty() ? Frame{0,0,static_cast<int>(image_->GetWidth()),static_cast<int>(image_->GetHeight()),125} : frames_[sequence_[step_]];
      const float scale = std::min(static_cast<float>(size)/static_cast<float>(f.width),static_cast<float>(size)/static_cast<float>(f.height));
      const float w = static_cast<float>(f.width) * scale, h = static_cast<float>(f.height) * scale;
      const float output_size = static_cast<float>(size);
      g.SetInterpolationMode(Gdiplus::InterpolationModeBilinear);
      g.DrawImage(image_.get(), Gdiplus::RectF((output_size-w)/2,(output_size-h)/2,w,h),
          static_cast<float>(f.x),static_cast<float>(f.y),static_cast<float>(f.width),static_cast<float>(f.height),Gdiplus::UnitPixel);
    } else {
      g.ScaleTransform(static_cast<float>(size)/100,static_cast<float>(size)/100);
      Gdiplus::SolidBrush body(Gdiplus::Color(255,219,232,185)), leaf(Gdiplus::Color(255,111,152,87));
      Gdiplus::SolidBrush eye(Gdiplus::Color(255,62,84,58)), blush(Gdiplus::Color(255,232,184,161));
      g.FillEllipse(&leaf,27,5,23,28); g.FillEllipse(&leaf,49,7,26,23);
      g.FillEllipse(&body,15,25,70,64); g.FillEllipse(&body,7,55,18,24); g.FillEllipse(&body,77,55,18,24);
      g.FillEllipse(&blush,23,63,13,7); g.FillEllipse(&blush,64,63,13,7);
      Gdiplus::Pen pen(Gdiplus::Color(255,62,84,58),2.2f);
      if (expression_ == "resting" || expression_ == "happy") {
        g.DrawLine(&pen,32,55,40,55); g.DrawLine(&pen,60,55,68,55);
      } else { g.FillEllipse(&eye,33,52,6,6); g.FillEllipse(&eye,61,52,6,6); }
      if (expression_ == "focused" || expression_ == "resting") g.DrawLine(&pen,44,67,56,67);
      else g.DrawArc(&pen,44,60,12,12,0,180);
    }
    if (!click_) {
      // A visible grip also gives layered-window alpha hit testing a reliable
      // resize target when imported artwork has transparent corners.
      g.ResetTransform();
      const float grip = static_cast<float>(MulDiv(14,std::max(96,Dpi(window_)),96));
      const float edge = static_cast<float>(size);
      Gdiplus::SolidBrush handle(Gdiplus::Color(200,82,107,75));
      g.FillEllipse(&handle,edge-grip-1,edge-grip-1,grip,grip);
    }
    g.Flush(Gdiplus::FlushIntentionSync);
  }
  POINT destination{rect.left,rect.top}, source{0,0}; SIZE dimensions{size,size};
  BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};
  UpdateLayeredWindow(window_, nullptr, &destination,&dimensions,dc_,&source,0,&blend,ULW_ALPHA);
  rendered_++;
}

void FloatingCompanionWindow::ScheduleFrame() {
  if (!window_ || policy_hidden_ || low_ || sequence_.size() < 2 ||
      (!loop_ && step_ + 1 == sequence_.size())) return;
  SetTimer(window_,kFrame,frames_[sequence_[step_]].duration,nullptr);
}

void FloatingCompanionWindow::Policy() {
  if (!window_) return;
  QUERY_USER_NOTIFICATION_STATE state = QUNS_ACCEPTS_NOTIFICATIONS;
  if (SUCCEEDED(SHQueryUserNotificationState(&state))) notification_state_ = state;
  std::string reason;
  if (quiet_) reason = "quiet";
  else if (CompanionFocusBlocked(state)) reason = "focus";
  else {
    HWND foreground = GetForegroundWindow();
    if (foreground && foreground != window_ && foreground != main_ &&
        foreground != GetDesktopWindow() && foreground != GetShellWindow() && !IsIconic(foreground)) {
      wchar_t klass[64]{}; GetClassNameW(foreground,klass,64);
      if (wcscmp(klass,L"Shell_TrayWnd") != 0 && wcscmp(klass,L"WorkerW") != 0 && wcscmp(klass,L"Progman") != 0) {
        RECT rect{}; MONITORINFO monitor{}; monitor.cbSize = sizeof(monitor);
        if (GetWindowRect(foreground,&rect) && GetMonitorInfoW(MonitorFromWindow(foreground,MONITOR_DEFAULTTONEAREST),&monitor) &&
            CompanionCoversMonitor(rect,monitor.rcMonitor)) reason = "fullscreen";
      }
    }
  }
  hidden_reason_ = reason;
  const bool hide = !reason.empty();
  if (hide == policy_hidden_) return;
  policy_hidden_ = hide;
  if (hide) {
    KillTimer(window_,kFrame); ShowWindow(window_,SW_HIDE); FreeSurface();
  } else {
    ClampBounds(); Draw(); ShowWindow(window_,SW_SHOWNOACTIVATE); ScheduleFrame();
  }
}

void FloatingCompanionWindow::ClampBounds() {
  if (!window_) return;
  RECT rect{}; GetWindowRect(window_,&rect);
  MONITORINFO monitor{}; monitor.cbSize = sizeof(monitor);
  if (!GetMonitorInfoW(MonitorFromRect(&rect,MONITOR_DEFAULTTONEAREST),&monitor)) return;
  const RECT work = monitor.rcWork;
  const LONG size = std::min({rect.right-rect.left, work.right-work.left, work.bottom-work.top});
  const LONG x = std::clamp(rect.left,work.left,work.right-size), y = std::clamp(rect.top,work.top,work.bottom-size);
  SetWindowPos(window_,nullptr,x,y,size,size,SWP_NOACTIVATE|SWP_NOZORDER);
}

void FloatingCompanionWindow::Moved() {
  if (!window_) return;
  RECT r{}; GetWindowRect(window_,&r);
  size_dp_ = std::clamp(MulDiv(r.right-r.left,96,std::max(96,Dpi(window_))),80,256);
  event_("moved",V(M{{V("x"),V(static_cast<int32_t>(r.left))},{V("y"),V(static_cast<int32_t>(r.top))},{V("size"),V(size_dp_)}}));
}
void FloatingCompanionWindow::Recover() {
  if (window_) {
    click_ = false;
    SetWindowLongPtrW(window_,GWL_EXSTYLE,GetWindowLongPtrW(window_,GWL_EXSTYLE)&~WS_EX_TRANSPARENT);
    MONITORINFO monitor{}; monitor.cbSize = sizeof(monitor);
    GetMonitorInfoW(MonitorFromWindow(main_,MONITOR_DEFAULTTONEAREST),&monitor);
    const int size = MulDiv(size_dp_,std::max(96,Dpi(window_)),96);
    SetWindowPos(window_,nullptr,monitor.rcWork.right-size-24,monitor.rcWork.bottom-size-24,size,size,SWP_NOACTIVATE|SWP_NOZORDER);
    ClampBounds(); Draw();
  }
  event_("recovered",V());
}
void FloatingCompanionWindow::Close() {
  if (window_) { KillTimer(window_,kPolicy); KillTimer(window_,kFrame); DestroyWindow(window_); window_ = nullptr; }
  FreeSurface(); image_.reset(); art_key_.clear(); frames_.clear(); sequence_.clear(); step_ = 0;
  moving_ = resizing_ = false; policy_hidden_ = true; hidden_reason_ = "disabled";
}
flutter::EncodableMap FloatingCompanionWindow::State() const {
  RECT r{}; if (window_) GetWindowRect(window_,&r);
  FILETIME creation{},exit{},kernel{},user{};
  GetProcessTimes(GetCurrentProcess(),&creation,&exit,&kernel,&user);
  ULARGE_INTEGER k{},u{};
  k.LowPart=kernel.dwLowDateTime;k.HighPart=kernel.dwHighDateTime;
  u.LowPart=user.dwLowDateTime;u.HighPart=user.dwHighDateTime;
  return {{V("exists"),V(window_ != nullptr)},{V("visible"),V(window_ && IsWindowVisible(window_))},
    {V("reason"),V(hidden_reason_)},{V("notificationState"),V(static_cast<int32_t>(notification_state_))},
    {V("clickThrough"),V(click_)},{V("topmost"),V(topmost_)},{V("size"),V(size_dp_)},
    {V("x"),V(static_cast<int32_t>(r.left))},{V("y"),V(static_cast<int32_t>(r.top))},{V("pixels"),V(static_cast<int32_t>(r.right-r.left))},
    {V("frame"),V(static_cast<int32_t>(sequence_.empty()?0:sequence_[step_]))},
    {V("atlasWidth"),V(static_cast<int32_t>(image_?image_->GetWidth():0))},
    {V("atlasHeight"),V(static_cast<int32_t>(image_?image_->GetHeight():0))},
    {V("gdiObjects"),V(static_cast<int32_t>(GetGuiResources(GetCurrentProcess(),GR_GDIOBJECTS)))},
    {V("surfaceBytes"),V(static_cast<int64_t>(surface_size_)*surface_size_*4)},
    {V("cpuMs"),V(static_cast<int64_t>((k.QuadPart+u.QuadPart)/10000))},
    {V("renders"),V(static_cast<int64_t>(rendered_))}};
}
LRESULT CALLBACK FloatingCompanionWindow::WndProc(HWND w,UINT m,WPARAM p,LPARAM l) {
  auto* self = reinterpret_cast<FloatingCompanionWindow*>(GetWindowLongPtrW(w,GWLP_USERDATA));
  if (m == WM_NCCREATE) {
    self = static_cast<FloatingCompanionWindow*>(reinterpret_cast<CREATESTRUCTW*>(l)->lpCreateParams);
    self->window_ = w; SetWindowLongPtrW(w,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(self));
  }
  return self ? self->Message(m,p,l) : DefWindowProcW(w,m,p,l);
}
LRESULT FloatingCompanionWindow::Message(UINT message,WPARAM w,LPARAM l) {
  switch (message) {
    case WM_MOUSEACTIVATE: return MA_NOACTIVATE;
    case WM_NCHITTEST: {
      if (click_) return HTTRANSPARENT;
      POINT p{GET_X_LPARAM(l),GET_Y_LPARAM(l)}; ScreenToClient(window_,&p);
      if (pixels_ && p.x>=0 && p.y>=0 && p.x<surface_size_ && p.y<surface_size_) {
        const auto* pixel = static_cast<const BYTE*>(pixels_)+(p.y*surface_size_+p.x)*4;
        if (pixel[3] < 8) return HTTRANSPARENT;
      }
      return HTCLIENT;
    }
    case WM_SETCURSOR: {
      POINT p{};GetCursorPos(&p);ScreenToClient(window_,&p);
      const int grip = MulDiv(18,std::max(96,Dpi(window_)),96);
      SetCursor(LoadCursorW(nullptr,p.x>=surface_size_-grip && p.y>=surface_size_-grip ? IDC_SIZENWSE : IDC_SIZEALL));
      return TRUE;
    }
    case WM_LBUTTONDOWN: {
      if (click_) return 0;
      GetCursorPos(&drag_); GetWindowRect(window_,&origin_);
      const int grip = MulDiv(18,std::max(96,Dpi(window_)),96);
      resizing_ = drag_.x >= origin_.right-grip && drag_.y >= origin_.bottom-grip;
      moving_ = !resizing_; SetCapture(window_); return 0;
    }
    case WM_MOUSEMOVE: {
      if (!moving_ && !resizing_) break;
      POINT p{};GetCursorPos(&p);
      int size = origin_.right-origin_.left;
      if (resizing_) size = std::clamp(size+static_cast<int>(std::max(p.x-drag_.x,p.y-drag_.y)),MulDiv(80,std::max(96,Dpi(window_)),96),MulDiv(256,std::max(96,Dpi(window_)),96));
      SetWindowPos(window_,nullptr,origin_.left+(moving_?p.x-drag_.x:0),origin_.top+(moving_?p.y-drag_.y:0),size,size,SWP_NOACTIVATE|SWP_NOZORDER);
      ClampBounds(); Draw(); return 0;
    }
    case WM_LBUTTONUP:
      if (moving_ || resizing_) { moving_ = resizing_ = false; ReleaseCapture(); ClampBounds(); Moved(); }
      return 0;
    case WM_CAPTURECHANGED: moving_ = resizing_ = false; return 0;
    case WM_CONTEXTMENU: {
      HMENU menu = CreatePopupMenu(); if (!menu) return 0;
      AppendMenuW(menu,MF_STRING,801,L"M\u1edf DayMind");
      AppendMenuW(menu,MF_STRING,803,L"Kh\u00f4i ph\u1ee5c v\u1ecb tr\u00ed / nh\u1eadn chu\u1ed9t");
      POINT p{};GetCursorPos(&p);
      const UINT command = TrackPopupMenu(menu,TPM_RETURNCMD|TPM_NONOTIFY,p.x,p.y,0,window_,nullptr);
      DestroyMenu(menu); if(command) PostMessageW(main_,WM_COMMAND,command,0); return 0;
    }
    case WM_TIMER:
      if (w == kPolicy) Policy();
      else if (w == kFrame) {
        KillTimer(window_,kFrame);
        // Check policy before every frame as well as the 500ms idle policy tick.
        Policy();
        if (!policy_hidden_ && !sequence_.empty()) { step_=(step_+1)%sequence_.size(); Draw(); ScheduleFrame(); }
      }
      return 0;
    case WM_DISPLAYCHANGE: ClampBounds(); Draw(); return 0;
    case WM_DPICHANGED: {
      const auto* r = reinterpret_cast<const RECT*>(l);
      const int size = MulDiv(size_dp_,HIWORD(w),96);
      SetWindowPos(window_,nullptr,r->left,r->top,size,size,SWP_NOACTIVATE|SWP_NOZORDER);
      ClampBounds(); Draw(); Moved(); return 0;
    }
    case WM_CLOSE: Close(); return 0;
  }
  return DefWindowProcW(window_,message,w,l);
}
