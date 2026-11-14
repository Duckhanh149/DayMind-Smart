enum NotificationDiagnosticCode {
  initialized,
  initializationFailed,
  timezoneUnavailable,
  permissionGranted,
  permissionDenied,
  permissionUnknown,
  foregroundRoute,
  osAttempt,
  osAccepted,
  osFailed,
  testRequested,
  quietHours,
  secondaryDevice,
  pollFailed,
}

/// Opt-in session-only ring. No free text, IDs, absolute times or task data.
class NotificationDiagnostics {
  final _clock = Stopwatch()..start();
  final _entries = <Map<String, Object>>[];
  bool _enabled = false;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) _entries.clear();
  }

  void record(NotificationDiagnosticCode code, {int? setting, int? state}) {
    if (!_enabled) return;
    if (_entries.length == 128) _entries.removeAt(0);
    _entries.add({
      'elapsedMs': _clock.elapsedMilliseconds,
      'code': code.name,
      if (setting != null && setting >= 0 && setting <= 4) 'osSetting': setting,
      if (state != null && state >= 1 && state <= 7) 'osState': state,
    });
  }

  List<Map<String, Object>> export() =>
      _enabled ? _entries.map((e) => Map<String, Object>.from(e)).toList() : [];
}
