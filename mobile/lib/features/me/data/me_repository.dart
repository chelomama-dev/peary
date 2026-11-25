import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/demo/demo_store.dart';
import '../../groups/data/group_dtos.dart';
import '../../groups/data/groups_repository.dart';
import 'me_dtos.dart';

abstract interface class MeRepository {
  Future<MeResponse> getMe();
  Future<GroupDetail> acceptInvitation(String invitationId);
  Future<void> declineInvitation(String invitationId);
}

class HttpMeRepository implements MeRepository {
  const HttpMeRepository(this._client);

  final ApiClient _client;

  @override
  Future<MeResponse> getMe() async {
    final json = await _client.getJson('/api/me');
    return MeResponse.fromJson(json);
  }

  @override
  Future<GroupDetail> acceptInvitation(String invitationId) async {
    final json =
        await _client.postJson('/api/invitations/$invitationId/accept');
    return GroupDetail.fromJson(json);
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _client.postNoContent('/api/invitations/$invitationId/decline');
  }
}

class DemoMeRepository implements MeRepository {
  const DemoMeRepository(this._store);

  final DemoStore _store;

  @override
  Future<MeResponse> getMe() async => _store.getMe();

  @override
  Future<GroupDetail> acceptInvitation(String invitationId) async =>
      _store.acceptInvitation(invitationId);

  @override
  Future<void> declineInvitation(String invitationId) async =>
      _store.declineInvitation(invitationId);
}

final meRepositoryProvider = Provider<MeRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.demoMode) {
    return DemoMeRepository(ref.watch(demoStoreProvider));
  }
  return HttpMeRepository(ref.watch(apiClientProvider));
});

class MeNotifier extends AsyncNotifier<MeResponse> {
  @override
  Future<MeResponse> build() {
    return ref.watch(meRepositoryProvider).getMe();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(meRepositoryProvider).getMe(),
    );
  }

  Future<GroupDetail> createGroup({
    required String name,
    required String timeZone,
  }) async {
    final created = await ref
        .read(groupsRepositoryProvider)
        .createGroup(CreateGroupRequest(name: name, timeZone: timeZone));
    ref.read(selectedGroupIdProvider.notifier).select(created.groupId);
    final updatedMe = await ref.read(meRepositoryProvider).getMe();
    state = AsyncData(updatedMe);
    return created;
  }

  Future<GroupDetail> acceptInvitation(String invitationId) async {
    final joined =
        await ref.read(meRepositoryProvider).acceptInvitation(invitationId);
    ref.read(selectedGroupIdProvider.notifier).select(joined.groupId);
    final updatedMe = await ref.read(meRepositoryProvider).getMe();
    state = AsyncData(updatedMe);
    return joined;
  }

  Future<void> declineInvitation(String invitationId) async {
    await ref.read(meRepositoryProvider).declineInvitation(invitationId);
    final updatedMe = await ref.read(meRepositoryProvider).getMe();
    state = AsyncData(updatedMe);
  }
}

final meProvider = AsyncNotifierProvider<MeNotifier, MeResponse>(
  MeNotifier.new,
);
