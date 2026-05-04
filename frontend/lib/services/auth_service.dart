import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? null : dotenv.env['GOOGLE_IOS_CLIENT_ID'],
    serverClientId: dotenv.env['WEB_CLIENT_ID'],
  );

  /// Triggers the Google Sign In flow and returns the idToken
 Future<String?> signInWithGoogle() async {
    try {
      debugPrint("🔵 Starting Google Sign In...");

      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint("🔴 User cancelled sign in");
        return null;
      }

      debugPrint("🟢 Account selected: ${account.email}");

      final GoogleSignInAuthentication auth = await account.authentication;

      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      debugPrint("🟢 Got idToken: ${idToken != null ? 'YES ✅' : 'NULL ❌'}");
      debugPrint("🟢 Got accessToken: ${accessToken != null ? 'YES ✅' : 'NULL ❌'}");

      if (idToken == null) {
        debugPrint("🔴 No Google idToken found");
        return null;
      }

      if (accessToken == null) {
        debugPrint("🔴 No Google accessToken found");
        return null;
      }

      try {
        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );
        debugPrint("🟢 Supabase login SUCCESS: ${Supabase.instance.client.auth.currentUser?.id}");
      } catch (supabaseError) {
        debugPrint("⚠️ Supabase login failed (nonce issue?), but continuing main login: $supabaseError");
      }

      return idToken;
    } catch (e) {
      debugPrint("🔴 Google Sign In Error: $e");
      return null;
    }
  }
  /// Signs out of Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await Supabase.instance.client.auth.signOut();
  }
}

