import 'dart:convert';
import 'package:flutter/foundation.dart';

class SessionService {
  // Singleton pattern
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? _jwtToken;
  String? name;    
  String? email;   
  String? avatar;  
  int? userId;  

  /// Saves the token in memory for the current session and extracts userId
  void setToken(String token) {
    _jwtToken = token;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        String payload = parts[1];
        // Add padding if needed
        while (payload.length % 4 != 0) {
          payload += '=';
        }
        final String decoded = utf8.decode(base64Url.decode(payload));
        final Map<String, dynamic> data = jsonDecode(decoded);
        userId = data['user_id'] ?? data['id'] ?? data['sub'];
        debugPrint("🔑 SessionService: Token saved. Extracted userId: $userId");
      }
    } catch (e) {
      debugPrint("⚠️ SessionService: Could not decode token: $e");
    }
  }

  /// Returns the current session token
  String? get token => _jwtToken;
  bool get IsLoggedIn => _jwtToken != null;

  /// Clears the token on logout
  Future<void> clearSession() async {
    _jwtToken = null;
    name = null;
    email = null;
    avatar = null;
    userId = null;
    debugPrint("🔑 SessionService: Session cleared.");
  }

  /// Check if user is logged in
  bool get isLoggedIn => _jwtToken != null;
}
