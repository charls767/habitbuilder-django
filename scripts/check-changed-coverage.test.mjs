import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';

import {calculateCoverage, normalizePath, parseLcov} from './check-changed-coverage.mjs';

const scriptPath = fileURLToPath(
  new URL('./check-changed-coverage.mjs', import.meta.url),
);

const lcov = `SF:lib/core/network/api_exception.dart
LF:10
LH:8
end_of_record
SF:C:\\repo\\lib\\core\\network\\jwt_interceptor.dart
LF:20
LH:18
end_of_record
SF:lib/generated.g.dart
LF:100
LH:0
end_of_record
`;

test('parses and normalizes multiple LCOV records', () => {
  const records = parseLcov(lcov);
  assert.deepEqual(records.get('lib/core/network/api_exception.dart'), {
    found: 10,
    hit: 8,
  });
  assert.deepEqual(records.get('lib/core/network/jwt_interceptor.dart'), {
    found: 20,
    hit: 18,
  });
  assert.equal(normalizePath('C:\\repo\\lib\\file.dart'), 'lib/file.dart');
});

test('aggregates changed files and excludes generated code', () => {
  const result = calculateCoverage(parseLcov(lcov), [
    'lib/core/network/api_exception.dart',
    'lib/core/network/jwt_interceptor.dart',
    'lib/generated.g.dart',
  ]);

  assert.equal(result.found, 30);
  assert.equal(result.hit, 26);
  assert.equal(result.included.length, 2);
  assert.ok(result.percent > 80);
});

test('reports a value below the gate', () => {
  const result = calculateCoverage(parseLcov(lcov), [
    'lib/core/network/api_exception.dart',
  ]);
  assert.equal(result.percent, 80);

  const failing = calculateCoverage(
    new Map([['lib/file.dart', {found: 10, hit: 7}]]),
    ['lib/file.dart'],
  );
  assert.equal(failing.percent, 70);
});

function git(repo, args) {
  const result = spawnSync(
    'git',
    ['-c', 'user.name=Coverage Test', '-c', 'user.email=coverage@example.com', ...args],
    {cwd: repo, encoding: 'utf8'},
  );
  assert.equal(
    result.status,
    0,
    `git ${args.join(' ')} failed: ${result.stderr}`,
  );
  return result.stdout.trim();
}

function runFixture({changedPath = 'lib/file.dart', lcovContent = ''}) {
  const repo = mkdtempSync(join(tmpdir(), 'habitbuilder-coverage-'));
  assert.ok(
    repo.startsWith(tmpdir()),
    `Refusing to manage fixture outside the OS temp directory: ${repo}`,
  );

  try {
    git(repo, ['init', '--quiet']);
    writeFileSync(join(repo, 'README.md'), 'coverage fixture\n');
    git(repo, ['add', 'README.md']);
    git(repo, ['commit', '--quiet', '-m', 'fixture base']);
    const base = git(repo, ['rev-parse', 'HEAD']);

    const changedFile = join(repo, ...changedPath.split('/'));
    mkdirSync(dirname(changedFile), {recursive: true});
    writeFileSync(changedFile, 'void fixture() {}\n');
    git(repo, ['add', changedPath]);
    git(repo, ['commit', '--quiet', '-m', 'fixture change']);

    const lcovPath = join(repo, 'lcov.info');
    writeFileSync(lcovPath, lcovContent);

    return spawnSync(
      process.execPath,
      [scriptPath, '--base', base, '--lcov', lcovPath, '--min', '80'],
      {cwd: repo, encoding: 'utf8'},
    );
  } finally {
    rmSync(repo, {recursive: true, force: true});
  }
}

test('fails closed when a changed Dart path is absent from LCOV', () => {
  const result = runFixture({lcovContent: ''});

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /missing LCOV.*lib\/file\.dart/i);
});

test('fails closed when a changed Dart path has zero measurable lines', () => {
  const result = runFixture({
    lcovContent: `SF:lib/file.dart
LF:0
LH:0
end_of_record
`,
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /zero measurable lines.*lib\/file\.dart/i);
});

test('fails when changed-code coverage is below 80.00%', () => {
  const result = runFixture({
    lcovContent: `SF:lib/file.dart
LF:10
LH:7
end_of_record
`,
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /70\.00%.*80\.00%/);
});

test('passes when changed-code coverage is exactly 80.00%', () => {
  const result = runFixture({
    lcovContent: `SF:lib/file.dart
LF:10
LH:8
end_of_record
`,
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /80\.00%/);
});

test('passes when changed-code coverage is above 80.00%', () => {
  const result = runFixture({
    lcovContent: `SF:lib/file.dart
LF:10
LH:9
end_of_record
`,
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /90\.00%/);
});

test('ignores excluded generated Dart paths missing from LCOV', () => {
  const result = runFixture({changedPath: 'lib/generated.g.dart'});

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Changed-code coverage: 0\/0/);
});
