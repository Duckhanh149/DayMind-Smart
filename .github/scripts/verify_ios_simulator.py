"""Read-only verification of Xcode's iOS Simulator product and embedded identity.

Simulator iOS entitlements belong in __TEXT sections, not in a macOS signature.
This script never signs or changes binaries. Real iPhone signing is separate.
"""
import argparse
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path


def simulator_bundle_id(app):
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if (info.get('DTPlatformName') != 'iphonesimulator'
            or info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']):
        raise ValueError('Refusing non-Simulator app')
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
        parser.error('Requires macOS Xcode and an iOS Simulator build')
    app = args.app.resolve(strict=True)
    bundle = simulator_bundle_id(app)
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    executable = info.get('CFBundleExecutable', '')
    if not executable or Path(executable).name != executable:
        raise ValueError('Invalid simulator executable name')
    sections = subprocess.check_output(['xcrun', 'otool', '-l', str(app / executable)], text=True)
    embedded = [name for name in ['__entitlements', '__ents_der']
                if re.search(r'sectname\s+' + name + r'\b', sections)]
    if not embedded:
        raise RuntimeError('Xcode did not embed Simulator entitlements; Keychain identity is unverified')
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(json.dumps({'bundle': bundle, 'platform': 'iPhoneSimulator',
                                       'simulator_entitlement_sections': embedded,
                                       'signing': 'Xcode-managed Simulator, no Apple account'}, indent=2) + '\n')
    print('Verified Xcode embedded Simulator entitlement sections; native Keychain test still required.')



if __name__ == '__main__':
    main()
