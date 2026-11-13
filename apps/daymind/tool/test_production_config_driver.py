import unittest
from validate_firebase_production import validate
from android_device_report import parse_memory, parse_cpu

class ProductionConfigGuards(unittest.TestCase):
    def test_service_account_or_arbitrary_backend_never_accepted_as_client_config(self):
        good={'DAYMIND_FIREBASE_MODE':'production','DAYMIND_FIREBASE_PROJECT':'daymind-production','DAYMIND_FIREBASE_API_KEY':'AIza'+'a'*35}
        validate(good)
        for value in [{**good,'private_key':'SENSITIVE_SENTINEL'},{**good,'endpoint':'http://localhost:8180'},{**good,'DAYMIND_FIREBASE_PROJECT':'demo-daymind'},{**good,'DAYMIND_FIREBASE_MODE':'emulator'}]:
            with self.assertRaises(ValueError) as error:validate(value)
            self.assertNotIn('SENSITIVE_SENTINEL',str(error.exception))

    def test_physical_capture_extracts_only_numeric_resources(self):
        raw='User email private@example.invalid path /private/user TASK_TITLE\n TOTAL PSS: 1234 TOTAL RSS: 5678\n 12.5% 999/dev.daymind.daymind_smart: foo\n 1.5% 888/dev.daymind.daymind_smart:reminders: bar\n 99% 777/private.other.app: bad'
        self.assertEqual(parse_memory(raw),{'pssKiB':1234,'rssKiB':5678})
        self.assertEqual(parse_cpu(raw),14.0)
        self.assertEqual(parse_memory('permission denied'),{'pssKiB':None,'rssKiB':None})
        self.assertIsNone(parse_cpu('unknown'))

if __name__=='__main__':unittest.main()
