import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_KEY'] ?? '';
    
    if (url.isNotEmpty && key.isNotEmpty) {
      try {
        debugPrint("🔵 Initializing Supabase with URL: $url");
        await Supabase.initialize(url: url, anonKey: key);
        _isInitialized = true;
      } catch (e) {
        debugPrint("🔴 Supabase Init Error: $e");
      }
    } else {
      debugPrint("🔴 Supabase URL or Key is missing in .env!");
    }
  }

  /// Returns the URL on success, or throws an error string on failure
  Future<String> uploadAvatar(File imageFile, String userId) async {
    try {
      await initialize();
      
      // Sanitize userId for filename
      final safeId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'avatar_${safeId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      debugPrint("🔵 Uploading to Supabase: $fileName (User: $userId)");
      
      final storage = Supabase.instance.client.storage.from('avatars');
      
      // Upload file
      await storage.upload(fileName, imageFile);
      
      final publicUrl = storage.getPublicUrl(fileName);
      debugPrint("🟢 Upload successful: $publicUrl");
      return publicUrl;
    } catch (e) {
      debugPrint("🔴 Avatar upload failed: $e");
      if (e is StorageException) {
        debugPrint("🔴 Storage Error Message: ${e.message}");
        debugPrint("🔴 Status Code: ${e.statusCode}");
      }
      throw e.toString();
    }
  }
}
