import {writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {performance} from 'node:perf_hooks';
import {pathToFileURL} from 'node:url';

function roundMilliseconds(value) {
  return Math.round(value * 100) / 100;
}

export function percentile(values, percentileValue) {
  if (!Array.isArray(values) || values.length === 0) {
    throw new Error('Latency samples cannot be empty');
  }
  if (percentileValue < 0 || percentileValue > 1) {
    throw new Error('Percentile must be between 0 and 1');
  }

  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.max(0, Math.ceil(percentileValue * sorted.length) - 1);
  return sorted[index];
}

export function summarizeLatencySamples(samples) {
  if (!Array.isArray(samples) || samples.length === 0) {
    throw new Error('Latency samples cannot be empty');
  }

  const mean = samples.reduce((total, value) => total + value, 0) / samples.length;
  return {
    count: samples.length,
    meanMs: roundMilliseconds(mean),
    medianMs: roundMilliseconds(percentile(samples, 0.5)),
    p95Ms: roundMilliseconds(percentile(samples, 0.95)),
    minimumMs: roundMilliseconds(Math.min(...samples)),
    maximumMs: roundMilliseconds(Math.max(...samples)),
  };
}

function normalizeBaseUrl(baseUrl) {
  const parsed = new URL(baseUrl);
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('API_BASE_URL must use http or https');
  }
  parsed.username = '';
  parsed.password = '';
  parsed.search = '';
  parsed.hash = '';
  return parsed;
}

function normalizeEndpoint(endpoint) {
  if (typeof endpoint !== 'string' || !endpoint.startsWith('/')) {
    throw new Error('LATENCY_ENDPOINT must be a relative path starting with /');
  }
  if (endpoint.startsWith('//')) {
    throw new Error('LATENCY_ENDPOINT cannot target another host');
  }
  return endpoint;
}

function positiveInteger(value, label) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`${label} must be a positive integer`);
  }
  return parsed;
}

async function authenticate({
  fetchImpl,
  baseUrl,
  accessToken,
  email,
  password,
}) {
  if (accessToken) return accessToken;
  if (!email || !password) {
    throw new Error(
      'Set API_ACCESS_TOKEN or both API_EMAIL and API_PASSWORD; credentials are never written to reports',
    );
  }

  const response = await fetchImpl(new URL('/auth/login', baseUrl), {
    method: 'POST',
    headers: {'content-type': 'application/json', accept: 'application/json'},
    body: JSON.stringify({email, password}),
  });
  if (!response.ok) {
    throw new Error(`Authentication failed with HTTP ${response.status}`);
  }

  const payload = await response.json();
  if (typeof payload?.accessToken !== 'string' || payload.accessToken === '') {
    throw new Error('Authentication response did not contain accessToken');
  }
  return payload.accessToken;
}

async function measureRequest({fetchImpl, url, token, now}) {
  const startedAt = now();
  const response = await fetchImpl(url, {
    headers: {accept: 'application/json', authorization: `Bearer ${token}`},
  });
  await response.arrayBuffer();
  const durationMs = roundMilliseconds(now() - startedAt);

  if (!response.ok) {
    throw new Error(`Measured request failed with HTTP ${response.status}`);
  }
  return {durationMs, status: response.status};
}

export async function runLatencyStudy({
  baseUrl,
  endpoint = '/progress?periodo=semana',
  warmRuns = 10,
  accessToken,
  email,
  password,
  environment = 'unspecified',
  fetchImpl = globalThis.fetch,
  now = () => performance.now(),
}) {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl);
  const normalizedEndpoint = normalizeEndpoint(endpoint);
  const normalizedWarmRuns = positiveInteger(warmRuns, 'LATENCY_WARM_RUNS');
  const token = await authenticate({
    fetchImpl,
    baseUrl: normalizedBaseUrl,
    accessToken,
    email,
    password,
  });
  const requestUrl = new URL(normalizedEndpoint, normalizedBaseUrl);
  const cold = await measureRequest({fetchImpl, url: requestUrl, token, now});
  const warm = [];

  for (let index = 0; index < normalizedWarmRuns; index += 1) {
    warm.push(
      await measureRequest({fetchImpl, url: requestUrl, token, now}),
    );
  }

  const warmSamples = warm.map(({durationMs}) => durationMs);
  return {
    schemaVersion: 1,
    ticket: 'HBM-20',
    measuredAt: new Date().toISOString(),
    environment,
    baseUrl: normalizedBaseUrl.origin,
    endpoint: normalizedEndpoint,
    cold,
    warm: {
      samplesMs: warmSamples,
      ...summarizeLatencySamples(warmSamples),
    },
  };
}

export async function runLatencyCli(environmentVariables, options = {}) {
  const report = await runLatencyStudy({
    baseUrl: environmentVariables.API_BASE_URL ?? 'http://127.0.0.1:4010',
    endpoint:
      environmentVariables.LATENCY_ENDPOINT ?? '/progress?periodo=semana',
    warmRuns: environmentVariables.LATENCY_WARM_RUNS ?? '10',
    accessToken: environmentVariables.API_ACCESS_TOKEN,
    email: environmentVariables.API_EMAIL,
    password: environmentVariables.API_PASSWORD,
    environment: environmentVariables.LATENCY_ENVIRONMENT ?? 'unspecified',
    fetchImpl: options.fetchImpl,
    now: options.now,
  });
  const serialized = `${JSON.stringify(report, null, 2)}\n`;

  if (environmentVariables.LATENCY_OUTPUT) {
    await writeFile(resolve(environmentVariables.LATENCY_OUTPUT), serialized, 'utf8');
  } else {
    process.stdout.write(serialized);
  }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await runLatencyCli(process.env);
  } catch (error) {
    console.error(`Client latency study failed: ${error.message}`);
    process.exitCode = 1;
  }
}
