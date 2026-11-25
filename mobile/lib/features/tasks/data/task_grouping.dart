import '../../../core/formatting/date_formatting.dart';
import 'task_dtos.dart';

enum TaskSectionKind {
  overdue,
  today,
  upcoming,
  noDate;

  String get titleEs => switch (this) {
        TaskSectionKind.overdue => 'Atrasadas',
        TaskSectionKind.today => 'Hoy',
        TaskSectionKind.upcoming => 'Próximamente',
        TaskSectionKind.noDate => 'Sin fecha',
      };
}

class TaskSection {
  const TaskSection({
    required this.kind,
    required this.tasks,
  });

  final TaskSectionKind kind;
  final List<TaskItem> tasks;

  String get titleEs => kind.titleEs;
}

/// Orders open tasks per `docs/api.md`:
/// by `dueDate` and `dueTime` ascending (earliest first, overdue included),
/// then undated tasks by `createdAt` ascending.
int compareOpenTasks(TaskItem a, TaskItem b) {
  final aHasDate = a.dueDate != null && a.dueDate!.isNotEmpty;
  final bHasDate = b.dueDate != null && b.dueDate!.isNotEmpty;

  if (aHasDate && !bHasDate) return -1;
  if (!aHasDate && bHasDate) return 1;

  if (aHasDate && bHasDate) {
    final dateCmp = a.dueDate!.compareTo(b.dueDate!);
    if (dateCmp != 0) return dateCmp;

    final aTime = a.dueTime;
    final bTime = b.dueTime;
    if (aTime == null && bTime != null) return -1;
    if (aTime != null && bTime == null) return 1;
    if (aTime != null && bTime != null) {
      final timeCmp = aTime.compareTo(bTime);
      if (timeCmp != 0) return timeCmp;
    }
  }

  return a.createdAt.compareTo(b.createdAt);
}

/// Orders done tasks per `docs/api.md`: by `completedAt`, newest first.
int compareDoneTasks(TaskItem a, TaskItem b) {
  final aTime = a.completedAt ?? a.updatedAt;
  final bTime = b.completedAt ?? b.updatedAt;
  return bTime.compareTo(aTime);
}

/// Groups open tasks into "Atrasadas", "Hoy", "Próximamente" and "Sin fecha",
/// preserving the contract ordering within each section and omitting empty
/// sections.
List<TaskSection> groupOpenTasks(
  List<TaskItem> tasks, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);

  final sorted = [...tasks]..sort(compareOpenTasks);

  final overdue = <TaskItem>[];
  final todayItems = <TaskItem>[];
  final upcoming = <TaskItem>[];
  final noDate = <TaskItem>[];

  for (final task in sorted) {
    final parsedDate = parseApiDate(task.dueDate);
    if (parsedDate == null) {
      noDate.add(task);
    } else if (parsedDate.isBefore(today)) {
      overdue.add(task);
    } else if (parsedDate == today) {
      todayItems.add(task);
    } else {
      upcoming.add(task);
    }
  }

  return [
    if (overdue.isNotEmpty)
      TaskSection(kind: TaskSectionKind.overdue, tasks: overdue),
    if (todayItems.isNotEmpty)
      TaskSection(kind: TaskSectionKind.today, tasks: todayItems),
    if (upcoming.isNotEmpty)
      TaskSection(kind: TaskSectionKind.upcoming, tasks: upcoming),
    if (noDate.isNotEmpty)
      TaskSection(kind: TaskSectionKind.noDate, tasks: noDate),
  ];
}

/// Computes the next `dueDate` (`yyyy-MM-dd`) for a repeating task per
/// `docs/api.md` (monthly tasks on the 31st fall on the last day of shorter
/// months).
String? computeNextDueDate(String? dueDate, TaskRecurrence recurrence) {
  if (dueDate == null || recurrence == TaskRecurrence.none) {
    return null;
  }
  final parsed = parseApiDate(dueDate);
  if (parsed == null) return null;

  final DateTime next;
  switch (recurrence) {
    case TaskRecurrence.none:
      return null;
    case TaskRecurrence.daily:
      next = DateTime(parsed.year, parsed.month, parsed.day + 1);
    case TaskRecurrence.weekly:
      next = DateTime(parsed.year, parsed.month, parsed.day + 7);
    case TaskRecurrence.monthly:
      final targetMonth = parsed.month + 1;
      final targetYear = parsed.year + (targetMonth > 12 ? 1 : 0);
      final normalizedMonth = ((targetMonth - 1) % 12) + 1;
      final lastDayOfTargetMonth =
          DateTime(targetYear, normalizedMonth + 1, 0).day;
      final clampedDay =
          parsed.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : parsed.day;
      next = DateTime(targetYear, normalizedMonth, clampedDay);
  }

  return formatApiDate(next);
}
