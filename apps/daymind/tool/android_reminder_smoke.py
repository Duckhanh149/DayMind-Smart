"""Android emulator test: cold process, obsolete revision, quiet hours, restart backlog.

Only uses the debug fixture endpoint. No production app data or cloud service.
"""
import base64
import json
import re
import subprocess
import time

PACKAGE = 'dev.daymind.daymind_smart'


def adb(*args):
    result = subprocess.run(['adb', *args], check=True, capture_output=True, text=True, timeout=40)
    return result.stdout


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
    result = subprocess.run(['adb', 'shell', 'pidof', PACKAGE], capture_output=True, text=True, timeout=10)
    return not result.stdout.strip()


adb('install', '-r', 'build/app/outputs/flutter-apk/app-debug.apk')
adb('shell', 'pm', 'grant', PACKAGE, 'android.permission.POST_NOTIFICATIONS')
adb('shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
until(lambda: fixture('ready').get('ready'), 90, 'Flutter opens SQLite and initializes native path')
fixture('seed')
cold_close()
# The process was absent at the scheduled time. Read-only adb dumps do not start it.
until(lambda: 'DayMind device smoke cold' in adb('shell', 'dumpsys', 'notification', '--noredact'),
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
