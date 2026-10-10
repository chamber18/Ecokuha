import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedView = 'list';
  bool _isOptimizing = false;
  bool _locationDenied = false;

  // Average urban travel speed (km/h) used for ETA heuristic.
  static const double _avgSpeedKmh = 25.0;

  final List<RouteStop> _todayRoutes = [
    RouteStop(
      id: '1',
      customerName: 'Maria Santos',
      address: '123 Taft Avenue, Malate, Manila',
      timeSlot: '8:00 - 9:00 AM',
      status: 'pending',
      wasteTypes: ['Plastic', 'Paper'],
      estimatedValue: 150,
      priority: 'high',
      // Approximate coordinates (Manila)
      latitude: 14.5698,
      longitude: 120.9942,
      estWeightKg: 5.2,
    ),
    RouteStop(
      id: '2',
      customerName: 'John Cruz',
      address: '456 Pedro Gil St, Ermita, Manila',
      timeSlot: '9:30 - 10:30 AM',
      status: 'in_progress',
      wasteTypes: ['Metal', 'Plastic'],
      estimatedValue: 320,
      priority: 'medium',
      latitude: 14.5793,
      longitude: 120.9839,
      estWeightKg: 8.7,
    ),
    RouteStop(
      id: '3',
      customerName: 'Ana Reyes',
      address: '789 Roxas Blvd, Malate, Manila',
      timeSlot: '11:00 - 12:00 PM',
      status: 'completed',
      wasteTypes: ['Paper', 'Cardboard'],
      estimatedValue: 200,
      priority: 'low',
      latitude: 14.5722,
      longitude: 120.9830,
      estWeightKg: 4.1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _resolveLocationAndComputeMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Routes',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: 'Refresh location metrics',
            onPressed: _resolveLocationAndComputeMetrics,
            icon: const Icon(Icons.my_location, color: Colors.black87),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            onSelected: (_) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('Today')),
              const PopupMenuItem(value: 'tomorrow', child: Text('Tomorrow')),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'all', child: Text('All Routes')),
            ],
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedView = _selectedView == 'list' ? 'map' : 'list';
              });
            },
            icon: Icon(
              _selectedView == 'list' ? Icons.map : Icons.list,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildRouteHeader(),
          _buildTabBar(),
          Expanded(
            child: _selectedView == 'list'
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTodayTab(),
                      _buildUpcomingTab(),
                      _buildCompletedTab(),
                    ],
                  )
                : _buildMapView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'collector_optimize_route',
        onPressed: _optimizeRoute,
        backgroundColor: Colors.green[700],
        icon: _isOptimizing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.route),
        label: Text(_isOptimizing ? 'Optimizing...' : 'Optimize Route'),
      ),
    );
  }

  Widget _buildRouteHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today\'s Stops',
                  '8',
                  Icons.location_on,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Distance',
                  '24.3 km',
                  Icons.directions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Est. Time',
                  '6h 30m',
                  Icons.schedule,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Route optimized for efficiency - Save 45 minutes',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.green[700],
        labelColor: Colors.green[700],
        unselectedLabelColor: Colors.grey[600],
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'Upcoming'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRouteProgress(),
        const SizedBox(height: 16),
        const Text(
          'Route Stops',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._todayRoutes.map((route) => _buildRouteStopCard(route)),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildUpcomingRoutesCard(),
        const SizedBox(height: 16),
        const Text(
          'Scheduled Routes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildScheduledRouteCard('Tomorrow', '10 stops', '28.7 km'),
        _buildScheduledRouteCard('Wednesday', '12 stops', '31.2 km'),
        _buildScheduledRouteCard('Thursday', '8 stops', '22.1 km'),
      ],
    );
  }

  Widget _buildCompletedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCompletedStats(),
        const SizedBox(height: 16),
        const Text(
          'Recent Completions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCompletedRouteCard('Yesterday', '9 stops', '26.4 km', '₱2,180'),
        _buildCompletedRouteCard('Dec 15', '11 stops', '32.1 km', '₱2,850'),
        _buildCompletedRouteCard('Dec 14', '7 stops', '19.8 km', '₱1,920'),
      ],
    );
  }

  Widget _buildMapView() {
    return Container(
      color: Colors.grey[200],
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Map View',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Interactive route map with GPS navigation',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Stop',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Maria Santos - 123 Taft Avenue',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '2.1 km away',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Start navigation
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                          ),
                          child: const Text('Navigate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteProgress() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Route Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '3 of 8 stops',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: 3 / 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProgressItem('Completed', '3', Colors.green),
                _buildProgressItem('In Progress', '1', Colors.orange),
                _buildProgressItem('Pending', '4', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, String count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildRouteStopCard(RouteStop route) {
    Color statusColor;
    IconData statusIcon;
    switch (route.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.radio_button_unchecked;
    }

    Color priorityColor;
    switch (route.priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to task details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                route.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                route.priority.toUpperCase(),
                                style: TextStyle(
                                  color: priorityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          route.timeSlot,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route.address,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.recycling, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route.wasteTypes.join(', '),
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Metrics row (Distance • ETA • Weight)
              Row(
                children: [
                  Icon(
                    Icons.directions_walk,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatMetrics(route),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₱${route.estimatedValue}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (route.status != 'completed') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Start navigation
                        },
                        icon: const Icon(Icons.navigation, size: 16),
                        label: const Text('Navigate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Mark as completed or start collection
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(
                          route.status == 'in_progress' ? 'Complete' : 'Start',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingRoutesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming Routes Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem('Routes', '30', Icons.route),
                ),
                Expanded(
                  child: _buildOverviewItem('Stops', '287', Icons.location_on),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    'Distance',
                    '724 km',
                    Icons.directions,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildScheduledRouteCard(String date, String stops, String distance) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.calendar_today, color: Colors.blue),
        ),
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$stops • $distance'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // View route details
        },
      ),
    );
  }

  Widget _buildCompletedStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week\'s Completion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildCompletionStat('Routes', '27', '30')),
                Expanded(child: _buildCompletionStat('Stops', '265', '287')),
                Expanded(child: _buildCompletionStat('Distance', '689', '724')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionStat(String label, String completed, String total) {
    double percentage = double.parse(completed) / double.parse(total);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                strokeWidth: 6,
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$completed/$total',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildCompletedRouteCard(
    String date,
    String stops,
    String distance,
    String earnings,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$stops • $distance',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Text(
              earnings,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _optimizeRoute() {
    setState(() {
      _isOptimizing = true;
    });
    final messenger = ScaffoldMessenger.of(context);

    // Simulate route optimization
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isOptimizing = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Route optimized successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  // -------- Location + Metrics Logic --------
  Future<void> _resolveLocationAndComputeMetrics() async {
    try {
      if (!mounted) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }

      if (!mounted) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      debugPrint(
        '🎯 ROUTES: Current position: ${pos.latitude}, ${pos.longitude}',
      );

      for (final stop in _todayRoutes) {
        if (stop.latitude == null || stop.longitude == null) {
          debugPrint('⚠️ ROUTES: Stop ${stop.id} missing coordinates');
          continue;
        }
        final distKm = _haversineKm(
          pos.latitude,
          pos.longitude,
          stop.latitude!,
          stop.longitude!,
        );
        stop.distanceKm = double.parse(distKm.toStringAsFixed(2));
        stop.etaMinutes = _estimateEtaMinutes(distKm);

        debugPrint('✅ ROUTES: Stop ${stop.id}:');
        debugPrint('   - Address: ${stop.address}');
        debugPrint('   - Distance: ${stop.distanceKm} km');
        debugPrint('   - ETA: ${stop.etaMinutes} min');
        debugPrint('   - Weight: ${stop.estWeightKg} kg');
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ ROUTES ERROR: $e');
      // Silent failure; keep placeholders
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  int _estimateEtaMinutes(double distanceKm) {
    var speed = _avgSpeedKmh <= 0 ? 25.0 : _avgSpeedKmh;
    final hours = distanceKm / speed;
    final minutes = (hours * 60).clamp(1, 24 * 60);
    return minutes.round();
  }

  String _formatMetrics(RouteStop stop) {
    if (_locationDenied) {
      return 'Location unavailable';
    }
    String distancePart;
    if (stop.distanceKm != null) {
      distancePart = '${stop.distanceKm!.toStringAsFixed(2)} km';
    } else if (stop.distance != null) {
      distancePart = stop.distance!; // legacy/fallback string
    } else {
      distancePart = '- km';
    }

    String etaPart = '-';
    if (stop.etaMinutes != null) {
      final m = stop.etaMinutes!;
      if (m < 60) {
        etaPart = '${m}m';
      } else {
        final h = (m / 60).floor();
        final rem = m % 60;
        etaPart = rem > 0 ? '${h}h ${rem}m' : '${h}h';
      }
    }

    String weightPart = '-';
    if (stop.estWeightKg != null) {
      weightPart = '${stop.estWeightKg!.toStringAsFixed(1)} kg';
    }
    return '$distancePart • ETA $etaPart • $weightPart';
  }
}

class RouteStop {
  final String id;
  final String customerName;
  final String address;
  final String timeSlot;
  final String status;
  final List<String> wasteTypes;
  final int estimatedValue;
  final String priority;
  final double? latitude;
  final double? longitude;
  final String? distance; // legacy static sample distance string
  double? distanceKm; // computed
  int? etaMinutes; // computed
  final double? estWeightKg; // estimated weight (sample or computed)

  RouteStop({
    required this.id,
    required this.customerName,
    required this.address,
    required this.timeSlot,
    required this.status,
    required this.wasteTypes,
    required this.estimatedValue,
    required this.priority,
    this.latitude,
    this.longitude,
    this.distance,
    this.estWeightKg,
  });
}
