import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/supabase/supabase_helpers.dart';
import 'dart:async';

class LiveTrackingScreen extends StatefulWidget {
  final String postingId;
  final String collectorName;

  const LiveTrackingScreen({
    required this.postingId,
    this.collectorName = 'Collector',
    super.key,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  GoogleMapController? _mapController;
  Timer? _updateTimer;

  @override
  void dispose() {
    _mapController?.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Track Collector',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db
            .from('active_collections')
            .stream(primaryKey: ['posting_id'])
            .eq('posting_id', widget.postingId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_searching,
                    size: 64,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Waiting for collector to start',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The collector hasn\'t started the route yet',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          final data = rowToDoc('active_collections', snapshot.data!.first);
          final currentLoc = data['currentLocation'] is Map
              ? Map<String, dynamic>.from(data['currentLocation'] as Map)
              : null;
          final destination = Map<String, dynamic>.from(
            data['destination'] as Map,
          );
          final status = data['status'] as String;
          final eta = data['estimatedArrival'] as Timestamp?;
          final distance = (data['distanceRemaining'] as num?)?.toDouble();
          final collectorName =
              data['collectorName'] as String? ?? widget.collectorName;

          if (currentLoc == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final collectorPos = LatLng(
            (currentLoc['lat'] as num).toDouble(),
            (currentLoc['lng'] as num).toDouble(),
          );
          final destinationPos = LatLng(
            (destination['lat'] as num).toDouble(),
            (destination['lng'] as num).toDouble(),
          );

          // Update camera position when location changes
          _updateTimer?.cancel();
          _updateTimer = Timer(const Duration(milliseconds: 500), () {
            _fitBounds(collectorPos, destinationPos);
          });

          return Stack(
            children: [
              // Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: collectorPos,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitBounds(collectorPos, destinationPos);
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('collector'),
                    position: collectorPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: InfoWindow(
                      title: collectorName,
                      snippet: _getStatusLabel(status),
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: destinationPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    infoWindow: const InfoWindow(title: 'Your Location'),
                  ),
                },
                polylines:
                    {}, // Route will be drawn by Google Maps based on actual collector movement
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),

              // Status Card
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _buildStatusCard(
                  collectorName,
                  status,
                  eta,
                  distance,
                  currentLoc['accuracy'] as double?,
                ),
              ),

              // Recenter button
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => _fitBounds(collectorPos, destinationPos),
                  child: const Icon(
                    Icons.my_location,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(
    String collectorName,
    String status,
    Timestamp? eta,
    double? distance,
    double? accuracy,
  ) {
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collectorName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusLabel(status),
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (eta != null && distance != null && status == 'en_route') ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time,
                      'ETA',
                      _formatETA(eta),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.straighten,
                      'Distance',
                      '${distance.toStringAsFixed(1)} km',
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'arrived') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Collector has arrived at your location',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (accuracy != null && accuracy > 50) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.signal_cellular_alt,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Low GPS accuracy (±${accuracy.round()}m)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'en_route':
        return 'On the way';
      case 'arrived':
        return 'Arrived';
      case 'collecting':
        return 'Collecting items';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'en_route':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      case 'collecting':
        return Icons.inventory_2;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'en_route':
        return const Color(0xFF3B82F6); // Blue
      case 'arrived':
        return AppColors.primaryGreen; // Green
      case 'collecting':
        return const Color(0xFFF59E0B); // Amber
      case 'completed':
        return const Color(0xFF10B981); // Success green
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  String _formatETA(Timestamp eta) {
    final now = DateTime.now();
    final arrival = eta.toDate();
    final diff = arrival.difference(now);

    if (diff.inMinutes < 1) return 'Arriving now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  void _fitBounds(LatLng pos1, LatLng pos2) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        pos1.latitude < pos2.latitude ? pos1.latitude : pos2.latitude,
        pos1.longitude < pos2.longitude ? pos1.longitude : pos2.longitude,
      ),
      northeast: LatLng(
        pos1.latitude > pos2.latitude ? pos1.latitude : pos2.latitude,
        pos1.longitude > pos2.longitude ? pos1.longitude : pos2.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }
}
