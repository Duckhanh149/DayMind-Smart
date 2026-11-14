import 'dart:async';

import '../data/sync_store.dart';
import '../domain/account.dart';
import '../domain/sync_record.dart';

enum SyncState { idle, working, offline, attention, stopped }

/// One serialized cycle; a durable outbox survives process termination.
/// Network calls never hold a SQLite transaction open.
class SyncService {
  SyncService({
    required this.store,
    required this.gateway,
    required this.session,
    required this.deviceId,
    required this.deviceName,
    this.onChanged,
    this.onPrimary,
  });
  final _updates = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _updates.stream;
  void _notify() {
    if (!_updates.isClosed) _updates.add(null);
  }

  final SyncStore store;
  final SyncGateway gateway;
  final Future<AuthSession> Function() session;
  final String deviceId, deviceName;
  final Future<void> Function()? onChanged;
  final Future<void> Function(bool)? onPrimary;
  SyncState state = SyncState.idle;
  String? message;
  int pendingCount = 0, conflictCount = 0;
  DateTime? lastSynced;
  bool primaryHere = false;
  bool _stopped = false, _again = false, _registered = false;
  Future<void>? _flight;
  Future<void>? _initializing;
  Timer? _timer;
  int _failures = 0;
  int _localVersion = 0, _capturedVersion = 0;
  bool get localChanges => _localVersion != _capturedVersion;
  void markLocalChange() {
    _localVersion++;
    lastSynced = null;
    _notify();
  }

  Future<void> _capture() async {
    final revision = _localVersion;
    await store.capture();
    _capturedVersion = revision;
  }

  Future<void> start() async {
    _initializing = store.bindOwner();
    await _initializing;
    if (_stopped) return;
    await sync();
    _schedule();
  }

  Future<void> resume() async {
    _stopped = false;
    await start();
  }

  void _schedule() {
    _timer?.cancel();
    if (_stopped) return;
    final seconds = _failures == 0
        ? 20
        : (5 * (1 << _failures.clamp(0, 4))).clamp(10, 80);
    _timer = Timer(Duration(seconds: seconds), () async {
      await sync();
      _schedule();
    });
  }

  Future<void> sync() {
    if (_stopped) return Future.value();
    if (_flight != null) {
      _again = true;
      return _flight!;
    }
    late Future<void> future;
    future = _run().whenComplete(() {
      if (identical(_flight, future)) _flight = null;
    });
    _flight = future;
    return future;
  }

  Future<void> _run() async {
    do {
      _again = false;
      state = SyncState.working;
      message = null;
      _notify();
      try {
        await _capture();
        if (_stopped) break;
        final s = await session();
        if (s.uid != store.owner) {
          throw const AccountFailure(
            'owner_mismatch',
            'Phiên đăng nhập không thuộc kho dữ liệu này.',
          );
        }
        await gateway.provision(s);
        if (_stopped) break;
        if (!_registered) {
          await gateway.registerDevice(s, deviceId, deviceName);
          _registered = true;
        }
        final primary = await gateway.primary(s);
        if (_stopped) break;
        primaryHere = primary?.id == deviceId;
        await onPrimary?.call(primaryHere);
        final remote = await gateway.fetchAll(s);
        if (_stopped) break;
        await store.pull(remote);
        // Ruleset conflict resolution may preserve disabled historical segments.
        await _capture();
        for (final mutation in await store.pending()) {
          if (_stopped) break;
          if (await store.blocked(mutation.record)) continue;
          try {
            final version = await gateway.write(
              s,
              mutation.record,
              expectedVersion: await store.version(mutation.record.key),
            );
            // Always acknowledge a completed write, including during shutdown.
            // This only clears the exact mutation that was sent.
            await store.acknowledge(mutation, version);
          } on AccountFailure catch (e) {
            if (![
              'FAILED_PRECONDITION',
              'ALREADY_EXISTS',
              'ABORTED',
            ].contains(e.code)) {
              rethrow;
            }
            final current = await gateway.fetch(s, mutation.record.key);
            await store.failedWrite(mutation, current);
          }
        }
        _failures = 0;
        pendingCount = (await store.pending()).length;
        conflictCount = (await store.conflicts()).length;
        state = conflictCount > 0 ? SyncState.attention : SyncState.idle;
        if (pendingCount == 0 && conflictCount == 0 && !localChanges) {
          lastSynced = DateTime.now().toUtc();
        }
        if (!_stopped) await onChanged?.call();
      } on AccountFailure catch (e) {
        _failures++;
        message = e.message;
        state = e.retryable ? SyncState.offline : SyncState.attention;
        pendingCount = (await store.pending()).length;
        if (e.code == 'account_deleted') {
          primaryHere = false;
          await onPrimary?.call(false);
        }
        _again = false;
      } catch (_) {
        // Never log tokens, payloads, private task text or raw server responses.
        message = 'Chưa đồng bộ được. Dữ liệu trên thiết bị vẫn được giữ.';
        state = SyncState.attention;
        _again = false;
      }
      if (!_stopped) _notify();
    } while (_again && !_stopped);
  }

  Future<void> _exclusive(Future<void> Function() action) {
    final previous = _flight;
    late Future<void> job;
    job =
        Future(() async {
          try {
            await previous;
          } catch (_) {
            /* The caller of the previous command receives its error. */
          }
          if (!_stopped) await action();
        }).whenComplete(() {
          if (identical(_flight, job)) {
            _flight = null;
            if (_again && !_stopped) unawaited(sync());
          }
        });
    _flight = job;
    return job;
  }

  Future<void> claimPrimary() => _exclusive(() async {
    final s = await session();
    final old = await gateway.primary(s);
    await gateway.claimPrimary(s, deviceId, expectedVersion: old?.version);
    primaryHere = true;
    await onPrimary?.call(true);
    if (!_stopped) _notify();
  });

  Future<void> resolve(String id, {required bool keepLocal}) =>
      _exclusive(() async {
        await store.resolve(id, keepLocal: keepLocal);
        await _run();
      });

  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    try {
      await _initializing;
    } catch (_) {
      /* Initialization failure does not prevent closing. */
    }
    try {
      await _flight;
    } catch (_) {
      /* Command errors must not prevent logout. */
    }
    state = SyncState.stopped;
  }

  void dispose() {
    _stopped = true;
    _timer?.cancel();
    unawaited(_updates.close());
  }
}
