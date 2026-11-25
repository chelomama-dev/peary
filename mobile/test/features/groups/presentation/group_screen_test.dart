import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:peary/core/formatting/date_formatting.dart';
import 'package:peary/features/groups/data/group_dtos.dart';
import 'package:peary/features/groups/data/groups_repository.dart';
import 'package:peary/features/groups/presentation/group_screen.dart';
import 'package:peary/features/me/data/me_dtos.dart';
import 'package:peary/features/me/data/me_repository.dart';

class _StubMeRepository implements MeRepository {
  _StubMeRepository(this._me);

  final MeResponse _me;

  @override
  Future<MeResponse> getMe() async => _me;

  @override
  Future<GroupDetail> acceptInvitation(String invitationId) =>
      throw UnimplementedError();

  @override
  Future<void> declineInvitation(String invitationId) =>
      throw UnimplementedError();
}

class _StubGroupsRepository implements GroupsRepository {
  _StubGroupsRepository(this._group);

  final GroupDetail _group;

  @override
  Future<GroupDetail> getGroup(String groupId) async => _group;

  @override
  Future<GroupDetail> createGroup(CreateGroupRequest request) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting(kSpanishLocale);
  });

  testWidgets('shows Alguien in GroupScreen for pending invitation with null invitedBy',
      (tester) async {
    final me = MeResponse(
      userId: 'user-1',
      name: 'Roberto',
      email: 'roberto@example.com',
      groups: const [
        GroupSummary(
          groupId: 'grp-casa',
          name: 'Casa',
          role: GroupRole.admin,
          memberCount: 1,
        ),
      ],
      invitations: [
        PendingInvitation(
          invitationId: 'inv-null',
          group: const InvitationGroup(
            groupId: 'grp-abuela',
            name: 'Piso de la abuela',
          ),
          invitedBy: null,
          expiresAt: DateTime.utc(2026, 12, 2, 10, 0),
        ),
      ],
    );

    final group = GroupDetail(
      groupId: 'grp-casa',
      name: 'Casa',
      timeZone: 'Europe/Madrid',
      myRole: GroupRole.admin,
      createdAt: DateTime.utc(2026, 11, 25, 10, 0),
      members: [
        GroupMember(
          userId: 'user-1',
          name: 'Roberto',
          email: 'roberto@example.com',
          role: GroupRole.admin,
          joinedAt: DateTime.utc(2026, 11, 25, 10, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          meRepositoryProvider.overrideWithValue(_StubMeRepository(me)),
          groupsRepositoryProvider
              .overrideWithValue(_StubGroupsRepository(group)),
        ],
        child: const MaterialApp(
          locale: Locale('es', 'ES'),
          supportedLocales: [Locale('es', 'ES')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: GroupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Piso de la abuela'), 300);
    expect(find.text('Piso de la abuela'), findsOneWidget);
    expect(find.textContaining('Invitado por Alguien'), findsOneWidget);
  });
}
