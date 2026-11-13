import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const device = process.platform === 'win32' ? 'windows' : 'emulator-5554';
const soak = process.env.DAYMIND_RESOURCE_SOAK === 'true';
const windowsTarget = soak
  ? ['drive', '--profile', '--no-dds', '--no-devtools', '--no-pub', '--driver=test_driver/native_integration.dart', '--target=integration_test/app_smoke_test.dart']
  : ['test', 'integration_test/app_smoke_test.dart'];
const args = process.platform === 'win32' ? ['tool/retry_native_assets.py', 'flutter', ...windowsTarget,
  '-d', device, '--dart-define=RUN_ACCOUNT_EMULATOR=true'] : ['tool/android_native_integration.py'];
if (process.platform === 'win32' && soak) args.push('--dart-define=RUN_RESOURCE_SOAK=true', `--dart-define=DAYMIND_RESOURCE_SOAK_SECONDS=${process.env.DAYMIND_RESOURCE_SOAK_SECONDS || '120'}`);
const result = spawnSync('python', args,
  { cwd: root, stdio: 'inherit', env: process.env, timeout: 20*60*1000, shell: process.platform === 'win32' });
process.exit(result.status === 0 && !result.error ? 0 : result.status || 1);
