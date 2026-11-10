#include "companion_policy.h"
#include <iostream>

int main() {
  int checks = 0, failures = 0;
  auto check = [&](bool value) { ++checks; if (!value) ++failures; };
  check(!CompanionFocusBlocked(QUNS_ACCEPTS_NOTIFICATIONS));
  for (const auto state : {QUNS_NOT_PRESENT,QUNS_BUSY,QUNS_RUNNING_D3D_FULL_SCREEN,
      QUNS_PRESENTATION_MODE,QUNS_QUIET_TIME}) check(CompanionFocusBlocked(state));
  const RECT monitor{0,0,1920,1080};
  check(CompanionCoversMonitor(RECT{0,0,1920,1080},monitor));
  check(CompanionCoversMonitor(RECT{-8,-8,1928,1088},monitor));
  check(!CompanionCoversMonitor(RECT{0,0,1920,1040},monitor));
  check(!CompanionCoversMonitor(RECT{10,10,1910,1070},monitor));
  check(CompanionCoversMonitor(RECT{-1920,-1080,0,0},RECT{-1920,-1080,0,0}));
  check(!CompanionCoversMonitor(RECT{0,0,1920,1080},RECT{-1920,0,0,1080}));
  std::cout << "COMPANION_POLICY: " << checks << " checks, " << failures << " failures\n";
  return failures ? 1 : 0;
}
