import 'package:json_annotation/json_annotation.dart';

part 'group_dtos.g.dart';

enum GroupRole {
  @JsonValue('admin')
  admin,
  @JsonValue('member')
  member;

  String get labelEs => switch (this) {
        GroupRole.admin => 'Administrador',
        GroupRole.member => 'Miembro',
      };
}

@JsonSerializable()
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);

  final String userId;
  final String? name;
  final String email;
  final GroupRole role;
  final DateTime joinedAt;

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return email;
  }

  Map<String, dynamic> toJson() => _$GroupMemberToJson(this);
}

@JsonSerializable()
class GroupDetail {
  const GroupDetail({
    required this.groupId,
    required this.name,
    required this.timeZone,
    required this.myRole,
    required this.members,
    required this.createdAt,
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) =>
      _$GroupDetailFromJson(json);

  final String groupId;
  final String name;
  final String timeZone;
  final GroupRole myRole;
  final List<GroupMember> members;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$GroupDetailToJson(this);
}

@JsonSerializable()
class CreateGroupRequest {
  const CreateGroupRequest({
    required this.name,
    required this.timeZone,
  });

  factory CreateGroupRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateGroupRequestFromJson(json);

  final String name;
  final String timeZone;

  Map<String, dynamic> toJson() => _$CreateGroupRequestToJson(this);
}
