"""Android emulator test: cold process, obsolete revision, quiet hours, restart backlog.

Only uses the debug fixture endpoint. No production app data or cloud service.
"""
import base64
import json
import os
import re
import shlex
import subprocess
import time

from android_native_integration import diagnostic, sanitized

PACKAGE = 'dev.daymind.daymind_smart'
DEVICE = os.environ.get('ANDROID_SERIAL', 'emulator-5554')


def adb(*args):
    command = ['adb', '-s', DEVICE, *args]
    try:
        result = subprocess.run(command, check=False, capture_output=True,
                                text=True, errors='replace', timeout=40)
    except (OSError, subprocess.TimeoutExpired):
        diagnostic(DEVICE)
        raise
    if result.returncode:
        print('ADB_FAILURE:', result.returncode, 'stderr:',
              sanitized(result.stderr[-3000:]), flush=True)
        print('ADB_STDOUT_HEAD:', sanitized(result.stdout[:2000]), flush=True)
        print('ADB_STDOUT_TAIL:', sanitized(result.stdout[-2000:]), flush=True)
        diagnostic(DEVICE)  # Read-only; never retries or restarts a failed case.
        raise subprocess.CalledProcessError(result.returncode, command)
    return result.stdout


def posted_notifications():
    # Android 15 NotificationShellCmd's get dumps one NotificationRecord with
    # redact=false. List/get are read-only and never start the application.
    # Avoid dumping unrelated system ranking/settings records during startup.
    keys = adb('shell', 'cmd', 'notification', 'list').splitlines()
    records = []
    for line in keys:
        key = line.strip()
        parts = key.split('|', 2)
        if len(parts) >= 2 and parts[1] == PACKAGE:
            # adb shell joins remote arguments; quote key separators literally.
            records.append(adb('shell', 'cmd', 'notification', 'get', shlex.quote(key)))
    return '\n'.join(records)


def fixture(command='status', name='cold'):
    result = adb('shell', 'am', 'broadcast', '-n', f'{PACKAGE}/.ReminderDebugReceiver',
                 '--es', 'command', command, '--es', 'fixture', name)
    match = re.search(r'data="([A-Za-z0-9+/=]+)"', result)
    if not match:
        raise AssertionError(f'No debug fixture response: {result}')
    data = json.loads(base64.b64decode(match[1]))
    assert 'error' not in data, data
    return data


def until(predicate, seconds, label):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(2)
    raise AssertionError(f'Timeout: {label}')


def cold_close():
    adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    # am kill preserves AlarmManager registrations; force-stop would cancel them.
    until(lambda: kill_and_check(), 30, 'background application process exits')


def kill_and_check():
    adb('shell', 'am', 'kill', PACKAGE)
    command = ['adb', '-s', DEVICE, 'shell', 'pidof', PACKAGE]
    result = subprocess.run(command, capture_output=True, text=True,
                            errors='replace', timeout=10)
    if result.returncode == 0:
        return not result.stdout.strip()
    if result.returncode == 1 and not result.stdout.strip() and not result.stderr.strip():
        return True  # Android pidof reports no process with an empty status 1.
    print('ADB_PROCESS_CHECK_FAILURE:', sanitized(result.stderr[-3000:]), flush=True)
    diagnostic(DEVICE)
    raise subprocess.CalledProcessError(result.returncode, command)



def main():
    adb('install', '-r', 'build/app/outputs/flutter-apk/app-debug.apk')
    adb('shell', 'pm', 'grant', PACKAGE, 'android.permission.POST_NOTIFICATIONS')
    adb('shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
    until(lambda: fixture('ready').get('ready'), 90, 'Flutter opens SQLite and initializes native path')
    assert fixture('secure')['securePassed'] is True
    print('PASS: Android Keystore encrypted write/read/replace/delete on the actual emulator.')
    fixture('seed')
    cold_close()
    # The process was absent at the scheduled time. Read-only adb dumps do not start it.
    until(lambda: 'DayMind device smoke cold' in posted_notifications(),
          360, 'OS notification after cold process termination (inexact alarm)')
    observed = fixture()
    assert observed['state'] == 'unknown' and observed['notifications'] == 1, observed
    print('PASS: Android OS posted one notification after the application process exited.')

    fixture('seed', 'edited')
    fixture('seed', 'quiet')
    cold_close()
    until(lambda: fixture(name='edited').get('state') == 'cancelled', 360, 'obsolete event rejected')
    until(lambda: fixture(name='quiet').get('state') == 'suppressed', 360, 'quiet hours suppress event')
    assert fixture()['notifications'] <= 1
    print('PASS: edited task and quiet hours did not add notifications.')

    fixture('seed', 'past')
    fixture('recover', 'past')
    until(lambda: fixture(name='past').get('state') == 'expired', 30, 'restart recovery skips historical reminder')
    assert fixture()['notifications'] <= 1
    print('PASS: recovery did not replay a past reminder. This is not an OEM/Doze/real reboot test.')

    fixture('seed', 'digest')
    cold_close()
    until(lambda: 'Nhịp ngày mới' in posted_notifications(),
          360, 'opt-in daily digest after cold process termination')
    observed = fixture(name='digest')
    assert observed['state'] == 'unknown' and observed['digestNotifications'] == 1 and observed['digestActions'] == 0 and observed['attempts'] == 1, observed
    fixture('retime', 'digest')
    observed = fixture(name='digest')  # single native executor queues this read after recovery
    assert observed['state'] == 'unknown' and observed['attempts'] == 1, observed
    assert fixture(name='digest')['digestNotifications'] == 1
    print('PASS: opt-in digest posted after cold close, has no task actions, and time edit/recovery did not repeat it.')


if __name__ == '__main__':
    main()
