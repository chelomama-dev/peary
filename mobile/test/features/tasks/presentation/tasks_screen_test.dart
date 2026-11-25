import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:peary/core/api/api_exception.dart';
import 'package:peary/core/demo/demo_store.dart';
import 'package:peary/core/formatting/date_formatting.dart';
import 'package:peary/features/groups/data/group_dtos.dart';
import 'package:peary/features/groups/data/groups_repository.dart';
import 'package:peary/features/me/data/me_dtos.dart';
import 'package:peary/features/me/data/me_repository.dart';
import 'package:peary/features/tasks/data/task_dtos.dart';
import 'package:peary/features/tasks/data/tasks_repository.dart';
import 'package:peary/features/tasks/presentation/tasks_screen.dart';

class _StubMeRepository implements MeRepository {
  @override
  Future<MeResponse> getMe() async => const MeResponse(
        userId: DemoStore.currentUserId,
        name: 'Roberto',
        email: 'roberto@example.com',
        groups: [
          GroupSummary(
            groupId: DemoStore.casaGroupId,
            name: 'Casa',
            role: GroupRole.admin,
            memberCount: 3,
          ),
        ],
        invitations: [],
      );

  @override
  Future<GroupDetail> acceptInvitation(String invitationId) =>
      throw UnimplementedError();

  @override
  Future<void> declineInvitation(String invitationId) =>
      throw UnimplementedError();
}

class _ConfigurableTasksRepository implements TasksRepository {
  _ConfigurableTasksRepository({
    required this.onListTasks,
  });

  final Future<TasksPage> Function(TaskStatus status) onListTasks;

  @override
  Future<TasksPage> listTasks(
    String groupId, {
    TaskStatus status = TaskStatus.open,
    String? assignee,
    String? cursor,
    int limit = 50,
  }) =>
      onListTasks(status);

  @override
  Future<CompleteTaskResponse> completeTask(String groupId, String taskId) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> createTask(String groupId, CreateTaskRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(String groupId, String taskId) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> getTask(String groupId, String taskId) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> reopenTask(String groupId, String taskId) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> updateTask(
    String groupId,
    String taskId,
    UpdateTaskRequest request,
  ) =>
      throw UnimplementedError();
}

Widget _buildTestApp({
  required TasksRepository tasksRepository,
  DateTime? now,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      meRepositoryProvider.overrideWithValue(_StubMeRepository()),
      currentGroupIdProvider.overrideWithValue(DemoStore.casaGroupId),
      tasksRepositoryProvider.overrideWithValue(tasksRepository),
    ],
    child: MaterialApp(
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: TasksScreen(now: now),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting(kSpanishLocale);
  });

  testWidgets('shows loading state while tasks are loading', (tester) async {
    final completer = Completer<TasksPage>();
    final repo = _ConfigurableTasksRepository(
      onListTasks: (_) => completer.future,
    );

    await tester.pumpWidget(_buildTestApp(tasksRepository: repo));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cargando tareas…'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no open tasks', (tester) async {
    final repo = _ConfigurableTasksRepository(
      onListTasks: (_) async => const TasksPage(items: [], nextCursor: null),
    );

    await tester.pumpWidget(_buildTestApp(tasksRepository: repo));
    await tester.pumpAndSettle();

    expect(find.text('No hay tareas pendientes'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });

  testWidgets('shows error state with Reintentar button and retries on tap',
      (tester) async {
    var attempts = 0;
    final repo = _ConfigurableTasksRepository(
      onListTasks: (_) async {
        attempts++;
        if (attempts == 1) {
          throw const ApiException(
            statusCode: 500,
            message: 'No se han podido cargar las tareas.',
          );
        }
        return const TasksPage(items: [], nextCursor: null);
      },
    );

    await tester.pumpWidget(_buildTestApp(tasksRepository: repo));
    await tester.pumpAndSettle();

    expect(find.text('No se han podido cargar las tareas.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('No hay tareas pendientes'), findsOneWidget);
  });

  testWidgets('shows grouped open tasks, completes repeating task, and filters Hechas',
      (tester) async {
    final fixedNow = DateTime(2026, 11, 25, 12, 0);
    final demoStore = DemoStore(now: fixedNow);
    final demoRepo = DemoTasksRepository(demoStore);

    await tester.pumpWidget(
      _buildTestApp(tasksRepository: demoRepo, now: fixedNow),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atrasadas'), findsOneWidget);
    expect(find.text('Hoy'), findsAtLeastNWidgets(1));
    expect(find.text('Próximamente'), findsOneWidget);
    expect(find.text('Revisar la presión de la caldera'), findsOneWidget);
    expect(find.text('Comprar pan y leche'), findsOneWidget);

    // Scroll down to verify the "Sin fecha" section is rendered too.
    await tester.scrollUntilVisible(find.text('Sin fecha'), 300);
    expect(find.text('Sin fecha'), findsOneWidget);
    expect(find.text('Ordenar el trastero'), findsOneWidget);

    // Switch to "Hechas" filter and verify done tasks appear.
    await tester.tap(find.text('Hechas'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar las sábanas'), findsOneWidget);

    // Switch back to "Pendientes" and complete a repeating task ("Comprar pan y leche").
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();

    final buyingTile = find.ancestor(
      of: find.text('Comprar pan y leche'),
      matching: find.byType(Card),
    );
    final checkbox = find.descendant(
      of: buyingTile,
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // The recurring next occurrence ("Mañana") appears in the open list.
    expect(find.text('Tarea completada. Próxima programada.'), findsOneWidget);
    expect(find.text('Comprar pan y leche'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);
  });
}
