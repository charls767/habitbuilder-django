import assert from 'node:assert/strict';
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';

import {
  runSusCli,
  scoreSusAnswers,
  summarizeSusStudy,
  validateSusStudy,
} from './sus-score.mjs';

const optimalAnswers = [5, 1, 5, 1, 5, 1, 5, 1, 5, 1];
const minimumAnswers = [1, 5, 1, 5, 1, 5, 1, 5, 1, 5];

function study(responses) {
  return {
    schemaVersion: 1,
    study: {ticket: 'HBM-20', targetSus: 80},
    responses,
  };
}

test('scores the ten SUS answers with alternating contributions', () => {
  assert.equal(scoreSusAnswers([1, 2, 3, 4, 5, 1, 2, 3, 4, 5]), 50);
  assert.equal(scoreSusAnswers(optimalAnswers), 100);
  assert.equal(scoreSusAnswers(minimumAnswers), 0);
});

test('summarizes anonymous participant scores against the target', () => {
  const report = summarizeSusStudy(
    study([
      {participantId: 'P01', answers: optimalAnswers},
      {participantId: 'P02', answers: minimumAnswers},
    ]),
  );

  assert.equal(report.participantCount, 2);
  assert.equal(report.mean, 50);
  assert.equal(report.median, 50);
  assert.equal(report.minimum, 0);
  assert.equal(report.maximum, 100);
  assert.equal(report.targetMet, false);
});

test('rejects incomplete, invalid and duplicated responses', () => {
  assert.throws(
    () =>
      validateSusStudy(
        study([{participantId: 'P01', answers: optimalAnswers.slice(0, 9)}]),
      ),
    /exactly 10 answers/,
  );
  assert.throws(
    () =>
      validateSusStudy(
        study([{participantId: 'P01', answers: [...optimalAnswers.slice(0, 9), 6]}]),
      ),
    /integer from 1 to 5/,
  );
  assert.throws(
    () =>
      validateSusStudy(
        study([
          {participantId: 'P01', answers: optimalAnswers},
          {participantId: 'P01', answers: optimalAnswers},
        ]),
      ),
    /Duplicate participantId/,
  );
});

test('refuses to report a study without real responses', () => {
  assert.throws(
    () => summarizeSusStudy(study([])),
    /At least one real participant/,
  );
});

test('reads a study and writes a machine-readable CLI report', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'habitbuilder-sus-'));
  const input = join(directory, 'responses.json');
  const output = join(directory, 'report.json');

  try {
    writeFileSync(
      input,
      JSON.stringify(
        study([{participantId: 'P01', answers: optimalAnswers}]),
      ),
    );
    const report = await runSusCli([input, '--output', output]);

    assert.equal(report.mean, 100);
    assert.equal(JSON.parse(readFileSync(output, 'utf8')).targetMet, true);
    await assert.rejects(() => runSusCli([]), /Usage/);
    await assert.rejects(
      () => runSusCli([input, 'unexpected.json']),
      /Unexpected argument/,
    );
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
});
