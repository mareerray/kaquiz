import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../utils/ui_utils.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final SessionService _session = SessionService();
  final SupabaseService _supabaseService = SupabaseService();
  final _picker = ImagePicker();
  
  final _nameController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _session.name ?? '';
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compressing for faster upload
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      UIUtils.showError(context, "Name cannot be empty");
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      String? avatarUrl = _session.avatar;

      // 1. If new image selected, upload to Supabase
      if (_selectedImage != null) {
        final userId = _session.email ?? 'user';
        // This will now THROW an exception on error, going straight to catch block
        avatarUrl = await _supabaseService.uploadAvatar(_selectedImage!, userId);
      }

      // 2. Update backend
      final success = await _apiService.updateUserProfile(
        _nameController.text.trim(),
        avatarUrl ?? '',
      );

      if (success && mounted) {
        // 3. Update local session
        _session.name = _nameController.text.trim();
        _session.avatar = avatarUrl;
        
        UIUtils.showSuccess(context, "Profile updated successfully! ✨");
        setState(() => _selectedImage = null);
      } else {
        if (mounted) UIUtils.showError(context, "Failed to update profile on backend.");
      }
    } catch (e) {
      debugPrint("🔴 Profile Save Error: $e");
      if (mounted) UIUtils.showError(context, "Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    setState(() => _isSaving = true);
  
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      throw Exception('No Supabase user found');
    }    
    
    final url = await _apiService.uploadAvatar(supabaseUser.id);

    if (url != null) {
      final success = await _apiService.updateUserProfile(
        _nameController.text.trim(), // keep current name
        url,
      );
      if (success) {
        setState(() => _avatarUrl = url); // show new avatar immediately
        _session.avatar = url;            // keep session in sync
        _session.name = _nameController.text.trim(); // also update name in session just in case
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated! ✨'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    setState(() => _isSaving = false);
  }

  void _handleLogout() async {
    await _session.clearSession();
    if (mounted) {
      // Direct navigation is safer if routes are being problematic
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String initial = (_session.name?.isNotEmpty == true) ? _session.name![0].toUpperCase() : "U";
    final String? avatarUrl = _selectedImage != null ? null : _session.avatar;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE8EAF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 80),
          child: Column(
            children: [
              // Avatar Section with Glassmorphism
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Colors.deepPurple, Colors.pinkAccent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          image: (_selectedImage != null || (avatarUrl != null && avatarUrl.isNotEmpty))
                              ? DecorationImage(
                                  image: _selectedImage != null 
                                      ? FileImage(_selectedImage!) as ImageProvider
                                      : NetworkImage(avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (_selectedImage == null && (avatarUrl == null || avatarUrl.isEmpty))
                            ? Center(child: Text(initial, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple)))
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Info Card
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("DISPLAY NAME", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Enter your name",
                          ),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text("EMAIL ADDRESS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(_session.email ?? "Not signed in", style: const TextStyle(fontSize: 16, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 5,
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              
              TextButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
