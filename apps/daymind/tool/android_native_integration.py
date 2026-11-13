"""Bound and diagnose the Android integration runner on a synthetic CI emulator.

This runs after the separate cold-process OS notification test. Force-stop here
starts a fresh debug session, preserves SQLite, and is not used to simulate
background reminder delivery.
"""
from collections import deque
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time
from urllib.parse import urlencode, urlparse
from urllib.request import ProxyHandler, build_opener

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


def observe_vm_uri(discovery, line):
    # Keep authenticated service paths private. Without DDS, map the device VM
    # URL to the host port that Flutter actually forwarded through adb.
    direct = re.search(r'VM Service URL on device: (http://127\.0\.0\.1:\d+/[^\s,]+)', line)
    if direct:
        discovery['deviceVm'] = direct.group(1)
    forwarded = re.search(r'Forwarded host port (\d+) to device port (\d+) for VM Service', line)
    if forwarded and discovery.get('deviceVm'):
        parsed = urlparse(discovery['deviceVm'])
        host_port, device_port = map(int, forwarded.groups())
        if parsed.port == device_port and 1 <= host_port <= 65535:
            discovery['vm'] = parsed._replace(netloc=f'127.0.0.1:{host_port}').geturl()
    dds = re.search(r'Dart Development Service started at (http://(?:127\.0\.0\.1|localhost):\d+/[^\s,]+)', line)
    if dds:
        discovery['vm'] = dds.group(1)


def diagnostic(device, vm_uri=None):
    commands = [
        ['adb', '-s', device, 'get-state'],
        ['adb', '-s', device, 'shell', 'pidof', PACKAGE],
        ['adb', '-s', device, 'forward', '--list'],
        ['adb', '-s', device, 'logcat', '-d', '-t', '4000', '-s', 'AndroidRuntime:E', 'flutter:V'],
    ]
    for command in commands:
        try:
            result = subprocess.run(command, capture_output=True, text=True,
                                    errors='replace', timeout=15, check=False)
            print('DIAGNOSTIC:', ' '.join(command), flush=True)
            print(sanitized(result.stdout + result.stderr), flush=True)
        except (OSError, subprocess.TimeoutExpired) as error:
            print('DIAGNOSTIC unavailable:', type(error).__name__, flush=True)
    if vm_uri:
        try:
            parsed = urlparse(vm_uri)
            if parsed.scheme != 'http' or parsed.hostname not in ('127.0.0.1', 'localhost'):
                return
            opener = build_opener(ProxyHandler({}))
            def rpc(method, params=None):
                url = vm_uri.rstrip('/') + '/' + method
                if params:
                    url += '?' + urlencode(params)
                with opener.open(url, timeout=5) as response:
                    return json.loads(response.read(1024 * 1024))['result']
            vm = rpc('getVM')
            for ref in vm.get('isolates', [])[:8]:
                isolate = rpc('getIsolate', {'isolateId':ref['id']})
                root = isolate.get('rootLib', {}).get('uri', '')
                extensions = isolate.get('extensionRPCs', [])
                print('VM_DISCOVERY_DIAGNOSTIC:', json.dumps({
                    'rootFile':urlparse(root).path.replace('\\','/').rsplit('/',1)[-1],
                    'pauseKind':isolate.get('pauseEvent',{}).get('kind'),
                    'runnable':isolate.get('runnable'),
                    'integrationExtension':'ext.flutter.integrationTest' in extensions,
                    'extensionCount':len(extensions),
                    'exceptionClass':isolate.get('pauseEvent',{}).get('exception',{}).get('class',{}).get('name'),
                }), flush=True)
                if isolate.get('pauseEvent',{}).get('kind') == 'PauseException':
                    stack = rpc('getStack', {'isolateId':ref['id'],'limit':3})
                    frames = [{
                        'function':frame.get('function',{}).get('name'),
                        'file':urlparse(frame.get('location',{}).get('script',{}).get('uri','')).path.replace('\\','/').rsplit('/',1)[-1],
                    } for frame in stack.get('frames',[])[:3]]
                    print('VM_DISCOVERY_STACK:',json.dumps(frames),flush=True)
        except Exception as error:
            print('VM_DISCOVERY_DIAGNOSTIC unavailable:', type(error).__name__, flush=True)


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


