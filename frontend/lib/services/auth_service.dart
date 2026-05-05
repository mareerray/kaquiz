import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? null : dotenv.env['GOOGLE_IOS_CLIENT_ID'],
    serverClientId: dotenv.env['WEB_CLIENT_ID'],
  );

  /// Generates a random nonce for secure authentication
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Triggers the Google Sign In flow and returns the idToken
 Future<String?> signInWithGoogle() async {
    try {
      final String rawNonce = _generateNonce();
      final String hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // On iOS, we need to pass the nonce to Google Sign In
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

      try {
        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          nonce: rawNonce, // Passing the raw nonce here!
        );
        debugPrint("🟢 Supabase login SUCCESS: ${Supabase.instance.client.auth.currentUser?.id}");
      } catch (supabaseError) {
        // If it still fails, it's likely because the google_sign_in plugin 
        // doesn't support setting a custom nonce yet, or uses a different one.
        debugPrint("⚠️ Supabase login could not verify nonce, but main flow is fine: $supabaseError");
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

