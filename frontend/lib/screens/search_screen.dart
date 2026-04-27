import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';

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
  bool _isRequestSent = false; 
  bool _isAlreadyFriend = false; // Check if the searched user is already a friend

  Timer? _debounce;
  List<dynamic> _myFriends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await _apiService.getFriends();
    if (mounted) {
      setState(() => _myFriends = friends);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query.trim().toLowerCase());
      } else {
        setState(() {
          _foundUser = null;
          _isRequestSent = false;
          _isAlreadyFriend = false;
        });
      }
    });
  }

  Future<void> _performSearch(String email) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    setState(() {
      _isSearching = true;
      _isRequestSent = false;
      _isAlreadyFriend = false;
    });

    try {
      final user = await _apiService.searchUsers(email);
      if (mounted) {
        bool friend = false;
        if (user != null) {
          friend = _myFriends.any((f) => f['id'] == user['id'] || f['email'] == user['email']);
        }
        
        setState(() {
          _foundUser = user;
          _isAlreadyFriend = friend;
        });
        
        if (user == null) {
          UIUtils.showError(context, "No user found with this email.");
        }
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showError(context, "An error occurred while searching.");
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _foundUser = null;
      _isRequestSent = false;
      _isAlreadyFriend = false;
    });
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
            // Search Input with Clear (X) button
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
                decoration: InputDecoration(
                  hintText: 'Enter friend\'s email...',
                  border: InputBorder.none,
                  icon: const Icon(Icons.search, color: Colors.deepPurple),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Search Results
            if (_isSearching)
              const CircularProgressIndicator()
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
          const SizedBox(height: 16),
          Text(
            user['name'] ?? 'Unknown User',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            user['email'] ?? '',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          
          // Action Area
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isRequestSent || _isAlreadyFriend) 
                    ? null 
                    : () async {
                        if (user['id'] == null) return;
                        final success = await _apiService.sendFriendRequest(user['id']);
                        if (mounted && success) {
                          setState(() => _isRequestSent = true);
                          UIUtils.showSuccess(context, 'Request sent!');
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAlreadyFriend 
                        ? Colors.green.shade400 
                        : (_isRequestSent ? Colors.grey.shade400 : Colors.deepPurple),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _isAlreadyFriend ? Colors.green.shade300 : Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _isAlreadyFriend 
                        ? 'Already Friends' 
                        : (_isRequestSent ? 'Pending...' : 'Add Friend')
                  ),
                ),
              ),
              if (_isRequestSent) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    setState(() => _isRequestSent = false);
                    UIUtils.showInfo(context, "Search cleared.");
                  },
                )
              ]
            ],
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
