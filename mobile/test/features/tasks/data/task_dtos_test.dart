import 'package:flutter_test/flutter_test.dart';
import 'package:peary/features/tasks/data/task_dtos.dart';

void main() {
  final sampleTaskJson = <String, dynamic>{
    'taskId': '4a5b6c7d-8e9f-4a0b-9c1d-2e3f4a5b6c7d',
    'title': 'Dentista de Pablo',
    'notes': 'Llevar la tarjeta sanitaria',
    'assignee': {
      'userId': '7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d',
      'name': 'Lucía',
    },
    'dueDate': '2026-11-28',
    'dueTime': '17:30',
    'recurrence': 'none',
    'reminderMinutesBefore': 60,
    'status': 'open',
    'completedAt': null,
    'completedBy': null,
    'createdBy': {
      'userId': '6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c',
      'name': 'Roberto',
    },
    'createdAt': '2026-11-25T18:10:00Z',
    'updatedAt': '2026-11-25T18:10:00Z',
    'extraFutureField': 'ignored',
  };

  group('Task DTOs', () {
    test('parses the task object example from docs/api.md', () {
      final task = TaskItem.fromJson(sampleTaskJson);

      expect(task.taskId, '4a5b6c7d-8e9f-4a0b-9c1d-2e3f4a5b6c7d');
      expect(task.title, 'Dentista de Pablo');
      expect(task.notes, 'Llevar la tarjeta sanitaria');
      expect(task.assignee?.userId, '7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d');
      expect(task.assignee?.name, 'Lucía');
      expect(task.dueDate, '2026-11-28');
      expect(task.dueTime, '17:30');
      expect(task.recurrence, TaskRecurrence.none);
      expect(task.reminderMinutesBefore, 60);
      expect(task.status, TaskStatus.open);
      expect(task.isDone, isFalse);
      expect(task.completedAt, isNull);
      expect(task.completedBy, isNull);
      expect(task.createdBy.name, 'Roberto');
      expect(task.createdAt, DateTime.utc(2026, 11, 25, 18, 10, 0));
    });

    test('parses TasksPage and CompleteTaskResponse examples', () {
      final page = TasksPage.fromJson({
        'items': [sampleTaskJson],
        'nextCursor': 'opaque-cursor-token',
      });
      expect(page.items, hasLength(1));
      expect(page.nextCursor, 'opaque-cursor-token');

      final completedJson = Map<String, dynamic>.from(sampleTaskJson)
        ..['status'] = 'done'
        ..['completedAt'] = '2026-11-28T18:00:00Z'
        ..['completedBy'] = {
          'userId': '6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c',
          'name': 'Roberto',
        };

      final response = CompleteTaskResponse.fromJson({
        'completed': completedJson,
        'next': null,
      });
      expect(response.completed.isDone, isTrue);
      expect(response.completed.completedBy?.name, 'Roberto');
      expect(response.next, isNull);
    });

    test('serializes CreateTaskRequest matching docs/api.md', () {
      const request = CreateTaskRequest(
        title: 'Recoger la secadora',
        notes: null,
        assigneeId: '7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d',
        dueDate: '2026-11-26',
        dueTime: null,
        recurrence: TaskRecurrence.weekly,
        reminderMinutesBefore: null,
      );

      expect(request.toJson(), {
        'title': 'Recoger la secadora',
        'notes': null,
        'assigneeId': '7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d',
        'dueDate': '2026-11-26',
        'dueTime': null,
        'recurrence': 'weekly',
        'reminderMinutesBefore': null,
      });
    });

    test('UpdateTaskRequest sends only changed fields and null when clearing', () {
      const patch = UpdateTaskRequest(
        title: PatchField.value('Nuevo título'),
        notes: PatchField.value(null),
        recurrence: PatchField.value(TaskRecurrence.daily),
      );

      expect(patch.isEmpty, isFalse);
      expect(patch.toJson(), {
        'title': 'Nuevo título',
        'notes': null,
        'recurrence': 'daily',
      });
      expect(patch.toJson().containsKey('dueDate'), isFalse);
      expect(patch.toJson().containsKey('assigneeId'), isFalse);
    });
  });
}
