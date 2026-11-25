import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatting/date_formatting.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../me/data/me_dtos.dart';
import '../../me/data/me_repository.dart';
import '../data/group_dtos.dart';
import '../data/groups_repository.dart';
import 'group_switcher.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  String? _busyInvitationId;

  Future<void> _refresh() async {
    await ref.read(meProvider.notifier).refresh();
    ref.invalidate(currentGroupProvider);
    await ref.read(currentGroupProvider.future);
  }

  Future<void> _acceptInvitation(PendingInvitation invitation) async {
    setState(() => _busyInvitationId = invitation.invitationId);
    try {
      await ref
          .read(meProvider.notifier)
          .acceptInvitation(invitation.invitationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Te has unido a "${invitation.group.name}".'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyInvitationId = null);
      }
    }
  }

  Future<void> _declineInvitation(PendingInvitation invitation) async {
    setState(() => _busyInvitationId = invitation.invitationId);
    try {
      await ref
          .read(meProvider.notifier)
          .declineInvitation(invitation.invitationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitación a "${invitation.group.name}" rechazada.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyInvitationId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(currentGroupProvider);
    final me = ref.watch(meProvider).asData?.value;
    final invitations = me?.invitations ?? const <PendingInvitation>[];

    return Scaffold(
      appBar: AppBar(
        title: const GroupSwitcherTitle(),
        actions: [
          IconButton(
            tooltip: 'Crear nuevo grupo',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => showCreateGroupDialog(context, ref),
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const LoadingView(message: 'Cargando grupo…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(currentGroupProvider),
        ),
        data: (group) {
          if (group == null) {
            return const EmptyView(
              icon: Icons.group_outlined,
              title: 'Sin grupo seleccionado',
              message: 'Crea un grupo o acepta una invitación para empezar.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _GroupHeaderCard(group: group),
                const SizedBox(height: 20),
                Text(
                  'Miembros (${group.members.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (group.members.isEmpty)
                  const EmptyView(
                    icon: Icons.person_outline,
                    title: 'Sin miembros',
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < group.members.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _MemberTile(
                            member: group.members[i],
                            isCurrentUser:
                                me?.userId == group.members[i].userId,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (invitations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Invitaciones pendientes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final invitation in invitations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invitation.group.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                invitation.invitedBy != null &&
                                        invitation.invitedBy!.trim().isNotEmpty
                                    ? 'Invitado por ${invitation.invitedBy} · Caduca el ${formatUtcDateLocal(invitation.expiresAt)}'
                                    : 'Caduca el ${formatUtcDateLocal(invitation.expiresAt)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: _busyInvitationId ==
                                            invitation.invitationId
                                        ? null
                                        : () => _declineInvitation(invitation),
                                    child: const Text('Rechazar'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: _busyInvitationId ==
                                            invitation.invitationId
                                        ? null
                                        : () => _acceptInvitation(invitation),
                                    child: const Text('Aceptar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                Chip(
                  label: Text(group.myRole.labelEs),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Zona horaria: ${group.timeZone}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Creado el ${formatUtcDateLocal(group.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
  });

  final GroupMember member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = member.displayName.characters.first.toUpperCase();
    final title =
        isCurrentUser ? '${member.displayName} (tú)' : member.displayName;

    return ListTile(
      leading: CircleAvatar(
        child: Text(initial),
      ),
      title: Text(title),
      subtitle: Text(
        '${member.email}\nDesde el ${formatUtcDateLocal(member.joinedAt)}',
      ),
      isThreeLine: true,
      trailing: Chip(
        label: Text(member.role.labelEs),
        visualDensity: VisualDensity.compact,
        backgroundColor: member.role == GroupRole.admin
            ? theme.colorScheme.primaryContainer
            : null,
      ),
    );
  }
}
