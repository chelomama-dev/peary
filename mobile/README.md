# Peary mobile (Flutter)

Android-first Flutter client for Peary ([ADR 0003](../docs/adr/0003-android-first.md)), implementing the HTTP contract in [docs/api.md](../docs/api.md).

## Commands

Run all commands from `mobile/`:

```bash
# Install dependencies
flutter pub get

# Generate json_serializable code (*.g.dart)
dart run build_runner build --delete-conflicting-outputs

# Static analysis
flutter analyze

# Unit and widget tests
flutter test

# Run in demo mode (in-memory fake repositories, no backend required)
flutter run --dart-define=DEMO=true

# Run against a local API from the Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080

# Build a debug APK in demo mode
flutter build apk --debug --dart-define=DEMO=true
```

## Configuration

Runtime settings come from `--dart-define` (or `--dart-define-from-file=config/azure.json`, see [config/azure.example.json](config/azure.example.json)):

- `DEMO` (`bool`, default `false`): uses in-memory demo repositories seeded with made-up data shaped after `docs/api.md`.
- `API_BASE_URL` (`String`, default `http://10.0.2.2:5080`): base URL of the Peary API.

Plain HTTP is only permitted in debug builds (`android/app/src/debug/res/xml/network_security_config.xml`); release builds require HTTPS.
