import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../me/data/me_dtos.dart';
import '../../me/data/me_repository.dart';
import '../../me/presentation/onboarding_screen.dart';
import '../data/groups_repository.dart';

/// AppBar title widget showing the active group and opening a switcher sheet.
class GroupSwitcherTitle extends ConsumerWidget {
  const GroupSwitcherTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).asData?.value;
    final currentGroupId = ref.watch(currentGroupIdProvider);
    final groups = me?.groups ?? const <GroupSummary>[];

    GroupSummary? activeGroup;
    for (final g in groups) {
      if (g.groupId == currentGroupId) {
        activeGroup = g;
        break;
      }
    }

    final label = activeGroup?.name ?? 'Peary';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: groups.isEmpty
          ? null
          : () => _showGroupSwitcherSheet(context, ref, groups, currentGroupId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (groups.isNotEmpty) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 22),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showGroupSwitcherSheet(
    BuildContext context,
    WidgetRef ref,
    List<GroupSummary> groups,
    String? currentGroupId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Tus grupos',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final group in groups)
                ListTile(
                  leading: Icon(
                    group.groupId == currentGroupId
                        ? Icons.check_circle
                        : Icons.group_outlined,
                    color: group.groupId == currentGroupId
                        ? Theme.of(sheetContext).colorScheme.primary
                        : null,
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    '${group.memberCount} ${group.memberCount == 1 ? 'miembro' : 'miembros'} · ${group.role.labelEs}',
                  ),
                  onTap: () {
                    ref
                        .read(selectedGroupIdProvider.notifier)
                        .select(group.groupId);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Crear nuevo grupo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showCreateGroupDialog(context, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final groupName = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Nuevo grupo'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
              hintText: 'Ej. Casa',
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Escribe un nombre para el grupo.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Crear'),
          ),
        ],
      );
    },
  );
  controller.dispose();

  if (groupName == null || !context.mounted) return;
  try {
    await ref.read(meProvider.notifier).createGroup(
          name: groupName,
          timeZone: kDefaultGroupTimeZone,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Grupo "$groupName" creado.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userErrorMessage(error))),
    );
  }
}
