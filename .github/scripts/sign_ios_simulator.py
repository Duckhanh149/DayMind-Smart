"""Ad-hoc identity for disposable iOS Simulator builds; never signs device apps.

An unsigned Simulator app cannot access Keychain on recent runtimes (-34018).
Real iPhone signing remains Xcode/Personal Team work; no Apple credentials here.
"""
import argparse
import json
import plistlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def simulator_bundle_id(app):
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if (info.get('DTPlatformName') != 'iphonesimulator'
            or info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']):
        raise ValueError('Refusing to sign: this is not an iOS Simulator app')
    bundle = info.get('CFBundleIdentifier', '')
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
        raise ValueError('Invalid simulator bundle identifier')
    return bundle


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Requires macOS codesign and an iOS Simulator build')
    app = args.app.resolve(strict=True)
    bundle = simulator_bundle_id(app)
    entitlements = {'application-identifier': bundle,
                    'keychain-access-groups': [bundle], 'get-task-allow': True}
    # Sign nested binaries first, with no app entitlements on libraries.
    nested = [*app.rglob('*.dylib'), *app.rglob('*.framework'), *app.rglob('*.xctest')]
    for path in sorted(nested, key=lambda p: len(p.parts), reverse=True):
        subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none', str(path)], check=True)
    with tempfile.TemporaryDirectory(prefix='daymind-simulator-') as temp:
        path = Path(temp) / 'entitlements.plist'
        with path.open('wb') as stream:
            plistlib.dump(entitlements, stream)
        subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none',
                        '--entitlements', str(path), str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(json.dumps({'bundle': bundle, 'platform': 'iPhoneSimulator',
                                       'identity': 'ad-hoc (not an iPhone signing identity)',
                                       'entitlements': entitlements}, indent=2) + '\n')
    print('Verified ad-hoc Simulator identity; real-device signing is still pending.')


if __name__ == '__main__':
    main()
