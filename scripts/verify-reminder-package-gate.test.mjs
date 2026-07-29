import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';

const scriptPath = fileURLToPath(
  new URL('./verify-reminder-package-gate.mjs', import.meta.url),
);

const flutterNotificationsApi =
  'https://pub.dev/api/packages/flutter_local_notifications/versions/22.2.0';
const timezoneApi =
  'https://pub.dev/api/packages/timezone/versions/0.11.1';

const baselinePubspec = `name: fixture
environment:
  sdk: ">=3.12.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
`;

const baselineLock = `packages:
  collection:
    dependency: transitive
    description:
      name: collection
      url: "https://pub.dev"
    source: hosted
    version: "1.19.1"
`;

const pinnedPubspec = `${baselinePubspec}
  flutter_local_notifications: 22.2.0
  timezone: 0.11.1
`;

function pinnedLock({
  flutterNotificationsVersion = '22.2.0',
  timezoneVersion = '0.11.1',
} = {}) {
  return `packages:
  flutter_local_notifications:
    dependency: "direct main"
    description:
      name: flutter_local_notifications
      url: "https://pub.dev"
    source: hosted
    version: "${flutterNotificationsVersion}"
  timezone:
    dependency: "direct main"
    description:
      name: timezone
      url: "https://pub.dev"
    source: hosted
    version: "${timezoneVersion}"
`;
}

function validMetadata() {
  return {
    [flutterNotificationsApi]: {
      archive_url:
        'https://pub.dev/api/archives/flutter_local_notifications-22.2.0.tar.gz',
      pubspec: {
        name: 'flutter_local_notifications',
        version: '22.2.0',
        homepage:
          'https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications',
        repository: null,
      },
    },
    [timezoneApi]: {
      archive_url: 'https://pub.dev/api/archives/timezone-0.11.1.tar.gz',
      pubspec: {
        name: 'timezone',
        version: '0.11.1',
        homepage: null,
        repository: 'https://github.com/dart-lang/labs/tree/main/pkgs/timezone',
      },
    },
  };
}

function withFixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'habitbuilder-package-gate-'));
  assert.ok(
    root.startsWith(tmpdir()),
    `Refusing to manage fixture outside the OS temp directory: ${root}`,
  );
  const pubspec = join(root, 'pubspec.yaml');
  const lockfile = join(root, 'pubspec.lock');
  const evidence = join(root, 'packages.json');
  const fixture = join(root, 'metadata.json');
  writeFileSync(pubspec, baselinePubspec);
  writeFileSync(lockfile, baselineLock);
  writeFileSync(fixture, `${JSON.stringify(validMetadata(), null, 2)}\n`);

  try {
    return run({root, pubspec, lockfile, evidence, fixture});
  } finally {
    rmSync(root, {recursive: true, force: true});
  }
}

function runGate(args) {
  return spawnSync(process.execPath, [scriptPath, ...args], {
    encoding: 'utf8',
  });
}

function runPre(paths) {
  return runGate([
    'pre',
    '--output',
    paths.evidence,
    '--pubspec',
    paths.pubspec,
    '--lockfile',
    paths.lockfile,
    '--fixture',
    paths.fixture,
  ]);
}

function preparePost(paths) {
  const pre = runPre(paths);
  assert.equal(pre.status, 0, pre.stderr);
  writeFileSync(paths.pubspec, pinnedPubspec);
  writeFileSync(paths.lockfile, pinnedLock());
}

function runPost(paths) {
  return runGate([
    'post',
    '--evidence',
    paths.evidence,
    '--pubspec',
    paths.pubspec,
    '--lockfile',
    paths.lockfile,
  ]);
}

function mutateMetadata(paths, mutate) {
  const metadata = validMetadata();
  mutate(metadata);
  writeFileSync(paths.fixture, `${JSON.stringify(metadata, null, 2)}\n`);
}

test('pre and post accept exact official metadata and exact lock pins', () => {
  withFixture((paths) => {
    preparePost(paths);
    const post = runPost(paths);

    assert.equal(post.status, 0, post.stderr);
    const evidence = JSON.parse(readFileSync(paths.evidence, 'utf8'));
    assert.ok(evidence.checkedAtUtc < evidence.mutationStartedAtUtc);
    assert.match(evidence.checkedAtUtc, /Z$/);
    assert.match(evidence.postValidatedAtUtc, /Z$/);
    assert.equal(evidence.packages.length, 2);
    assert.equal(
      evidence.packages[0].sourceUrl,
      flutterNotificationsApi,
    );
    assert.equal(evidence.packages[1].sourceUrl, timezoneApi);
  });
});

test('repeated post validation is byte-for-byte idempotent', () => {
  withFixture((paths) => {
    preparePost(paths);
    const first = runPost(paths);
    assert.equal(first.status, 0, first.stderr);
    const firstEvidence = readFileSync(paths.evidence, 'utf8');

    const second = runPost(paths);

    assert.equal(second.status, 0, second.stderr);
    assert.equal(readFileSync(paths.evidence, 'utf8'), firstEvidence);
  });
});

