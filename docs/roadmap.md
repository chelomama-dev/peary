# Roadmap

Status: accepted (2026-11-25). The owner has 5-10 hours a week, so each phase is small enough to be used for real
by a family before the next one starts.

## v0.1: Foundation and tasks (MVP)

The goal: the owner's family uses it every day.

- [ ] Repo, docs and contract (this file, `AGENTS.md`, ADRs, `docs/api.md`)
- [ ] Backend solution: Clean Architecture, EF Core + SQL Server, Aspire, tests, CI
- [ ] Flutter app skeleton: navigation, theme, demo mode, CI
- [ ] Sign in with Entra External ID (API + app)
- [ ] Groups: create, rename, leave, list members, roles (admin, member)
- [ ] Invitations by email, accepted from the app
- [ ] Tasks: title, notes, assignee, due date, simple recurrence (daily, weekly, monthly), complete
- [ ] Push notifications (FCM): a task assigned to you, a reminder before it's due
- [ ] Attachments on a task: photo or PDF, in Blob Storage
- [ ] Azure: Bicep, Container Apps, Azure SQL free offer, Blob Storage, deploy from GitHub Actions with OIDC

## v0.2: Shopping and receipts

- [ ] Shopping list as a kind of task: items ticked off in real time (SignalR)
- [ ] Group documents: bills, warranties, receipts, with tags and search
- [ ] Read receipts with Azure AI Document Intelligence (prebuilt receipt model): shop, date, total, lines
- [ ] Spending at a glance: per month, per person, per shop, from the receipts

## v0.3: Places and location

In steps, because background location is the hardest part of the project (permissions, store reviews, battery,
GDPR):

1. [ ] Places on a map (home, school, work) and arrive/leave events from the phone's native geofencing: "Roberto
       is at work since 9:12" on the home screen, with very little battery
2. [ ] The last known position of each member on a map, shared only while each person allows it
3. [ ] Continuous tracking, only if 1 and 2 turn out not to be enough

Every member can pause sharing at any time, and location history is kept for a short, fixed time.

## Later, maybe

- iOS (needs a Mac or a macOS CI runner, and an Apple developer account)
- Read-only calendar export (iCal)
- Email for invitations (Azure Communication Services)

## Left out on purpose

- **Bank connections.** PSD2 needs a regulated aggregator. Enable Banking's free mode (used in Finances Hub) only
  allows the developer's own accounts, and a multi-user product needs a commercial contract, plus the
  responsibility of storing other people's bank data. Reading receipts covers most of the value.
- **Group chat.** WhatsApp already won.
- **A web app.** Phones first.
- **Monetisation.** Peary is multi-tenant but free; no plans, no payments.
