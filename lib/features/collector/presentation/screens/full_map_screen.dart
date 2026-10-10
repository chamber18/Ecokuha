import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/status_action_bar.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class FullMapScreen extends StatefulWidget {
  final String address;
  final double? householdLatitude;
  final double? householdLongitude;
  final String householdName;
  final String? currentStatus;
  final Function(String)? onUpdateStatus;
  final Function(String)? onGoBack;

  const FullMapScreen({
    super.key,
    required this.address,
    this.householdLatitude,
    this.householdLongitude,
    this.householdName = 'Household Location',
    this.currentStatus,
    this.onUpdateStatus,
    this.onGoBack,
  });

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  GoogleMapController? _controller;
  Position? _collectorPosition;
  bool _isLoadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingLocation = true;
          _locationError = null;
        });
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationError = 'Location services are disabled';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationError = 'Location permission denied';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permission permanently denied';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _collectorPosition = position;
          _isLoadingLocation = false;
        });
      }

      if (mounted &&
          widget.householdLatitude != null &&
          widget.householdLongitude != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _controller != null) {
            _fitBothMarkers();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to get location: ${e.toString()}';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _fitBothMarkers() {
    if (_controller == null ||
        widget.householdLatitude == null ||
        widget.householdLongitude == null ||
        _collectorPosition == null) {
      return;
    }

    final householdLat = widget.householdLatitude!;
    final householdLng = widget.householdLongitude!;
    final collectorLat = _collectorPosition!.latitude;
    final collectorLng = _collectorPosition!.longitude;

    final double minLat = householdLat < collectorLat
        ? householdLat
        : collectorLat;
    final double maxLat = householdLat > collectorLat
        ? householdLat
        : collectorLat;
    final double minLng = householdLng < collectorLng
        ? householdLng
        : collectorLng;
    final double maxLng = householdLng > collectorLng
        ? householdLng
        : collectorLng;

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;

    double latPadding = latDiff * 0.10;
    double lngPadding = lngDiff * 0.10;

    latPadding = latPadding.clamp(0.0008, 0.005);
    lngPadding = lngPadding.clamp(0.0008, 0.005);

    try {
      _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - latPadding, minLng - lngPadding),
            northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
          ),
          80,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('[FullMap] Error fitting bounds: $e');
    }
  }

  void _centerOnCollector() {
    if (_controller != null && _collectorPosition != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _collectorPosition!.latitude,
              _collectorPosition!.longitude,
            ),
            zoom: 16,
          ),
        ),
      );
    }
  }

  void _centerOnHousehold() {
    if (_controller != null &&
        widget.householdLatitude != null &&
        widget.householdLongitude != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.householdLatitude!,
              widget.householdLongitude!,
            ),
            zoom: 16,
          ),
        ),
      );
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.householdLatitude != null && widget.householdLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('household'),
          position: LatLng(
            widget.householdLatitude!,
            widget.householdLongitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.householdName,
            snippet: widget.address,
          ),
        ),
      );
    }

    if (_collectorPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('collector'),
          position: LatLng(
            _collectorPosition!.latitude,
            _collectorPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final hasHouseholdCoords =
        widget.householdLatitude != null && widget.householdLongitude != null;
    final hasCollectorCoords = _collectorPosition != null;
    final hasAnyCoords = hasHouseholdCoords || hasCollectorCoords;

    late double lat;
    late double lng;

    if (hasHouseholdCoords) {
      lat = widget.householdLatitude!;
      lng = widget.householdLongitude!;
    } else if (hasCollectorCoords) {
      lat = _collectorPosition!.latitude;
      lng = _collectorPosition!.longitude;
    } else {
      lat = 12.8797;
      lng = 121.7740;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          if (hasAnyCoords)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 15,
              ),
              markers: _buildMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              onMapCreated: (controller) {
                _controller = controller;
                if (hasHouseholdCoords && hasCollectorCoords) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _fitBothMarkers();
                    }
                  });
                }
              },
            )
          else
            Container(
              color: const Color(0xFFDBEAFE),
              child: const Center(child: Text('Map not available')),
            ),

          // Top bar with back button and title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Route to Pickup',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (widget.address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Control buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Fit both markers button
                if (hasHouseholdCoords && hasCollectorCoords)
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: InkWell(
                      onTap: _fitBothMarkers,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        child: const Icon(
                          Icons.fit_screen,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Center on household
                if (hasHouseholdCoords)
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: InkWell(
                      onTap: _centerOnHousehold,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        child: const Icon(
                          Icons.home,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Refresh location / Center on collector
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: hasCollectorCoords
                        ? _centerOnCollector
                        : _getCurrentLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: _isLoadingLocation
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.primaryGreen,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.local_shipping,
                              color: AppColors.primaryGreen,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status action button at bottom
          if (widget.currentStatus != null && widget.onUpdateStatus != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: StatusActionBar(
                status: widget.currentStatus!,
                onUpdateStatus: (status) {
                  if (widget.onUpdateStatus != null) {
                    widget.onUpdateStatus!(status);
                  }
                },
                onGoBack: widget.onGoBack != null
                    ? (prevStatus) {
                        if (widget.onGoBack != null) {
                          widget.onGoBack!(prevStatus);
                        }
                      }
                    : null,
              ),
            ),

          // Error message
          if (_locationError != null)
            Positioned(
              bottom: _locationError != null && widget.currentStatus != null
                  ? 90
                  : 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
