import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final SessionService _session = SessionService();
  final AuthService _auth = AuthService();
  
  final TextEditingController _nameController = TextEditingController();
  String? _avatarUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default or current name from session (if we stored it)
    _nameController.text = _session.name ?? "Explorer";
    _avatarUrl = _session.avatar ?? "";
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    
    final success = await _apiService.updateUserProfile(
      _nameController.text.trim(),
      _avatarUrl ?? "", // Avatar URL
    );

    if (success) {
      _session.name = _nameController.text.trim(); // keep session in sync
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated! ✨' : 'Failed to update profile.'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
      setState(() => _isSaving = false);
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
        title: const Text('My Profile', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.deepPurple,
              backgroundImage: (_avatarUrl ?? "").isNotEmpty
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: (_avatarUrl ?? "").isEmpty
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            ),
            
            const SizedBox(height: 24),
            
            // Email (non-editable)
            Text(
              _session.email ?? "Not available",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),

            const SizedBox(height: 32),
            // Editable Name Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.edit, color: Colors.deepPurple),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 100),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
