"""Run the available AGP host-test task and require actual receiver test results."""
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
android = root / 'android'
wrapper = str(android / 'gradlew')
listed = subprocess.run([wrapper, ':app:tasks', '--all', '--console=plain'], cwd=android,
                        capture_output=True, text=True, encoding='utf-8', errors='replace')
if listed.returncode:
    print(listed.stdout + listed.stderr)
    sys.exit(listed.returncode)
available = set(re.findall(r'^(test\S+(?:UnitTest|HostTest))\b', listed.stdout, re.M))
print('Available Android host tests:', ', '.join(sorted(available)), flush=True)
task = next((t for t in ['testDebugUnitTest', 'testDebugHostTest', 'testReleaseUnitTest', 'testReleaseHostTest'] if t in available), None)
if task is None:
    print(listed.stdout)
    raise SystemExit('No Android host-test task exists; refusing to claim tests passed.')
results = root / 'build/app/test-results'
for old in results.rglob('TEST-*ReminderRuntimeTest*.xml'):
    old.unlink()
status = subprocess.call([wrapper, f':app:{task}', '--no-daemon', '--console=plain',
                          '-Ptarget-platform=android-x64'], cwd=android)
if status:
    for report in results.rglob('TEST-*ReminderRuntimeTest*.xml'):
        suite=ET.parse(report).getroot()
        for failure in suite.findall('.//failure'):
            print(failure.text or failure.get('message',''),flush=True)
    sys.exit(status)
count = 0
for report in results.rglob('TEST-*ReminderRuntimeTest*.xml'):
    suite = ET.parse(report).getroot()
    assert int(suite.get('failures', 0)) == 0 and int(suite.get('errors', 0)) == 0
    count += int(suite.get('tests', 0)) - int(suite.get('skipped', 0))
assert count >= 23, f'Expected >=23 receiver tests, observed {count}; no empty-suite pass.'
print(f'PASS: {count} Android receiver/recovery tests actually executed.', flush=True)
