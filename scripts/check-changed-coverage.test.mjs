import assert from 'node:assert/strict';
import test from 'node:test';

import {calculateCoverage, normalizePath, parseLcov} from './check-changed-coverage.mjs';

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
