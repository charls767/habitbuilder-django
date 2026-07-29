import {createHash} from 'node:crypto';
import {
  readFile,
  stat,
  writeFile,
} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const maxCheckToMutationMs = 5 * 60 * 1000;
const utcTimestampPattern =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

export const packageDescriptors = Object.freeze([
  Object.freeze({
    name: 'flutter_local_notifications',
    version: '22.2.0',
    sourceUrl:
      'https://pub.dev/api/packages/flutter_local_notifications/versions/22.2.0',
    archiveUrl:
      'https://pub.dev/api/archives/flutter_local_notifications-22.2.0.tar.gz',
    homepage:
      'https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications',
    repository: null,
  }),
  Object.freeze({
    name: 'timezone',
    version: '0.11.1',
    sourceUrl: 'https://pub.dev/api/packages/timezone/versions/0.11.1',
    archiveUrl: 'https://pub.dev/api/archives/timezone-0.11.1.tar.gz',
    homepage: null,
    repository: 'https://github.com/dart-lang/labs/tree/main/pkgs/timezone',
  }),
]);

function argumentValue(args, name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
}

function requireArgument(args, name) {
  const value = argumentValue(args, name);
  if (!value) {
    throw new Error(`Missing required argument ${name}`);
  }
  return value;
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(
      `${label} mismatch: expected ${JSON.stringify(expected)}, ` +
        `received ${JSON.stringify(actual)}`,
    );
  }
}

function assertExactHttpsUrl(actual, expected, label) {
  assertEqual(actual, expected, label);
  let parsed;
  try {
    parsed = new URL(actual);
  } catch {
    throw new Error(`${label} is not a valid URL: ${actual}`);
  }
  if (parsed.protocol !== 'https:') {
    throw new Error(`${label} must use HTTPS: ${actual}`);
  }
}

function parseUtcTimestamp(value, label) {
  if (typeof value !== 'string' || !utcTimestampPattern.test(value)) {
    throw new Error(`${label} must be an exact UTC ISO-8601 timestamp`);
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed) || new Date(parsed).toISOString() !== value) {
    throw new Error(`${label} is not a canonical UTC timestamp`);
  }
  return parsed;
}

function validatePackageResponse(descriptor, response) {
  if (!response || typeof response !== 'object' || Array.isArray(response)) {
    throw new Error(`${descriptor.name} metadata must be a JSON object`);
  }
  if (
    !response.pubspec ||
    typeof response.pubspec !== 'object' ||
    Array.isArray(response.pubspec)
  ) {
    throw new Error(`${descriptor.name} pubspec metadata is missing`);
  }

  assertEqual(response.pubspec.name, descriptor.name, `${descriptor.name} name`);
  assertEqual(
    response.pubspec.version,
    descriptor.version,
    `${descriptor.name} version`,
  );
  assertExactHttpsUrl(
    response.archive_url,
    descriptor.archiveUrl,
    `${descriptor.name} archive URL`,
  );
  assertEqual(
    response.pubspec.homepage ?? null,
    descriptor.homepage,
    `${descriptor.name} homepage`,
  );
  assertEqual(
    response.pubspec.repository ?? null,
    descriptor.repository,
    `${descriptor.name} repository`,
  );

  return {
    name: descriptor.name,
    version: descriptor.version,
    sourceUrl: descriptor.sourceUrl,
    archiveUrl: descriptor.archiveUrl,
    homepage: descriptor.homepage,
    repository: descriptor.repository,
  };
}

