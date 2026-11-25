import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatting/date_formatting.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/me_dtos.dart';
import '../data/me_repository.dart';

// TODO: Read the device's IANA time zone instead of hard-coding Europe/Madrid.
const String kDefaultGroupTimeZone = 'Europe/Madrid';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _busyInvitationId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(meProvider.notifier).createGroup(
            name: _nameController.text.trim(),
            timeZone: kDefaultGroupTimeZone,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _acceptInvitation(PendingInvitation invitation) async {
    setState(() => _busyInvitationId = invitation.invitationId);
    try {
      await ref
          .read(meProvider.notifier)
          .acceptInvitation(invitation.invitationId);
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
          content: Text('Invitación a ${invitation.group.name} rechazada.'),
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
    final meAsync = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido a Peary')),
      body: meAsync.when(
        loading: () => const LoadingView(message: 'Cargando…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(meProvider.notifier).refresh(),
        ),
        data: (me) => RefreshIndicator(
          onRefresh: () => ref.read(meProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Hola, ${me.displayName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Aún no perteneces a ningún grupo. Crea uno para tu familia o acepta una invitación pendiente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Crea tu primer grupo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_submitting,
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
                            if (trimmed.length > 60) {
                              return 'Máximo 60 caracteres.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _createGroup(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _submitting ? null : _createGroup,
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Crear grupo'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (me.invitations.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Invitaciones pendientes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final invitation in me.invitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InvitationCard(
                      invitation: invitation,
                      busy: _busyInvitationId == invitation.invitationId,
                      onAccept: () => _acceptInvitation(invitation),
                      onDecline: () => _declineInvitation(invitation),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final PendingInvitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final invitedBy = invitation.invitedBy?.trim();
    final subtitle = (invitedBy != null && invitedBy.isNotEmpty)
        ? 'Invitado por $invitedBy · Caduca el ${formatUtcDateLocal(invitation.expiresAt)}'
        : 'Caduca el ${formatUtcDateLocal(invitation.expiresAt)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitation.group.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aceptar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
