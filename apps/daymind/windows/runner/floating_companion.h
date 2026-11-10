#ifndef DAYMIND_FLOATING_COMPANION_H_
#define DAYMIND_FLOATING_COMPANION_H_
#include <windows.h>
#include <shellapi.h>
#include <gdiplus.h>
#include <flutter/encodable_value.h>
#include <functional>
#include <memory>
#include <string>
#include <vector>
#include <cstdint>

class FloatingCompanionWindow {
 public:
  using Event = std::function<void(const std::string&, const flutter::EncodableValue&)>;
  FloatingCompanionWindow(HWND main_window, Event event);
  ~FloatingCompanionWindow();
  bool Configure(const flutter::EncodableMap& value, std::string* error);
  void Close();
  void Recover();
  flutter::EncodableMap State() const;
 private:
  struct Frame { int x, y, width, height, duration; };
  static LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
  LRESULT Message(UINT, WPARAM, LPARAM);
  bool EnsureWindow();
  bool LoadImage(const std::vector<uint8_t>& bytes, std::unique_ptr<Gdiplus::Bitmap>* image);
  void Draw();
  void FreeSurface();
  void Policy();
  void ScheduleFrame();
  void ClampBounds();
  void Moved();
  HWND main_, window_ = nullptr;
  Event event_;
  ULONG_PTR gdiplus_ = 0;
  std::unique_ptr<Gdiplus::Bitmap> image_;
  std::string art_key_, expression_ = "neutral", hidden_reason_ = "disabled";
  std::vector<Frame> frames_;
  std::vector<int> sequence_;
  size_t step_ = 0;
  bool loop_ = false, quiet_ = false, low_ = false, topmost_ = false, click_ = false;
  bool moving_ = false, resizing_ = false, policy_hidden_ = true;
  POINT drag_{};
  RECT origin_{};
  int size_dp_ = 112;
  HDC dc_ = nullptr;
  HBITMAP dib_ = nullptr;
  HGDIOBJ previous_bitmap_ = nullptr;
  void* pixels_ = nullptr;
  int surface_size_ = 0;
  uint64_t rendered_ = 0;
  QUERY_USER_NOTIFICATION_STATE notification_state_ = QUNS_ACCEPTS_NOTIFICATIONS;
};
#endif
