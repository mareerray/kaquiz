import 'dart:io';
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
      await Supabase.initialize(url: url, anonKey: key);
      _isInitialized = true;
    }
  }

  Future<String?> uploadAvatar(File imageFile, String userId) async {
    try {
      await initialize();
      
      final fileName = 'avatar_$userId\_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'avatars/$fileName';
      
      final storage = Supabase.instance.client.storage.from('avatars');
      
      await storage.upload(path, imageFile);
      
      // Get public URL
      final publicUrl = storage.getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print("Error uploading to Supabase: $e");
      return null;
    }
  }
}
