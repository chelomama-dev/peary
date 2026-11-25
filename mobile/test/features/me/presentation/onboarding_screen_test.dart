import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:peary/core/formatting/date_formatting.dart';
import 'package:peary/features/groups/data/group_dtos.dart';
import 'package:peary/features/me/data/me_dtos.dart';
import 'package:peary/features/me/data/me_repository.dart';
import 'package:peary/features/me/presentation/onboarding_screen.dart';

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

void main() {
  setUpAll(() async {
    await initializeDateFormatting(kSpanishLocale);
  });

  testWidgets('shows Alguien when a pending invitation has null invitedBy',
      (tester) async {
    final me = MeResponse(
      userId: 'user-1',
      name: 'Roberto',
      email: 'roberto@example.com',
      groups: const [],
      invitations: [
        PendingInvitation(
          invitationId: 'inv-null',
          group: const InvitationGroup(
            groupId: 'grp-1',
            name: 'Piso de la abuela',
          ),
          invitedBy: null,
          expiresAt: DateTime.utc(2026, 12, 2, 10, 0),
        ),
        PendingInvitation(
          invitationId: 'inv-named',
          group: const InvitationGroup(
            groupId: 'grp-2',
            name: 'Casa de la playa',
          ),
          invitedBy: 'Lucía',
          expiresAt: DateTime.utc(2026, 12, 3, 10, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          meRepositoryProvider.overrideWithValue(_StubMeRepository(me)),
        ],
        child: const MaterialApp(
          locale: Locale('es', 'ES'),
          supportedLocales: [Locale('es', 'ES')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

    await tester.scrollUntilVisible(
      find.text('Piso de la abuela'),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('Piso de la abuela'), findsOneWidget);
    expect(find.textContaining('Invitado por Alguien'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Casa de la playa'),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('Casa de la playa'), findsOneWidget);
    expect(find.textContaining('Invitado por Lucía'), findsOneWidget);
  });
}
