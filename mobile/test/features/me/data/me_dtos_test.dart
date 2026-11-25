import 'package:flutter_test/flutter_test.dart';
import 'package:peary/features/groups/data/group_dtos.dart';
import 'package:peary/features/me/data/me_dtos.dart';

void main() {
  group('MeResponse DTO', () {
    test('parses the GET /api/me example from docs/api.md and ignores unknown fields', () {
      final json = <String, dynamic>{
        'userId': '6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c',
        'name': 'Roberto',
        'email': 'roberto@example.com',
        'futureField': 'ignored',
        'groups': [
          {
            'groupId': '0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e',
            'name': 'Casa',
            'role': 'admin',
            'memberCount': 4,
            'extraGroupField': 123,
          },
        ],
        'invitations': [
          {
            'invitationId': '9e8d7c6b-5a4f-4e3d-2c1b-0a9f8e7d6c5b',
            'group': {
              'groupId': '1d2e3f4a-5b6c-4d7e-8f9a-0b1c2d3e4f5a',
              'name': 'Piso de la abuela',
            },
            'invitedBy': 'Lucía',
            'expiresAt': '2026-12-02T10:00:00Z',
          },
        ],
      };

      final me = MeResponse.fromJson(json);

      expect(me.userId, '6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c');
      expect(me.name, 'Roberto');
      expect(me.displayName, 'Roberto');
      expect(me.email, 'roberto@example.com');
      expect(me.groups, hasLength(1));
      expect(me.groups.first.groupId, '0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e');
      expect(me.groups.first.name, 'Casa');
      expect(me.groups.first.role, GroupRole.admin);
      expect(me.groups.first.memberCount, 4);

      expect(me.invitations, hasLength(1));
      expect(
        me.invitations.first.invitationId,
        '9e8d7c6b-5a4f-4e3d-2c1b-0a9f8e7d6c5b',
      );
      expect(me.invitations.first.group.name, 'Piso de la abuela');
      expect(me.invitations.first.invitedBy, 'Lucía');
      expect(
        me.invitations.first.expiresAt,
        DateTime.utc(2026, 12, 2, 10, 0, 0),
      );
    });

    test('handles nullable name falling back to email for displayName', () {
      final me = MeResponse.fromJson({
        'userId': 'user-1',
        'name': null,
        'email': 'ana@example.com',
        'groups': <Map<String, dynamic>>[],
        'invitations': <Map<String, dynamic>>[],
      });

      expect(me.name, isNull);
      expect(me.displayName, 'ana@example.com');
    });

    test('handles nullable invitedBy falling back to Alguien', () {
      final nullInviter = PendingInvitation.fromJson({
        'invitationId': 'inv-1',
        'group': {
          'groupId': 'grp-1',
          'name': 'Piso de la abuela',
        },
        'invitedBy': null,
        'expiresAt': '2026-12-02T10:00:00Z',
      });
      final blankInviter = PendingInvitation.fromJson({
        'invitationId': 'inv-2',
        'group': {
          'groupId': 'grp-2',
          'name': 'Casa',
        },
        'invitedBy': '   ',
        'expiresAt': '2026-12-02T10:00:00Z',
      });
      final namedInviter = PendingInvitation.fromJson({
        'invitationId': 'inv-3',
        'group': {
          'groupId': 'grp-3',
          'name': 'Playa',
        },
        'invitedBy': 'Lucía',
        'expiresAt': '2026-12-02T10:00:00Z',
      });

      expect(nullInviter.invitedBy, isNull);
      expect(nullInviter.inviterDisplayName, 'Alguien');
      expect(blankInviter.inviterDisplayName, 'Alguien');
      expect(namedInviter.inviterDisplayName, 'Lucía');
    });
  });
}
