import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/error_view.dart';
import '../core/widgets/loading_view.dart';
import '../features/groups/presentation/group_screen.dart';
import '../features/me/data/me_dtos.dart';
import '../features/me/data/me_repository.dart';
import '../features/me/presentation/onboarding_screen.dart';
import '../features/tasks/presentation/task_form_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import 'shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _RouterRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<AsyncValue<MeResponse>>(meProvider, (_, _) {
    refreshNotifier.trigger();
  });
  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/loading',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final meState = ref.read(meProvider);
      final location = state.matchedLocation;

      if (meState.isLoading && !meState.hasValue) {
        return location == '/loading' ? null : '/loading';
      }

      if (meState.hasError && !meState.hasValue) {
        return location == '/error' ? null : '/error';
      }

      final me = meState.asData?.value;
      if (me == null) {
        return location == '/loading' ? null : '/loading';
      }

      if (me.groups.isEmpty) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      if (location == '/loading' ||
          location == '/error' ||
          location == '/onboarding') {
        return '/tasks';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          body: LoadingView(message: 'Cargando tu espacio…'),
        ),
      ),
      GoRoute(
        path: '/error',
        builder: (context, state) => const _StartupErrorScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const TaskFormScreen(),
                  ),
                  GoRoute(
                    path: ':taskId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => TaskFormScreen(
                      taskId: state.pathParameters['taskId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/group',
                builder: (context, state) => const GroupScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class _StartupErrorScreen extends ConsumerWidget {
  const _StartupErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(meProvider).error ?? 'Error al cargar los datos.';
    return Scaffold(
      appBar: AppBar(title: const Text('Peary')),
      body: ErrorView(
        title: 'No se pudo iniciar',
        error: error,
        onRetry: () => ref.read(meProvider.notifier).refresh(),
      ),
    );
  }
}
