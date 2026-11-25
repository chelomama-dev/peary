import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstracts sign-in and access-token retrieval so the identity provider
/// (Microsoft Entra External ID) stays isolated from the rest of the app.
abstract interface class Authenticator {
  /// Returns an access token for the Peary API, or `null` when running
  /// without authentication (for example against a local dev API).
  Future<String?> getAccessToken();

  Future<bool> isSignedIn();

  Future<void> signIn();

  Future<void> signOut();
}

/// Temporary signed-in implementation used while Entra External ID sign-in
/// is evaluated in its own spike (see ADR 0001).
class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({this.accessToken});

  final String? accessToken;
  bool _signedIn = true;

  @override
  Future<String?> getAccessToken() async => _signedIn ? accessToken : null;

  @override
  Future<bool> isSignedIn() async => _signedIn;

  @override
  Future<void> signIn() async {
    _signedIn = true;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
  }
}

final authenticatorProvider = Provider<Authenticator>((ref) {
  return FakeAuthenticator();
});
