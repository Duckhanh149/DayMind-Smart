import plistlib
import tempfile
import unittest
from pathlib import Path
from verify_ios_simulator import simulator_bundle_id


class SimulatorVerificationBoundary(unittest.TestCase):
    def validate(self, platform, supported, bundle='dev.daymind.daymindSmart'):
        with tempfile.TemporaryDirectory() as temp:
            app = Path(temp)
            with (app / 'Info.plist').open('wb') as stream:
                plistlib.dump({'DTPlatformName': platform,
                               'CFBundleSupportedPlatforms': supported,
                               'CFBundleIdentifier': bundle}, stream)
            return simulator_bundle_id(app)

    def test_device_and_macos_bundles_are_rejected(self):
        for platform, supported in [('iphoneos', ['iPhoneOS']), ('macosx', ['MacOSX']),
                                    ('iphonesimulator', ['iPhoneOS'])]:
            with self.assertRaises(ValueError):
                self.validate(platform, supported)

    def test_missing_or_malformed_bundle_identifier_is_rejected(self):
        for bundle in ['', 'bad/id', '$(BUNDLE_ID)', 'dev.daymind\n']:
            with self.assertRaises(ValueError):
                self.validate('iphonesimulator', ['iPhoneSimulator'], bundle)

    def test_valid_simulator_metadata_is_accepted(self):
        self.assertEqual(self.validate('iphonesimulator', ['iPhoneSimulator']),
                         'dev.daymind.daymindSmart')


if __name__ == '__main__':
    unittest.main()
