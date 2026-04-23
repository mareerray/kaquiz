import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'session_service.dart';

class ApiService {
  final _session = SessionService();

  // Use dotenv for the API URL so you can point it to the local Mac IP or a real server
  // Defaulting to 127.0.0.1 for local emulator testing if no .env is provided
  String get baseUrl {
    if (dotenv.isInitialized) {
      final url = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8080';
      print("🌐 Using baseUrl: $url");  // ← BEFORE return
      return url;    
    }
    print("🌐 dotenv NOT initialized! Using fallback");
    return 'http://127.0.0.1:8080';
  }

  Future<String?> authenticateWithBackend(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth'),
        headers: {'Content-Type': 'application/json'},
        // The Swagger says Flutter sends Google id_token
        body: jsonEncode({'id_token': idToken}), 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Returns access_token
        return data['access_token'];
      } else {
        print("Backend Auth Error: ${response.statusCode} - ${response.body}");
        return "ERROR: HTTP ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      print("API Serivce Error: $e");
      return "ERROR: API Exception $e";
    }
  }

  Future<bool> updateUserLocation(double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/locations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("API Service Error (Location): $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> searchUsers(String email) async {
    try {
      final url = '$baseUrl/api/users/search?email=$email';
      print("🔍 Searching user at: $url");
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );

      print("📡 Search Response Status: ${response.statusCode}");
      print("📡 Search Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print("❌ API Service Error (Search): $e");
      return null;
    }
  }

  // --- SOCIAL METHODS (DAY 6/7) ---

  Future<List<dynamic>> getFriends() async {
    // This will call GET /api/friends/list (once implemented)
    // For now, it returns an empty list or mock data
    return [];
  }

  Future<List<dynamic>> getPendingInvites() async {
    // This will call GET /api/invites/pending
    return [];
  }

  Future<bool> sendFriendRequest(int targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
        body: jsonEncode({'target_user_id': targetUserId}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> respondToInvite(int inviteId, bool accept) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/invites/$inviteId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
        body: jsonEncode({'status': accept ? 'accepted' : 'declined'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

