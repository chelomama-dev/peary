import 'package:flutter_test/flutter_test.dart';
import 'package:peary/features/tasks/data/task_dtos.dart';
import 'package:peary/features/tasks/data/task_grouping.dart';

TaskItem _task({
  required String id,
  required String title,
  String? dueDate,
  String? dueTime,
  DateTime? createdAt,
  TaskStatus status = TaskStatus.open,
  DateTime? completedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 11, 20, 10, 0);
  return TaskItem(
    taskId: id,
    title: title,
    notes: null,
    assignee: null,
    dueDate: dueDate,
    dueTime: dueTime,
    recurrence: TaskRecurrence.none,
    reminderMinutesBefore: null,
    status: status,
    completedAt: completedAt,
    completedBy: null,
    createdBy: const TaskUserRef(userId: 'u1', name: 'Roberto'),
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  final referenceNow = DateTime(2026, 11, 25, 14, 0);

  group('groupOpenTasks', () {
    test('groups into Atrasadas, Hoy, Próximamente, Sin fecha in contract order', () {
      final tasks = [
        _task(
          id: 'nodate-late',
          title: 'Sin fecha 2',
          createdAt: DateTime.utc(2026, 11, 22, 12, 0),
        ),
        _task(
          id: 'upcoming-2',
          title: 'Próxima tarde',
          dueDate: '2026-11-28',
          dueTime: '17:30',
        ),
        _task(
          id: 'today-timed-late',
          title: 'Hoy 19:00',
          dueDate: '2026-11-25',
          dueTime: '19:00',
        ),
        _task(
          id: 'overdue-1',
          title: 'Atrasada',
          dueDate: '2026-11-24',
        ),
        _task(
          id: 'today-all-day',
          title: 'Hoy todo el día',
          dueDate: '2026-11-25',
        ),
        _task(
          id: 'today-timed-early',
          title: 'Hoy 09:00',
          dueDate: '2026-11-25',
          dueTime: '09:00',
        ),
        _task(
          id: 'nodate-early',
          title: 'Sin fecha 1',
          createdAt: DateTime.utc(2026, 11, 21, 9, 0),
        ),
        _task(
          id: 'upcoming-1',
          title: 'Mañana',
          dueDate: '2026-11-26',
        ),
      ];

      final sections = groupOpenTasks(tasks, now: referenceNow);

      expect(
        sections.map((s) => s.titleEs).toList(),
        ['Atrasadas', 'Hoy', 'Próximamente', 'Sin fecha'],
      );
      expect(sections[0].tasks.map((t) => t.taskId), ['overdue-1']);
      expect(
        sections[1].tasks.map((t) => t.taskId),
        ['today-all-day', 'today-timed-early', 'today-timed-late'],
      );
      expect(
        sections[2].tasks.map((t) => t.taskId),
        ['upcoming-1', 'upcoming-2'],
      );
      expect(
        sections[3].tasks.map((t) => t.taskId),
        ['nodate-early', 'nodate-late'],
      );
    });

    test('omits empty sections', () {
      final tasks = [
        _task(id: 'today', title: 'Hoy', dueDate: '2026-11-25'),
        _task(id: 'nodate', title: 'Sin fecha'),
      ];

      final sections = groupOpenTasks(tasks, now: referenceNow);

      expect(sections.map((s) => s.kind), [
        TaskSectionKind.today,
        TaskSectionKind.noDate,
      ]);
    });

    test('uses fixed now and explicit today to assign sections deterministically',
        () {
      final tasks = [
        _task(id: 'd24', title: 'Día 24', dueDate: '2026-11-24'),
        _task(id: 'd25', title: 'Día 25', dueDate: '2026-11-25'),
        _task(id: 'd26', title: 'Día 26', dueDate: '2026-11-26'),
      ];

      final on24 = groupOpenTasks(tasks, now: DateTime(2026, 11, 24, 23, 59));
      expect(on24.map((s) => s.kind), [
        TaskSectionKind.today,
        TaskSectionKind.upcoming,
      ]);
      expect(on24[0].tasks.map((t) => t.taskId), ['d24']);
      expect(on24[1].tasks.map((t) => t.taskId), ['d25', 'd26']);

      final on26 = groupOpenTasks(
        tasks,
        today: DateTime(2026, 11, 26),
        now: DateTime(2026, 11, 24, 9, 0),
      );
      expect(on26.map((s) => s.kind), [
        TaskSectionKind.overdue,
        TaskSectionKind.today,
      ]);
      expect(on26[0].tasks.map((t) => t.taskId), ['d24', 'd25']);
      expect(on26[1].tasks.map((t) => t.taskId), ['d26']);
    });
  });

  group('compareDoneTasks', () {
    test('orders done tasks by completedAt newest first', () {
      final older = _task(
        id: '1',
        title: 'Antigua',
        status: TaskStatus.done,
        completedAt: DateTime.utc(2026, 11, 24, 10, 0),
      );
      final newer = _task(
        id: '2',
        title: 'Reciente',
        status: TaskStatus.done,
        completedAt: DateTime.utc(2026, 11, 25, 18, 0),
      );

      final list = [older, newer]..sort(compareDoneTasks);
      expect(list.map((t) => t.taskId), ['2', '1']);
    });
  });

  group('computeNextDueDate', () {
    test('handles daily, weekly and monthly recurrence including month-end clamping', () {
      expect(
        computeNextDueDate('2026-11-25', TaskRecurrence.none),
        isNull,
      );
      expect(
        computeNextDueDate('2026-11-30', TaskRecurrence.daily),
        '2026-12-01',
      );
      expect(
        computeNextDueDate('2026-11-25', TaskRecurrence.weekly),
        '2026-12-02',
      );
      expect(
        computeNextDueDate('2026-01-31', TaskRecurrence.monthly),
        '2026-02-28',
      );
      expect(
        computeNextDueDate('2028-01-31', TaskRecurrence.monthly),
        '2028-02-29',
      );
      expect(
        computeNextDueDate('2026-03-31', TaskRecurrence.monthly),
        '2026-04-30',
      );
      expect(
        computeNextDueDate('2026-12-15', TaskRecurrence.monthly),
        '2027-01-15',
      );
    });
  });
}
