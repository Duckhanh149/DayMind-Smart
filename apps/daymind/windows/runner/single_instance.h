#ifndef DAYMIND_SINGLE_INSTANCE_H_
#define DAYMIND_SINGLE_INSTANCE_H_
#include <windows.h>

// Per Windows user, across sessions: a second process must not open the same
// SQLite/artwork workspace. The kernel releases ownership after a crash.
class DayMindSingleInstance {
 public:
  enum class Result { primary, existing, failed };
  DayMindSingleInstance() = default;
  ~DayMindSingleInstance();
  DayMindSingleInstance(const DayMindSingleInstance&) = delete;
  DayMindSingleInstance& operator=(const DayMindSingleInstance&) = delete;
  Result Acquire();
  static void OpenExisting();
 private:
  HANDLE mutex_ = nullptr;
  bool owned_ = false;
};
#endif
