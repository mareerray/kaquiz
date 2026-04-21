import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
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
}

