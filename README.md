# pr-guard

Reusable workflows that screen external pull requests across BuenDia-Builders
repos before merge: GitHub Actions security linting (`actionlint`, `zizmor`),
dependency review (`dependency-review-action`), and a heuristic risk score on
the PR author's profile (new account, mass-forking pattern, first-time
contributor).

## How it works

Two separate workflows, run in two separate jobs, on purpose: the one that
touches the PR's code never has comment permissions, and the one that can
comment never touches the PR's code. This avoids recreating the classic
`pull_request_target` leak the whole tool exists to catch.

| Step | Workflow | Trigger | Permissions | Runs on attacker's code? | What it does |
|---|---|---|---|---|---|
| 1 | `pr-guard-scan.yml` (calls `reusable-scan.yml`) | `pull_request` | `contents: read` only | Yes, safely (no secrets to steal) | Runs `actionlint`, `zizmor`, `dependency-review-action`, and the risk-score script; writes results to an artifact |
| 2 | `pr-guard-comment.yml` (calls `reusable-comment.yml`) | `workflow_run` (after step 1 finishes) | `pull-requests: write` | No, only reads the artifact's JSON/Markdown | Posts the risk report as a PR comment |

## What the risk score checks

| Signal | Threshold | Points |
|---|---|---|
| Account age | younger than 30 days | +2 |
| Fork pattern | more than 15 forked repos and ≤1 original repo | +3 |
| Contribution history | first PR to this repo | +1 |

Score ≥5 is flagged `HIGH`, 3-4 is `medium`, below that is `low`. This is the
exact signature seen on the accounts that were mass-forking Stellar bounty
repos and sneaking malicious contributions into point-based programs.

## Installing it on a repo

Copy the two files from `templates/` into the target repo's
`.github/workflows/`:

```
templates/pr-guard-scan.yml    -> .github/workflows/pr-guard-scan.yml
templates/pr-guard-comment.yml -> .github/workflows/pr-guard-comment.yml
```

Nothing else to configure. Both files just `uses:` the reusable workflows in
this repo, pinned to `@main`.

## What it does NOT do

It does not replace reading the diff yourself. It's a first line of defense
against the most common vectors (workflow injection, malicious dependencies,
bounty-farming accounts). The source code itself (e.g. a backdoor hidden in a
contract) still needs a human reviewer.
