import 'dart:ffi';
import 'dart:io';

typedef _HandleNative = Pointer<Void> Function();
typedef _HandleDart = Pointer<Void> Function();
typedef _AllocNative = Pointer<Void> Function(Pointer<Void>, Uint32, IntPtr);
typedef _AllocDart = Pointer<Void> Function(Pointer<Void>, int, int);
typedef _FreeNative = Int32 Function(Pointer<Void>, Uint32, Pointer<Void>);
typedef _FreeDart = int Function(Pointer<Void>, int, Pointer<Void>);
typedef _TimesNative = Int32 Function(
  Pointer<Void>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Uint64>,
);
typedef _TimesDart = int Function(
  Pointer<Void>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Uint64>,
);

/// Test-only real process CPU accounting, all threads; no shell commands/PII.
int? cpuMicros() {
  try {
    if (Platform.isWindows) {
      final lib = DynamicLibrary.open('kernel32.dll');
      final heap = lib.lookupFunction<_HandleNative, _HandleDart>(
        'GetProcessHeap',
      )();
      final alloc = lib.lookupFunction<_AllocNative, _AllocDart>('HeapAlloc');
      final free = lib.lookupFunction<_FreeNative, _FreeDart>('HeapFree');
      final memory = alloc(heap, 8, 32);
      if (memory.address == 0) return null;
      try {
        final times = memory.cast<Uint64>();
        final ok =
            lib.lookupFunction<_TimesNative, _TimesDart>('GetProcessTimes')(
              lib.lookupFunction<_HandleNative, _HandleDart>(
                'GetCurrentProcess',
              )(),
              times,
              times + 1,
              times + 2,
              times + 3,
            );
        return ok == 0 ? null : (times[2] + times[3]) ~/ 10;
      } finally {
        free(heap, 0, memory);
      }
    }
    if (Platform.isLinux || Platform.isAndroid) {
      final lib = DynamicLibrary.open(
        Platform.isAndroid ? 'libc.so' : 'libc.so.6',
      );
      final alloc = lib
          .lookupFunction<
            Pointer<Void> Function(IntPtr),
            Pointer<Void> Function(int)
          >('malloc');
      final free = lib
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('free');
      final memory = alloc(16);
      if (memory.address == 0) return null;
      try {
        final times = memory.cast<Int64>();
        final rc = lib
            .lookupFunction<
              Int32 Function(Int32, Pointer<Int64>),
              int Function(int, Pointer<Int64>)
            >('clock_gettime')(2, times);
        return rc == 0 ? times[0] * 1000000 + times[1] ~/ 1000 : null;
      } finally {
        free(memory);
      }
    }
  } catch (_) {
    /* Explicit unavailable, never invent zero CPU. */
  }
  return null;
}

class ResourceSampler {
  ResourceSampler()
    : cpuStart = cpuMicros(),
      rssStart = ProcessInfo.currentRss,
      rssPeak = ProcessInfo.currentRss;
  final int? cpuStart;
  final int rssStart;
  final watch = Stopwatch()..start();
  int rssPeak, samples = 0;
  void sample() {
    final rss = ProcessInfo.currentRss;
    if (rss > rssPeak) rssPeak = rss;
    samples++;
  }

  Map<String, Object?> finish() {
    sample();
    final elapsed = watch.elapsedMicroseconds, end = cpuMicros();
    final cpu = cpuStart != null && end != null ? end - cpuStart! : null;
    return {
      'elapsedMs': elapsed ~/ 1000,
      'samples': samples,
      'rssStart': rssStart,
      'rssSamplePeak': rssPeak,
      'rssEnd': ProcessInfo.currentRss,
      'processLifetimePeakRss': ProcessInfo.maxRss,
      'cpuSupported': cpu != null,
      'cpuMs': cpu == null ? null : cpu ~/ 1000,
      'cpuPercentOneCore': cpu == null || elapsed == 0
          ? null
          : cpu * 100 / elapsed,
    };
  }
}
