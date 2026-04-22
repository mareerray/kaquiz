import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

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

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(50.4501, 30.5234), // Kyiv as default fallback
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      setState(() {
        _currentPosition = location;
        _isMapLoading = false;
      });
      _goToCurrentPosition();
      
      // Send initial location to backend
      _apiService.updateUserLocation(location.latitude, location.longitude);
    } else {
      setState(() => _isMapLoading = false);
    }
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
                const SizedBox(height: 12),
                _buildMapActionButton(
                  icon: Icons.people,
                  onPressed: () {
                     // Nav to friends list
                  },
                  heroTag: 'friends_list',
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Search friends...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),
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
