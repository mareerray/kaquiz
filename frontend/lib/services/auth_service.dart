import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // We only need the client ID for iOS, and we added it to Info.plist
    // We can also explicitly specify it here if needed, but Info.plist is better.
  );

  /// Triggers the Google Sign In flow and returns the idToken
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return null; // User canceled
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      return auth.idToken;
    } catch (e) {
      print("Google Sign In Error: $e");
      return null;
    }
  }

  /// Signs out of Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