def run_bounded(command, deadline, required=(), device=None):
    """A zero exit is insufficient without the expected native assertions."""
    seen = set()
    tail = deque(maxlen=40)
    discovery = {'at':None, 'vm':None, 'started':False}
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, errors='replace',
                               start_new_session=True)

    def output():
        for line in process.stdout:
            observe_vm_uri(discovery, line)
            if discovery['at'] is None and discovery['vm']:
                discovery['at'] = time.monotonic()
            if 'Finding the correct isolate with the integration test service extension' in line:
                discovery['at'] = time.monotonic()
            if 'NATIVE_INTEGRATION_STAGE:' in line:
                discovery['started'] = True
            clean = sanitized(line)
            tail.append(clean)
            for marker in required:
                if marker in clean:
                    seen.add(marker)
            print(clean, end='', flush=True)

    reader = threading.Thread(target=output, daemon=True)
    reader.start()
    try:
        end = time.monotonic() + deadline
        diagnosed = False
        while True:
            try:
                code = process.wait(timeout=min(5,max(.1,end-time.monotonic())))
                break
            except subprocess.TimeoutExpired:
                now = time.monotonic()
                waiting = now - discovery['at'] if discovery['at'] else 0
                if device and waiting > 45 and not discovery['started'] and not diagnosed:
                    diagnostic(device, discovery['vm'])
                    diagnosed = True
                if waiting > 120 and not discovery['started']:
                    print('NATIVE_DISCOVERY_TIMEOUT: no integration extension/test entry after 120s; zero tests cannot pass.',flush=True)
                    stop_group(process)
                    code = 125
                    break
                if now >= end:
                    raise
    except subprocess.TimeoutExpired:
        print(f'NATIVE_INTEGRATION_TIMEOUT: exceeded {deadline}s; stopping the test process group.', flush=True)
        if device:
            diagnostic(device, discovery['vm']) # Before Flutter cleanup force-stops the app.
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
    # flutter test --no-dds registers a golden-comparator stream which the direct
    # VM cannot provide in this pinned SDK. The SDK's official drive adapter
    # runs the same suite, preserves assertion failures and avoids that listener.
    command = ['flutter', '--verbose', 'drive', '--no-dds', '--no-devtools',
               '--driver=test_driver/native_integration.dart',
               '--target=integration_test/app_smoke_test.dart',
               '--no-pub', '-d', device, '--dart-define=RUN_ACCOUNT_EMULATOR=true']
    soak = os.environ.get('DAYMIND_RESOURCE_SOAK') == 'true'
    if soak:
        command += ['--dart-define=RUN_RESOURCE_SOAK=true', '--dart-define=DAYMIND_RESOURCE_SOAK_SECONDS=' + os.environ.get('DAYMIND_RESOURCE_SOAK_SECONDS','120')]
    code = run_bounded(command, 1200 if soak else 600, device=device, required=((('RESOURCE_SOAK_POC:',) if soak else ()) + (
        'SECURE_STORAGE_POC:', 'SCOPED_SESSION_POC:', 'RECURRENCE_POC:', 'COMPANION_RESOURCE_POC:', 'ANIMATION_RESOURCE_POC:', 'MAX_ATLAS_RESOURCE_POC:', 'ACCOUNT_NATIVE_POC:', 'ACCOUNT_ARTWORK_POC:', 'BACKUP_NATIVE_POC:', 'ANDROID_SQLITE_ISOLATION_POC:',
    )))
    if code:
        diagnostic(device)
    return code


if __name__ == '__main__':
    sys.exit(main())