function validatePackageRecord(descriptor, record) {
  if (!record || typeof record !== 'object' || Array.isArray(record)) {
    throw new Error(`${descriptor.name} evidence record is missing`);
  }
  assertEqual(record.name, descriptor.name, `${descriptor.name} evidence name`);
  assertEqual(
    record.version,
    descriptor.version,
    `${descriptor.name} evidence version`,
  );
  assertExactHttpsUrl(
    record.sourceUrl,
    descriptor.sourceUrl,
    `${descriptor.name} source URL`,
  );
  assertExactHttpsUrl(
    record.archiveUrl,
    descriptor.archiveUrl,
    `${descriptor.name} evidence archive URL`,
  );
  assertEqual(
    record.homepage ?? null,
    descriptor.homepage,
    `${descriptor.name} evidence homepage`,
  );
  assertEqual(
    record.repository ?? null,
    descriptor.repository,
    `${descriptor.name} evidence repository`,
  );
}

async function sha256(path) {
  const bytes = await readFile(path);
  return createHash('sha256').update(bytes).digest('hex').toUpperCase();
}

async function fileRecord(path) {
  const info = await stat(path);
  return {
    path: resolve(path),
    sha256: await sha256(path),
    mtimeUtc: info.mtime.toISOString(),
  };
}

async function loadMetadataFixture(path) {
  if (!path) {
    return null;
  }
  const fixture = JSON.parse(await readFile(path, 'utf8'));
  if (!fixture || typeof fixture !== 'object' || Array.isArray(fixture)) {
    throw new Error('Metadata fixture must be an object keyed by source URL');
  }
  return fixture;
}

async function fetchPackageMetadata(descriptor, fixture, fetchImpl) {
  assertExactHttpsUrl(
    descriptor.sourceUrl,
    descriptor.sourceUrl,
    `${descriptor.name} source URL`,
  );
  if (fixture) {
    if (!Object.hasOwn(fixture, descriptor.sourceUrl)) {
      throw new Error(`Fixture is missing ${descriptor.sourceUrl}`);
    }
    return fixture[descriptor.sourceUrl];
  }

  const response = await fetchImpl(descriptor.sourceUrl, {
    headers: {accept: 'application/json'},
    redirect: 'error',
  });
  if (!response.ok) {
    throw new Error(
      `${descriptor.name} metadata request failed with HTTP ${response.status}`,
    );
  }
  if (response.url && response.url !== descriptor.sourceUrl) {
    throw new Error(
      `${descriptor.name} metadata redirected to unexpected URL ${response.url}`,
    );
  }
  return response.json();
}

async function nextUtcTimestamp(afterUtc) {
  const after = Date.parse(afterUtc);
  let current = new Date().toISOString();
  while (Date.parse(current) <= after) {
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 1));
    current = new Date().toISOString();
  }
  return current;
}

export async function runPre({
  output,
  pubspec,
  lockfile,
  fixturePath,
  fetchImpl = globalThis.fetch,
}) {
  if (typeof fetchImpl !== 'function') {
    throw new Error('Fetch implementation is unavailable');
  }
  const fixture = await loadMetadataFixture(fixturePath);
  const packages = [];
  for (const descriptor of packageDescriptors) {
    const response = await fetchPackageMetadata(
      descriptor,
      fixture,
      fetchImpl,
    );
    packages.push(validatePackageResponse(descriptor, response));
  }

  const checkedAtUtc = new Date().toISOString();
  const beforePubspec = await fileRecord(pubspec);
  const beforeLockfile = await fileRecord(lockfile);
  const mutationStartedAtUtc = await nextUtcTimestamp(checkedAtUtc);
  const evidence = {
    schemaVersion: 1,
    checkedAtUtc,
    mutationStartedAtUtc,
    packages,
    files: {
      pubspec: {
        path: beforePubspec.path,
        beforeSha256: beforePubspec.sha256,
        beforeMtimeUtc: beforePubspec.mtimeUtc,
      },
      lockfile: {
        path: beforeLockfile.path,
        beforeSha256: beforeLockfile.sha256,
        beforeMtimeUtc: beforeLockfile.mtimeUtc,
      },
    },
  };
  await writeFile(output, `${JSON.stringify(evidence, null, 2)}\n`, 'utf8');
  console.log(
    `D-16 preflight passed for ${packages
      .map((item) => `${item.name}@${item.version}`)
      .join(', ')}`,
  );
  return evidence;
}

