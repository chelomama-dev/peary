import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatting/date_formatting.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../groups/presentation/group_switcher.dart';
import '../data/task_dtos.dart';
import '../data/task_grouping.dart';
import '../data/tasks_repository.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.now});

  /// Optional reference time for deterministic date grouping in tests.
  final DateTime? now;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final Set<String> _busyTaskIds = {};

  Future<void> _toggleComplete(TaskItem task) async {
    if (_busyTaskIds.contains(task.taskId)) return;
    setState(() => _busyTaskIds.add(task.taskId));
    try {
      if (task.isDone) {
        await ref.read(tasksListProvider.notifier).reopenTask(task.taskId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea reabierta.')),
        );
      } else {
        final result = await ref
            .read(tasksListProvider.notifier)
            .completeTask(task.taskId);
        if (!mounted) return;
        final message = result.next != null
            ? 'Tarea completada. Próxima programada.'
            : 'Tarea completada.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyTaskIds.remove(task.taskId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusFilter = ref.watch(tasksStatusFilterProvider);
    final tasksAsync = ref.watch(tasksListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const GroupSwitcherTitle(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<TaskStatus>(
                segments: const [
                  ButtonSegment(
                    value: TaskStatus.open,
                    label: Text('Pendientes'),
                    icon: Icon(Icons.radio_button_unchecked),
                  ),
                  ButtonSegment(
                    value: TaskStatus.done,
                    label: Text('Hechas'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                ],
                selected: {statusFilter},
                onSelectionChanged: (selection) {
                  ref
                      .read(tasksStatusFilterProvider.notifier)
                      .setStatus(selection.first);
                },
              ),
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              loading: () => const LoadingView(message: 'Cargando tareas…'),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.read(tasksListProvider.notifier).refresh(),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tasksListProvider.notifier).refresh(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: EmptyView(
                              icon: statusFilter == TaskStatus.open
                                  ? Icons.task_alt
                                  : Icons.history,
                              title: statusFilter == TaskStatus.open
                                  ? 'No hay tareas pendientes'
                                  : 'Todavía no hay tareas hechas',
                              message: statusFilter == TaskStatus.open
                                  ? 'Pulsa "Nueva tarea" para añadir la primera.'
                                  : 'Cuando completes una tarea aparecerá aquí.',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                if (statusFilter == TaskStatus.done) {
                  final sortedDone = [...tasks]..sort(compareDoneTasks);
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tasksListProvider.notifier).refresh(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: sortedDone.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = sortedDone[index];
                        return _TaskCard(
                          task: task,
                          isOverdue: false,
                          busy: _busyTaskIds.contains(task.taskId),
                          now: widget.now,
                          onToggleComplete: () => _toggleComplete(task),
                          onTap: () => context.push('/tasks/${task.taskId}'),
                        );
                      },
                    ),
                  );
                }

                final sections = groupOpenTasks(tasks, now: widget.now);
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(tasksListProvider.notifier).refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      for (final section in sections) ...[
                        _SectionHeader(section: section),
                        const SizedBox(height: 6),
                        for (final task in section.tasks) ...[
                          _TaskCard(
                            task: task,
                            isOverdue: section.kind == TaskSectionKind.overdue,
                            busy: _busyTaskIds.contains(task.taskId),
                            now: widget.now,
                            onToggleComplete: () => _toggleComplete(task),
                            onTap: () => context.push('/tasks/${task.taskId}'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final TaskSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = section.kind == TaskSectionKind.overdue
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Text(
            section.titleEs,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${section.tasks.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.isOverdue,
    required this.busy,
    required this.now,
    required this.onToggleComplete,
    required this.onTap,
  });

  final TaskItem task;
  final bool isOverdue;
  final bool busy;
  final DateTime? now;
  final VoidCallback onToggleComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final metaWidgets = <Widget>[];
    if (task.isDone) {
      final completedAt = task.completedAt;
      final completedBy = task.completedBy?.displayName;
      final parts = <String>[
        if (completedBy != null) 'Hecha por $completedBy',
        if (completedAt != null) formatUtcTimestampLocal(completedAt),
      ];
      if (parts.isNotEmpty) {
        metaWidgets.add(
          _MetaBadge(
            icon: Icons.check_circle_outline,
            label: parts.join(' · '),
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
    } else if (task.dueDate != null) {
      metaWidgets.add(
        _MetaBadge(
          icon: Icons.event_outlined,
          label: formatDueDateLabel(
            task.dueDate!,
            dueTime: task.dueTime,
            now: now,
          ),
          color: isOverdue
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (task.recurrence != TaskRecurrence.none) {
      metaWidgets.add(
        _MetaBadge(
          icon: Icons.repeat,
          label: task.recurrence.labelEs,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (task.reminderMinutesBefore != null) {
      metaWidgets.add(
        _MetaBadge(
          icon: Icons.notifications_outlined,
          label: formatReminderMinutes(task.reminderMinutesBefore!),
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    metaWidgets.add(
      _MetaBadge(
        icon: Icons.person_outline,
        label: task.assignee?.displayName ?? 'Cualquiera',
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                height: 40,
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Checkbox(
                        value: task.isDone,
                        onChanged: (_) => onToggleComplete(),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (metaWidgets.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: metaWidgets,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
