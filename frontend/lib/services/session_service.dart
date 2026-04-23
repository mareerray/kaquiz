class SessionService {
  // Singleton pattern
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? _jwtToken;

  /// Saves the token in memory for the current session
  void setToken(String token) {
    _jwtToken = token;
    print("🔑 SessionService: Token saved.");
  }

  /// Returns the current session token
  String? get token => _jwtToken;

  /// Clears the token on logout
  void clear() {
    _jwtToken = null;
    print("🔑 SessionService: Session cleared.");
  }

  /// Check if user is logged in
  bool get isLoggedIn => _jwtToken != null;
}
