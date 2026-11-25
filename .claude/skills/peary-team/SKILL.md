---
name: peary-team
description: Run Peary's end-to-end AI team - Claude leads and splits the work between itself, Gemini (through T3 delegate_task) and Claude subagents (explore, plan, implement, test, review) - from a roadmap item to merged PRs. Use when starting a feature or roadmap item, when the owner asks to split work, delegate, run things in parallel, or "work as a team", and whenever Gemini's work needs briefing or reviewing.
---

# Peary team

Peary is built by a small AI team under one human owner. Claude is the **lead**: it plans, splits the work,
briefs the others, reviews everything and merges (with the `github-flow` skill). The shared rules for every
member are in `AGENTS.md`; the lanes there are the source of truth.

## Who's who

| Member | How to start it | Owns | Good for |
|---|---|---|---|
| Owner (human) | ask in the reply, or `AskUserQuestion` when blocked | scope, decisions, everything in **Owner only** | |
| Claude (lead) | this session | backend `src/` `tests/`, infra `infra/`, CI `.github/`, contract and docs | planning, contract, backend, reviews, merges |
| Gemini | T3 `delegate_task`, `target: {providerInstanceId: "antigravity", model: "gemini-4-neon"}`, `isolation: "worktree"` | the Flutter app `mobile/` | app features, app tests, a second opinion on reviews |
| Claude subagents | `Agent` tool (`Explore`, `Plan`, `general-purpose`), `isolation: "worktree"` when they write | whatever the lead hands them, inside the lead's lanes | parallel backend slices, test writing, focused reviews, research |

Check the Gemini target is still offered with `orchestrator_capabilities` once per thread before the first
`delegate_task`; if it's gone, tell the owner instead of switching provider.

Gemini may use its own subagents inside its task; say so in the brief when the task is big.

## The loop for a roadmap item

1. **Pick and slice.** Take the next unchecked item of `docs/roadmap.md`. Split it into slices that can run in
   parallel without touching the same files: usually *contract*, *backend*, *app*, sometimes *infra*.
2. **Contract first.** The lead writes the `docs/api.md` change (and an ADR if a decision is hard to undo) in
   its own PR and merges it. Nothing else starts against a contract that isn't on `main`. If the contract
   already covers the item, skip this step.
3. **Fan out in parallel**, each on its own branch and worktree:
   - Gemini: the app slice (brief below).
   - Claude subagents: backend slices that don't overlap (for example domain + persistence in one,
     endpoints + API tests in another only if they don't collide; when in doubt, one subagent per vertical
     slice). The lead may also do a slice itself.
   - Run them in the background and keep working; don't poll. Each finished delegate wakes the lead.
4. **Review every PR** with the `github-flow` skill: CI, contract, ADRs, `AGENTS.md`. For anything non-trivial,
   get a second pair of eyes from the other model: a Claude reviewer subagent for Gemini's PRs, a new Gemini
   `delegate_task` with `role: "review"` for big backend PRs. Small fixes in its own lane, the lead does; fixes
   in another lane go back to that member as a **new** delegate with the findings.
5. **Merge in order**: contract, backend, app. Update each next branch after a merge (strict checks).
6. **Close the loop**: tick the item in `docs/roadmap.md` (in the last PR or a small docs PR), and tell the owner
   in a few lines what shipped, what's pending and what needs them.

## Writing a brief (Gemini or subagent)

Delegates start cold: they don't see this conversation. Every brief has:

- **Context**: one line on Peary, and "read `AGENTS.md`, `docs/api.md` and the ADRs first".
- **Lane and limits**: the paths they may touch and the ones they must not.
- **The task**: what to build, which contract sections, the UI text (Spanish) or behaviour expected.
- **Done means**: the exact build and test commands that must pass.
- **Git**: branch name, commit style and attribution line, push, open a PR, **don't merge**.
- **Report**: what was built, contract doubts, and the last line
  `PR <full URL>, head <SHA>, checks and reviews <state>`.
- No secrets, no tenant or client IDs in the brief.

Subagents doing review or research don't need the git part; ask for findings ranked by severity, each with
file and line.

## Owner only (stop and ask)

- Anything in Azure or Entra that needs the portal or the owner's credentials: tenants, subscriptions, user flows,
  app registrations the first time, cost-relevant resources.
- Secrets and keys: Firebase project and `google-services.json`, signing keys, GitHub environment secrets.
- Product scope, roadmap order, an ADR that changes a decision, anything that touches real family data.
- Store publishing and public releases.
- A delegate keeps failing the same way after one corrected retry.

Ask with a short, self-contained question and a recommendation, then keep going with whatever doesn't depend on
the answer.
