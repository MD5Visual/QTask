import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

  User? _user;
  User? get user => _user;

  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeGoogleSignIn();

    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> _initializeGoogleSignIn() async {
    // Check if we're on web first, as Platform.isWindows won't work on web
    if (kIsWeb) {
      // For web, we don't use google_sign_in_all_platforms at all
      // We'll handle web separately in signInWithGoogle
      _googleSignIn = GoogleSignIn(params: const GoogleSignInParams());
    } else {
      String? clientId;
      String? clientSecret;

      // Load OAuth credentials for desktop platforms
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          // Try to load from local config file (gitignored)
          final configFile = File('lib/oauth_config.json');
          if (await configFile.exists()) {
            final configJson = jsonDecode(await configFile.readAsString());
            clientId = configJson['web_client_id'];
            clientSecret = configJson['web_client_secret'];
          } else {
            debugPrint(
                'WARNING: lib/oauth_config.json not found. Create it from oauth_config.json.example');
          }
        } catch (e) {
          debugPrint('Error loading OAuth config: $e');
        }
      }

      _googleSignIn = GoogleSignIn(
        params: GoogleSignInParams(
          clientId: clientId,
          clientSecret: clientSecret,
        ),
      );
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Handle web separately
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      }

      // Use google_sign_in_all_platforms API (works on all platforms)
      final GoogleSignInCredentials? credentials = await _googleSignIn.signIn();

      if (credentials == null) {
        // User canceled the sign-in
        return null;
      }

      // Create Firebase credential from Google credentials
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: credentials.accessToken,
        idToken: credentials.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
