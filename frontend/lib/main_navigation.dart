import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/invites_screen.dart';
import 'services/api_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;
  int _pendingInvitesCount = 0;
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _checkInvites();
    // Poll for new invites every 20 seconds
    _badgeTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _checkInvites();
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInvites() async {
    try {
      final invites = await _apiService.getPendingInvites();
      if (mounted) {
        setState(() {
          _pendingInvitesCount = invites.length;
        });
      }
    } catch (e) {
      // Silently fail, it's just a badge
    }
  }

  final List<Widget> _screens = [
    const MapScreen(),
    const FriendsScreen(),
    const InvitesScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 2) {
        // If they click Invites, we can assume they saw them for a bit, 
        // but we'll let the next poll clear it properly if they accept/decline.
      }
    });
  }

  void switchTab(int index) {
    _onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.map_outlined, Icons.map, 'Map', 0),
                  _buildNavItem(Icons.people_outline, Icons.people, 'Friends', 1),
                  _buildNavItem(Icons.mail_outline, Icons.mail, 'Invites', 2, hasBadge: _pendingInvitesCount > 0),
                  _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index, {bool hasBadge = false}) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.deepPurple : Colors.grey.shade600;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 24),
              if (hasBadge)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                    child: Text(
                      '$_pendingInvitesCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
