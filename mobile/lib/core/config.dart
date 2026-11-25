import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime configuration supplied via `--dart-define`.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.demoMode,
  });

  factory AppConfig.fromEnvironment() {
    const rawUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5080',
    );
    const demo = bool.fromEnvironment('DEMO', defaultValue: false);
    return AppConfig(
      apiBaseUrl: rawUrl.endsWith('/')
          ? rawUrl.substring(0, rawUrl.length - 1)
          : rawUrl,
      demoMode: demo,
    );
  }

  final String apiBaseUrl;
  final bool demoMode;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
