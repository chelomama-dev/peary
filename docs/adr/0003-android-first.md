# ADR 0003: Android first

- Status: accepted
- Date: 2026-11-25

## Context

Flutter builds for Android and iOS from the same code, but the owner develops on Linux. Building, signing and
testing an iOS app needs macOS (a Mac or a macOS CI runner), an Apple Developer Program membership to install it
on real phones beyond a few days, and its own setup for push notifications (APNs) and background location.

## Decision

- v0.1 to v0.3 target **Android only**. The app is installed from a signed APK published in GitHub releases, as
  in Finances Hub; no store yet.
- The code avoids Android-only assumptions: platform specifics stay behind interfaces (auth, notifications,
  location), and packages are chosen only if they support iOS too.
- iOS is reconsidered when someone in the test families needs it.

## Consequences

- Family members with an iPhone can't use Peary until then. Accepted for the MVP.
- No Apple fees or macOS runners until iOS is worth it.
- Push notifications go through Firebase Cloud Messaging, which also delivers to iOS through APNs, so the backend
  won't change when iOS comes.
