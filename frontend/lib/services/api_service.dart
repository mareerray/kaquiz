import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'session_service.dart';

class ApiService {
  final _session = SessionService();

  String get baseUrl {
    if (dotenv.isInitialized) {
      final url = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8080';
      return url;    
    }
    return 'http://127.0.0.1:8080';
  }

  Future<String?> authenticateWithBackend(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}), 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> searchUsers(String email) async {
    try {
      final url = '$baseUrl/api/users/search?email=$email';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- SOCIAL METHODS (WEEK 2) ---

  Future<List<dynamic>> getFriends() async {
    // Note: Backend /api/friends is not yet ready (empty handler)
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<dynamic>> getPendingInvites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/invites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendFriendRequest(int targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> respondToInvite(int inviteId, bool accept) async {
    try {
      final action = accept ? 'accept' : 'decline';
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$inviteId/$action'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFriend(int friendId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/friends/$friendId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- LOCATION METHODS ---

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
      return false;
    }
  }

  Future<List<dynamic>> getFriendsLocations(double myLat, double myLng) async {
    // Mocking for Day 7 until GET /friends/locations is ready
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {
        'id': 101,
        'name': 'Maire',
        'latitude': myLat + 0.005,
        'longitude': myLng + 0.005,
        'avatar_url': 'https://i.pravatar.cc/150?u=maire',
        'last_seen_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      },
      {
        'id': 102,
        'name': 'Oleksii',
        'latitude': myLat - 0.008,
        'longitude': myLng + 0.003,
        'avatar_url': null,
        'last_seen_at': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
      },
      {
        'id': 103,
        'name': 'Kateryna (Twin)',
        'latitude': myLat + 0.002,
        'longitude': myLng - 0.007,
        'avatar_url': 'https://i.pravatar.cc/150?u=kat',
        'last_seen_at': DateTime.now().subtract(const Duration(seconds: 45)).toIso8601String(),
      },
    ];
  }
}
