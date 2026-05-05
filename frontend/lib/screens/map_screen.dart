import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../utils/marker_utils.dart';
import 'search_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static final ValueNotifier<LatLng?> focusLocationNotifier = ValueNotifier(null);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  final SessionService _session = SessionService();
  
  LatLng? _currentPosition;
  bool _isMapLoading = true;
  Set<Marker> _friendsMarkers = {};
  Timer? _refreshTimer;
  Timer? _locationUpdateTimer;
  bool _isRefreshing = false;

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(50.4501, 30.5234), // Kyiv as default fallback
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    MapScreen.focusLocationNotifier.addListener(_onFocusLocationChanged);
    _initializeLocation();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_currentPosition != null && !_isRefreshing) {
        _isRefreshing = true;
        await _updateFriendsMarkers();
        _isRefreshing = false;
      }
    });

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final newLocation = await _locationService.getCurrentLocation();
      if (newLocation != null) {
        if (mounted) setState(() => _currentPosition = newLocation);
        _apiService.updateUserLocation(newLocation.latitude, newLocation.longitude);
      }
    });
  }

  @override
  void dispose() {
    MapScreen.focusLocationNotifier.removeListener(_onFocusLocationChanged);
    _refreshTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _onFocusLocationChanged() async {
    final location = MapScreen.focusLocationNotifier.value;
    if (location != null) {
      final GoogleMapController controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 16),
      ));
      // Reset so next tap on same friend still fires
      MapScreen.focusLocationNotifier.value = null;
    }
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
      _apiService.updateUserLocation(location.latitude, location.longitude);
      // print('\n\n📍 ТВОИ ТЕКУЩИЕ КООРДИНАТЫ: ${location.latitude}, ${location.longitude} \n(Скопируй их в Simulator -> Features -> Location -> Custom Location)\n\n');
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

    // Combine friends and the current user into a single list for grouping
    final List<dynamic> allUsers = List.from(friendsData);
    allUsers.add({
      'id': 'me',
      'name': _session.name ?? 'Me',
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
      'avatar': _session.avatar,
      'is_me': true,
    });

    // Group users by exact location to handle overlaps
    final Map<String, List<dynamic>> locationGroups = {};
    for (var user in allUsers) {
      final double? lat = user['lat'] != null ? (user['lat'] as num).toDouble() : null;
      final double? lng = user['lng'] != null ? (user['lng'] as num).toDouble() : null;
      if (lat == null || lng == null) continue;
      
      final String key = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
      locationGroups.putIfAbsent(key, () => []).add(user);
    }

    for (var group in locationGroups.values) {
      final int count = group.length;
      if (count == 1) {
        final user = group[0];
        final bool isMe = user['is_me'] == true;
        final String name = user['name'] ?? 'Unknown';
        double lat = (user['lat'] as num).toDouble();
        double lng = (user['lng'] as num).toDouble();
        final String? avatarUrl = user['avatar'];
        final DateTime? lastSeen = user['last_seen'] != null ? DateTime.parse(user['last_seen']) : null;

        final String status = isMe ? 'Your current location' : (lastSeen != null ? _formatLastSeen(lastSeen) : 'Never seen');

        final icon = await MarkerUtils.getAvatarMarker(
          url: avatarUrl,
          name: name,
          color: isMe ? Colors.blueAccent : Colors.deepPurple,
          hasStar: isMe,
        );

        newMarkers.add(
          Marker(
            markerId: MarkerId(isMe ? 'me_marker' : 'friend_${user['id']}'),
            position: LatLng(lat, lng),
            icon: icon,
            zIndex: isMe ? 10.0 : 0.0,
            infoWindow: InfoWindow(
              title: isMe ? 'You' : name,
              snippet: status,
            ),
          ),
        );
      } else {
        // We have a cluster!
        // We use the first user's exact coordinates for the whole cluster.
        final firstUser = group[0];
        double lat = (firstUser['lat'] as num).toDouble();
        double lng = (firstUser['lng'] as num).toDouble();
        
        // Check if I am in this group
        bool includesMe = group.any((u) => u['is_me'] == true);
        
        // Generate group marker using Canvas collage
        final List<Map<String, dynamic>> typedGroup = List<Map<String, dynamic>>.from(group);
        final icon = await MarkerUtils.getGroupAvatarMarker(typedGroup);
        
        // Create a summary snippet with status for each friend in the cluster
        List<String> details = [];
        for (var u in group.take(3)) {
          String name = (u['name'] ?? 'Unknown').toString();
          String statusStr = 'Active';
          if (u['last_seen'] != null) {
            try {
              DateTime ls = DateTime.parse(u['last_seen'].toString());
              // Use a more compact version for clusters
              final now = DateTime.now().toUtc();
              final diff = now.difference(ls.toUtc());
              if (diff.inMinutes < 1) statusStr = 'Just now';
              else if (diff.inMinutes < 60) statusStr = '${diff.inMinutes}m ago';
              else if (diff.inHours < 24) statusStr = '${diff.inHours}h ago';
              else statusStr = 'Yesterday';
            } catch (_) {}
          }
          details.add('$name ($statusStr)');
        }
        
        String snippet = details.join(', ');
        if (group.length > 3) snippet += ' and ${group.length - 3} others';

        newMarkers.add(
          Marker(
            markerId: MarkerId('cluster_${lat}_$lng'),
            position: LatLng(lat, lng),
            icon: icon,
            zIndex: includesMe ? 10.0 : 5.0,
            infoWindow: InfoWindow(
              title: '${group.length} friends here',
              snippet: snippet,
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _friendsMarkers = newMarkers;
    });
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(lastSeen.toUtc());
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
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Kaquiz',
                style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w900, fontSize: 22),
              ),
              TextSpan(
                text: ' | Map',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 20),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            myLocationEnabled: false, 
            myLocationButtonEnabled: false, 
            zoomControlsEnabled: false,
            markers: _friendsMarkers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // Floating Action Buttons (Moved up for Nav Bar)
          Positioned(
            bottom: 125, 
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
