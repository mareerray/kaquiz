import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../utils/ui_utils.dart';
import 'dart:ui';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _session = SessionService();
  final _apiService = ApiService();
  final _supabaseService = SupabaseService();
  final _auth = AuthService();
  final _picker = ImagePicker();
  
  late TextEditingController _nameController;
  bool _isSaving = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _session.name ?? 'Explorer');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    try {
      String? avatarUrl = _session.avatar;

      // 1. If new image selected, upload to Supabase
      if (_selectedImage != null) {
        final userId = _session.email ?? 'user';
        final uploadedUrl = await _supabaseService.uploadAvatar(_selectedImage!, userId);
        
        if (uploadedUrl != null) {
          avatarUrl = uploadedUrl;
        } else {
          if (mounted) {
            UIUtils.showError(context, "Failed to upload image to Cloud. Please check if 'avatars' bucket exists and is public.");
          }
          setState(() => _isSaving = false);
          return; // STOP HERE if upload failed
        }
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
        if (mounted) UIUtils.showError(context, "Failed to save profile on server.");
      }
    } catch (e) {
      if (mounted) UIUtils.showError(context, "An error occurred: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleLogout() async {
    _session.clear();
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildAvatarSection(),
            const SizedBox(height: 40),
            _buildInfoCard(),
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 60),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.blueAccent, Colors.pinkAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white,
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (_session.avatar != null && _session.avatar!.isNotEmpty
                      ? NetworkImage(_session.avatar!)
                      : null) as ImageProvider?,
              child: (_selectedImage == null && (_session.avatar == null || _session.avatar!.isEmpty))
                  ? Text(
                      (_session.name?.isNotEmpty ?? false) ? _session.name![0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "DISPLAY NAME",
                style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "Enter your name",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const Divider(height: 32),
              const Text(
                "EMAIL ADDRESS",
                style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                _session.email ?? "Not signed in",
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
          shadowColor: Colors.deepPurple.withOpacity(0.4),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : const Text(
                "Save Changes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _handleLogout,
      icon: const Icon(Icons.logout_rounded),
      label: const Text("Log Out"),
      style: TextButton.styleFrom(
        foregroundColor: Colors.redAccent,
        iconColor: Colors.redAccent,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
