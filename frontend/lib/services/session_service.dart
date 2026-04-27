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

  /// Saves the token in memory for the current session
  void setToken(String token) {
    _jwtToken = token;
    debugPrint("🔑 SessionService: Token saved.");
  }

  /// Returns the current session token
  String? get token => _jwtToken;
  bool get IsLoggedIn => _jwtToken != null;

  /// Clears the token on logout
  void clear() {
    _jwtToken = null;
    name = null;
    email = null;
    avatar = null;
    debugPrint("🔑 SessionService: Session cleared.");
  }

  /// Check if user is logged in
  bool get isLoggedIn => _jwtToken != null;
}
