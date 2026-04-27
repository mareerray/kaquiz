import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;
  String? _error;

  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query.trim().toLowerCase());
      } else {
        setState(() {
          _foundUser = null;
          _error = null;
        });
      }
    });
  }

  Future<void> _performSearch(String email) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final user = await _apiService.searchUsers(email);
      setState(() {
        _foundUser = user;
        if (user == null) {
          _error = "No user found with this email.";
        }
      });
    } catch (e) {
      setState(() {
        _error = "An error occurred while searching.";
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Search Friends', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Search Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Enter friend\'s email...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.deepPurple),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Search Results
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_error != null)
              Text(_error!, style: TextStyle(color: Colors.grey.shade600))
            else if (_foundUser != null)
              _buildUserCard(_foundUser!)
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.deepPurple,
            backgroundImage: (user['avatar'] != null && user['avatar'].toString().isNotEmpty)
                ? NetworkImage(user['avatar'])
                : null,
            child: (user['avatar'] == null || user['avatar'].toString().isEmpty)
                ? Text(
                    user['name']?[0]?.toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          // Avatar
          // CircleAvatar(
          //   radius: 40,
          //   backgroundColor: Colors.deepPurple,
          //   child: Text(
          //     user['name']?[0]?.toUpperCase() ?? 'U',
          //     style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
          //   ),
          // ),
          
          const SizedBox(height: 16),
          
          // User Info
          Text(
            user['name'] ?? 'Unknown User',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            user['email'] ?? '',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          
          const SizedBox(height: 24),
          
          // Add Friend Button
          SizedBox(
            width: double.infinity,
            child: _isSearching 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: () async {
                    if (user['id'] == null) return;
                    
                    final success = await _apiService.sendFriendRequest(user['id']);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success 
                            ? 'Friend request sent to ${user['name']}! 📨' 
                            : 'Failed to send request. Maybe already sent?'),
                          backgroundColor: success ? Colors.green : Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Add Friend'),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Find your friends to start tracking!',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
