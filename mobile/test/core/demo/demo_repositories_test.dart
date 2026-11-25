import 'package:flutter_test/flutter_test.dart';
import 'package:peary/core/api/api_exception.dart';
import 'package:peary/core/demo/demo_store.dart';
import 'package:peary/features/groups/data/group_dtos.dart';
import 'package:peary/features/groups/data/groups_repository.dart';
import 'package:peary/features/me/data/me_repository.dart';
import 'package:peary/features/tasks/data/task_dtos.dart';
import 'package:peary/features/tasks/data/tasks_repository.dart';

void main() {
  late DemoStore store;
  late DemoMeRepository meRepo;
  late DemoGroupsRepository groupsRepo;
  late DemoTasksRepository tasksRepo;

  setUp(() {
    store = DemoStore(now: DateTime(2026, 11, 25, 12, 0));
    meRepo = DemoMeRepository(store);
    groupsRepo = DemoGroupsRepository(store);
    tasksRepo = DemoTasksRepository(store);
  });

  group('DemoMeRepository & DemoGroupsRepository', () {
    test('returns seeded groups ordered by name and pending invitations', () async {
      final me = await meRepo.getMe();

      expect(me.userId, DemoStore.currentUserId);
      expect(me.groups.map((g) => g.name), ['Casa', 'Casa de la playa']);
      expect(me.invitations, hasLength(1));
      expect(me.invitations.first.group.name, 'Piso de la abuela');
    });

    test('creates a new group with caller as admin', () async {
      final created = await groupsRepo.createGroup(
        const CreateGroupRequest(name: 'Familia', timeZone: 'Europe/Madrid'),
      );

      expect(created.name, 'Familia');
      expect(created.myRole, GroupRole.admin);
      expect(created.members, hasLength(1));

      final me = await meRepo.getMe();
      expect(me.groups.any((g) => g.groupId == created.groupId), isTrue);
    });

    test('accepts and declines pending invitations', () async {
      final joined =
          await meRepo.acceptInvitation(DemoStore.abuelaInvitationId);
      expect(joined.name, 'Piso de la abuela');
      expect(joined.myRole, GroupRole.member);

      final me = await meRepo.getMe();
      expect(me.invitations, isEmpty);
      expect(me.groups.any((g) => g.groupId == joined.groupId), isTrue);

      final freshStore = DemoStore(
        now: DateTime(2026, 11, 25, 12, 0),
        startWithoutGroups: true,
      );
      final freshMeRepo = DemoMeRepository(freshStore);
      await freshMeRepo.declineInvitation(DemoStore.abuelaInvitationId);
      expect((await freshMeRepo.getMe()).invitations, isEmpty);
    });

    test('throws 404 ApiException for unknown group', () async {
      await expectLater(
        groupsRepo.getGroup('non-existent-group'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('DemoTasksRepository', () {
    test('creates, updates, completes repeating task, reopens and deletes', () async {
      final created = await tasksRepo.createTask(
        DemoStore.casaGroupId,
        const CreateTaskRequest(
          title: 'Regar las plantas',
          notes: 'Terraza y salón',
          assigneeId: DemoStore.luciaUserId,
          dueDate: '2026-11-25',
          dueTime: '20:00',
          recurrence: TaskRecurrence.weekly,
          reminderMinutesBefore: 30,
        ),
      );
      expect(created.title, 'Regar las plantas');
      expect(created.assignee?.name, 'Lucía');

      final updated = await tasksRepo.updateTask(
        DemoStore.casaGroupId,
        created.taskId,
        const UpdateTaskRequest(
          notes: PatchField.value(null),
          title: PatchField.value('Regar todas las plantas'),
        ),
      );
      expect(updated.title, 'Regar todas las plantas');
      expect(updated.notes, isNull);

      final completion =
          await tasksRepo.completeTask(DemoStore.casaGroupId, created.taskId);
      expect(completion.completed.isDone, isTrue);
      expect(completion.next, isNotNull);
      expect(completion.next!.dueDate, '2026-12-02');
      expect(completion.next!.isDone, isFalse);

      // Completing an already done task returns 409.
      await expectLater(
        tasksRepo.completeTask(DemoStore.casaGroupId, created.taskId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );

      // Editing a done task returns 409.
      await expectLater(
        tasksRepo.updateTask(
          DemoStore.casaGroupId,
          created.taskId,
          const UpdateTaskRequest(title: PatchField.value('Otro')),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );

      final reopened =
          await tasksRepo.reopenTask(DemoStore.casaGroupId, created.taskId);
      expect(reopened.isDone, isFalse);

      await tasksRepo.deleteTask(DemoStore.casaGroupId, created.taskId);
      await expectLater(
        tasksRepo.getTask(DemoStore.casaGroupId, created.taskId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });
}
