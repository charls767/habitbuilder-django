import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';

const scriptPath = fileURLToPath(
  new URL('./check-reminder-boundaries.mjs', import.meta.url),
);

function withFixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'habitbuilder-boundaries-'));
  assert.ok(
    root.startsWith(tmpdir()),
    `Refusing to manage fixture outside the OS temp directory: ${root}`,
  );
  writeFixture(
    root,
    'lib/features/reminders/domain/services/safe.dart',
    'final class SafeReminderService {}\n',
  );
  writeFixture(
    root,
    'lib/features/reminders/infrastructure/notifications/adapter.dart',
    "import 'package:flutter_local_notifications/flutter_local_notifications.dart';\n",
  );
  writeFixture(
    root,
    'test/features/reminders/domain/safe_test.dart',
    "import 'package:flutter_test/flutter_test.dart';\n",
  );

  try {
    return run(root);
  } finally {
    rmSync(root, {recursive: true, force: true});
  }
}

function writeFixture(root, relativePath, content) {
  const path = join(root, ...relativePath.split('/'));
  mkdirSync(dirname(path), {recursive: true});
  writeFileSync(path, content);
}

function runGate(root, extraArgs = []) {
  return spawnSync(
    process.execPath,
    [scriptPath, '--root', root, ...extraArgs],
    {encoding: 'utf8'},
  );
}

test('passes when plugin imports stay in infrastructure and time is injected', () => {
  withFixture((root) => {
    const result = runGate(root);
    assert.equal(result.status, 0, result.stderr);
  });
});

test('fails on a plugin import in domain', () => {
  withFixture((root) => {
    writeFixture(
      root,
      'lib/features/reminders/domain/services/bad.dart',
      "import 'package:" +
        "flutter_local_notifications/flutter_local_notifications.dart';\n",
    );

    assert.notEqual(runGate(root).status, 0);
  });
});

test('fails on a plugin import in presentation', () => {
  withFixture((root) => {
    writeFixture(
      root,
      'lib/features/reminders/presentation/bad.dart',
      "import 'package:" +
        "flutter_local_notifications/flutter_local_notifications.dart';\n",
    );

    assert.notEqual(runGate(root).status, 0);
  });
});

test('fails on a plugin import in reminder tests', () => {
  withFixture((root) => {
    writeFixture(
      root,
      'test/features/reminders/bad_test.dart',
      "import 'package:" +
        "flutter_local_notifications/flutter_local_notifications.dart';\n",
    );

    assert.notEqual(runGate(root).status, 0);
  });
});

test('fails on managed-unaware bulk cancellation', () => {
  withFixture((root) => {
    writeFixture(
      root,
      'lib/features/reminders/infrastructure/notifications/bad.dart',
      'Future<void> clear(plugin) => plugin.' + 'cancelAll();\n',
    );

    assert.notEqual(runGate(root).status, 0);
  });
});

for (const [name, source] of [
  ['DateTime now', 'final now = DateTime.' + 'now();\n'],
  ['TZDateTime local', 'final now = TZDateTime.' + 'local(2026);\n'],
  ['toLocal conversion', 'final local = instant.' + 'toLocal();\n'],
]) {
  test(`fails on ${name} in reminder scheduling code`, () => {
    withFixture((root) => {
      writeFixture(
        root,
        'lib/features/reminders/domain/services/bad.dart',
        source,
      );

      assert.notEqual(runGate(root).status, 0);
    });
  });
}

test('fails closed when rg is unavailable', () => {
  withFixture((root) => {
    const missing = join(root, 'missing-rg-executable');
    const result = runGate(root, ['--rg-json', JSON.stringify([missing])]);

    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /rg|spawn|executable/i);
  });
});

test('fails closed when rg exits with an error', () => {
  withFixture((root) => {
    const result = runGate(root, [
      '--rg-json',
      JSON.stringify([process.execPath, '-e', 'process.exit(2)']),
    ]);

    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /rg|status|exit/i);
  });
});
