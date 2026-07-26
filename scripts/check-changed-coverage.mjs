import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const defaultExcluded = [
  /\.g\.dart$/,
  /\.freezed\.dart$/,
  /^lib\/main\.dart$/,
  /^lib\/app\.dart$/,
  /^lib\/core\/router\//,
  /^lib\/core\/theme\//,
  /^lib\/core\/network\/dio_client\.dart$/,
];

export function parseLcov(content) {
  const records = new Map();
  let file;
  let found = 0;
  let hit = 0;

  const flush = () => {
    if (file) {
      records.set(normalizePath(file), {found, hit});
    }
    file = undefined;
    found = 0;
    hit = 0;
  };

  for (const line of content.split(/\r?\n/)) {
    if (line.startsWith('SF:')) {
      flush();
      file = line.slice(3);
    } else if (line.startsWith('LF:')) {
      found = Number.parseInt(line.slice(3), 10);
    } else if (line.startsWith('LH:')) {
      hit = Number.parseInt(line.slice(3), 10);
    } else if (line === 'end_of_record') {
      flush();
    }
  }
  flush();
  return records;
}

export function normalizePath(value) {
  const normalized = value.replaceAll('\\', '/');
  const libIndex = normalized.lastIndexOf('/lib/');
  return libIndex >= 0 ? normalized.slice(libIndex + 1) : normalized;
}

export function calculateCoverage(records, changedFiles, excluded = defaultExcluded) {
  const included = [];
  let found = 0;
  let hit = 0;

  for (const rawFile of changedFiles) {
    const file = normalizePath(rawFile.trim());
    if (!file || excluded.some((pattern) => pattern.test(file))) {
      continue;
    }
    const record = records.get(file);
    if (!record || record.found === 0) {
      continue;
    }
    included.push({file, ...record});
    found += record.found;
    hit += record.hit;
  }

  return {
    included,
    found,
    hit,
    percent: found === 0 ? 100 : (hit / found) * 100,
  };
}

function argumentValue(args, name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
}

function changedDartFiles(base) {
  const result = spawnSync(
    'git',
    ['diff', '--name-only', '--diff-filter=AM', `${base}...HEAD`, '--', '*.dart'],
    {encoding: 'utf8'},
  );
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `Unable to diff against ${base}`);
  }
  return result.stdout.split(/\r?\n/).filter(Boolean);
}

async function main() {
  const args = process.argv.slice(2);
  const base = argumentValue(args, '--base', 'main');
  const lcovPath = argumentValue(args, '--lcov', 'coverage/lcov.info');
  const minimum = Number.parseFloat(argumentValue(args, '--min', '80'));
  const records = parseLcov(await readFile(lcovPath, 'utf8'));
  const result = calculateCoverage(records, changedDartFiles(base));

  for (const item of result.included) {
    const percent = ((item.hit / item.found) * 100).toFixed(2);
    console.log(`${item.file}: ${item.hit}/${item.found} (${percent}%)`);
  }
  console.log(
    `Changed-code coverage: ${result.hit}/${result.found} ` +
      `(${result.percent.toFixed(2)}%), minimum ${minimum.toFixed(2)}%`,
  );

  if (result.percent < minimum) {
    process.exitCode = 1;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