function requireExactPins(pubspecContent) {
  for (const descriptor of packageDescriptors) {
    const escapedName = descriptor.name.replaceAll('_', '\\_');
    const directPin = new RegExp(
      `^  ${escapedName}: ${descriptor.version.replaceAll('.', '\\.')}\\s*$`,
      'gm',
    );
    const matches = pubspecContent.match(directPin) ?? [];
    if (matches.length !== 1) {
      throw new Error(
        `pubspec.yaml must pin exactly ${descriptor.name}: ${descriptor.version}`,
      );
    }
  }
}

function parseLockPackages(lockContent) {
  const lines = lockContent.split(/\r?\n/);
  const records = new Map();
  let current;
  for (const line of lines) {
    const packageMatch = /^  ([A-Za-z0-9_]+):\s*$/.exec(line);
    if (packageMatch) {
      current = {name: packageMatch[1]};
      records.set(current.name, current);
      continue;
    }
    if (!current) {
      continue;
    }
    const dependency = /^    dependency: "?([^"]+)"?\s*$/.exec(line);
    if (dependency) {
      current.dependency = dependency[1];
      continue;
    }
    const source = /^    source: (\S+)\s*$/.exec(line);
    if (source) {
      current.source = source[1];
      continue;
    }
    const version = /^    version: "([^"]+)"\s*$/.exec(line);
    if (version) {
      current.version = version[1];
    }
  }
  return records;
}

function requireExactLock(lockContent) {
  const packages = parseLockPackages(lockContent);
  for (const descriptor of packageDescriptors) {
    const record = packages.get(descriptor.name);
    if (!record) {
      throw new Error(`pubspec.lock is missing ${descriptor.name}`);
    }
    assertEqual(
      record.version,
      descriptor.version,
      `${descriptor.name} lock version`,
    );
    assertEqual(
      record.dependency,
      'direct main',
      `${descriptor.name} lock dependency`,
    );
    assertEqual(
      record.source,
      'hosted',
      `${descriptor.name} lock source`,
    );
  }
  return Object.fromEntries(
    packageDescriptors.map((descriptor) => [
      descriptor.name,
      packages.get(descriptor.name).version,
    ]),
  );
}

function validateEvidence(evidence, pubspec, lockfile) {
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) {
    throw new Error('D-16 evidence must be a JSON object');
  }
  assertEqual(evidence.schemaVersion, 1, 'Evidence schema version');
  if (
    !Array.isArray(evidence.packages) ||
    evidence.packages.length !== packageDescriptors.length
  ) {
    throw new Error('D-16 evidence must contain exactly two package records');
  }
  packageDescriptors.forEach((descriptor, index) => {
    validatePackageRecord(descriptor, evidence.packages[index]);
  });

  const checkedAt = parseUtcTimestamp(evidence.checkedAtUtc, 'checkedAtUtc');
  const mutationStartedAt = parseUtcTimestamp(
    evidence.mutationStartedAtUtc,
    'mutationStartedAtUtc',
  );
  if (checkedAt >= mutationStartedAt) {
    throw new Error('checkedAtUtc must precede mutationStartedAtUtc');
  }
  if (mutationStartedAt - checkedAt > maxCheckToMutationMs) {
    throw new Error('D-16 package verification was stale before mutation');
  }

  if (!evidence.files?.pubspec || !evidence.files?.lockfile) {
    throw new Error('D-16 evidence is missing before-file records');
  }
  assertEqual(
    resolve(evidence.files.pubspec.path),
    resolve(pubspec),
    'pubspec evidence path',
  );
  assertEqual(
    resolve(evidence.files.lockfile.path),
    resolve(lockfile),
    'lockfile evidence path',
  );
  return mutationStartedAt;
}

