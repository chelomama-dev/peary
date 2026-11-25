# ADR 0002: Groups are the tenants, and people join them by verified email

- Status: accepted
- Date: 2026-11-25

## Context

Peary is multi-tenant: a family's tasks, documents and places must never be visible to another family. Unlike
Plumy, where a user belongs to one firm at most, a Peary user can belong to **several groups** (their family, a
shared flat, their parents' house), so the tenant can't be derived from the user alone.

A new user arrives from Entra External ID (ADR 0001) with an `oid` and a verified `email`, and no group.

## Decision

### Tenancy

- **The group is the tenant.** Every group-scoped resource (tasks, documents, places...) has a `GroupId`.
- **The group is always explicit in the URL**: `/api/groups/{groupId}/...`. The app knows which group is open; the
  API never guesses it from the user.
- An endpoint filter resolves the caller's membership in `{groupId}` before the handler runs and exposes it as the
  current group context (group ID, member ID, role). **A non-member gets `404`**, never `403`, so a group ID can't
  be probed. Handlers only receive a group context that has already been checked.
- Every group-scoped query filters by `GroupId`. Integration tests cover that a member of one group can't read or
  change anything in another.

### Members and roles

- A `GroupMember` row links a user to a group with a role: **Admin** or **Member**.
- Whoever creates a group is its first admin. Admins rename the group, invite, remove members and change roles.
  Every member can do everything else (tasks, documents...): it's a family, not a company.
- A group always keeps at least one admin: the last admin can't leave or be demoted while other members remain. If
  the last member leaves, the group and its data are deleted.

### Invitations (as in Plumy's ADR 0002)

- An invitation is a row tied to a group and an **email address** (trimmed and lowercased). It has no secret.
- Whoever signs in with that address sees it in `GET /api/me` and can accept or decline it. Accepting checks that
  the invitation was sent to the `email` claim of the token, which Entra has verified.
- Peary doesn't send emails yet: the admin tells the person to install the app and sign up with that address.
- Invitations expire after 7 days. Inviting the same address again renews the open invitation (a filtered unique
  index keeps one open invitation per address and group). Inviting someone who is already a member fails.

## Consequences

Good:

- One user, many groups, with no tenant switching in the token and no special claims in Entra.
- No email infrastructure and no secret to leak. Sending an email or a push later only adds a notification.

Bad:

- Every group-scoped endpoint pays one membership lookup. It's a single indexed query; cache it only if it shows
  up as a problem.
- Forgetting the `GroupId` filter in a query leaks data across families. Mitigated by the endpoint filter, a
  repository pattern that takes the group context, and the cross-group integration tests.
- Relies on the `email` claim being verified, for any identity provider added later.

## Alternatives considered

- **EF Core global query filters by "current group"**: they hide the filter, which is good, but the current group
  still has to come from the URL, and a forgotten `IgnoreQueryFilters` is just as easy to miss. Can be added on
  top later.
- **Invitation links with a secret token or a short code**: easier to share on WhatsApp, which is how families
  actually invite each other. Kept as a candidate for v0.2 if the email flow turns out to be awkward; it would get
  its own ADR.
