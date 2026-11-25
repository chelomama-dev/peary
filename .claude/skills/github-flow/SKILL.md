---
name: github-flow
description: Peary's whole git and GitHub flow, run by Claude end to end - branch, commit, push, open the PR, check CI against the main ruleset, review, keep the branch up to date, squash merge and clean up. Use for any commit, branch, push, PR, review, merge or "is this PR ready" in this repo, including PRs opened by Gemini or by subagents.
---

# GitHub flow for Peary

The owner delegated the whole git flow to Claude (2026-11-25): branches, commits, pushes, PRs, reviews and
merges. The owner steps in only for what needs a human (see **Stop and ask**). Rules of the repo are in
`AGENTS.md`; this skill is how to apply them.

## The ruleset on `main` (`protect-main`)

Read it live before relying on it: `gh api repos/chelomama-dev/peary/rulesets`. As set up on 2026-11-25:

- No direct pushes, no force pushes, no deletion, **linear history**.
- Changes only through a PR, merged with **squash** only. No approvals required.
- Required status checks **`backend`** and **`frontend`** (both jobs of `.github/workflows/ci.yml`), with
  **strict** policy: the branch must be up to date with `main` before merging.
- No bypass actors: never try to get around it (no admin merge, no disabling the ruleset, no pushing to `main`).
  If the ruleset blocks something legitimate, stop and tell the owner.

## 1. Start

```bash
git switch main && git pull --ff-only
git switch -c <prefix>/<short-name>     # feat/ fix/ chore/ docs/ refactor/ - lowercase, hyphens
```

- One branch per lane and per agent. When Gemini or a subagent works at the same time, they get their own
  worktree (`delegate_task` with `isolation: "worktree"`, or `Agent` with `isolation: "worktree"`).
- Contract changes (`docs/api.md`) go in their own PR before the code that needs them.

## 2. Commit

- English, imperative, capitalised, no prefixes: `Add the groups endpoints`. Body explains the why when it isn't
  obvious. One logical change per commit.
- End every commit with the attribution line from the current session's instructions (Claude) or
  `Co-Authored-By: Gemini <noreply@google.com>` (Gemini).
- Stage specific paths, not `git add -A` blindly: check `git status` first. Never commit secrets, `*.g.dart`,
  `mobile/config/*.json` (except the example), keystores, `google-services.json` or `.claude/settings.local.json`.
- Before committing, what you touched must build and pass its tests:
  - backend: `dotnet build` and `dotnet test` from the root (Docker must be running for Testcontainers);
  - app: from `mobile/`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze --fatal-infos`,
    `flutter test`.

## 3. Push and open the PR

```bash
git push -u origin HEAD
```

Open it with the T3 `pull_request_create` tool when it's available (it links the PR to the thread); otherwise
`gh pr create` and then `link_pull_request`. The body:

```markdown
## What
<what changes and why, in a few bullets; link the ADR or the contract section>

## Tests
<what ran locally and the result>

## Packages
<new dependencies and why, or "None">

<attribution line for PR bodies from the session's instructions>
```

## 4. Validate a PR (yours, Gemini's or a subagent's)

1. **CI**: `gh pr checks <n>`. Both `backend` and `frontend` must be green. If one fails, read the log
   (`gh run view <run id> --log-failed`, or the T3 `ci_logs` tool), fix it on the branch, push again. Don't wait
   with sleep loops or `--watch`: when you must wait for checks, use the T3 `watch_pull_request` tool and end the
   turn.
2. **Up to date**: if `main` moved, `gh pr update-branch <n> --rebase` (or rebase locally and
   `git push --force-with-lease` on the **PR branch only**), then wait for the checks again.
3. **Review** against `AGENTS.md`, `docs/api.md` and the ADRs. Ask a reviewer subagent for anything larger than
   a small change (see the `peary-team` skill). Look for: contract drift, a group-scoped query without `GroupId`,
   a missing membership check (`404` for non-members), secrets or real personal data, missing tests, UI text not
   in Spanish, dependencies added without a reason.
4. Leave the review as a PR comment (`gh pr comment`, or `pull_request_review` when available). The PR author and
   the reviewer are the same GitHub account, so GitHub won't accept an "approve"; a comment is the record.
5. Small fixes in your own lane: fix them yourself on the branch. Fixes in Gemini's lane: send them to Gemini in
   a new `delegate_task` with the review findings, unless the owner says otherwise.

## 5. Merge

Only when CI is green, the branch is up to date and the review found nothing blocking:

```bash
gh pr merge <n> --squash --delete-branch
```

(or the T3 `pull_request_merge` tool). The squash commit title is the PR title. The repo deletes merged branches
on its own (`delete_branch_on_merge`).

Merge order when PRs depend on each other: contract first, then backend, then app; after each merge, update the
next branch and let CI run again (strict checks).

## 6. Clean up

```bash
git switch main && git pull --ff-only
git fetch --prune
git branch --merged main | grep -v '^\*\|main' | xargs -r git branch -d
git worktree prune
```

## Stop and ask the owner

- CI fails for a reason you can't fix in the branch (runner, secrets, GitHub settings, a flaky external service).
- A change would need the ruleset, repo settings that affect security, GitHub environments or secrets.
- Anything that publishes: releases, tags, making something public outside the repo.
- A PR changes the product scope, an ADR decision, or the contract in a way that breaks the app.
- History on `main` looks wrong. Never rewrite it.
