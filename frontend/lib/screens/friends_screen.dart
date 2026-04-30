import 'dart:ui';
import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'invites_screen.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import 'map_screen.dart';
import '../main_navigation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _friends = [];
  int _pendingCount = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> get filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends.where((friend) {
      final name = (friend['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final results = await Future.wait([
      _apiService.getFriends(),
      _apiService.getPendingInvites(),
    ]);
    
    if (mounted) {
      setState(() {
        _friends = results[0];
        _pendingCount = (results[1] as List).length;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F7FA), Color(0xFFE8EAF6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Friends List', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    _buildAddFriendHeader(),
                    _buildLocalSearchBar(),
                    Expanded(
                      child: filteredFriends.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                              itemCount: filteredFriends.length,
                              itemBuilder: (context, index) {
                                return _buildFriendCard(filteredFriends[index]);
                              },
                            ),
                    ),
                    const SizedBox(height: 100), // Space for floating nav bar
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAddFriendHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Find New Friends',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search in friends list...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  bool _isOnline(String? lastSeenStr) {
    if (lastSeenStr == null) return false;
    try {
      final lastSeen = DateTime.parse(lastSeenStr);
      return DateTime.now().difference(lastSeen).inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  Widget _buildFriendCard(dynamic friend) {
    final bool online = _isOnline(friend['last_seen']);
    final String name = friend['name'] ?? 'Unknown';
    final String? avatar = friend['avatar'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: (avatar != null && avatar.isNotEmpty) 
                          ? NetworkImage(avatar) 
                          : null,
                      child: (avatar == null || avatar.isEmpty) 
                          ? Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
                          : null,
                    ),
                    if (online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        online ? 'Online' : 'Offline',
                        style: TextStyle(color: online ? Colors.green : Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (friend['lat'] != null && friend['lng'] != null)
                  IconButton(
                    icon: const Icon(Icons.location_on_outlined, color: Colors.blueAccent),
                    onPressed: () {
                      final double lat = (friend['lat'] as num).toDouble();
                      final double lng = (friend['lng'] as num).toDouble();
                      MapScreen.focusLocationNotifier.value = LatLng(lat, lng);
                      context.findAncestorStateOfType<MainNavigationState>()?.switchTab(0);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(friend),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(dynamic friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text('Are you sure you want to remove ${friend['name']} from your friends list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) setState(() => _isLoading = true);
      
      final success = await _apiService.deleteFriend(friend['id'] ?? 0);
      
      if (success && mounted) {
        UIUtils.showSuccess(context, 'Friend removed.');
        _loadData();
      } else if (mounted) {
        UIUtils.showError(context, 'Failed to remove friend.');
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No friends yet. Time to explore!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
