"""Precache the unchanged official Gradle distribution with its pinned SHA256."""
import hashlib
import os
from pathlib import Path
from urllib.request import Request, urlopen

VERSION = '9.3.1'
EXPECTED = 'b266d5ff6b90eada6dc3b20cb090e3731302e553a27c5d3e4df1f0d76beaff06'
properties = Path('android/gradle/wrapper/gradle-wrapper.properties').read_text()
url = next(line.split('=', 1)[1].replace('\\:', ':') for line in properties.splitlines() if line.startswith('distributionUrl='))
assert url == f'https://services.gradle.org/distributions/gradle-{VERSION}-bin.zip'
assert f'distributionSha256Sum={EXPECTED}' in properties
value = int.from_bytes(hashlib.md5(url.encode()).digest(), 'big')
key = ''
while value:
    value, digit = divmod(value, 36)
    key = '0123456789abcdefghijklmnopqrstuvwxyz'[digit] + key
cache = Path(os.environ.get('GRADLE_USER_HOME', str(Path.home() / '.gradle')))
directory = cache / f'wrapper/dists/gradle-{VERSION}-bin' / key
zip_path = directory / f'gradle-{VERSION}-bin.zip'
if (zip_path.with_suffix('.zip.ok')).exists() and (directory / f'gradle-{VERSION}/lib/gradle-launcher-{VERSION}.jar').exists():
    print(f'Gradle {VERSION} already installed in wrapper cache.')
else:
    directory.mkdir(parents=True, exist_ok=True)
    if not zip_path.exists() or hashlib.sha256(zip_path.read_bytes()).hexdigest() != EXPECTED:
        request = Request('https://api.github.com/repos/gradle/gradle-distributions/releases/assets/347704202',
                          headers={'Accept': 'application/octet-stream', 'User-Agent': 'DayMind verified Gradle precache'})
        temporary = zip_path.with_suffix('.zip.precache-tmp')
        digest = hashlib.sha256()
        with urlopen(request, timeout=90) as response, temporary.open('wb') as output:
            while block := response.read(1024 * 1024):
                digest.update(block)
                output.write(block)
        assert digest.hexdigest() == EXPECTED, 'Gradle distribution checksum mismatch'
        temporary.replace(zip_path)
    print(f'PASS official release API + checksum: Gradle {VERSION}. Wrapper will verify again.')
