# ADR 0001: Authentication with Microsoft Entra External ID

- Status: accepted
- Date: 2026-11-25

## Context

Anyone must be able to sign up in Peary on their own, from the phone, and then create or join groups. Peary will
store personal data (who lives with whom, receipts, and later locations), so a breach is costly (GDPR), and the
project runs on a personal budget.

The owner already uses Microsoft Entra in two projects: Plumy (an **External ID** tenant: self-service sign-up,
multi-tenant, tenancy in its own database, see Plumy's ADR 0001 and 0002) and Finances Hub (a **workforce** tenant
with a single allowed user, and a Flutter app that signs in with MSAL through the browser). Peary is Plumy's model
with Finances Hub's app.

## Decision

- **Identity provider: Microsoft Entra External ID**, in an external tenant of its own (`peary`), not Plumy's:
  each product has its own users, branding and user flows.
- **Sign-up and sign-in method: email + one-time code or password**, in a `signup-signin` user flow. Google sign-in
  can be added later in the tenant without code changes, as long as it issues verified emails (ADR 0002 depends
  on that).
- **Two app registrations**, created by an idempotent script (`infra/scripts/bootstrap-entra-apps.sh`, adapted
  from Plumy's):
  - `peary-api`: exposes the delegated scope `access_as_user` and issues v2 access tokens with the `email` claim.
  - `peary-android`: a public client (no secret), with the redirect URI `msauth://dev.chelomama.peary/<signature
    hash>` for the debug and release keys, as in Finances Hub's ADR 0002. Admin consent is granted once.
- **The API** validates JWT bearer tokens against `https://<tenant id>.ciamlogin.com/<tenant id>/v2.0` (same code
  as Plumy's `EntraAuthentication`) and requires the scope on every endpoint except health checks.
- **Entra answers who the user is.** Groups, roles and memberships live in Peary's database, keyed by `oid`. A
  copy of the name and email from the token is kept in a `User` row and refreshed by `GET /api/me`.
- **The app signs in through the browser** (a Custom Tab), never a WebView. Which Flutter package does it is
  settled by a spike, below.

## Open point: the Flutter package

Finances Hub uses `msal_auth`, against a workforce tenant (`login.microsoftonline.com`). Its docs list AAD and B2C
authorities; we haven't confirmed it accepts a `ciamlogin.com` authority. The first task of the app lane is a
spike that signs in against the external tenant on Android with, in this order:

1. `msal_auth` with the external tenant's authority (reuses Finances Hub's code as is).
2. `flutter_appauth`: a generic OpenID Connect client, which works with any standards-compliant provider.

The spike updates this ADR with the result. Whatever wins stays behind the app's `Authenticator` interface.

## Consequences

Good:

- No password hashes in Peary's database. Password policy, reset, lockout, MFA and attack detection come from
  Entra.
- Free up to 50,000 monthly active users (checked 2026-11-25), far above what Peary will reach.
- Standard OIDC and JWT: the API doesn't depend on the provider beyond configuration.

Bad:

- The sign-in page is on `<tenant>.ciamlogin.com`. A custom domain needs Azure Front Door, which has a fixed
  monthly fee. Accepted; company branding is applied instead.
- The external tenant can't be managed with Bicep: it's created once in the Entra admin center.
- Local development of the login depends on the external tenant. The local API can run without auth (as in
  Finances Hub), and API tests sign their own tokens.

## Alternatives considered

- **ASP.NET Core Identity**: everything in our code, simpler local development. Rejected for the same reasons as in
  Plumy: Peary would own password storage, reset emails, MFA and lockout.
- **Reusing Plumy's external tenant**: one tenant less to manage, but users, branding and sign-up flows would be
  shared between unrelated products.
