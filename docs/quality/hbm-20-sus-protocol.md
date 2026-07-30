# HBM-20 SUS Study Protocol

This protocol produces the human evidence required by `QUALITY-06`. Automated
tests validate scoring and measurement tooling, but they do not replace real
participants or real client measurements.

## Study gate

- Test the integrated `main` build and record its commit.
- Recruit real target users and assign anonymous IDs such as `P01`.
- Do not record names, email addresses, credentials or free-form personal data.
- Use the same task script for every participant.
- Administer SUS immediately after the participant completes the tasks.
- Keep HBM-20 in review until the mean SUS score is at least 80 and the study
  evidence is attached to Jira.

## Task script

1. Register an account.
2. Sign in.
3. Create or edit a habit and a goal.
4. Record a daily result and optional note.
5. Review progress and statistics.

The facilitator may repeat the task goal but must not explain where controls are
or complete the task for the participant. Record task failures separately from
the SUS answers.

## SUS questionnaire

Use a five-point scale for every statement:

1. Strongly disagree
2. Disagree
3. Neither agree nor disagree
4. Agree
5. Strongly agree

Statements:

1. I think that I would like to use HabitBuilder frequently.
2. I found HabitBuilder unnecessarily complex.
3. I thought HabitBuilder was easy to use.
4. I think that I would need the support of a technical person to use
   HabitBuilder.
5. I found the functions in HabitBuilder well integrated.
6. I thought there was too much inconsistency in HabitBuilder.
7. I imagine that most people would learn to use HabitBuilder quickly.
8. I found HabitBuilder cumbersome to use.
9. I felt confident using HabitBuilder.
10. I needed to learn many things before I could use HabitBuilder.

Enter the ten numeric answers in
`docs/quality/hbm-20-sus-responses.template.json` using anonymous participant
IDs. Score a completed response file with:

```powershell
npm run quality:sus -- path\to\sus-responses.json --output path\to\sus-report.json
```

The scorer rejects missing answers, values outside 1-5, duplicate participant
IDs and empty studies. Odd statements contribute `answer - 1`; even statements
contribute `5 - answer`; the total is multiplied by 2.5.

## Client latency context

Measure the same authenticated read endpoint on the same device, build, network
and API environment used for the study. The first request is cold; the
subsequent requests are warm. Credentials are read only from environment
variables and are never included in the report.

```powershell
$env:API_BASE_URL='https://api.example.com'
$env:API_EMAIL='participant-test-account@example.com'
$env:API_PASSWORD='set-locally'
$env:LATENCY_ENDPOINT='/progress?periodo=semana'
$env:LATENCY_WARM_RUNS='10'
$env:LATENCY_ENVIRONMENT='Android 14, Wi-Fi, release build'
$env:LATENCY_OUTPUT='latency-report.json'
npm run quality:latency
```

`API_ACCESS_TOKEN` can replace email and password. The report records one cold
sample and warm mean, median, p95, minimum and maximum values.

## Evidence checklist

- Integrated commit and app version
- Participant count and anonymous response file
- Generated SUS report and target comparison
- Device, OS, network and API environment
- Generated cold-versus-warm latency report
- Observed usability defects linked in Jira
- Facilitator and study date
