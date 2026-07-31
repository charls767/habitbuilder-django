import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import test from 'node:test';

import {runMockGate} from './run-mock-gate.mjs';

class FakeChild extends EventEmitter {
  constructor(pid) {
    super();
    this.pid = pid;
    this.exitCode = null;
    this.signalCode = null;
  }

  finish(code = 0, signal = null) {
    this.exitCode = code;
    this.signalCode = signal;
    queueMicrotask(() => {
      this.emit('exit', code, signal);
      this.emit('close', code, signal);
    });
  }
}

function successfulSmoke(pid = 202) {
  const child = new FakeChild(pid);
  child.finish();
  return child;
}

test('accepts any HTTP response as readiness before spawning smoke', async () => {
  const mock = new FakeChild(101);
  const events = [];

  await runMockGate({
    spawnMock: () => {
      events.push('mock');
      return mock;
    },
    fetchImpl: async () => {
      events.push('ready:503');
      return {status: 503};
    },
    spawnSmoke: () => {
      events.push('smoke');
      return successfulSmoke();
    },
    terminateTree: async (child) => {
      assert.equal(child, mock);
      events.push('cleanup');
    },
    readinessTimeoutMs: 50,
    readinessPollMs: 1,
  });

  assert.deepEqual(events, ['mock', 'ready:503', 'smoke', 'cleanup']);
});

test('times out readiness and still cleans up the owned mock', async () => {
  const mock = new FakeChild(102);
  let cleanupCount = 0;

  await assert.rejects(
    runMockGate({
      spawnMock: () => mock,
      fetchImpl: async () => {
        throw new Error('connection refused');
      },
      spawnSmoke: () => {
        assert.fail('smoke must not start before readiness');
      },
      terminateTree: async (child) => {
        assert.equal(child, mock);
        cleanupCount += 1;
      },
      readinessTimeoutMs: 10,
      readinessPollMs: 1,
    }),
    /readiness timed out/i,
  );
  assert.equal(cleanupCount, 1);
});

test('propagates child spawn failure and cleans up the owned mock', async () => {
  const mock = new FakeChild(103);
  let cleaned = false;

  await assert.rejects(
    runMockGate({
      spawnMock: () => mock,
      fetchImpl: async () => ({status: 200}),
      spawnSmoke: () => {
        throw new Error('smoke spawn denied');
      },
      terminateTree: async (child) => {
        assert.equal(child, mock);
        cleaned = true;
      },
      readinessTimeoutMs: 50,
      readinessPollMs: 1,
    }),
    /smoke spawn denied/,
  );
  assert.equal(cleaned, true);
});

test('rejects smoke failure and cleans up the owned mock', async () => {
  const mock = new FakeChild(104);
  const smoke = new FakeChild(204);
  let cleanupCount = 0;
  smoke.finish(7);

  await assert.rejects(
    runMockGate({
      spawnMock: () => mock,
      fetchImpl: async () => ({status: 200}),
      spawnSmoke: () => smoke,
      terminateTree: async (child) => {
        assert.equal(child, mock);
        cleanupCount += 1;
      },
      readinessTimeoutMs: 50,
      readinessPollMs: 1,
    }),
    /smoke process exited with code 7/i,
  );
  assert.equal(cleanupCount, 1);
});

test('awaits process-tree cleanup before resolving', async () => {
  const mock = new FakeChild(105);
  let cleanupComplete = false;

  await runMockGate({
    spawnMock: () => mock,
    fetchImpl: async () => ({status: 204}),
    spawnSmoke: () => successfulSmoke(205),
    terminateTree: async (child) => {
      assert.equal(child, mock);
      await new Promise((resolve) => setImmediate(resolve));
      cleanupComplete = true;
    },
    readinessTimeoutMs: 50,
    readinessPollMs: 1,
  });

  assert.equal(cleanupComplete, true);
});
