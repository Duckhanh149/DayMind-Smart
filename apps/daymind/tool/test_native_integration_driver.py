"""A hung/empty Android test launch must fail, with bounded and redacted output."""
import contextlib
import io
import os
import sys
import unittest
import android_native_integration as driver


class NativeLaunchGuards(unittest.TestCase):
    @unittest.skipUnless(os.name == 'posix', 'Android process groups run on the Linux CI host')
    def test_real_child_requires_its_expected_assertion_marker(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(driver.run_bounded([sys.executable,'-c',"print('SYNTHETIC_POC: passed')"],3,required=('SYNTHETIC_POC:',)),0)

    @unittest.skipUnless(os.name == 'posix', 'Android process groups run on the Linux CI host')
    def test_zero_exit_without_any_native_assertions_is_failure(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(driver.run_bounded([sys.executable,'-c','pass'],3,required=('SYNTHETIC_POC:',)),1)

    @unittest.skipUnless(os.name == 'posix', 'Android process groups run on the Linux CI host')
    def test_real_hung_child_is_stopped_and_cannot_pass(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(driver.run_bounded([sys.executable,'-c','import time;time.sleep(10)'],.1,required=('SYNTHETIC_POC:',)),124)

    def test_debug_service_auth_paths_and_tokens_are_redacted(self):
        output=driver.sanitized('http://127.0.0.1:1234/synthetic-debug-auth/ws "idToken":"synthetic-token" Bearer synthetic-bearer')
        for private in ['synthetic-debug-auth','synthetic-token','synthetic-bearer']:
            self.assertNotIn(private,output)


if __name__ == '__main__':
    unittest.main()