for (const [name, mutate] of [
  [
    'wrong package name',
    (metadata) => {
      metadata[flutterNotificationsApi].pubspec.name = 'lookalike';
    },
  ],
  [
    'wrong package version',
    (metadata) => {
      metadata[timezoneApi].pubspec.version = '0.11.0';
    },
  ],
  [
    'HTTP archive URL',
    (metadata) => {
      metadata[timezoneApi].archive_url =
        'http://pub.dev/api/archives/timezone-0.11.1.tar.gz';
    },
  ],
  [
    'wrong FLN homepage',
    (metadata) => {
      metadata[flutterNotificationsApi].pubspec.homepage =
        'https://example.com/flutter_local_notifications';
    },
  ],
  [
    'unexpected FLN repository',
    (metadata) => {
      metadata[flutterNotificationsApi].pubspec.repository =
        'https://github.com/MaikuB/flutter_local_notifications';
    },
  ],
  [
    'wrong timezone repository',
    (metadata) => {
      metadata[timezoneApi].pubspec.repository =
        'https://example.com/timezone';
    },
  ],
  [
    'unexpected timezone homepage',
    (metadata) => {
      metadata[timezoneApi].pubspec.homepage =
        'https://pub.dev/packages/timezone';
    },
  ],
  [
    'wrong archive URL',
    (metadata) => {
      metadata[flutterNotificationsApi].archive_url =
        'https://pub.dev/api/archives/flutter_local_notifications-22.2.0.zip';
    },
  ],
]) {
  test(`pre fails closed for ${name}`, () => {
    withFixture((paths) => {
      mutateMetadata(paths, mutate);
      const result = runPre(paths);

      assert.notEqual(result.status, 0);
      assert.ok(result.stderr.trim(), 'expected a diagnostic on stderr');
    });
  });
}

test('post fails closed for an HTTP source URL in evidence', () => {
  withFixture((paths) => {
    preparePost(paths);
    const evidence = JSON.parse(readFileSync(paths.evidence, 'utf8'));
    evidence.packages[0].sourceUrl =
      'http://pub.dev/api/packages/flutter_local_notifications/versions/22.2.0';
    writeFileSync(paths.evidence, `${JSON.stringify(evidence, null, 2)}\n`);

    assert.notEqual(runPost(paths).status, 0);
  });
});

test('post fails closed for stale package verification', () => {
  withFixture((paths) => {
    preparePost(paths);
    const evidence = JSON.parse(readFileSync(paths.evidence, 'utf8'));
    evidence.checkedAtUtc = '2026-01-01T00:00:00.000Z';
    evidence.mutationStartedAtUtc = '2026-01-01T00:10:01.000Z';
    writeFileSync(paths.evidence, `${JSON.stringify(evidence, null, 2)}\n`);

    assert.notEqual(runPost(paths).status, 0);
  });
});

test('post fails closed for a non-UTC timestamp', () => {
  withFixture((paths) => {
    preparePost(paths);
    const evidence = JSON.parse(readFileSync(paths.evidence, 'utf8'));
    evidence.checkedAtUtc = '2026-07-29T10:00:00.000-05:00';
    writeFileSync(paths.evidence, `${JSON.stringify(evidence, null, 2)}\n`);

    assert.notEqual(runPost(paths).status, 0);
  });
});

test('post fails closed when mutation starts before the check', () => {
  withFixture((paths) => {
    preparePost(paths);
    const evidence = JSON.parse(readFileSync(paths.evidence, 'utf8'));
    evidence.mutationStartedAtUtc = evidence.checkedAtUtc;
    writeFileSync(paths.evidence, `${JSON.stringify(evidence, null, 2)}\n`);

    assert.notEqual(runPost(paths).status, 0);
  });
});

test('post fails closed when the lockfile hash is unchanged', () => {
  withFixture((paths) => {
    const pre = runPre(paths);
    assert.equal(pre.status, 0, pre.stderr);
    writeFileSync(paths.pubspec, pinnedPubspec);

    assert.notEqual(runPost(paths).status, 0);
  });
});

test('post fails closed when the lockfile is missing', () => {
  withFixture((paths) => {
    preparePost(paths);
    rmSync(paths.lockfile);

    assert.notEqual(runPost(paths).status, 0);
  });
});

test('post fails closed for wrong resolved lock versions', () => {
  withFixture((paths) => {
    const pre = runPre(paths);
    assert.equal(pre.status, 0, pre.stderr);
    writeFileSync(paths.pubspec, pinnedPubspec);
    writeFileSync(
      paths.lockfile,
      pinnedLock({timezoneVersion: '0.11.0'}),
    );

    assert.notEqual(runPost(paths).status, 0);
  });
});
