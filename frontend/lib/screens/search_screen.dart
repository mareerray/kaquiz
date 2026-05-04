import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
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
  bool _isActionLoading = false;
  bool _isRequestSent = false; 
  bool _isAlreadyFriend = false; 
  bool _isIncomingRequest = false;

  Timer? _debounce;
  Timer? _statusPollingTimer; // Timer for checking acceptance status
  List<dynamic> _myFriends = [];
  List<dynamic> _sentInvites = [];
  List<dynamic> _incomingInvites = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final results = await Future.wait([
      _apiService.getFriends(),
      _apiService.getSentInvites(),
      _apiService.getPendingInvites(),
    ]);
    
    if (mounted) {
      _myFriends = results[0];
      _sentInvites = results[1];
      _incomingInvites = results[2];
      
      if (mounted) {
        final foundId = _foundUser?['id']?.toString();
        debugPrint("🔍 SEARCH DEBUG: My ID = ${SessionService().userId}, Found ID = $foundId");
        debugPrint("🔍 SEARCH DEBUG: Sent Count = ${_sentInvites.length}, Incoming Count = ${_incomingInvites.length}");

        if (foundId != null) {
          _isAlreadyFriend = _myFriends.any((f) => f['id']?.toString() == foundId);
          
          _isRequestSent = _sentInvites.any((inv) {
            final rid = (inv['receiver_id'] ?? inv['receiverId'] ?? inv['recipient_id'])?.toString();
            return rid == foundId;
          });

          _isIncomingRequest = _incomingInvites.any((inv) {
            final sid = (inv['sender_id'] ?? inv['senderId'])?.toString();
            return sid == foundId;
          });
          
          debugPrint("🔍 RESULT: Friend=$_isAlreadyFriend, Sent=$_isRequestSent, Incoming=$_isIncomingRequest");
          
          if (_isAlreadyFriend) _stopPolling();
        }
        setState(() {});
      }
    }
  }

  void _startPolling() {
    _stopPolling();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadFriends();
    });
  }

  void _stopPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query.trim().toLowerCase());
      } else {
        _clearSearch();
      }
    });
  }

  Future<void> _performSearch(String email) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _stopPolling();
    
    await _loadFriends();

    setState(() {
      _isSearching = true;
      _isRequestSent = false;
      _isAlreadyFriend = false;
      _isIncomingRequest = false;
    });

    try {
      final user = await _apiService.searchUsers(email);
      if (mounted) {
        bool friend = false;
        if (user != null) {
          friend = _myFriends.any((f) => f['id'] == user['id']);
        }
        
        setState(() {
          _foundUser = user;
          _isAlreadyFriend = friend;
          final foundId = user?['id']?.toString();
          
          _isRequestSent = _sentInvites.any((inv) {
            final receiverId = (inv['receiver_id'] ?? inv['receiverId'] ?? inv['recipient_id'])?.toString();
            return receiverId == foundId;
          });

          _isIncomingRequest = _incomingInvites.any((inv) {
            final senderId = (inv['sender_id'] ?? inv['senderId'])?.toString();
            return senderId == foundId;
          });
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
    _stopPolling();
    _searchController.clear();
    setState(() {
      _foundUser = null;
      _isRequestSent = false;
      _isAlreadyFriend = false;
      _isIncomingRequest = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _stopPolling();
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10, offset: const Offset(0, 4),
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
            blurRadius: 20, offset: const Offset(0, 10),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isAlreadyFriend || _isActionLoading) 
                    ? null 
                    : () async {
                        setState(() => _isActionLoading = true);
                        
                        if (_isIncomingRequest) {
                          // If there's an incoming request, accept it!
                          final invite = _incomingInvites.firstWhere(
                            (inv) => inv['sender_id']?.toString() == user['id']?.toString(),
                          );
                          final success = await _apiService.respondToInvite(invite['id'], true);
                          if (mounted && success) {
                            UIUtils.showSuccess(context, 'Friend request accepted!');
                            _loadFriends();
                          }
                          setState(() => _isActionLoading = false);
                          return;
                        }

                        if (_isRequestSent) {
                          // If it's already sent, clicking again cancels it
                          final invite = _sentInvites.firstWhere(
                            (inv) {
                              final receiverId = (inv['receiver_id'] ?? inv['receiverId'] ?? inv['recipient_id'])?.toString();
                              return receiverId == user['id']?.toString();
                            },
                            orElse: () => null,
                          );
                          
                          if (invite != null) {
                            final success = await _apiService.cancelInvite(invite['id']);
                            if (mounted && success) {
                              UIUtils.showSuccess(context, 'Request cancelled.');
                              _loadFriends();
                            }
                          }
                          setState(() => _isActionLoading = false);
                          return;
                        }

                        // Otherwise, send a new request
                        final success = await _apiService.sendFriendRequest(user['id']);
                        if (mounted && success) {
                          _isRequestSent = true;
                          _loadFriends();
                          UIUtils.showSuccess(context, 'Request sent!');
                        } else if (mounted) {
                          UIUtils.showError(context, 'Failed to send request.');
                        }
                        setState(() => _isActionLoading = false);
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAlreadyFriend ? Colors.green : (_isIncomingRequest ? Colors.purple : (_isRequestSent ? Colors.orange : Colors.blue)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isActionLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isAlreadyFriend 
                            ? 'Accepted!' 
                            : (_isIncomingRequest ? 'Accept Invite' : (_isRequestSent ? 'Pending...' : 'Add Friend'))
                      ),
                ),
              ),
              if (_isRequestSent && !_isAlreadyFriend) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    // Find the invite ID to cancel
                    final invite = _sentInvites.firstWhere(
                      (inv) {
                        final receiverId = (inv['receiver_id'] ?? inv['receiverId'])?.toString();
                        return receiverId == user['id']?.toString();
                      },
                      orElse: () => null,
                    );
                    
                    if (invite != null) {
                      final success = await _apiService.cancelInvite(invite['id']);
                      if (success) {
                        _loadFriends(); // Refresh lists
                        UIUtils.showSuccess(context, 'Request cancelled.');
                      }
                    } else {
                      // If we don't have the ID yet (just sent), we can still reset local state
                      setState(() => _isRequestSent = false);
                    }
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
