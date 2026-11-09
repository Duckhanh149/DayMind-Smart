import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const directory = path.dirname(fileURLToPath(import.meta.url));
for (const [command, args, cwd] of [
  [process.execPath, ['smoke.mjs'], directory],
  ['python', ['../tool/retry_native_assets.py', 'dart', 'test', '--concurrency=1', '--reporter=expanded'], path.join(path.dirname(directory), 'emulator_test')],
  ['python', ['../tool/retry_native_assets.py', 'dart', 'test', 'test/firebase_protocol_test.dart', 'test/payload_limits_test.dart', '--compiler=exe', '--concurrency=1', '--reporter=expanded'], path.join(path.dirname(directory), 'emulator_test')],
]) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', env: { ...process.env, RUN_EMULATOR: 'true' } });
  if (result.error || result.status !== 0) process.exit(result.status || 1);
}
