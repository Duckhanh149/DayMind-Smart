"""Bound and diagnose the Android integration runner on a synthetic CI emulator.

This runs after the separate cold-process OS notification test. Force-stop here
starts a fresh debug session, preserves SQLite, and is not used to simulate
background reminder delivery.
"""
from collections import deque
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'dev.daymind.daymind_smart'


def sanitized(text):
    text = re.sub(r'(?i)(Bearer\s+)\S+', r'\1[redacted]', text)
    text = re.sub(
        r'(?i)("(?:idToken|refreshToken|password|id_token|refresh_token)"\s*:\s*)"(?:\\.|[^"\\])*"',
        r'\1"[redacted]"', text)
    return re.sub(
        r'((?:https?|wss?)://(?:127\.0\.0\.1|localhost|10\.0\.2\.2)(?::\d+)?)/[^\s\]\)"<>]+',
        r'\1/[local-path]', text)


def diagnostic(device):
    commands = [
        ['adb', '-s', device, 'get-state'],
        ['adb', '-s', device, 'shell', 'pidof', PACKAGE],
        ['adb', '-s', device, 'forward', '--list'],
        ['adb', '-s', device, 'logcat', '-d', '-t', '200', '-s', 'AndroidRuntime:E', 'flutter:V'],
    ]
    for command in commands:
        try:
            result = subprocess.run(command, capture_output=True, text=True,
                                    errors='replace', timeout=15, check=False)
            print('DIAGNOSTIC:', ' '.join(command), flush=True)
            print(sanitized(result.stdout + result.stderr), flush=True)
        except (OSError, subprocess.TimeoutExpired) as error:
            print('DIAGNOSTIC unavailable:', type(error).__name__, flush=True)


def stop_group(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=5)


def run_bounded(command, deadline, required=()):
    """A zero exit is insufficient without the expected native assertions."""
    seen = set()
    tail = deque(maxlen=40)
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, errors='replace',
                               start_new_session=True)

    def output():
        for line in process.stdout:
            clean = sanitized(line)
            tail.append(clean)
            for marker in required:
                if marker in clean:
                    seen.add(marker)
            print(clean, end='', flush=True)

    reader = threading.Thread(target=output, daemon=True)
    reader.start()
    try:
        code = process.wait(timeout=deadline)
    except subprocess.TimeoutExpired:
        print(f'NATIVE_INTEGRATION_TIMEOUT: exceeded {deadline}s; stopping the test process group.', flush=True)
        stop_group(process)
        code = 124
    except BaseException:
        stop_group(process)
        raise
    reader.join(timeout=5)
    if code == 0:
        missing = set(required) - seen
        if missing:
            print('NATIVE_INTEGRATION_MISSING_ASSERTIONS:', ', '.join(sorted(missing)), flush=True)
            return 1
    return code


def main():
    device = os.environ.get('ANDROID_SERIAL', 'emulator-5554')
    # The prior OS alarm smoke has finished. Keep its local database for the
    # native account-isolation checks while replacing the old debug process.
    subprocess.run(['adb', '-s', device, 'shell', 'am', 'force-stop', PACKAGE],
                   check=True, timeout=30)
    subprocess.run(['adb', '-s', device, 'logcat', '-c'], check=True, timeout=30)
    command = ['flutter', '--verbose', 'test', 'integration_test/app_smoke_test.dart',
               '--no-pub', '-d', device, '--dart-define=RUN_ACCOUNT_EMULATOR=true']
    code = run_bounded(command, 600, required=(
        'SECURE_STORAGE_POC:', 'RECURRENCE_POC:', 'COMPANION_RESOURCE_POC:', 'ANIMATION_RESOURCE_POC:', 'MAX_ATLAS_RESOURCE_POC:', 'ACCOUNT_NATIVE_POC:',
    ))
    if code:
        diagnostic(device)
    return code


if __name__ == '__main__':
    sys.exit(main())
