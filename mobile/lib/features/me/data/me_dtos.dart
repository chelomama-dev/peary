import 'package:json_annotation/json_annotation.dart';

import '../../groups/data/group_dtos.dart';

part 'me_dtos.g.dart';

@JsonSerializable()
class GroupSummary {
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.role,
    required this.memberCount,
  });

  factory GroupSummary.fromJson(Map<String, dynamic> json) =>
      _$GroupSummaryFromJson(json);

  final String groupId;
  final String name;
  final GroupRole role;
  final int memberCount;

  Map<String, dynamic> toJson() => _$GroupSummaryToJson(this);
}

@JsonSerializable()
class InvitationGroup {
  const InvitationGroup({
    required this.groupId,
    required this.name,
  });

  factory InvitationGroup.fromJson(Map<String, dynamic> json) =>
      _$InvitationGroupFromJson(json);

  final String groupId;
  final String name;

  Map<String, dynamic> toJson() => _$InvitationGroupToJson(this);
}

@JsonSerializable()
class PendingInvitation {
  const PendingInvitation({
    required this.invitationId,
    required this.group,
    required this.invitedBy,
    required this.expiresAt,
  });

  factory PendingInvitation.fromJson(Map<String, dynamic> json) =>
      _$PendingInvitationFromJson(json);

  final String invitationId;
  final InvitationGroup group;
  final String? invitedBy;
  final DateTime expiresAt;

  String get inviterDisplayName {
    final trimmed = invitedBy?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'Alguien';
  }

  Map<String, dynamic> toJson() => _$PendingInvitationToJson(this);
}

@JsonSerializable()
class MeResponse {
  const MeResponse({
    required this.userId,
    required this.name,
    required this.email,
    required this.groups,
    required this.invitations,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);

  final String userId;
  final String? name;
  final String email;
  final List<GroupSummary> groups;
  final List<PendingInvitation> invitations;

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return email;
  }

  Map<String, dynamic> toJson() => _$MeResponseToJson(this);
}
