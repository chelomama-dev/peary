import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/formatting/date_formatting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(kSpanishLocale);
  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      child: const PearyApp(),
    ),
  );
}
