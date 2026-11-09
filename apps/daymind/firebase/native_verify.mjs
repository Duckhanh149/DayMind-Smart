import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const device = process.platform === 'win32' ? 'windows' : 'emulator-5554';
const args = process.platform === 'win32' ? ['tool/retry_native_assets.py', 'flutter', 'test',
  'integration_test/app_smoke_test.dart', '-d', device,
  '--dart-define=RUN_ACCOUNT_EMULATOR=true'] : ['tool/android_native_integration.py'];
const result = spawnSync('python', args,
  { cwd: root, stdio: 'inherit', env: process.env, shell: process.platform === 'win32' });
process.exit(result.status === 0 && !result.error ? 0 : result.status || 1);
