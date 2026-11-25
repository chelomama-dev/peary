import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/demo/demo_store.dart';
import '../../me/data/me_repository.dart';
import 'group_dtos.dart';

abstract interface class GroupsRepository {
  Future<GroupDetail> getGroup(String groupId);
  Future<GroupDetail> createGroup(CreateGroupRequest request);
}

class HttpGroupsRepository implements GroupsRepository {
  const HttpGroupsRepository(this._client);

  final ApiClient _client;

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    final json = await _client.getJson('/api/groups/$groupId');
    return GroupDetail.fromJson(json);
  }

  @override
  Future<GroupDetail> createGroup(CreateGroupRequest request) async {
    final json = await _client.postJson('/api/groups', data: request.toJson());
    return GroupDetail.fromJson(json);
  }
}

class DemoGroupsRepository implements GroupsRepository {
  const DemoGroupsRepository(this._store);

  final DemoStore _store;

  @override
  Future<GroupDetail> getGroup(String groupId) async =>
      _store.getGroup(groupId);

  @override
  Future<GroupDetail> createGroup(CreateGroupRequest request) async =>
      _store.createGroup(request);
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.demoMode) {
    return DemoGroupsRepository(ref.watch(demoStoreProvider));
  }
  return HttpGroupsRepository(ref.watch(apiClientProvider));
});

class SelectedGroupIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? groupId) {
    state = groupId;
  }
}

final selectedGroupIdProvider =
    NotifierProvider<SelectedGroupIdNotifier, String?>(
  SelectedGroupIdNotifier.new,
);

/// Resolves the active group ID: uses the explicitly selected group if it
/// still belongs to `me.groups`, otherwise falls back to the first group.
final currentGroupIdProvider = Provider<String?>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null || me.groups.isEmpty) {
    return null;
  }
  final selected = ref.watch(selectedGroupIdProvider);
  if (selected != null && me.groups.any((g) => g.groupId == selected)) {
    return selected;
  }
  return me.groups.first.groupId;
});

final currentGroupProvider = FutureProvider<GroupDetail?>((ref) async {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return null;
  return ref.watch(groupsRepositoryProvider).getGroup(groupId);
});
