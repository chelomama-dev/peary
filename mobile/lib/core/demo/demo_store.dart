import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../formatting/date_formatting.dart';
import '../../features/groups/data/group_dtos.dart';
import '../../features/me/data/me_dtos.dart';
import '../../features/tasks/data/task_dtos.dart';
import '../../features/tasks/data/task_grouping.dart';

/// Shared in-memory store backing the demo repositories when `DEMO=true`.
///
/// All fixtures are made up and shaped after the examples in `docs/api.md`.
class DemoStore {
  DemoStore({
    DateTime? now,
    bool startWithoutGroups = false,
  }) : _clock = now {
    _seed(startWithoutGroups: startWithoutGroups);
  }

  static const String currentUserId = '6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c';
  static const String currentUserName = 'Roberto';
  static const String currentUserEmail = 'roberto@example.com';

  static const String luciaUserId = '7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d';
  static const String pabloUserId = '8d3f4e0a-7b2c-4e3a-9c9d-4f5a6b7c8d9e';

  static const String casaGroupId = '0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e';
  static const String playaGroupId = '2e3f4a5b-6c7d-4e8f-9a0b-1c2d3e4f5a6b';
  static const String abuelaGroupId = '1d2e3f4a-5b6c-4d7e-8f9a-0b1c2d3e4f5a';
  static const String abuelaInvitationId =
      '9e8d7c6b-5a4f-4e3d-2c1b-0a9f8e7d6c5b';

  final DateTime? _clock;
  int _idCounter = 1;

  final Map<String, GroupDetail> _groups = {};
  final Map<String, GroupDetail> _invitedGroups = {};
  final List<PendingInvitation> _invitations = [];
  final Map<String, List<TaskItem>> _tasksByGroup = {};

  DateTime get _now => _clock ?? DateTime.now();

  String _nextId(String prefix) {
    final n = (_idCounter++).toString().padLeft(4, '0');
    return '00000000-0000-4000-8000-$prefix$n';
  }

