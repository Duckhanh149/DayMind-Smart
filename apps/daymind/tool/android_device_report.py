"""Read-only physical Android metadata/resource capture, fixed schema, no raw dumps."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

PACKAGE = 'dev.daymind.daymind_smart'

def parse_memory(text):
    pss = re.findall(r'TOTAL PSS:\s*(\d+)', text)
    if not pss:
        pss = re.findall(r'^\s*TOTAL\s+(\d+)', text, re.M)
    rss = re.findall(r'TOTAL RSS:\s*(\d+)', text)
    return {'pssKiB': sum(map(int,pss)) if pss else None, 'rssKiB': sum(map(int,rss)) if rss else None}

def parse_cpu(text):
    matches = re.findall(r'^\s*([0-9.]+)%\s+\d+/' + re.escape(PACKAGE) + r'(?::reminders)?:', text, re.M)
    return sum(float(x) for x in matches) if matches else None

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scenario', choices=['foreground','tray','batterySaver','doze','dnd','afterReboot','upgrade'], required=True)
    parser.add_argument('--seconds', type=int, default=120)
    args = parser.parse_args()
    if not 30 <= args.seconds <= 1800:
        parser.error('seconds must be between 30 and 1800')
    def adb(*command):
        try:
            result = subprocess.run(['adb','-s',args.serial,'shell',*command],capture_output=True,text=True,timeout=15)
            return result.stdout if result.returncode == 0 else ''
        except (OSError,subprocess.TimeoutExpired):
            return ''
    api = adb('getprop','ro.build.version.sdk').strip()
    saver = adb('settings','get','global','low_power').strip()
    idle = adb('dumpsys','deviceidle','get','deep').strip()
    samples = []
    watch = time.monotonic()
    while time.monotonic()-watch < args.seconds:
        samples.append({'elapsedSeconds': round(time.monotonic()-watch,2),
                        **parse_memory(adb('dumpsys','meminfo',PACKAGE)),
                        'cpuPercentOsWindow': parse_cpu(adb('dumpsys','cpuinfo',PACKAGE))})
        time.sleep(2)
    report = {'schema':1,'scenario':args.scenario,'apiLevel':int(api) if api.isdigit() else None,
              'physicalAcceptanceComplete':False,
              'batterySaver':saver=='1' if saver in ('0','1') else None,
              'deviceIdle':idle if idle in {'ACTIVE','INACTIVE','IDLE_PENDING','SENSING','LOCATING','IDLE','IDLE_MAINTENANCE'} else 'unknown',
              'notificationVisibility':'not_observed_by_tool','dataRetention':'not_verified_by_tool',
              'cpuScope':'Android OS sampling window; main and private reminders process when reported',
              'samples':samples}
    try:
        args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    except OSError:
        print(json.dumps({'saved':False,'code':'output_unavailable'})); return 1
    print(json.dumps({'saved':True,'samples':len(samples),'physicalAcceptanceComplete':False}))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
