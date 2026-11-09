"""Retry only known transient SQLite release-asset HTTP failures, never app/test failures."""
import re
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')
for attempt in range(3):
    lines = []
    with subprocess.Popen(sys.argv[1:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          shell=os.name == 'nt', text=True, encoding='utf-8', errors='replace') as process:
        for line in process.stdout:
            print(line, end='', flush=True)
            lines.append(line)
        status = process.wait()
    output = ''.join(lines)
    if status == 0:
        sys.exit(0)
    if not ('sqlite3' in output and 'pre-compiled SQLite library' in output and
            re.search(r'Unexpected response code: (502|503|504)', output)):
        sys.exit(status)
    if attempt < 2:
        print(f'SQLite asset server returned a transient HTTP error; retry {attempt + 1}/2.', flush=True)
sys.exit(status)