  void _seed({required bool startWithoutGroups}) {
    final nowUtc = _now.toUtc();
    final today = DateTime(_now.year, _now.month, _now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final inThreeDays = DateTime(today.year, today.month, today.day + 3);
    final inTenDays = DateTime(today.year, today.month, today.day + 10);
    final inFiveDays = DateTime(today.year, today.month, today.day + 5);

    const robertoRef = TaskUserRef(
      userId: currentUserId,
      name: currentUserName,
    );
    const luciaRef = TaskUserRef(
      userId: luciaUserId,
      name: 'Lucía',
    );

    if (!startWithoutGroups) {
      _groups[casaGroupId] = GroupDetail(
        groupId: casaGroupId,
        name: 'Casa',
        timeZone: 'Europe/Madrid',
        myRole: GroupRole.admin,
        createdAt: nowUtc.subtract(const Duration(days: 30)),
        members: [
          GroupMember(
            userId: currentUserId,
            name: currentUserName,
            email: currentUserEmail,
            role: GroupRole.admin,
            joinedAt: nowUtc.subtract(const Duration(days: 30)),
          ),
          GroupMember(
            userId: luciaUserId,
            name: 'Lucía',
            email: 'lucia@example.com',
            role: GroupRole.member,
            joinedAt: nowUtc.subtract(const Duration(days: 29)),
          ),
          GroupMember(
            userId: pabloUserId,
            name: 'Pablo',
            email: 'pablo@example.com',
            role: GroupRole.member,
            joinedAt: nowUtc.subtract(const Duration(days: 20)),
          ),
        ],
      );

      _groups[playaGroupId] = GroupDetail(
        groupId: playaGroupId,
        name: 'Casa de la playa',
        timeZone: 'Europe/Madrid',
        myRole: GroupRole.member,
        createdAt: nowUtc.subtract(const Duration(days: 14)),
        members: [
          GroupMember(
            userId: luciaUserId,
            name: 'Lucía',
            email: 'lucia@example.com',
            role: GroupRole.admin,
            joinedAt: nowUtc.subtract(const Duration(days: 14)),
          ),
          GroupMember(
            userId: currentUserId,
            name: currentUserName,
            email: currentUserEmail,
            role: GroupRole.member,
            joinedAt: nowUtc.subtract(const Duration(days: 13)),
          ),
        ],
      );

      _tasksByGroup[casaGroupId] = [
        TaskItem(
          taskId: '11111111-1111-4111-8111-111111111111',
          title: 'Revisar la presión de la caldera',
          notes: 'Debe estar entre 1,2 y 1,5 bares.',
          assignee: robertoRef,
          dueDate: formatApiDate(yesterday),
          dueTime: null,
          recurrence: TaskRecurrence.none,
          reminderMinutesBefore: null,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: robertoRef,
          createdAt: nowUtc.subtract(const Duration(days: 4)),
          updatedAt: nowUtc.subtract(const Duration(days: 4)),
        ),
        TaskItem(
          taskId: '22222222-2222-4222-8222-222222222222',
          title: 'Comprar pan y leche',
          notes: null,
          assignee: null,
          dueDate: formatApiDate(today),
          dueTime: null,
          recurrence: TaskRecurrence.daily,
          reminderMinutesBefore: null,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: luciaRef,
          createdAt: nowUtc.subtract(const Duration(days: 2)),
          updatedAt: nowUtc.subtract(const Duration(days: 2)),
        ),
        TaskItem(
          taskId: '33333333-3333-4333-8333-333333333333',
          title: 'Recoger la secadora',
          notes: 'Doblar las toallas antes de que se arruguen.',
          assignee: luciaRef,
          dueDate: formatApiDate(today),
          dueTime: '19:00',
          recurrence: TaskRecurrence.weekly,
          reminderMinutesBefore: 30,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: robertoRef,
          createdAt: nowUtc.subtract(const Duration(days: 1)),
          updatedAt: nowUtc.subtract(const Duration(days: 1)),
        ),
        TaskItem(
          taskId: '4a5b6c7d-8e9f-4a0b-9c1d-2e3f4a5b6c7d',
          title: 'Dentista de Pablo',
          notes: 'Llevar la tarjeta sanitaria',
          assignee: luciaRef,
          dueDate: formatApiDate(inThreeDays),
          dueTime: '17:30',
          recurrence: TaskRecurrence.none,
          reminderMinutesBefore: 60,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: robertoRef,
          createdAt: nowUtc.subtract(const Duration(hours: 6)),
          updatedAt: nowUtc.subtract(const Duration(hours: 6)),
        ),
        TaskItem(
          taskId: '55555555-5555-4555-8555-555555555555',
          title: 'Pagar el recibo de la comunidad',
          notes: null,
          assignee: robertoRef,
          dueDate: formatApiDate(inTenDays),
          dueTime: null,
          recurrence: TaskRecurrence.monthly,
          reminderMinutesBefore: null,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: robertoRef,
          createdAt: nowUtc.subtract(const Duration(days: 5)),
          updatedAt: nowUtc.subtract(const Duration(days: 5)),
        ),
        TaskItem(
          taskId: '66666666-6666-4666-8666-666666666666',
          title: 'Ordenar el trastero',
          notes: 'Separar lo que ya no usamos para donar.',
          assignee: null,
          dueDate: null,
          dueTime: null,
          recurrence: TaskRecurrence.none,
          reminderMinutesBefore: null,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: luciaRef,
          createdAt: nowUtc.subtract(const Duration(days: 3)),
          updatedAt: nowUtc.subtract(const Duration(days: 3)),
        ),
        TaskItem(
          taskId: '77777777-7777-4777-8777-777777777777',
          title: 'Cambiar las sábanas',
          notes: null,
          assignee: luciaRef,
          dueDate: formatApiDate(yesterday),
          dueTime: null,
          recurrence: TaskRecurrence.weekly,
          reminderMinutesBefore: null,
          status: TaskStatus.done,
          completedAt: nowUtc.subtract(const Duration(hours: 18)),
          completedBy: luciaRef,
          createdBy: robertoRef,
          createdAt: nowUtc.subtract(const Duration(days: 7)),
          updatedAt: nowUtc.subtract(const Duration(hours: 18)),
        ),
      ];

      _tasksByGroup[playaGroupId] = [
        TaskItem(
          taskId: '88888888-8888-4888-8888-888888888888',
          title: 'Llamar al electricista',
          notes: 'Revisar el enchufe de la terraza.',
          assignee: robertoRef,
          dueDate: formatApiDate(inFiveDays),
          dueTime: '11:00',
          recurrence: TaskRecurrence.none,
          reminderMinutesBefore: 60,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: luciaRef,
          createdAt: nowUtc.subtract(const Duration(days: 2)),
          updatedAt: nowUtc.subtract(const Duration(days: 2)),
        ),
        TaskItem(
          taskId: '99999999-9999-4999-8999-999999999999',
          title: 'Comprar sombrilla nueva',
          notes: null,
          assignee: null,
          dueDate: null,
          dueTime: null,
          recurrence: TaskRecurrence.none,
          reminderMinutesBefore: null,
          status: TaskStatus.open,
          completedAt: null,
          completedBy: null,
          createdBy: robertoRef,
          createdAt: nowUtc.subtract(const Duration(days: 1)),
          updatedAt: nowUtc.subtract(const Duration(days: 1)),
        ),
      ];
    }

    _invitations.add(
      PendingInvitation(
        invitationId: abuelaInvitationId,
        group: const InvitationGroup(
          groupId: abuelaGroupId,
          name: 'Piso de la abuela',
        ),
        invitedBy: 'Lucía',
        expiresAt: nowUtc.add(const Duration(days: 7)),
      ),
    );

    _invitedGroups[abuelaGroupId] = GroupDetail(
      groupId: abuelaGroupId,
      name: 'Piso de la abuela',
      timeZone: 'Europe/Madrid',
      myRole: GroupRole.member,
      createdAt: nowUtc.subtract(const Duration(days: 10)),
      members: [
        GroupMember(
          userId: luciaUserId,
          name: 'Lucía',
          email: 'lucia@example.com',
          role: GroupRole.admin,
          joinedAt: nowUtc.subtract(const Duration(days: 10)),
        ),
      ],
    );
  }

  MeResponse getMe() {
    final summaries = _groups.values
        .map(
          (g) => GroupSummary(
            groupId: g.groupId,
            name: g.name,
            role: g.myRole,
            memberCount: g.members.length,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return MeResponse(
      userId: currentUserId,
      name: currentUserName,
      email: currentUserEmail,
      groups: summaries,
      invitations: List.unmodifiable(_invitations),
    );
  }

  GroupDetail getGroup(String groupId) {
    final group = _groups[groupId];
    if (group == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'No se ha encontrado el grupo.',
      );
    }
    return group;
  }

  GroupDetail createGroup(CreateGroupRequest request) {
    final trimmedName = request.name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 60) {
      throw const ApiException(
        statusCode: 400,
        message: 'El nombre del grupo debe tener entre 1 y 60 caracteres.',
      );
    }
    final nowUtc = _now.toUtc();
    final groupId = _nextId('00001000');
    final created = GroupDetail(
      groupId: groupId,
      name: trimmedName,
      timeZone: request.timeZone,
      myRole: GroupRole.admin,
      createdAt: nowUtc,
      members: [
        GroupMember(
          userId: currentUserId,
          name: currentUserName,
          email: currentUserEmail,
          role: GroupRole.admin,
          joinedAt: nowUtc,
        ),
      ],
    );
    _groups[groupId] = created;
    _tasksByGroup[groupId] = [];
    return created;
  }

  GroupDetail acceptInvitation(String invitationId) {
    final index =
        _invitations.indexWhere((inv) => inv.invitationId == invitationId);
    if (index == -1) {
      throw const ApiException(
        statusCode: 404,
        message: 'La invitación ya no está disponible.',
      );
    }
    final invitation = _invitations.removeAt(index);
    final template = _invitedGroups.remove(invitation.group.groupId);
    final nowUtc = _now.toUtc();

    final members = [
      ...(template?.members ?? const <GroupMember>[]),
      GroupMember(
        userId: currentUserId,
        name: currentUserName,
        email: currentUserEmail,
        role: GroupRole.member,
        joinedAt: nowUtc,
      ),
    ];

    final joined = GroupDetail(
      groupId: invitation.group.groupId,
      name: invitation.group.name,
      timeZone: template?.timeZone ?? 'Europe/Madrid',
      myRole: GroupRole.member,
      members: members,
      createdAt: template?.createdAt ?? nowUtc,
    );

    _groups[joined.groupId] = joined;
    _tasksByGroup.putIfAbsent(joined.groupId, () => []);
    return joined;
  }

  void declineInvitation(String invitationId) {
    final index =
        _invitations.indexWhere((inv) => inv.invitationId == invitationId);
    if (index == -1) {
      throw const ApiException(
        statusCode: 404,
        message: 'La invitación ya no está disponible.',
      );
    }
    _invitations.removeAt(index);
  }

  TasksPage listTasks(
    String groupId, {
    TaskStatus status = TaskStatus.open,
    String? assignee,
    int limit = 50,
  }) {
    final tasks = _requireGroupTasks(groupId);
    final filtered = tasks.where((task) {
      if (task.status != status) return false;
      if (assignee == 'me') {
        return task.assignee?.userId == currentUserId;
      }
      if (assignee == 'unassigned') {
        return task.assignee == null;
      }
      if (assignee != null && assignee.isNotEmpty) {
        return task.assignee?.userId == assignee;
      }
      return true;
    }).toList();

    if (status == TaskStatus.open) {
      filtered.sort(compareOpenTasks);
    } else {
      filtered.sort(compareDoneTasks);
    }

    return TasksPage(
      items: filtered.take(limit).toList(),
      nextCursor: null,
    );
  }

  TaskItem getTask(String groupId, String taskId) {
    final tasks = _requireGroupTasks(groupId);
    for (final task in tasks) {
      if (task.taskId == taskId) return task;
    }
    throw const ApiException(
      statusCode: 404,
      message: 'No se ha encontrado la tarea.',
    );
  }

  TaskItem createTask(String groupId, CreateTaskRequest request) {
    final group = getGroup(groupId);
    final tasks = _requireGroupTasks(groupId);
    final title = request.title.trim();
    if (title.isEmpty || title.length > 200) {
      throw const ApiException(
        statusCode: 400,
        message: 'El título debe tener entre 1 y 200 caracteres.',
      );
    }
    _validateTaskScheduling(
      dueDate: request.dueDate,
      dueTime: request.dueTime,
      recurrence: request.recurrence,
      reminderMinutesBefore: request.reminderMinutesBefore,
    );

    final assignee = _resolveAssignee(group, request.assigneeId);
    final nowUtc = _now.toUtc();
    final task = TaskItem(
      taskId: _nextId('00002000'),
      title: title,
      notes: _normalizeNotes(request.notes),
      assignee: assignee,
      dueDate: request.dueDate,
      dueTime: request.dueTime,
      recurrence: request.recurrence,
      reminderMinutesBefore: request.reminderMinutesBefore,
      status: TaskStatus.open,
      completedAt: null,
      completedBy: null,
      createdBy: const TaskUserRef(
        userId: currentUserId,
        name: currentUserName,
      ),
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
    tasks.add(task);
    return task;
  }

  TaskItem updateTask(
    String groupId,
    String taskId,
    UpdateTaskRequest request,
  ) {
    final group = getGroup(groupId);
    final tasks = _requireGroupTasks(groupId);
    final index = tasks.indexWhere((t) => t.taskId == taskId);
    if (index == -1) {
      throw const ApiException(
        statusCode: 404,
        message: 'No se ha encontrado la tarea.',
      );
    }
    final existing = tasks[index];
    if (existing.status == TaskStatus.done) {
      throw const ApiException(
        statusCode: 409,
        message: 'No se puede editar una tarea hecha. Ábrela de nuevo primero.',
      );
    }

    final title =
        request.title.isSet ? request.title.value!.trim() : existing.title;
    if (title.isEmpty || title.length > 200) {
      throw const ApiException(
        statusCode: 400,
        message: 'El título debe tener entre 1 y 200 caracteres.',
      );
    }

    final notes = request.notes.isSet
        ? _normalizeNotes(request.notes.value)
        : existing.notes;
    final assignee = request.assigneeId.isSet
        ? _resolveAssignee(group, request.assigneeId.value)
        : existing.assignee;
    final dueDate =
        request.dueDate.isSet ? request.dueDate.value : existing.dueDate;
    final dueTime =
        request.dueTime.isSet ? request.dueTime.value : existing.dueTime;
    final recurrence = request.recurrence.isSet
        ? request.recurrence.value!
        : existing.recurrence;
    final reminder = request.reminderMinutesBefore.isSet
        ? request.reminderMinutesBefore.value
        : existing.reminderMinutesBefore;

    _validateTaskScheduling(
      dueDate: dueDate,
      dueTime: dueTime,
      recurrence: recurrence,
      reminderMinutesBefore: reminder,
    );

    final updated = TaskItem(
      taskId: existing.taskId,
      title: title,
      notes: notes,
      assignee: assignee,
      dueDate: dueDate,
      dueTime: dueTime,
      recurrence: recurrence,
      reminderMinutesBefore: reminder,
      status: existing.status,
      completedAt: existing.completedAt,
      completedBy: existing.completedBy,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: _now.toUtc(),
    );
    tasks[index] = updated;
    return updated;
  }

  void deleteTask(String groupId, String taskId) {
    final tasks = _requireGroupTasks(groupId);
    final index = tasks.indexWhere((t) => t.taskId == taskId);
    if (index == -1) {
      throw const ApiException(
        statusCode: 404,
        message: 'No se ha encontrado la tarea.',
      );
    }
    tasks.removeAt(index);
  }

  CompleteTaskResponse completeTask(String groupId, String taskId) {
    final tasks = _requireGroupTasks(groupId);
    final index = tasks.indexWhere((t) => t.taskId == taskId);
    if (index == -1) {
      throw const ApiException(
        statusCode: 404,
        message: 'No se ha encontrado la tarea.',
      );
    }
    final existing = tasks[index];
    if (existing.status == TaskStatus.done) {
      throw const ApiException(
        statusCode: 409,
        message: 'Esta tarea ya está marcada como hecha.',
      );
    }

    final nowUtc = _now.toUtc();
    const caller = TaskUserRef(
      userId: currentUserId,
      name: currentUserName,
    );

    final completed = TaskItem(
      taskId: existing.taskId,
      title: existing.title,
      notes: existing.notes,
      assignee: existing.assignee,
      dueDate: existing.dueDate,
      dueTime: existing.dueTime,
      recurrence: existing.recurrence,
      reminderMinutesBefore: existing.reminderMinutesBefore,
      status: TaskStatus.done,
      completedAt: nowUtc,
      completedBy: caller,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: nowUtc,
    );
    tasks[index] = completed;

    TaskItem? nextTask;
    final nextDueDate =
        computeNextDueDate(existing.dueDate, existing.recurrence);
    if (nextDueDate != null) {
      nextTask = TaskItem(
        taskId: _nextId('00003000'),
        title: existing.title,
        notes: existing.notes,
        assignee: existing.assignee,
        dueDate: nextDueDate,
        dueTime: existing.dueTime,
        recurrence: existing.recurrence,
        reminderMinutesBefore: existing.reminderMinutesBefore,
        status: TaskStatus.open,
        completedAt: null,
        completedBy: null,
        createdBy: caller,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
      tasks.add(nextTask);
    }

    return CompleteTaskResponse(completed: completed, next: nextTask);
  }

  TaskItem reopenTask(String groupId, String taskId) {
    final tasks = _requireGroupTasks(groupId);
    final index = tasks.indexWhere((t) => t.taskId == taskId);
    if (index == -1) {
      throw const ApiException(
        statusCode: 404,
        message: 'No se ha encontrado la tarea.',
      );
    }
    final existing = tasks[index];
    final reopened = TaskItem(
      taskId: existing.taskId,
      title: existing.title,
      notes: existing.notes,
      assignee: existing.assignee,
      dueDate: existing.dueDate,
      dueTime: existing.dueTime,
      recurrence: existing.recurrence,
      reminderMinutesBefore: existing.reminderMinutesBefore,
      status: TaskStatus.open,
      completedAt: null,
      completedBy: null,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: _now.toUtc(),
    );
    tasks[index] = reopened;
    return reopened;
  }

  List<TaskItem> _requireGroupTasks(String groupId) {
    if (!_groups.containsKey(groupId)) {
      throw const ApiException(
        statusCode: 404,
        message: 'No se ha encontrado el grupo.',
      );
    }
    return _tasksByGroup.putIfAbsent(groupId, () => []);
  }

  TaskUserRef? _resolveAssignee(GroupDetail group, String? assigneeId) {
    if (assigneeId == null || assigneeId.isEmpty) return null;
    for (final member in group.members) {
      if (member.userId == assigneeId) {
        return TaskUserRef(userId: member.userId, name: member.name);
      }
    }
    throw const ApiException(
      statusCode: 400,
      message: 'La persona asignada no pertenece al grupo.',
    );
  }

  String? _normalizeNotes(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void _validateTaskScheduling({
    required String? dueDate,
    required String? dueTime,
    required TaskRecurrence recurrence,
    required int? reminderMinutesBefore,
  }) {
    if (dueTime != null && dueDate == null) {
      throw const ApiException(
        statusCode: 400,
        message: 'Para indicar una hora hace falta elegir una fecha.',
      );
    }
    if (recurrence != TaskRecurrence.none && dueDate == null) {
      throw const ApiException(
        statusCode: 400,
        message: 'Las tareas repetitivas necesitan una fecha.',
      );
    }
    if (reminderMinutesBefore != null) {
      if (dueTime == null) {
        throw const ApiException(
          statusCode: 400,
          message: 'Para activar un recordatorio hace falta elegir una hora.',
        );
      }
      if (reminderMinutesBefore < 0 || reminderMinutesBefore > 10080) {
        throw const ApiException(
          statusCode: 400,
          message: 'El recordatorio debe estar entre 0 minutos y 1 semana.',
        );
      }
    }
  }
}

final demoStoreProvider = Provider<DemoStore>((ref) {
  return DemoStore();
});
