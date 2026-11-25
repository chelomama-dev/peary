import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/demo/demo_store.dart';
import '../../groups/data/groups_repository.dart';
import 'task_dtos.dart';
import 'task_grouping.dart';

abstract interface class TasksRepository {
  Future<TasksPage> listTasks(
    String groupId, {
    TaskStatus status = TaskStatus.open,
    String? assignee,
    String? cursor,
    int limit = 50,
  });

  Future<TaskItem> getTask(String groupId, String taskId);

  Future<TaskItem> createTask(String groupId, CreateTaskRequest request);

  Future<TaskItem> updateTask(
    String groupId,
    String taskId,
    UpdateTaskRequest request,
  );

  Future<void> deleteTask(String groupId, String taskId);

  Future<CompleteTaskResponse> completeTask(String groupId, String taskId);

  Future<TaskItem> reopenTask(String groupId, String taskId);
}

class HttpTasksRepository implements TasksRepository {
  const HttpTasksRepository(this._client);

  final ApiClient _client;

  @override
  Future<TasksPage> listTasks(
    String groupId, {
    TaskStatus status = TaskStatus.open,
    String? assignee,
    String? cursor,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'status': status.apiValue,
      'limit': limit,
      if (assignee != null && assignee.isNotEmpty) 'assignee': assignee,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final json = await _client.getJson(
      '/api/groups/$groupId/tasks',
      queryParameters: query,
    );
    return TasksPage.fromJson(json);
  }

  @override
  Future<TaskItem> getTask(String groupId, String taskId) async {
    final json = await _client.getJson('/api/groups/$groupId/tasks/$taskId');
    return TaskItem.fromJson(json);
  }

  @override
  Future<TaskItem> createTask(
    String groupId,
    CreateTaskRequest request,
  ) async {
    final json = await _client.postJson(
      '/api/groups/$groupId/tasks',
      data: request.toJson(),
    );
    return TaskItem.fromJson(json);
  }

  @override
  Future<TaskItem> updateTask(
    String groupId,
    String taskId,
    UpdateTaskRequest request,
  ) async {
    final json = await _client.patchJson(
      '/api/groups/$groupId/tasks/$taskId',
      data: request.toJson(),
    );
    return TaskItem.fromJson(json);
  }

  @override
  Future<void> deleteTask(String groupId, String taskId) async {
    await _client.deleteNoContent('/api/groups/$groupId/tasks/$taskId');
  }

  @override
  Future<CompleteTaskResponse> completeTask(
    String groupId,
    String taskId,
  ) async {
    final json = await _client.postJson(
      '/api/groups/$groupId/tasks/$taskId/complete',
    );
    return CompleteTaskResponse.fromJson(json);
  }

  @override
  Future<TaskItem> reopenTask(String groupId, String taskId) async {
    final json = await _client.postJson(
      '/api/groups/$groupId/tasks/$taskId/reopen',
    );
    return TaskItem.fromJson(json);
  }
}

class DemoTasksRepository implements TasksRepository {
  const DemoTasksRepository(this._store);

  final DemoStore _store;

  @override
  Future<TasksPage> listTasks(
    String groupId, {
    TaskStatus status = TaskStatus.open,
    String? assignee,
    String? cursor,
    int limit = 50,
  }) async {
    return _store.listTasks(
      groupId,
      status: status,
      assignee: assignee,
      limit: limit,
    );
  }

  @override
  Future<TaskItem> getTask(String groupId, String taskId) async =>
      _store.getTask(groupId, taskId);

  @override
  Future<TaskItem> createTask(
    String groupId,
    CreateTaskRequest request,
  ) async =>
      _store.createTask(groupId, request);

  @override
  Future<TaskItem> updateTask(
    String groupId,
    String taskId,
    UpdateTaskRequest request,
  ) async =>
      _store.updateTask(groupId, taskId, request);

