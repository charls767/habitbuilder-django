import {readFile, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

function assertAnswers(answers, participantId = 'participant') {
  if (!Array.isArray(answers) || answers.length !== 10) {
    throw new Error(`${participantId} must contain exactly 10 answers`);
  }

  answers.forEach((answer, index) => {
    if (!Number.isInteger(answer) || answer < 1 || answer > 5) {
      throw new Error(
        `${participantId} answer ${index + 1} must be an integer from 1 to 5`,
      );
    }
  });
}

export function scoreSusAnswers(answers) {
  assertAnswers(answers);
  const contribution = answers.reduce((total, answer, index) => {
    return total + (index % 2 === 0 ? answer - 1 : 5 - answer);
  }, 0);
  return contribution * 2.5;
}

export function validateSusStudy(document) {
  if (!document || typeof document !== 'object' || Array.isArray(document)) {
    throw new Error('SUS input must be a JSON object');
  }
  if (document.schemaVersion !== 1) {
    throw new Error('schemaVersion must be 1');
  }

  const target = document.study?.targetSus;
  if (typeof target !== 'number' || target < 0 || target > 100) {
    throw new Error('study.targetSus must be a number from 0 to 100');
  }
  if (!Array.isArray(document.responses)) {
    throw new Error('responses must be an array');
  }

  const participantIds = new Set();
  for (const response of document.responses) {
    const participantId = response?.participantId;
    if (typeof participantId !== 'string' || participantId.trim() === '') {
      throw new Error('Each response must have an anonymous participantId');
    }
    if (participantIds.has(participantId)) {
      throw new Error(`Duplicate participantId: ${participantId}`);
    }
    participantIds.add(participantId);
    assertAnswers(response.answers, participantId);
  }

  return document;
}

function round(value) {
  return Math.round(value * 100) / 100;
}

function median(values) {
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

export function summarizeSusStudy(document) {
  const validated = validateSusStudy(document);
  if (validated.responses.length === 0) {
    throw new Error('At least one real participant response is required');
  }

  const scores = validated.responses.map((response) => ({
    participantId: response.participantId,
    score: scoreSusAnswers(response.answers),
  }));
  const scoreValues = scores.map(({score}) => score);
  const mean =
    scoreValues.reduce((total, score) => total + score, 0) / scoreValues.length;
  const target = validated.study.targetSus;

  return {
    schemaVersion: 1,
    ticket: validated.study.ticket ?? 'HBM-20',
    targetSus: target,
    participantCount: scores.length,
    mean: round(mean),
    median: round(median(scoreValues)),
    minimum: Math.min(...scoreValues),
    maximum: Math.max(...scoreValues),
    targetMet: mean >= target,
    scores,
  };
}

function parseArguments(arguments_) {
  let input;
  let output;

  for (let index = 0; index < arguments_.length; index += 1) {
    const argument = arguments_[index];
    if (argument === '--output') {
      output = arguments_[index + 1];
      index += 1;
    } else if (!input) {
      input = argument;
    } else {
      throw new Error(`Unexpected argument: ${argument}`);
    }
  }

  if (!input) {
    throw new Error(
      'Usage: node scripts/sus-score.mjs <responses.json> [--output report.json]',
    );
  }
  return {input, output};
}

export async function runSusCli(arguments_) {
  const {input, output} = parseArguments(arguments_);
  const document = JSON.parse(await readFile(resolve(input), 'utf8'));
  const report = summarizeSusStudy(document);
  const serialized = `${JSON.stringify(report, null, 2)}\n`;

  if (output) {
    await writeFile(resolve(output), serialized, 'utf8');
  } else {
    process.stdout.write(serialized);
  }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await runSusCli(process.argv.slice(2));
  } catch (error) {
    console.error(`SUS scoring failed: ${error.message}`);
    process.exitCode = 1;
  }
}
