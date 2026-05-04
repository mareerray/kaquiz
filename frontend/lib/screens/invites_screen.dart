import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _incomingInvites = [];
  List<dynamic> _sentInvites = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadInvites();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isLoading) {
        _loadInvites(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInvites({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    final results = await Future.wait([
      _apiService.getPendingInvites(),
      _apiService.getSentInvites(),
    ]);
    
    if (mounted) {
      setState(() {
        _incomingInvites = results[0];
        _sentInvites = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancel(int id) async {
    setState(() => _isLoading = true);
    final success = await _apiService.cancelInvite(id);
    if (mounted) {
      if (success) {
        setState(() {
          _sentInvites.removeWhere((inv) => (inv['id'] ?? inv['id']) == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled.'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel request.'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(int id, bool accept) async {
    setState(() => _isLoading = true);
    
    final success = await _apiService.respondToInvite(id, accept);
    
    if (mounted) {
      if (success) {
        setState(() {
          _incomingInvites.removeWhere((invite) => (invite['id'] ?? invite['id']) == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Accepted! 🤝' : 'Declined.'),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process request.'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Friend Requests', style: TextStyle(color: Colors.black87)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInvites,
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'Outgoing'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildInvitesList(_incomingInvites, isOutgoing: false),
                  _buildInvitesList(_sentInvites, isOutgoing: true),
                ],
              ),
      ),
    );
  }

  Widget _buildInvitesList(List<dynamic> list, {required bool isOutgoing}) {
    if (list.isEmpty) return _buildEmptyState(isOutgoing);
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildInviteCard(list[index], isOutgoing: isOutgoing);
      },
    );
  }

  Widget _buildInviteCard(dynamic invite, {required bool isOutgoing}) {
    final String name = isOutgoing 
        ? (invite['receiver_name'] ?? invite['receiverName'] ?? 'Unknown') 
        : (invite['name'] ?? invite['sender_name'] ?? invite['senderName'] ?? 'Unknown');
    final String? avatar = isOutgoing 
        ? (invite['receiver_avatar'] ?? invite['receiverAvatar']) 
        : (invite['avatar'] ?? invite['sender_avatar'] ?? invite['senderAvatar']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isOutgoing ? Colors.blue.shade100 : Colors.orange.shade100,
                backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || avatar.toString().isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: isOutgoing ? Colors.blue : Colors.orange),
                      )
                    : null,
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
                      isOutgoing 
                        ? 'Sent on ${invite['created_at']?.split(' ')[0] ?? ''}'
                        : 'Requested on ${invite['created_at']?.split(' ')[0] ?? ''}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          if (isOutgoing)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _handleCancel(invite['id']),
                child: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _handleAction(invite['id'], false),
                    child: const Text('Decline', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(invite['id'], true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isOutgoing) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOutgoing ? Icons.send_outlined : Icons.mail_outline, 
            size: 80, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            isOutgoing ? 'No sent requests.' : 'No pending requests.', 
            style: const TextStyle(color: Colors.grey)
          ),
        ],
      ),
    );
  }
}
