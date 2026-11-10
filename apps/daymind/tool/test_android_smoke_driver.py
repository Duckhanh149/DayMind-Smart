"""Keep cold-process evidence strict when ADB itself fails; no emulator needed."""
import contextlib
import io
import subprocess
import unittest
from unittest.mock import patch

import android_reminder_smoke as smoke


class ColdProcessEvidence(unittest.TestCase):
    def test_missing_process_requires_pidof_empty_status_one(self):
        missing = subprocess.CompletedProcess([], 1, '', '')
        with patch.object(smoke, 'adb') as adb, patch.object(smoke.subprocess, 'run', return_value=missing) as run:
            self.assertTrue(smoke.kill_and_check())
        adb.assert_called_once_with('shell', 'am', 'kill', smoke.PACKAGE)
        self.assertEqual(run.call_args.args[0][:3], ['adb', '-s', smoke.DEVICE])

    def test_present_process_is_not_cold(self):
        present = subprocess.CompletedProcess([], 0, '1234\n', '')
        with patch.object(smoke, 'adb'), patch.object(smoke.subprocess, 'run', return_value=present):
            self.assertFalse(smoke.kill_and_check())

    def test_adb_offline_is_never_counted_as_a_terminated_process(self):
        offline = subprocess.CompletedProcess([], 1, '', 'adb: device offline')
        with patch.object(smoke, 'adb'), patch.object(smoke.subprocess, 'run', return_value=offline), \
                patch.object(smoke, 'diagnostic') as diagnostic, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(subprocess.CalledProcessError):
                smoke.kill_and_check()
        diagnostic.assert_called_once_with(smoke.DEVICE)

    def test_dump_failure_is_diagnosed_sanitized_and_never_retried(self):
        failed = subprocess.CompletedProcess([], 255, '', 'Bearer synthetic_marker')
        output = io.StringIO()
        with patch.object(smoke.subprocess, 'run', return_value=failed) as run, \
                patch.object(smoke, 'diagnostic') as diagnostic, contextlib.redirect_stdout(output):
            with self.assertRaises(subprocess.CalledProcessError):
                smoke.adb('shell', 'dumpsys', 'notification', '--noredact')
        self.assertEqual(run.call_count, 1)
        diagnostic.assert_called_once_with(smoke.DEVICE)
        self.assertIn('255', output.getvalue())
        self.assertNotIn('synthetic_marker', output.getvalue())

    def test_transport_timeout_remains_a_failure(self):
        with patch.object(smoke.subprocess, 'run', side_effect=subprocess.TimeoutExpired('adb', 40)), \
                patch.object(smoke, 'diagnostic') as diagnostic:
            with self.assertRaises(subprocess.TimeoutExpired):
                smoke.adb('shell', 'dumpsys', 'notification', '--noredact')
        diagnostic.assert_called_once_with(smoke.DEVICE)


if __name__ == '__main__':
    unittest.main()
