import 'package:json_annotation/json_annotation.dart';

part 'task_dtos.g.dart';

enum TaskRecurrence {
  @JsonValue('none')
  none,
  @JsonValue('daily')
  daily,
  @JsonValue('weekly')
  weekly,
  @JsonValue('monthly')
  monthly;

  String get apiValue => switch (this) {
        TaskRecurrence.none => 'none',
        TaskRecurrence.daily => 'daily',
        TaskRecurrence.weekly => 'weekly',
        TaskRecurrence.monthly => 'monthly',
      };

  String get labelEs => switch (this) {
        TaskRecurrence.none => 'Nunca',
        TaskRecurrence.daily => 'Cada día',
        TaskRecurrence.weekly => 'Cada semana',
        TaskRecurrence.monthly => 'Cada mes',
      };
}

enum TaskStatus {
  @JsonValue('open')
  open,
  @JsonValue('done')
  done;

  String get apiValue => switch (this) {
        TaskStatus.open => 'open',
        TaskStatus.done => 'done',
      };
}

@JsonSerializable()
class TaskUserRef {
  const TaskUserRef({
    required this.userId,
    required this.name,
  });

  factory TaskUserRef.fromJson(Map<String, dynamic> json) =>
      _$TaskUserRefFromJson(json);

  final String userId;
  final String? name;

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'Sin nombre';
  }

  Map<String, dynamic> toJson() => _$TaskUserRefToJson(this);
}

@JsonSerializable()
class TaskItem {
  const TaskItem({
    required this.taskId,
    required this.title,
    required this.notes,
    required this.assignee,
    required this.dueDate,
    required this.dueTime,
    required this.recurrence,
    required this.reminderMinutesBefore,
    required this.status,
    required this.completedAt,
    required this.completedBy,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) =>
      _$TaskItemFromJson(json);

  final String taskId;
  final String title;
  final String? notes;
  final TaskUserRef? assignee;

  /// Calendar date (`yyyy-MM-dd`) in the group's time zone.
  final String? dueDate;

  /// Time of day (`HH:mm`) in the group's time zone.
  final String? dueTime;

  final TaskRecurrence recurrence;
  final int? reminderMinutesBefore;
  final TaskStatus status;
  final DateTime? completedAt;
  final TaskUserRef? completedBy;
  final TaskUserRef createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDone => status == TaskStatus.done;

  Map<String, dynamic> toJson() => _$TaskItemToJson(this);
}

@JsonSerializable()
class TasksPage {
  const TasksPage({
    required this.items,
    required this.nextCursor,
  });

  factory TasksPage.fromJson(Map<String, dynamic> json) =>
      _$TasksPageFromJson(json);

  final List<TaskItem> items;
  final String? nextCursor;

  Map<String, dynamic> toJson() => _$TasksPageToJson(this);
}

@JsonSerializable()
class CompleteTaskResponse {
  const CompleteTaskResponse({
    required this.completed,
    required this.next,
  });

  factory CompleteTaskResponse.fromJson(Map<String, dynamic> json) =>
      _$CompleteTaskResponseFromJson(json);

  final TaskItem completed;
  final TaskItem? next;

  Map<String, dynamic> toJson() => _$CompleteTaskResponseToJson(this);
}

@JsonSerializable()
class CreateTaskRequest {
  const CreateTaskRequest({
    required this.title,
    this.notes,
    this.assigneeId,
    this.dueDate,
    this.dueTime,
    this.recurrence = TaskRecurrence.none,
    this.reminderMinutesBefore,
  });

  factory CreateTaskRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateTaskRequestFromJson(json);

  final String title;
  final String? notes;
  final String? assigneeId;
  final String? dueDate;
  final String? dueTime;
  final TaskRecurrence recurrence;
  final int? reminderMinutesBefore;

  Map<String, dynamic> toJson() => _$CreateTaskRequestToJson(this);
}

/// Wrapper distinguishing an omitted PATCH field from an explicitly cleared
/// (`null`) field, per `docs/api.md`.
class PatchField<T> {
  const PatchField.absent()
      : isSet = false,
        value = null;

  const PatchField.value(this.value) : isSet = true;

  final bool isSet;
  final T? value;
}

/// PATCH payload for `PATCH /api/groups/{groupId}/tasks/{taskId}`.
///
/// Only fields set via [PatchField.value] are included in [toJson]; nullable
/// fields explicitly set to `PatchField.value(null)` serialize as `null` to
/// clear them.
class UpdateTaskRequest {
  const UpdateTaskRequest({
    this.title = const PatchField.absent(),
    this.notes = const PatchField.absent(),
    this.assigneeId = const PatchField.absent(),
    this.dueDate = const PatchField.absent(),
    this.dueTime = const PatchField.absent(),
    this.recurrence = const PatchField.absent(),
    this.reminderMinutesBefore = const PatchField.absent(),
  });

  final PatchField<String> title;
  final PatchField<String?> notes;
  final PatchField<String?> assigneeId;
  final PatchField<String?> dueDate;
  final PatchField<String?> dueTime;
  final PatchField<TaskRecurrence> recurrence;
  final PatchField<int?> reminderMinutesBefore;

  bool get isEmpty =>
      !title.isSet &&
      !notes.isSet &&
      !assigneeId.isSet &&
      !dueDate.isSet &&
      !dueTime.isSet &&
      !recurrence.isSet &&
      !reminderMinutesBefore.isSet;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (title.isSet) map['title'] = title.value;
    if (notes.isSet) map['notes'] = notes.value;
    if (assigneeId.isSet) map['assigneeId'] = assigneeId.value;
    if (dueDate.isSet) map['dueDate'] = dueDate.value;
    if (dueTime.isSet) map['dueTime'] = dueTime.value;
    if (recurrence.isSet) map['recurrence'] = recurrence.value?.apiValue;
    if (reminderMinutesBefore.isSet) {
      map['reminderMinutesBefore'] = reminderMinutesBefore.value;
    }
    return map;
  }
}
