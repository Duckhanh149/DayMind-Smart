"""Precache the exact upstream sqlite3 3.9.1 assets through GitHub's release API.

Some proxies return HTTP504 for browser download URLs. No mirror or alternate
binary is used: the pinned package's SHA256 is checked here AND by its own hook.
Actions uses its built-in read token for API quota; no token follows an asset
redirect. TLS, binary versions and checksum verification remain unchanged.
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import platform
import re
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname

from upstream_github import download

config_path = Path('.dart_tool/package_config.json').resolve()
config = json.loads(config_path.read_text())
package = next(p for p in config['packages'] if p['name'] == 'sqlite3')
root_uri = urljoin(config_path.as_uri(), package['rootUri'])
assert urlparse(root_uri).scheme == 'file'
package_root = Path(url2pathname(urlparse(root_uri).path))
assert re.search(r'^version:\s*3\.9\.1\s*$', (package_root / 'pubspec.yaml').read_text(), re.M)
hashes = dict(re.findall(r"'([^']+)':\s*'([a-f0-9]{64})'", (package_root / 'lib/src/hook/asset_hashes.dart').read_text()))
base = 'https://api.github.com/repos/simolus3/sqlite3.dart/releases'


release = json.loads(download(f'{base}/tags/sqlite3-3.9.1', 'application/vnd.github+json'))
assert release['tag_name'] == 'sqlite3-3.9.1'
assets = {a['name']: a['id'] for a in release['assets']}
names = ['sqlite3.x64.windows.dll'] if platform.system() == 'Windows' else [
    'libsqlite3.x64.linux.so', 'libsqlite3.arm64.android.so', 'libsqlite3.x64.android.so']


def cache(name):
    expected = hashes[name]
    target_name = 'sqlite3.dll' if name.endswith('.dll') else 'libsqlite3.so'
    target = Path('.dart_tool/hooks_runner/shared/sqlite3/build') / f'download-{expected[:8]}' / target_name
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
        return f'PASS cached checksum: {name}'
    data = download(f'{base}/assets/{assets[name]}', 'application/octet-stream')
    assert hashlib.sha256(data).hexdigest() == expected, f'Checksum mismatch: {name}'
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + '.precache-tmp')
    temporary.write_bytes(data)
    temporary.replace(target)
    return f'PASS upstream release API + checksum: {name}'


with ThreadPoolExecutor(max_workers=3) as pool:
    for result in pool.map(cache, names):
        print(result, flush=True)
