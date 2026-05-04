import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'session_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

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
        final Map<String, dynamic> data = jsonDecode(response.body);
        // Normalize the ID field so the UI always sees 'id'
        data['id'] = data['id'] ?? data['userId'] ?? data['user_id'] ?? data['ID'];
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- SOCIAL METHODS (WEEK 2) ---

  Future<List<dynamic>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends'),
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
        final List<dynamic> allInvites = jsonDecode(response.body);
        debugPrint("📩 INVITES DEBUG (/api/invites): Found ${allInvites.length} items. Raw: $allInvites");
        
        return allInvites.where((inv) {
          final receiverId = (inv['receiver_id'] ?? inv['receiverId'] ?? inv['user_id'] ?? inv['to'])?.toString();
          final myId = _session.userId?.toString();
          return receiverId == myId;
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getSentInvites() async {
    try {
      // Let's try BOTH common endpoints to find where sent invites are
      final response = await http.get(
        Uri.parse('$baseUrl/api/invites/sent'), // Trying specialized endpoint first
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );
      
      List<dynamic> allInvites = [];
      if (response.statusCode == 200) {
        allInvites = jsonDecode(response.body);
        debugPrint("📤 SENT DEBUG (/api/invites/sent): Found ${allInvites.length} items.");
      } else {
        // Fallback to main endpoint
        final resp2 = await http.get(
          Uri.parse('$baseUrl/api/invites'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_session.token}',
          },
        );
        if (resp2.statusCode == 200) {
          allInvites = jsonDecode(resp2.body);
          debugPrint("📤 SENT DEBUG (fallback to /api/invites): Found ${allInvites.length} items.");
        }
      }
      
      return allInvites.where((inv) {
        final senderId = (inv['sender_id'] ?? inv['senderId'] ?? inv['from'])?.toString();
        final myId = _session.userId?.toString();
        return senderId == myId;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendFriendRequest(dynamic targetUserId) async {
    try {
      debugPrint("🚀 ApiService: Sending request to user $targetUserId");
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
      );
      debugPrint("🚀 ApiService: Response status: ${response.statusCode}");
      // 200/201 = Created, 409 = Already exists (Conflict)
      if (response.statusCode == 409) {
        debugPrint("🚀 ApiService: Request already exists (409 Conflict)");
        return true; 
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("🚀 ApiService: ERROR sending request: $e");
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

  Future<bool> cancelInvite(int inviteId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/invites/$inviteId'),
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

  Future<bool> updateUserProfile(String name, String avatar) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session.token}',
        },
        body: jsonEncode({
          'name': name,
          'avatar': avatar,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadAvatar(String userId) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return null;

      final file = File(image.path);
      final supabase = Supabase.instance.client;

      final filePath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await supabase.storage.from('avatars').upload(
        filePath,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
        ),
      );

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      if (supabaseUrl.isEmpty) {
        throw Exception('SUPABASE_URL is missing from .env');
      }

      final publicUrl =
    '$supabaseUrl/storage/v1/object/public/avatars/$filePath';      
      debugPrint('🟢 Avatar uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('🔴 Avatar upload failed: $e');
      return null;
    }
  }
  Future<void> fetchAndStoreUserInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {'Authorization': 'Bearer ${_session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("🟢 RAW USER DATA: $data"); // Let's see what's inside
        
        _session.name   = data['name'];
        _session.email  = data['email'];
        _session.avatar = data['avatar'];
        
        // Only update userId if it's actually in the response
        final newId = data['id'] ?? data['userId'] ?? data['user_id'] ?? data['ID'];
        if (newId != null) {
          _session.userId = newId;
        }
        
        debugPrint("🟢 User info loaded: ${_session.name} (ID: ${_session.userId})");
      }
    } catch (e) {
      debugPrint("🔴 Failed to fetch user info: $e");
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
    // Now calling the real GET /api/friends which returns locations
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends'),
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
}
