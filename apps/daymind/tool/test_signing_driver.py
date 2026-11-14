"""Release signing fails closed and never writes credentials into an artifact."""
import base64
import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import production_signing as signing


class SigningGuards(unittest.TestCase):
    def test_missing_configuration_prevents_store_creation(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "Missing GitHub"):
                signing.prepare_android()

    def test_public_fingerprint_must_be_full_sha256(self):
        with patch.dict(os.environ, {"TEST_CERT": "ab:cd"}):
            with self.assertRaises(ValueError):
                signing.fingerprint("TEST_CERT")

    def test_temporary_store_is_private_and_cleanup_removes_only_its_fixed_path(self):
        with tempfile.TemporaryDirectory() as root:
            env = {"RUNNER_TEMP": root, "GITHUB_ENV": str(Path(root) / "environment"),
                   "DAYMIND_ANDROID_KEYSTORE_BASE64": base64.b64encode(b"synthetic-not-a-real-key" * 10).decode(),
                   "DAYMIND_ANDROID_KEY_ALIAS": "synthetic", "DAYMIND_ANDROID_STORE_PASSWORD": "synthetic-fixture",
                   "DAYMIND_ANDROID_KEY_PASSWORD": "synthetic-fixture", "DAYMIND_ANDROID_CERT_SHA256": "a" * 64}
            keep = Path(root) / "keep"; keep.write_text("keep")
            with patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(io.StringIO()):
                signing.prepare_android()
                store = Path(root) / "daymind-production.keystore"
                self.assertTrue(store.exists())
                if os.name != "nt":
                    self.assertEqual(store.stat().st_mode & 0o777, 0o600)
                with self.assertRaises(FileExistsError):
                    signing.prepare_android()
                signing.cleanup()
                self.assertFalse(store.exists())
                self.assertTrue(keep.exists())

    def test_bad_secret_is_not_echoed_by_cli(self):
        marker = "synthetic-private-fixture-value"
        env = {**os.environ, "DAYMIND_ANDROID_KEYSTORE_BASE64": marker,
               "DAYMIND_ANDROID_KEY_ALIAS": "synthetic", "DAYMIND_ANDROID_STORE_PASSWORD": marker,
               "DAYMIND_ANDROID_KEY_PASSWORD": marker, "DAYMIND_ANDROID_CERT_SHA256": "a" * 64}
        result = subprocess.run([sys.executable, str(Path(signing.__file__)), "prepare-android"],
                                env=env, capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(marker, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
