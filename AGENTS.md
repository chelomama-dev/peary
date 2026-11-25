# AGENTS.md

Instructions for every AI agent working on this repo (Claude Code and Gemini CLI). `CLAUDE.md` and `GEMINI.md`
only import this file: **change the rules here, never there.**

What the product is and why: [README.md](README.md). What comes when: [docs/roadmap.md](docs/roadmap.md). The HTTP
contract between the backend and the app: [docs/api.md](docs/api.md). The decisions behind the design:
[docs/adr/](docs/adr/).

The owner decides the scope and reviews. Two agents build it in parallel, so the rules below about lanes and the
contract are what keep us from stepping on each other.

## Rules

- **The contract comes first.** An endpoint or field changes in `docs/api.md` (with a changelog line) before it
  changes in the API or the app. The app never uses anything the contract doesn't describe, and the API never
  ships a field the contract doesn't have.
- **A decision that is hard to undo gets an ADR** in `docs/adr/` (`NNNN-short-title.md`, same format as the
  existing ones) before or with the code that implements it.
- Before something is done, it must build and its tests must pass, in both the backend and the app.
- **This repo is public.** Never commit secrets: no keys, tokens, connection strings, `google-services.json`,
  signing keys or real personal data (locations, receipts, names of real people). Tenant and client IDs live in
  GitHub environment variables and in ignored local files, not in the repo. Fixtures and demo data are made up.
- Location and documents are personal data under GDPR: nothing is stored that the feature doesn't need, and every
  piece of it can be deleted.
- Don't add dependencies without a reason. Say which one you are adding and why in the PR.
- Before recommending or pinning a version of a Microsoft/Azure service or SDK, check the current docs: they
  change often. Note the date you checked it.
- Code, comments, commits and docs are in **English**. The app's UI text is in **Spanish**.

## Lanes: who works where

| Lane | Default owner | Paths |
|---|---|---|
| Backend | Claude | `src/`, `tests/`, `*.slnx` |
| Infra and CI/CD | Claude | `infra/`, `.github/` |
| Flutter app | Gemini | `mobile/` |
| Contract and docs | whoever needs the change, the owner approves | `docs/`, `AGENTS.md`, `README.md` |

- Stay in your lane. If you need something from another lane, change the contract in `docs/api.md` in its own
  PR, or leave a note for the owner; don't edit the other lane's code.
- Every agent works in its **own branch** (and its own git worktree when both work at the same time). Never two
  agents on the same branch.
- The other agent reviews the PR when the owner asks for it. Review against this file, the contract and the ADRs.
- Until the API has an endpoint, the app uses its demo repositories with the examples of `docs/api.md`, so the
  app lane is never blocked by the backend lane.

## Git

Nothing is committed straight to `main`: every change goes in a branch and reaches `main` through a pull request,
squash merged.

- Branch prefixes: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`. Lowercase, hyphens, short
  (`feat/groups-endpoints`, `feat/mobile-tasks-screen`).
- Commit messages in English, in the imperative, starting with a capital letter and no prefixes
  (`Add the groups endpoints`, not `feat: added endpoint`). If the why isn't obvious, explain it in the body.
  One logical change per commit.
- Merge only when the build, the tests and the CI checks are green. If something fails or is unclear, stop and
  tell the owner.
- Never force-push to `main` or rewrite its history.

## Repository layout

```
src/                         .NET backend
  Peary.Domain/              groups, members, invitations, tasks... no dependencies
  Peary.Application/         use cases (plain handlers, no MediatR)
  Peary.Infrastructure/      EF Core, Blob Storage, push notifications
  Peary.Api/                 HTTP API for the app
  Peary.AppHost/             Aspire orchestration for local dev
  Peary.ServiceDefaults/     OpenTelemetry, health checks, resilience
tests/                       backend tests (xUnit, Testcontainers)
infra/                       Bicep and one-off bootstrap scripts
.github/workflows/           CI/CD
docs/api.md                  HTTP contract between the API and the app
docs/adr/                    architecture decision records
docs/roadmap.md              phases and what is left out on purpose
mobile/                      Flutter app
```

## Backend

- .NET 10. Light Clean Architecture: `Domain` has no dependencies; `Application` depends on `Domain`;
  `Infrastructure` implements `Application`'s interfaces; `Api` is a host and only wires things together.
- Minimal APIs grouped by feature, errors as ProblemDetails, OpenAPI document at `/openapi/v1.json` in Development.
- **Multi-tenancy** ([ADR 0002](docs/adr/0002-groups-are-the-tenants.md)): the group is the tenant. Every
  group-scoped endpoint lives under `/api/groups/{groupId}/...` and checks that the caller is a member before
  doing anything; a non-member gets `404`, never `403`, so group IDs can't be probed. Every group-scoped query
  filters by `GroupId`.
- Auth ([ADR 0001](docs/adr/0001-authentication-with-entra-external-id.md)): Entra External ID access tokens.
  Users are identified by the `oid` claim; everything else about them (groups, roles) lives in our database.
- Package versions are locked (`packages.lock.json`): restore with `dotnet restore --locked-mode` in CI.
- Run everything locally with `aspire run` from the repo root.
- Build and test: `dotnet build` and `dotnet test` from the repo root.
- Tests: xUnit for the domain and the handlers; the API and persistence against a real SQL Server with
  Testcontainers. API tests sign their own tokens, they never depend on the real tenant.

## Flutter app

- Flutter, latest stable. **Android first** ([ADR 0003](docs/adr/0003-android-first.md)); keep the code free of
  Android-only assumptions so iOS can come later. Package name `dev.chelomama.peary`, app name "Peary".
- State: **Riverpod**. Navigation: **go_router**. HTTP: **dio**. JSON: **json_serializable** + `build_runner`.
  Dates and numbers: **intl** with the `es_ES` locale. Material 3, light and dark theme that follow the system.
- Feature-first folders: `lib/app/` (app, router, theme), `lib/core/` (config, auth, api client, shared widgets),
  `lib/features/<feature>/{data,presentation}/`. Screens never call dio directly: they read providers, providers
  call repositories. `test/` mirrors `lib/`.
- Every screen has loading, empty and error (with "Reintentar") states, and pull to refresh where it lists data.
- Configuration comes from `--dart-define`, never hard-coded: `API_BASE_URL` (the Android emulator reaches the local
  API at `http://10.0.2.2:5080`), `DEMO=true` for in-memory fake repositories shaped exactly like the examples in
  `docs/api.md`, and the Entra IDs from `--dart-define-from-file=config/azure.json` (ignored by git).
- Auth: **msal_auth** against the External ID tenant, through the browser. `core/auth/` hides it behind an
  `Authenticator` interface, and `api_client.dart` is the single place that adds `Authorization: Bearer <token>`.
- Plain HTTP is allowed only in debug builds (a debug-only network security config), never in release.
- Timestamps from the API are UTC; show them in local time.
- Commands, from `mobile/`: `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`,
  `flutter analyze`, `flutter test`, `flutter run --dart-define=DEMO=true`.
