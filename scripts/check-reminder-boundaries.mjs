import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const scans = Object.freeze([
  Object.freeze({
    name: 'flutter_local_notifications imports outside infrastructure',
    pattern:
      String.raw`^\s*import\s+['"]package:flutter_local_notifications(?:/|['"])`,
    paths: [
      'lib/features/reminders/domain',
      'lib/features/reminders/application',
      'lib/features/reminders/presentation',
      'test/features/reminders',
    ],
  }),
  Object.freeze({
    name: 'cancelAll calls in reminder code',
    pattern: String.raw`\.cancelAll\s*\(`,
    paths: ['lib/features/reminders', 'test/features/reminders'],
  }),
  Object.freeze({
    name: 'device-local time inputs in reminder scheduling code',
    pattern:
      String.raw`(?:\bDateTime\.now\s*\(|\bTZDateTime\.local\s*\(|\.toLocal\s*\()`,
    paths: ['lib/features/reminders', 'test/features/reminders'],
  }),
]);

function argumentValue(args, name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
}

function parseRgCommand(args) {
  const raw = argumentValue(args, '--rg-json');
  if (!raw) {
    return ['rg'];
  }
  let command;
  try {
    command = JSON.parse(raw);
  } catch {
    throw new Error('--rg-json must contain a JSON string array');
  }
  if (
    !Array.isArray(command) ||
    command.length === 0 ||
    command.some((part) => typeof part !== 'string' || part.length === 0)
  ) {
    throw new Error('--rg-json must contain a non-empty JSON string array');
  }
  return command;
}

function existingScanPaths(root, paths) {
  return paths.filter((path) => existsSync(resolve(root, path)));
}

export function runBoundaryScans({
  root = process.cwd(),
  rgCommand = ['rg'],
} = {}) {
  const absoluteRoot = resolve(root);
  if (!existsSync(absoluteRoot)) {
    throw new Error(`Reminder boundary root does not exist: ${absoluteRoot}`);
  }
  if (
    !Array.isArray(rgCommand) ||
    rgCommand.length === 0 ||
    rgCommand.some((part) => typeof part !== 'string' || part.length === 0)
  ) {
    throw new Error('rg command must be a non-empty string array');
  }

  let scannedAnyPath = false;
  for (const scan of scans) {
    const paths = existingScanPaths(absoluteRoot, scan.paths);
    if (paths.length === 0) {
      continue;
    }
    scannedAnyPath = true;
    const [command, ...prefixArgs] = rgCommand;
    const result = spawnSync(
      command,
      [
        ...prefixArgs,
        '-n',
        '--no-heading',
        '--color',
        'never',
        '--glob',
        '*.dart',
        scan.pattern,
        ...paths,
      ],
      {
        cwd: absoluteRoot,
        encoding: 'utf8',
        windowsHide: true,
      },
    );
    if (result.error) {
      throw new Error(
        `Unable to spawn rg for ${scan.name}: ${result.error.message}`,
      );
    }
    if (result.status === 0) {
      const hits = result.stdout.trim();
      throw new Error(
        `${scan.name} detected${hits ? `:\n${hits}` : ''}`,
      );
    }
    if (result.status !== 1) {
      throw new Error(
        `rg failed for ${scan.name} with exit status ${result.status}: ` +
          `${result.stderr.trim() || 'no diagnostic'}`,
      );
    }
  }
  if (!scannedAnyPath) {
    throw new Error('No reminder source or test paths were available to scan');
  }
  console.log('Reminder boundaries passed: plugin, cancellation, local time');
}

async function main() {
  const args = process.argv.slice(2);
  runBoundaryScans({
    root: argumentValue(args, '--root', process.cwd()),
    rgCommand: parseRgCommand(args),
  });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
