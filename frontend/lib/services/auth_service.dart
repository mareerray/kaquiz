import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // We only need the client ID for iOS, and we added it to Info.plist
    // We can also explicitly specify it here if needed, but Info.plist is better.
    serverClientId: dotenv.env['WEB_CLIENT_ID'],
  );

  /// Triggers the Google Sign In flow and returns the idToken
  Future<String?> signInWithGoogle() async {
    try {
      print("🔵 Starting Google Sign In...");
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        print("🔴 User cancelled sign in");
        return null; // User canceled
      }

      print("🟢 Account selected: ${account.email}");
      final GoogleSignInAuthentication auth = await account.authentication;

      print("🟢 Got idToken: ${auth.idToken != null ? 'YES ✅' : 'NULL ❌'}");
      return auth.idToken;
    } catch (e) {
      print("🔴 Google Sign In Error: $e");
      return null;
    }
  }

  /// Signs out of Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

