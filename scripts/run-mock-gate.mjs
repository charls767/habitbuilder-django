import {spawn} from 'node:child_process';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repoRoot = fileURLToPath(new URL('../', import.meta.url));
const prismEntry = fileURLToPath(
  new URL('../node_modules/@stoplight/prism-cli/dist/index.js', import.meta.url),
);
const smokeEntry = fileURLToPath(new URL('./mock-smoke.mjs', import.meta.url));

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function childOutcome(child, label, {allowNonZero = false} = {}) {
  if (!child || typeof child.once !== 'function') {
    return Promise.reject(new Error(`${label} did not return a child process`));
  }
  if (child.exitCode !== null || child.signalCode !== null) {
    if (allowNonZero || child.exitCode === 0) {
      return Promise.resolve();
    }
    return Promise.reject(
      new Error(
        `${label} exited with ` +
          (child.signalCode ? `signal ${child.signalCode}` : `code ${child.exitCode}`),
      ),
    );
  }

  return new Promise((resolve, reject) => {
    const onError = (error) => {
      dispose();
      reject(new Error(`${label} failed to spawn: ${error.message}`, {cause: error}));
    };
    const onClose = (code, signal) => {
      dispose();
      if (allowNonZero || code === 0) {
        resolve();
      } else {
        reject(
          new Error(
            `${label} exited with ${signal ? `signal ${signal}` : `code ${code}`}`,
          ),
        );
      }
    };
    const dispose = () => {
      child.off('error', onError);
      child.off('close', onClose);
    };

    child.once('error', onError);
    child.once('close', onClose);
  });
}

function mockFailureBeforeReadiness(child) {
  let dispose = () => {};
  const promise = new Promise((_, reject) => {
    const onError = (error) => {
      dispose();
      reject(new Error(`Mock process failed to spawn: ${error.message}`, {cause: error}));
    };
    const onExit = (code, signal) => {
      dispose();
      reject(
        new Error(
          `Mock process exited before readiness with ` +
            (signal ? `signal ${signal}` : `code ${code}`),
        ),
      );
    };
    dispose = () => {
      child.off('error', onError);
      child.off('exit', onExit);
    };
    child.once('error', onError);
    child.once('exit', onExit);
  });

  return {promise, dispose};
}

async function waitForReadiness({
  fetchImpl,
  readinessUrl,
  readinessTimeoutMs,
  readinessPollMs,
}) {
  const deadline = Date.now() + readinessTimeoutMs;
  let lastError;

  while (Date.now() <= deadline) {
    try {
      await fetchImpl(readinessUrl);
      return;
    } catch (error) {
      lastError = error;
    }

    const remaining = deadline - Date.now();
    if (remaining > 0) {
      await delay(Math.min(readinessPollMs, remaining));
    }
  }

  const suffix = lastError ? `: ${lastError.message}` : '';
  throw new Error(
    `Mock readiness timed out after ${readinessTimeoutMs}ms${suffix}`,
    {cause: lastError},
  );
}

function spawnMockProcess() {
  return spawn(
    process.execPath,
    [
      prismEntry,
      'mock',
      'docs/openapi.yaml',
      '-p',
      '4010',
      '--host',
      '127.0.0.1',
    ],
    {
      cwd: repoRoot,
      stdio: 'inherit',
      windowsHide: true,
      detached: process.platform !== 'win32',
    },
  );
}

function spawnSmokeProcess() {
  return spawn(process.execPath, [smokeEntry], {
    cwd: repoRoot,
    stdio: 'inherit',
    windowsHide: true,
  });
}

async function waitForOwnedExit(child, timeoutMs) {
  if (child.exitCode !== null || child.signalCode !== null) {
    return true;
  }

  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      dispose();
      resolve(false);
    }, timeoutMs);
    const onClose = () => {
      dispose();
      resolve(true);
    };
    const dispose = () => {
      clearTimeout(timeout);
      child.off('close', onClose);
    };
    child.once('close', onClose);
  });
}

export async function terminateOwnedProcessTree(child, timeoutMs = 5000) {
  if (!child?.pid || child.exitCode !== null || child.signalCode !== null) {
    return;
  }

  if (process.platform === 'win32') {
    const taskkill = spawn(
      'taskkill.exe',
      ['/PID', String(child.pid), '/T', '/F'],
      {stdio: 'ignore', windowsHide: true},
    );
    await childOutcome(taskkill, 'taskkill', {allowNonZero: true});
  } else {
    try {
      process.kill(-child.pid, 'SIGTERM');
    } catch (error) {
      if (error.code !== 'ESRCH') {
        throw error;
      }
    }
  }

  if (await waitForOwnedExit(child, timeoutMs)) {
    return;
  }

  if (process.platform === 'win32') {
    throw new Error(`Owned mock process tree ${child.pid} did not exit after taskkill`);
  }

  try {
    process.kill(-child.pid, 'SIGKILL');
  } catch (error) {
    if (error.code !== 'ESRCH') {
      throw error;
    }
  }
  if (!(await waitForOwnedExit(child, timeoutMs))) {
    throw new Error(`Owned mock process tree ${child.pid} did not exit after SIGKILL`);
  }
}

export async function runMockGate({
  spawnMock = spawnMockProcess,
  spawnSmoke = spawnSmokeProcess,
  terminateTree = terminateOwnedProcessTree,
  fetchImpl = globalThis.fetch,
  readinessUrl = 'http://127.0.0.1:4010/health',
  readinessTimeoutMs = 15000,
  readinessPollMs = 100,
} = {}) {
  let mockChild;

  try {
    mockChild = spawnMock();
    if (!mockChild?.pid) {
      throw new Error('Mock process did not expose a PID');
    }

    const mockFailure = mockFailureBeforeReadiness(mockChild);
    try {
      await Promise.race([
        waitForReadiness({
          fetchImpl,
          readinessUrl,
          readinessTimeoutMs,
          readinessPollMs,
        }),
        mockFailure.promise,
      ]);
    } finally {
      mockFailure.dispose();
    }

    const smokeChild = spawnSmoke();
    await childOutcome(smokeChild, 'Smoke process');
  } finally {
    if (mockChild) {
      await terminateTree(mockChild);
    }
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    await runMockGate();
  } catch (error) {
    console.error(`Mock gate failed: ${error.message}`);
    process.exitCode = 1;
  }
}
