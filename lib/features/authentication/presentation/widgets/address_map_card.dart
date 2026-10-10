import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/common/common_widgets.dart';

class AddressMapCard extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final VoidCallback onChangeLocation;
  final VoidCallback? onUseCurrentLocation;
  final bool isLoading;

  const AddressMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.controller,
    this.validator,
    required this.onChangeLocation,
    this.onUseCurrentLocation,
    this.isLoading = false,
  });

  @override
  State<AddressMapCard> createState() => _AddressMapCardState();
}

class _AddressMapCardState extends State<AddressMapCard> {
  GoogleMapController? _mapController;
  double? _lastLat;
  double? _lastLng;
  bool _isMapReady = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Default to Philippines coordinates if none provided
    final defaultLat = 12.8797;
    final defaultLng = 121.7740;

    final lat = widget.latitude ?? defaultLat;
    final lng = widget.longitude ?? defaultLng;
    final pos = LatLng(lat, lng);

    // Debug: Print coordinates being used
    debugPrint('📍 AddressMapCard build:');
    debugPrint('  Received latitude: ${widget.latitude}');
    debugPrint('  Received longitude: ${widget.longitude}');
    debugPrint(
      '  Using lat: $lat, lng: $lng (default if null: $defaultLat, $defaultLng)',
    );
    debugPrint('  Position: ${pos.latitude}, ${pos.longitude}');

    // Check if coordinates have changed
    final coordsChanged = _lastLat != lat || _lastLng != lng;
    if (coordsChanged && _mapController != null) {
      // Update camera position when coordinates change
      _lastLat = lat;
      _lastLng = lng;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _mapController != null) {
          _mapController!
              .animateCamera(CameraUpdate.newLatLngZoom(pos, 16))
              .catchError((_) {});
        }
      });
    }

    return CustomCard(
      padding: const EdgeInsets.all(AppDimensions.paddingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map preview container
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius - 6),
            child: SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Google Map preview - with better initialization
                  GoogleMap(
                    key: ValueKey(
                      '${lat}_$lng',
                    ), // Force rebuild on coordinate change
                    initialCameraPosition: CameraPosition(
                      target: pos,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: pos,
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    liteModeEnabled: false,
                    mapType: MapType.normal,
                    buildingsEnabled: true,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    trafficEnabled: false,
                    onMapCreated: (controller) async {
                      _mapController = controller;
                      _lastLat = lat;
                      _lastLng = lng;

                      // Delay to ensure map is ready
                      await Future.delayed(const Duration(milliseconds: 200));

                      if (mounted) {
                        try {
                          // Wait a bit more for tiles to load
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );

                          // Move camera to position
                          await controller.animateCamera(
                            CameraUpdate.newLatLngZoom(pos, 15),
                          );

                          // Mark as ready
                          if (mounted) {
                            setState(() {
                              _isMapReady = true;
                            });
                          }
                        } catch (e) {
                          debugPrint('Map preview initialization error: $e');
                          // Still mark as ready to hide loading indicator
                          if (mounted) {
                            setState(() {
                              _isMapReady = true;
                            });
                          }
                        }
                      }
                    },
                  ),

                  // Loading overlay
                  if (!_isMapReady)
                    Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading map preview...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Tappable overlay to open full-screen picker
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onChangeLocation,
                      child: Container(
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.edit_location,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Change Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Loading overlay for map only (NOT the whole card)
                  if (widget.isLoading)
                    Container(
                      color: Colors.black45,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Getting your location...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacing12),

          // Editable complete address inside the card
          CustomTextField(
            controller: widget.controller,
            label: 'Complete Address *',
            hint:
                'Blk 15 Lot 8, Angelia Homes Subd, Visayan Village, Tagum City, Davao del Norte, 8100, Davao (Region XI), Philippines',
            // Remove stroke and address icon as requested
            borderColor: Colors.transparent,
            focusedBorderColor: Colors.transparent,
            minLines: 2,
            maxLines: 5,
            validator: widget.validator,
          ),

          const SizedBox(height: AppDimensions.spacing8),
        ],
      ),
    );
  }
}
