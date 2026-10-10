import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/utils/phone_launcher.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  final List<Map<String, dynamic>> _activeOrders = [
    {
      'id': '#WC2024001',
      'status': 'in_progress',
      'statusLabel': 'Collection in Progress',
      'items': ['Plastic Bottles', 'Cardboard', 'Aluminum Cans'],
      'collectorName': 'Maria Santos',
      'collectorPhone': '+63 912 345 6789',
      'estimatedValue': 145.50,
      'scheduledDate': DateTime.now(),
      'address': '123 Main St, Barangay San Jose',
      'progress': 0.75,
      'timeline': [
        {'status': 'Request Submitted', 'time': '09:15 AM', 'completed': true},
        {'status': 'Collector Assigned', 'time': '09:30 AM', 'completed': true},
        {'status': 'On the Way', 'time': '10:00 AM', 'completed': true},
        {
          'status': 'Collection Completed',
          'time': 'Expected: 11:00 AM',
          'completed': false,
        },
      ],
    },
    {
      'id': '#WC2024002',
      'status': 'scheduled',
      'statusLabel': 'Scheduled for Today',
      'items': ['Glass Bottles', 'Newspaper'],
      'collectorName': 'Juan Dela Cruz',
      'collectorPhone': '+63 908 123 4567',
      'estimatedValue': 89.25,
      'scheduledDate': DateTime.now().add(const Duration(hours: 3)),
      'address': '456 Oak Ave, Barangay Centro',
      'progress': 0.25,
      'timeline': [
        {'status': 'Request Submitted', 'time': '08:45 AM', 'completed': true},
        {
          'status': 'Collector Assigned',
          'time': 'Expected: 12:00 PM',
          'completed': false,
        },
        {
          'status': 'On the Way',
          'time': 'Expected: 12:30 PM',
          'completed': false,
        },
        {
          'status': 'Collection Completed',
          'time': 'Expected: 1:00 PM',
          'completed': false,
        },
      ],
    },
  ];

  final List<Map<String, dynamic>> _completedOrders = [
    {
      'id': '#WC2024003',
      'status': 'completed',
      'statusLabel': 'Completed',
      'items': ['Metal Scraps', 'Plastic Containers'],
      'collectorName': 'Ana Reyes',
      'finalValue': 125.75,
      'completedDate': DateTime.now().subtract(const Duration(days: 1)),
      'address': '789 Pine St, Barangay East',
      'rating': 5,
    },
    {
      'id': '#WC2024004',
      'status': 'completed',
      'statusLabel': 'Completed',
      'items': ['Paper', 'Cardboard Boxes', 'Plastic Bags'],
      'collectorName': 'Carlos Mendoza',
      'finalValue': 198.50,
      'completedDate': DateTime.now().subtract(const Duration(days: 3)),
      'address': '321 Elm Rd, Barangay West',
      'rating': 4,
    },
    {
      'id': '#WC2024005',
      'status': 'completed',
      'statusLabel': 'Completed',
      'items': ['Aluminum Cans', 'Glass Jars'],
      'collectorName': 'Lisa Garcia',
      'finalValue': 76.25,
      'completedDate': DateTime.now().subtract(const Duration(days: 5)),
      'address': '654 Maple Ave, Barangay North',
      'rating': 5,
    },
  ];

  List<Map<String, dynamic>> get _filteredActiveOrders {
    if (_searchQuery.isEmpty) return _activeOrders;
    return _activeOrders.where((order) {
      return order['id'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order['collectorName'].toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          order['items'].any(
            (item) => item.toLowerCase().contains(_searchQuery.toLowerCase()),
          );
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCompletedOrders {
    if (_searchQuery.isEmpty) return _completedOrders;
    return _completedOrders.where((order) {
      return order['id'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order['collectorName'].toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          order['items'].any(
            (item) => item.toLowerCase().contains(_searchQuery.toLowerCase()),
          );
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.primaryBlue;
      case 'scheduled':
        return AppColors.primaryGreen;
      case 'completed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.local_shipping;
      case 'scheduled':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Search Bar
          _buildSearchBar(),

          // Tab Bar
          _buildTabBar(),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildActiveOrdersTab(), _buildCompletedOrdersTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios),
              color: AppColors.textWhite,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Track My Waste',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor your collection requests',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // Show filters or options
              },
              icon: const Icon(Icons.filter_list),
              color: AppColors.textWhite,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search orders, collectors, or items...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          color: AppColors.primaryGreen,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text('Active (${_filteredActiveOrders.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 8),
                Text('Completed (${_filteredCompletedOrders.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    if (_filteredActiveOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule,
        title: _searchQuery.isEmpty ? 'No Active Orders' : 'No Orders Found',
        message: _searchQuery.isEmpty
            ? 'You don\'t have any active collection requests'
            : 'No active orders match your search',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      itemCount: _filteredActiveOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredActiveOrders[index];
        return _buildActiveOrderCard(order);
      },
    );
  }

  Widget _buildCompletedOrdersTab() {
    if (_filteredCompletedOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: _searchQuery.isEmpty ? 'No Completed Orders' : 'No Orders Found',
        message: _searchQuery.isEmpty
            ? 'Your completed orders will appear here'
            : 'No completed orders match your search',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      itemCount: _filteredCompletedOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredCompletedOrders[index];
        return _buildCompletedOrderCard(order);
      },
    );
  }

  Widget _buildActiveOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _getStatusColor(order['status']).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _viewOrderDetails(order),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['id'],
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(order['status']),
                          size: 12,
                          color: _getStatusColor(order['status']),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order['statusLabel'],
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getStatusColor(order['status']),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing12),

              // Progress Bar
              if (order['progress'] != null) ...[
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(order['progress'] * 100).toInt()}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(order['status']),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing8),
                LinearProgressIndicator(
                  value: order['progress'],
                  backgroundColor: AppColors.backgroundDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(order['status']),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
              ],

              // Items
              Text(
                'Items',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: order['items'].map<Widget>((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Collector Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                    child: Text(
                      order['collectorName'][0],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['collectorName'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Collector',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _callCollector(order['collectorPhone']),
                    icon: const Icon(
                      Icons.phone,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Value',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₱${order['estimatedValue'].toStringAsFixed(2)}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  CustomButton(
                    onPressed: () => _viewOrderDetails(order),
                    text: 'Track Details',
                    backgroundColor: AppColors.primaryGreen,
                    textColor: Colors.white,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _viewOrderDetails(order),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['id'],
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing12),

              // Items
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: order['items'].map<Widget>((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.spacing12),

              // Collector and Rating
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.textSecondary.withValues(alpha: 0.2),
                    child: Text(
                      order['collectorName'][0],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      order['collectorName'],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ...List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 12,
                      color: index < order['rating']
                          ? AppColors.primaryBlue
                          : AppColors.borderLight,
                    );
                  }),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing12),

              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final Value',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '₱${order['finalValue'].toStringAsFixed(2)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _getTimeAgo(order['completedDate']),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              title,
              style: AppTextStyles.h6.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _viewOrderDetails(Map<String, dynamic> order) {
    // Navigate to track details screen
    Navigator.pushNamed(context, '/household/track-details', arguments: order);
  }

  void _callCollector(String phoneNumber) async {
    if (phoneNumber.isNotEmpty) {
      try {
        await PhoneLauncher.makePhoneCall(phoneNumber);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to make phone call: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
