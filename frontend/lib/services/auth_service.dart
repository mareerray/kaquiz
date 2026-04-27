import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? null : dotenv.env['GOOGLE_IOS_CLIENT_ID'],
    serverClientId: dotenv.env['WEB_CLIENT_ID'],
  );

  /// Triggers the Google Sign In flow and returns the idToken
  Future<String?> signInWithGoogle() async {
    try {
      debugPrint("🔵 Starting Google Sign In...");
      // Force sign out first to clear any cached tokens with wrong audiences
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint("🔴 User cancelled sign in");
        return null; // User canceled
      }

      debugPrint("🟢 Account selected: ${account.email}");
      final GoogleSignInAuthentication auth = await account.authentication;

      debugPrint("🟢 Got idToken: ${auth.idToken != null ? 'YES ✅' : 'NULL ❌'}");
      return auth.idToken;
    } catch (e) {
      debugPrint("🔴 Google Sign In Error: $e");
      return null;
    }
  }

  /// Signs out of Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