export async function runPost({evidencePath, pubspec, lockfile}) {
  const evidence = JSON.parse(await readFile(evidencePath, 'utf8'));
  const mutationStartedAt = validateEvidence(evidence, pubspec, lockfile);
  const [pubspecContent, lockContent, currentPubspec, currentLockfile] =
    await Promise.all([
      readFile(pubspec, 'utf8'),
      readFile(lockfile, 'utf8'),
      fileRecord(pubspec),
      fileRecord(lockfile),
    ]);

  if (currentPubspec.sha256 === evidence.files.pubspec.beforeSha256) {
    throw new Error('pubspec.yaml hash did not change after D-16 preflight');
  }
  if (currentLockfile.sha256 === evidence.files.lockfile.beforeSha256) {
    throw new Error('pubspec.lock hash did not change after D-16 preflight');
  }
  if (Date.parse(currentPubspec.mtimeUtc) <= mutationStartedAt) {
    throw new Error('pubspec.yaml mtime does not follow mutation start');
  }
  if (Date.parse(currentLockfile.mtimeUtc) <= mutationStartedAt) {
    throw new Error('pubspec.lock mtime does not follow mutation start');
  }

  requireExactPins(pubspecContent);
  const resolvedVersions = requireExactLock(lockContent);

  if (evidence.postValidatedAtUtc !== undefined) {
    const postValidatedAt = parseUtcTimestamp(
      evidence.postValidatedAtUtc,
      'postValidatedAtUtc',
    );
    if (
      postValidatedAt < Date.parse(currentPubspec.mtimeUtc) ||
      postValidatedAt < Date.parse(currentLockfile.mtimeUtc)
    ) {
      throw new Error('postValidatedAtUtc must follow resulting file mtimes');
    }
    assertEqual(
      evidence.files.pubspec.afterSha256,
      currentPubspec.sha256,
      'pubspec after hash',
    );
    assertEqual(
      evidence.files.pubspec.afterMtimeUtc,
      currentPubspec.mtimeUtc,
      'pubspec after mtime',
    );
    assertEqual(
      evidence.files.lockfile.afterSha256,
      currentLockfile.sha256,
      'lockfile after hash',
    );
    assertEqual(
      evidence.files.lockfile.afterMtimeUtc,
      currentLockfile.mtimeUtc,
      'lockfile after mtime',
    );
    for (const descriptor of packageDescriptors) {
      assertEqual(
        evidence.resolvedVersions?.[descriptor.name],
        resolvedVersions[descriptor.name],
        `${descriptor.name} recorded resolved version`,
      );
    }
    console.log('D-16 postflight passed with exact pubspec and lock versions');
    return evidence;
  }

  evidence.postValidatedAtUtc = new Date().toISOString();
  evidence.files.pubspec.afterSha256 = currentPubspec.sha256;
  evidence.files.pubspec.afterMtimeUtc = currentPubspec.mtimeUtc;
  evidence.files.lockfile.afterSha256 = currentLockfile.sha256;
  evidence.files.lockfile.afterMtimeUtc = currentLockfile.mtimeUtc;
  evidence.resolvedVersions = resolvedVersions;
  await writeFile(
    evidencePath,
    `${JSON.stringify(evidence, null, 2)}\n`,
    'utf8',
  );
  console.log('D-16 postflight passed with exact pubspec and lock versions');
  return evidence;
}

async function main() {
  const args = process.argv.slice(2);
  const mode = args[0];
  const pubspec = argumentValue(args, '--pubspec', 'pubspec.yaml');
  const lockfile = argumentValue(args, '--lockfile', 'pubspec.lock');
  if (mode === 'pre') {
    await runPre({
      output: requireArgument(args, '--output'),
      pubspec,
      lockfile,
      fixturePath: argumentValue(args, '--fixture'),
    });
    return;
  }
  if (mode === 'post') {
    await runPost({
      evidencePath: requireArgument(args, '--evidence'),
      pubspec,
      lockfile,
    });
    return;
  }
  throw new Error('Usage: verify-reminder-package-gate.mjs <pre|post> [options]');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
