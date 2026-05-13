---
description: Verify, review, commit, and ship the current branch with multi-skill orchestration
argument-hint: [optional PR title]
---

You are running the `/safe-ship` workflow. The goal is to take the current branch
from "code written" to "PR opened" — but only if quality gates pass.

## Context for this run

- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)"`
- Status: !`git status --short 2>/dev/null | head -20`
- User-provided PR title (may be empty): $ARGUMENTS

## Workflow

Execute the following phases **in order**. If any phase fails or surfaces
blocking issues, STOP and report to the user — do not proceed to later phases.

### Phase 1 — Verification gate
Invoke the `superpowers:verification-before-completion` skill.
Confirm tests pass, types check, and there are no obvious regressions.

### Phase 2 — Review gate
<!--
  TODO (user contribution):
  Decide the review strategy for this workflow.

  Options to weigh:
    (a) `coderabbit:code-review` — thorough AI review, slower, costs tokens
    (b) `code-review:code-review` — lighter local review
    (c) Skip review when diff is small (define "small": LOC? files?)
    (d) Always require review — safest, but adds friction on tiny changes

  Write 5-10 lines below describing WHICH skill to invoke and under WHAT
  conditions. Be explicit about the threshold so the model behaves
  deterministically across runs.
-->

### Phase 3 — Ship
Invoke the `commit-commands:commit-push-pr` skill to commit, push, and open
the PR. If `$ARGUMENTS` is non-empty, use it as the PR title; otherwise let
the skill infer one from the diff.

## Output
End with a one-line summary: branch name, PR URL, and which gates ran.
