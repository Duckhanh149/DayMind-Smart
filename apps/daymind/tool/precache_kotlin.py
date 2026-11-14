"""Cache pinned official Kotlin compiler artifacts when browser asset URLs fail.

JAR checksums are the upstream GitHub release digests; POM checksums are from
Maven Central. The generated local repository is exclusive to this module.
No SDK files, Maven binaries, TLS or version constraints are patched.
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import os
from pathlib import Path
import shutil
from urllib.request import Request, urlopen

ARTIFACTS = [
    ('2.2.21', 587847942, '9588fa696ac5507af764fd5660df6894185e12704ec1bc3f5cb772af4987f295',
     '0b33c64f2622ba3bc8283378bdb7505f2be330a2275807038ad54359b33ddf9b'),
    ('2.4.0', 587835542, 'c2b25e8c1c93ec416ba4327f5e31eaec0f0c8847241b9353e294b8db9dce564f',
     'f5d78540108e7bbc9162253ce52c42507ead2e530945213dd2a3b793b590c53c'),
]
root = Path('.dart_tool/verified-maven').resolve()
gradle_cache = Path(os.environ.get('GRADLE_USER_HOME', str(Path.home() / '.gradle')))


def fetch(url, accept='application/octet-stream'):
    request = Request(url, headers={'Accept': accept, 'User-Agent': 'DayMind verified Kotlin precache'})
    with urlopen(request, timeout=90) as response:
        return response.read()


def cache(item):
    version, asset, jar_hash, pom_hash = item
    name = f'kotlin-compiler-embeddable-{version}'
    directory = root / 'org/jetbrains/kotlin/kotlin-compiler-embeddable' / version
    directory.mkdir(parents=True, exist_ok=True)
    jar = directory / f'{name}.jar'
    existing = gradle_cache / 'caches/modules-2/files-2.1/org.jetbrains.kotlin/kotlin-compiler-embeddable' / version
    if not jar.exists() or hashlib.sha256(jar.read_bytes()).hexdigest() != jar_hash:
        local = next((p for p in existing.glob('*/*.jar') if hashlib.sha256(p.read_bytes()).hexdigest() == jar_hash), None)
        if local:
            shutil.copyfile(local, jar)
        else:
            data = fetch(f'https://api.github.com/repos/JetBrains/kotlin/releases/assets/{asset}')
            assert hashlib.sha256(data).hexdigest() == jar_hash, f'Invalid JAR: {version}'
            jar.write_bytes(data)
    pom = fetch(f'https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-compiler-embeddable/{version}/{name}.pom', 'application/xml')
    assert hashlib.sha256(pom).hexdigest() == pom_hash, f'Invalid POM: {version}'
    (directory / f'{name}.pom').write_bytes(pom)
    return f'PASS official JAR/POM checksums: Kotlin compiler {version}'


with ThreadPoolExecutor(max_workers=2) as pool:
    for result in pool.map(cache, ARTIFACTS):
        print(result, flush=True)

init = gradle_cache / 'init.d/daymind-verified-kotlin.gradle'
init.parent.mkdir(parents=True, exist_ok=True)
init.write_text('''
def verifiedPath = System.getenv('DAYMIND_VERIFIED_MAVEN')
if (verifiedPath != null) {
    def addVerified = { repositories ->
        repositories.exclusiveContent {
            forRepository {
                repositories.maven { name = 'DayMindVerifiedKotlin'; url = new File(verifiedPath).toURI() }
            }
            filter {
                includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.2.21')
                includeVersion('org.jetbrains.kotlin', 'kotlin-compiler-embeddable', '2.4.0')
            }
        }
    }
    gradle.settingsEvaluated { settings ->
        addVerified(settings.dependencyResolutionManagement.repositories)
        if (settings.dependencyResolutionManagement.repositoriesMode.get().toString() != 'FAIL_ON_PROJECT_REPOS') {
            gradle.beforeProject { project -> addVerified(project.repositories) }
        }
    }
}
''', encoding='utf-8')
if 'GITHUB_ENV' in os.environ:
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
        output.write(f'DAYMIND_VERIFIED_MAVEN={root}\n')
print('Verified repository configured; set DAYMIND_VERIFIED_MAVEN to its absolute path for local Gradle commands.')
