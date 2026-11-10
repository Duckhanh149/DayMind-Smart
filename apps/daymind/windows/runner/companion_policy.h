#ifndef DAYMIND_COMPANION_POLICY_H_
#define DAYMIND_COMPANION_POLICY_H_
#include <windows.h>
#include <shellapi.h>

inline bool CompanionFocusBlocked(QUERY_USER_NOTIFICATION_STATE state) {
  return state == QUNS_NOT_PRESENT || state == QUNS_BUSY ||
      state == QUNS_RUNNING_D3D_FULL_SCREEN || state == QUNS_PRESENTATION_MODE ||
      state == QUNS_QUIET_TIME;
}
inline bool CompanionCoversMonitor(const RECT& window, const RECT& monitor) {
  return window.left <= monitor.left + 2 && window.top <= monitor.top + 2 &&
      window.right >= monitor.right - 2 && window.bottom >= monitor.bottom - 2;
}
#endif