  @override
  Future<void> deleteTask(String groupId, String taskId) async =>
      _store.deleteTask(groupId, taskId);

  @override
  Future<CompleteTaskResponse> completeTask(
    String groupId,
    String taskId,
  ) async =>
      _store.completeTask(groupId, taskId);

  @override
  Future<TaskItem> reopenTask(String groupId, String taskId) async =>
      _store.reopenTask(groupId, taskId);
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.demoMode) {
    return DemoTasksRepository(ref.watch(demoStoreProvider));
  }
  return HttpTasksRepository(ref.watch(apiClientProvider));
});

class TasksStatusFilterNotifier extends Notifier<TaskStatus> {
  @override
  TaskStatus build() => TaskStatus.open;

  void setStatus(TaskStatus status) {
    state = status;
  }
}

final tasksStatusFilterProvider =
    NotifierProvider<TasksStatusFilterNotifier, TaskStatus>(
  TasksStatusFilterNotifier.new,
);

class TasksListNotifier extends AsyncNotifier<List<TaskItem>> {
  @override
  Future<List<TaskItem>> build() async {
    final groupId = ref.watch(currentGroupIdProvider);
    final status = ref.watch(tasksStatusFilterProvider);
    if (groupId == null) return const [];
    final page = await ref
        .watch(tasksRepositoryProvider)
        .listTasks(groupId, status: status);
    return page.items;
  }

  Future<void> refresh() async {
    final groupId = ref.read(currentGroupIdProvider);
    final status = ref.read(tasksStatusFilterProvider);
    if (groupId == null) {
      state = const AsyncData([]);
      return;
    }
    if (state.hasError) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(tasksRepositoryProvider)
          .listTasks(groupId, status: status);
      return page.items;
    });
  }

  Future<CompleteTaskResponse> completeTask(String taskId) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null) {
      throw StateError('No active group');
    }
    final response =
        await ref.read(tasksRepositoryProvider).completeTask(groupId, taskId);

    final current = state.asData?.value;
    if (current != null && ref.read(tasksStatusFilterProvider) == TaskStatus.open) {
      final updated = current.where((t) => t.taskId != taskId).toList();
      if (response.next != null) {
        updated.add(response.next!);
      }
      updated.sort(compareOpenTasks);
      state = AsyncData(updated);
    } else {
      await refresh();
    }
    return response;
  }

  Future<TaskItem> reopenTask(String taskId) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null) {
      throw StateError('No active group');
    }
    final reopened =
        await ref.read(tasksRepositoryProvider).reopenTask(groupId, taskId);

    final current = state.asData?.value;
    if (current != null && ref.read(tasksStatusFilterProvider) == TaskStatus.done) {
      final updated = current.where((t) => t.taskId != taskId).toList();
      state = AsyncData(updated);
    } else {
      await refresh();
    }
    return reopened;
  }

  Future<TaskItem> createTask(CreateTaskRequest request) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null) {
      throw StateError('No active group');
    }
    final created =
        await ref.read(tasksRepositoryProvider).createTask(groupId, request);
    await refresh();
    return created;
  }

  Future<TaskItem> updateTask(String taskId, UpdateTaskRequest request) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null) {
      throw StateError('No active group');
    }
    final updated = await ref
        .read(tasksRepositoryProvider)
        .updateTask(groupId, taskId, request);
    await refresh();
    return updated;
  }

  Future<void> deleteTask(String taskId) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null) {
      throw StateError('No active group');
    }
    await ref.read(tasksRepositoryProvider).deleteTask(groupId, taskId);
    await refresh();
  }
}

final tasksListProvider =
    AsyncNotifierProvider<TasksListNotifier, List<TaskItem>>(
  TasksListNotifier.new,
);

final taskDetailProvider =
    FutureProvider.family<TaskItem, String>((ref, taskId) async {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) {
    throw StateError('No active group');
  }
  return ref.watch(tasksRepositoryProvider).getTask(groupId, taskId);
});
