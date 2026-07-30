import assert from 'node:assert/strict';
import {
  mkdtempSync,
  readFileSync,
  rmSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';

import {
  percentile,
  runLatencyCli,
  runLatencyStudy,
  summarizeLatencySamples,
} from './client-latency.mjs';

test('calculates deterministic median and p95 latency statistics', () => {
  assert.equal(percentile([40, 10, 30, 20], 0.5), 20);
  assert.deepEqual(summarizeLatencySamples([10, 20, 30, 40]), {
    count: 4,
    meanMs: 25,
    medianMs: 20,
    p95Ms: 40,
    minimumMs: 10,
    maximumMs: 40,
  });
});

test('measures one cold request and configured warm requests after login', async () => {
  const calls = [];
  const timestamps = [0, 100, 100, 130, 130, 150];
  const fetchImpl = async (url, options = {}) => {
    calls.push({url: String(url), options});
    if (String(url).endsWith('/auth/login')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({accessToken: 'test-token'}),
      };
    }
    return {
      ok: true,
      status: 200,
      arrayBuffer: async () => new ArrayBuffer(0),
    };
  };

  const report = await runLatencyStudy({
    baseUrl: 'http://localhost:4010',
    endpoint: '/v1/progreso?periodo=semana',
    warmRuns: 2,
    email: 'tester@example.com',
    password: 'not-reported',
    environment: 'test fixture',
    fetchImpl,
    now: () => timestamps.shift(),
  });

  assert.equal(calls.length, 4);
  assert.equal(JSON.parse(calls[0].options.body).email, 'tester@example.com');
  assert.equal(calls[1].options.headers.authorization, 'Bearer test-token');
  assert.equal(report.cold.durationMs, 100);
  assert.deepEqual(report.warm.samplesMs, [30, 20]);
  assert.equal(report.warm.meanMs, 25);
  assert.equal(JSON.stringify(report).includes('not-reported'), false);
});

test('accepts an access token without sending a login request', async () => {
  const calls = [];
  const timestamps = [0, 5, 5, 8];
  const fetchImpl = async (url, options = {}) => {
    calls.push({url: String(url), options});
    return {
      ok: true,
      status: 200,
      arrayBuffer: async () => new ArrayBuffer(0),
    };
  };

  const report = await runLatencyStudy({
    baseUrl: 'https://api.example.com',
    endpoint: '/health',
    warmRuns: 1,
    accessToken: 'existing-token',
    fetchImpl,
    now: () => timestamps.shift(),
  });

  assert.equal(calls.length, 2);
  assert.equal(report.cold.durationMs, 5);
  assert.deepEqual(report.warm.samplesMs, [3]);
});

test('rejects cross-host endpoints and missing credentials', async () => {
  await assert.rejects(
    () =>
      runLatencyStudy({
        baseUrl: 'https://api.example.com',
        endpoint: '//attacker.example.com/collect',
      }),
    /cannot target another host/,
  );
  await assert.rejects(
    () =>
      runLatencyStudy({
        baseUrl: 'https://api.example.com',
        endpoint: '/v1/progreso',
      }),
    /API_ACCESS_TOKEN/,
  );
});

test('writes a CLI report without persisting credentials', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'habitbuilder-latency-'));
  const output = join(directory, 'latency.json');
  const timestamps = [0, 12, 12, 20];
  const fetchImpl = async () => ({
    ok: true,
    status: 200,
    arrayBuffer: async () => new ArrayBuffer(0),
  });

  try {
    const report = await runLatencyCli(
      {
        API_BASE_URL: 'https://api.example.com',
        API_ACCESS_TOKEN: 'secret-token',
        LATENCY_ENDPOINT: '/v1/progreso',
        LATENCY_WARM_RUNS: '1',
        LATENCY_ENVIRONMENT: 'test fixture',
        LATENCY_OUTPUT: output,
      },
      {fetchImpl, now: () => timestamps.shift()},
    );

    assert.equal(report.cold.durationMs, 12);
    assert.deepEqual(report.warm.samplesMs, [8]);
    assert.equal(readFileSync(output, 'utf8').includes('secret-token'), false);
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
});
