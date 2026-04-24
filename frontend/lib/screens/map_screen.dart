import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../utils/marker_utils.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  
  LatLng? _currentPosition;
  bool _isMapLoading = true;
  Set<Marker> _friendsMarkers = {};
  Timer? _refreshTimer;
  Timer? _locationUpdateTimer;

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(50.4501, 30.5234), // Kyiv as default fallback
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    
    // Day 7: Start polling for friends' locations every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentPosition != null) {
        _updateFriendsMarkers();
      }
    });

    // Day 12: Start sending OWN location to server every 10 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
       if (_currentPosition != null) {
          final newLocation = await _locationService.getCurrentLocation();
          if (newLocation != null) {
             setState(() => _currentPosition = newLocation);
             _apiService.updateUserLocation(newLocation.latitude, newLocation.longitude);
          }
       }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      if (!mounted) return;
      setState(() {
        _currentPosition = location;
        _isMapLoading = false;
      });
      _goToCurrentPosition();
      
      // Send initial location to backend
      _apiService.updateUserLocation(location.latitude, location.longitude);
      
      // Day 7: Initial pull of friends
      _updateFriendsMarkers();
    } else {
      if (!mounted) return;
      setState(() => _isMapLoading = false);
    }
  }

  Future<void> _updateFriendsMarkers() async {
    if (_currentPosition == null) return;

    final friendsData = await _apiService.getFriendsLocations(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    final Set<Marker> newMarkers = {};

    for (var friend in friendsData) {
      final String name = friend['name'] ?? 'Unknown';
      final double? lat = friend['lat'] != null ? (friend['lat'] as num).toDouble() : null;
      final double? lng = friend['lng'] != null ? (friend['lng'] as num).toDouble() : null;
      final String? avatarUrl = friend['avatar'];
      final DateTime? lastSeen = friend['last_seen'] != null ? DateTime.parse(friend['last_seen']) : null;
      
      // Only show marker if location is available
      if (lat == null || lng == null) continue;

      final String status = lastSeen != null ? _formatLastSeen(lastSeen) : 'Never seen';

      // Generate custom circular marker icon
      final icon = await MarkerUtils.getAvatarMarker(
        url: avatarUrl,
        name: name,
        color: Colors.deepPurple,
      );

      newMarkers.add(
        Marker(
          markerId: MarkerId('friend_${friend['id']}'),
          position: LatLng(lat, lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: name,
            snippet: status,
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _friendsMarkers = newMarkers;
    });
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Active just now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    return 'Active yesterday';
  }

  Future<void> _goToCurrentPosition() async {
    if (_currentPosition == null) return;
    
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _currentPosition!,
        zoom: 15,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // The Map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Custom button instead
            zoomControlsEnabled: false,
            markers: _friendsMarkers, // Day 7: Friend avatars
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // Top Overlay (Search Bar / Profile)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: _buildTopOverlay(),
          ),

          // Bottom Overlay (Friend Info / Actions) - Future Phase
          
          // Floating Action Buttons
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                _buildMapActionButton(
                  icon: Icons.my_location,
                  onPressed: _goToCurrentPosition,
                  heroTag: 'center_me',
                ),
              ],
            ),
          ),
          
          if (_isMapLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
                child: const Text(
                  'Search friends...',
                  style: TextStyle(color: Colors.black45, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String heroTag,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: Colors.white.withOpacity(0.9),
      foregroundColor: Colors.black87,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Icon(icon),
    );
  }
}
