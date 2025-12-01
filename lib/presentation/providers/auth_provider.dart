import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  // Local-only version: User is always "null" or we could simulate a local user if needed.
  // For now, we'll just say not authenticated to hide any cloud UI.

  // Actually, if we want to hide the cloud UI, isAuthenticated being false is fine.
  // But if the app relies on a user object for something else, we might need to check.
  // Based on SettingsScreen, it uses it to show profile info.

  // We will expose a dummy user getter if needed, but for now null is safer to ensure no cloud calls.

  bool get isAuthenticated => false;

  // Dummy user object if needed, but we removed the class import so we can't return User.
  // We'll just return dynamic or nothing.
  get user => null;

  AuthProvider() {
    // No initialization needed
  }

  Future<void> signInWithGoogle() async {
    debugPrint('Cloud sync is disabled in this version.');
  }

  Future<void> signOut() async {
    // No-op
  }
}
