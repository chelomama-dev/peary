import 'package:flutter_test/flutter_test.dart';
import 'package:peary/features/groups/data/group_dtos.dart';

void main() {
  group('Group DTOs', () {
    test('parses the group object example from docs/api.md', () {
      final json = <String, dynamic>{
        'groupId': '0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e',
        'name': 'Casa',
        'timeZone': 'Europe/Madrid',
        'myRole': 'admin',
        'unknownTopLevel': true,
        'members': [
          {
            'userId': '6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c',
            'name': 'Roberto',
            'email': 'roberto@example.com',
            'role': 'admin',
            'joinedAt': '2026-11-25T17:46:00Z',
          },
          {
            'userId': '7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d',
            'name': null,
            'email': 'lucia@example.com',
            'role': 'member',
            'joinedAt': '2026-11-26T09:12:00Z',
          },
        ],
        'createdAt': '2026-11-25T17:46:00Z',
      };

      final group = GroupDetail.fromJson(json);

      expect(group.groupId, '0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e');
      expect(group.name, 'Casa');
      expect(group.timeZone, 'Europe/Madrid');
      expect(group.myRole, GroupRole.admin);
      expect(group.createdAt, DateTime.utc(2026, 11, 25, 17, 46, 0));
      expect(group.members, hasLength(2));
      expect(group.members[0].displayName, 'Roberto');
      expect(group.members[0].role, GroupRole.admin);
      expect(group.members[1].name, isNull);
      expect(group.members[1].displayName, 'lucia@example.com');
      expect(group.members[1].role, GroupRole.member);
    });

    test('serializes CreateGroupRequest matching docs/api.md', () {
      const request = CreateGroupRequest(
        name: 'Casa',
        timeZone: 'Europe/Madrid',
      );

      expect(request.toJson(), {
        'name': 'Casa',
        'timeZone': 'Europe/Madrid',
      });
    });
  });
}
