import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatting/date_formatting.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../groups/data/group_dtos.dart';
import '../../groups/data/groups_repository.dart';
import '../data/task_dtos.dart';
import '../data/tasks_repository.dart';

const List<int?> _reminderOptions = [
  null,
  0,
  15,
  30,
  60,
  1440,
  10080,
];

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.taskId});

  final String? taskId;

  bool get isEditing => taskId != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  TaskItem? _originalTask;
  String? _assigneeId;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TaskRecurrence _recurrence = TaskRecurrence.none;
  int? _reminderMinutesBefore;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateFromTask(TaskItem task) {
    if (_initialized) return;
    _initialized = true;
    _originalTask = task;
    _titleController.text = task.title;
    _notesController.text = task.notes ?? '';
    _assigneeId = task.assignee?.userId;
    _dueDate = parseApiDate(task.dueDate);
    _dueTime = parseApiTime(task.dueTime);
    _recurrence = task.recurrence;
    _reminderMinutesBefore = task.reminderMinutesBefore;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _clearDate() {
    setState(() {
      _dueDate = null;
      _dueTime = null;
      _recurrence = TaskRecurrence.none;
      _reminderMinutesBefore = null;
    });
  }

  Future<void> _pickTime() async {
    if (_dueDate == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _dueTime = picked;
      });
    }
  }

  void _clearTime() {
    setState(() {
      _dueTime = null;
      _reminderMinutesBefore = null;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleController.text.trim();
    final rawNotes = _notesController.text.trim();
    final notes = rawNotes.isEmpty ? null : rawNotes;
    final dueDateStr = _dueDate != null ? formatApiDate(_dueDate!) : null;
    final dueTimeStr = _dueTime != null ? formatApiTime(_dueTime!) : null;
    final recurrence = dueDateStr == null ? TaskRecurrence.none : _recurrence;
    final reminder = dueTimeStr == null ? null : _reminderMinutesBefore;

    setState(() => _saving = true);
    try {
      if (!widget.isEditing) {
        await ref.read(tasksListProvider.notifier).createTask(
              CreateTaskRequest(
                title: title,
                notes: notes,
                assigneeId: _assigneeId,
                dueDate: dueDateStr,
                dueTime: dueTimeStr,
                recurrence: recurrence,
                reminderMinutesBefore: reminder,
              ),
            );
        if (!mounted) return;
        context.pop();
        return;
      }

      final original = _originalTask!;
      final patch = UpdateTaskRequest(
        title: title != original.title
            ? PatchField.value(title)
            : const PatchField.absent(),
        notes: notes != original.notes
            ? PatchField.value(notes)
            : const PatchField.absent(),
        assigneeId: _assigneeId != original.assignee?.userId
            ? PatchField.value(_assigneeId)
            : const PatchField.absent(),
        dueDate: dueDateStr != original.dueDate
            ? PatchField.value(dueDateStr)
            : const PatchField.absent(),
        dueTime: dueTimeStr != original.dueTime
            ? PatchField.value(dueTimeStr)
            : const PatchField.absent(),
        recurrence: recurrence != original.recurrence
            ? PatchField.value(recurrence)
            : const PatchField.absent(),
        reminderMinutesBefore: reminder != original.reminderMinutesBefore
            ? PatchField.value(reminder)
            : const PatchField.absent(),
      );

      if (!patch.isEmpty) {
        await ref
            .read(tasksListProvider.notifier)
            .updateTask(original.taskId, patch);
        ref.invalidate(taskDetailProvider(original.taskId));
      }
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _reopenTask(TaskItem task) async {
    setState(() => _saving = true);
    try {
      final reopened =
          await ref.read(tasksListProvider.notifier).reopenTask(task.taskId);
      ref.invalidate(taskDetailProvider(task.taskId));
      if (!mounted) return;
      setState(() {
        _originalTask = reopened;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea reabierta. Ya puedes editarla.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Seguro que quieres eliminar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(tasksListProvider.notifier).deleteTask(task.taskId);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(currentGroupProvider);

    if (widget.isEditing) {
      final taskAsync = ref.watch(taskDetailProvider(widget.taskId!));
      return taskAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Tarea')),
          body: const LoadingView(message: 'Cargando tarea…'),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Tarea')),
          body: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(taskDetailProvider(widget.taskId!)),
          ),
        ),
        data: (task) {
          _populateFromTask(task);
          return _buildFormScaffold(
            context,
            members: groupAsync.asData?.value?.members ?? const [],
            existingTask: _originalTask ?? task,
          );
        },
      );
    }

    return _buildFormScaffold(
      context,
      members: groupAsync.asData?.value?.members ?? const [],
      existingTask: null,
    );
  }

  Widget _buildFormScaffold(
    BuildContext context, {
    required List<GroupMember> members,
    required TaskItem? existingTask,
  }) {
    final isDone = existingTask?.isDone ?? false;
    final readOnly = _saving || isDone;

    final memberIds = members.map((m) => m.userId).toSet();
    final hasValidAssignee =
        _assigneeId == null || memberIds.contains(_assigneeId);
    final selectedAssigneeValue = hasValidAssignee ? _assigneeId : null;

    final reminderValues = <int?>[
      ..._reminderOptions,
      if (_reminderMinutesBefore != null &&
          !_reminderOptions.contains(_reminderMinutesBefore))
        _reminderMinutesBefore,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Detalle de tarea' : 'Nueva tarea'),
        actions: [
          if (existingTask != null)
            IconButton(
              tooltip: 'Eliminar tarea',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _deleteTask(existingTask),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isDone && existingTask != null) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Esta tarea está marcada como hecha.',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Para editarla, ábrela de nuevo primero.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed:
                            _saving ? null : () => _reopenTask(existingTask),
                        icon: const Icon(Icons.replay),
                        label: const Text('Reabrir tarea'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              enabled: !readOnly,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Dentista de Pablo',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Escribe un título para la tarea.';
                }
                if (trimmed.length > 200) {
                  return 'Máximo 200 caracteres.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              enabled: !readOnly,
              maxLength: 2000,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Ej. Llevar la tarjeta sanitaria',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Asignado a',
                prefixIcon: Icon(Icons.person_outline),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  isDense: true,
                  value: selectedAssigneeValue,
                  onChanged: readOnly
                      ? null
                      : (value) => setState(() => _assigneeId = value),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Cualquiera'),
                    ),
                    for (final member in members)
                      DropdownMenuItem<String?>(
                        value: member.userId,
                        child: Text(member.displayName),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Fecha'),
              subtitle: Text(
                _dueDate != null ? formatFullDate(_dueDate!) : 'Sin fecha',
              ),
              trailing: _dueDate != null && !readOnly
                  ? IconButton(
                      tooltip: 'Quitar fecha',
                      icon: const Icon(Icons.close),
                      onPressed: _clearDate,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: readOnly ? null : _pickDate,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _dueDate != null && !readOnly,
              leading: const Icon(Icons.access_time),
              title: const Text('Hora'),
              subtitle: Text(
                _dueTime != null
                    ? formatApiTime(_dueTime!)
                    : (_dueDate == null
                        ? 'Elige una fecha primero'
                        : 'Todo el día'),
              ),
              trailing: _dueTime != null && !readOnly
                  ? IconButton(
                      tooltip: 'Quitar hora',
                      icon: const Icon(Icons.close),
                      onPressed: _clearTime,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: (_dueDate == null || readOnly) ? null : _pickTime,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Repetición',
                prefixIcon: const Icon(Icons.repeat),
                helperText: _dueDate == null
                    ? 'Elige una fecha para repetir la tarea.'
                    : null,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TaskRecurrence>(
                  isExpanded: true,
                  isDense: true,
                  value: _dueDate == null ? TaskRecurrence.none : _recurrence,
                  onChanged: (_dueDate == null || readOnly)
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _recurrence = value);
                          }
                        },
                  items: [
                    for (final item in TaskRecurrence.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.labelEs),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Recordatorio',
                prefixIcon: const Icon(Icons.notifications_outlined),
                helperText: _dueTime == null
                    ? 'Elige una hora para añadir un recordatorio.'
                    : null,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  isDense: true,
                  value: _dueTime == null ? null : _reminderMinutesBefore,
                  onChanged: (_dueTime == null || readOnly)
                      ? null
                      : (value) =>
                          setState(() => _reminderMinutesBefore = value),
                  items: [
                    for (final minutes in reminderValues)
                      DropdownMenuItem<int?>(
                        value: minutes,
                        child: Text(
                          minutes == null
                              ? 'Sin recordatorio'
                              : formatReminderMinutes(minutes),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (existingTask != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Creada por ${existingTask.createdBy.displayName} el ${formatUtcTimestampLocal(existingTask.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (existingTask.completedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Completada por ${existingTask.completedBy?.displayName ?? 'Desconocido'} el ${formatUtcTimestampLocal(existingTask.completedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            if (!isDone)
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing ? 'Guardar cambios' : 'Crear tarea',
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
