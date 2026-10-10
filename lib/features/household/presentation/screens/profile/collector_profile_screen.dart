import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/utils/phone_launcher.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class CollectorProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? collector;

  const CollectorProfileScreen({super.key, this.collector});

  @override
  State<CollectorProfileScreen> createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Sample collector data - would come from API
  late Map<String, dynamic> _collectorData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _collectorData =
        widget.collector ??
        {
          'id': 'COL001',
          'name': 'Maria Santos',
          'profileImage': null,
          'rating': 4.8,
          'totalRatings': 127,
          'totalCollections': 342,
          'yearsActive': 3,
          'phone': '+63 912 345 6789',
          'email': 'maria.santos@email.com',
          'address': 'Barangay San Jose, Quezon City',
          'specialties': ['Plastic', 'Paper', 'Metal', 'Glass'],
          'availability': 'Mon-Sat, 8:00 AM - 6:00 PM',
          'responseTime': '< 30 minutes',
          'completionRate': 98.5,
          'badges': [
            {'name': 'Top Rated', 'icon': '⭐', 'color': AppColors.primaryBlue},
            {
              'name': 'Eco Warrior',
              'icon': '🌱',
              'color': AppColors.primaryGreen,
            },
            {
              'name': 'Fast Response',
              'icon': '⚡',
              'color': AppColors.primaryBlue,
            },
            {
              'name': 'Reliable',
              'icon': '🛡️',
              'color': AppColors.textSecondary,
            },
          ],
          'stats': {
            'thisMonth': {
              'collections': 28,
              'totalValue': 2485.50,
              'avgRating': 4.9,
            },
            'lastMonth': {
              'collections': 31,
              'totalValue': 2756.25,
              'avgRating': 4.7,
            },
          },
          'bio':
              'Experienced waste collector specializing in plastic and metal recycling. Committed to environmental sustainability and providing excellent service to the community.',
        };
  }

  final List<Map<String, dynamic>> _recentReviews = [
    {
      'id': 1,
      'customerName': 'Juan Dela Cruz',
      'rating': 5,
      'comment':
          'Very professional and punctual. Properly sorted all waste materials and provided fair pricing.',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'orderValue': 145.50,
    },
    {
      'id': 2,
      'customerName': 'Ana Reyes',
      'rating': 5,
      'comment':
          'Excellent service! Maria was very thorough in explaining the recycling process.',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'orderValue': 298.75,
    },
    {
      'id': 3,
      'customerName': 'Carlos Mendoza',
      'rating': 4,
      'comment': 'Good service overall. Quick response and fair prices.',
      'date': DateTime.now().subtract(const Duration(days: 8)),
      'orderValue': 187.25,
    },
    {
      'id': 4,
      'customerName': 'Lisa Garcia',
      'rating': 5,
      'comment':
          'Amazing collector! Very knowledgeable about different materials and their values.',
      'date': DateTime.now().subtract(const Duration(days: 12)),
      'orderValue': 234.00,
    },
  ];

  final List<Map<String, dynamic>> _recentCollections = [
    {
      'id': '#WC2024020',
      'date': DateTime.now().subtract(const Duration(hours: 6)),
      'items': ['Plastic Bottles', 'Aluminum Cans'],
      'value': 125.50,
      'customer': 'John Smith',
      'status': 'completed',
    },
    {
      'id': '#WC2024019',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'items': ['Cardboard', 'Paper'],
      'value': 89.25,
      'customer': 'Jane Doe',
      'status': 'completed',
    },
    {
      'id': '#WC2024018',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'items': ['Glass Bottles', 'Metal Scraps'],
      'value': 156.75,
      'customer': 'Mike Johnson',
      'status': 'completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header with Profile
          _buildProfileHeader(),

          // Tab Bar
          _buildTabBar(),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildReviewsTab(),
                _buildActivityTab(),
              ],
            ),
          ),
        ],
      ),
      // Bottom Action Bar
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
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
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            children: [
              // Header Row
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios),
                    color: AppColors.textWhite,
                  ),
                  const Spacer(),
                  Text(
                    'Collector Profile',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _shareProfile(),
                    icon: const Icon(Icons.share),
                    color: AppColors.textWhite,
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Profile Info
              Row(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: _collectorData['profileImage'] != null
                        ? ClipOval(
                            child: Image.network(
                              _collectorData['profileImage'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            _collectorData['name'][0],
                            style: AppTextStyles.h4.copyWith(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),

                  const SizedBox(width: AppDimensions.spacing16),

                  // Profile Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _collectorData['name'],
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Rating
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _collectorData['rating'].toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              ' (${_collectorData['totalRatings']} reviews)',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Experience
                        Text(
                          '${_collectorData['yearsActive']} years experience • ${_collectorData['totalCollections']} collections',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing20),

              // Badges
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      (_collectorData['badges'] as List<Map<String, dynamic>>)
                          .map(
                            (badge) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    badge['icon'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    badge['name'],
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textWhite,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing16),
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
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Reviews'),
          Tab(text: 'Activity'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          _buildStatsGrid(),

          const SizedBox(height: AppDimensions.spacing24),

          // Bio Section
          _buildBioSection(),

          const SizedBox(height: AppDimensions.spacing24),

          // Specialties
          _buildSpecialtiesSection(),

          const SizedBox(height: AppDimensions.spacing24),

          // Contact Info
          _buildContactInfoSection(),

          const SizedBox(height: AppDimensions.spacing24),

          // Availability
          _buildAvailabilitySection(),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Summary
          _buildRatingSummary(),

          const SizedBox(height: AppDimensions.spacing24),

          // Reviews List
          Text(
            'Recent Reviews',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          ..._recentReviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Summary
          _buildActivitySummary(),

          const SizedBox(height: AppDimensions.spacing24),

          // Recent Collections
          Text(
            'Recent Collections',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          ..._recentCollections.map(
            (collection) => _buildCollectionCard(collection),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _collectorData['stats']['thisMonth'];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppDimensions.spacing12,
      crossAxisSpacing: AppDimensions.spacing12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Collections',
          '${stats['collections']}',
          'This Month',
          Icons.recycling,
          AppColors.primaryGreen,
        ),
        _buildStatCard(
          'Total Value',
          '₱${stats['totalValue'].toStringAsFixed(0)}',
          'This Month',
          Icons.monetization_on,
          AppColors.primaryBlue,
        ),
        _buildStatCard(
          'Completion Rate',
          '${_collectorData['completionRate']}%',
          'Overall',
          Icons.check_circle,
          AppColors.primaryGreen,
        ),
        _buildStatCard(
          'Response Time',
          _collectorData['responseTime'],
          'Average',
          Icons.access_time,
          AppColors.primaryBlue,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            value,
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            _collectorData['bio'],
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specializes In',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_collectorData['specialties'] as List<String>)
                .map(
                  (specialty) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      specialty,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildContactRow(
            Icons.phone,
            'Phone',
            _collectorData['phone'],
            () => _callCollector(),
          ),

          _buildContactRow(
            Icons.email,
            'Email',
            _collectorData['email'],
            () => _emailCollector(),
          ),

          _buildContactRow(
            Icons.location_on,
            'Location',
            _collectorData['address'],
            () => _openLocation(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 20),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing12),

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Currently Available',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing8),

          Text(_collectorData['availability'], style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Overall Rating
          Column(
            children: [
              Text(
                _collectorData['rating'].toString(),
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 16,
                    color: index < _collectorData['rating'].floor()
                        ? Colors.amber
                        : AppColors.borderLight,
                  );
                }),
              ),
              Text(
                '${_collectorData['totalRatings']} reviews',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(width: AppDimensions.spacing24),

          // Rating Breakdown (mock data)
          Expanded(
            child: Column(
              children: [
                _buildRatingBar('5', 0.7, 89),
                _buildRatingBar('4', 0.2, 25),
                _buildRatingBar('3', 0.05, 7),
                _buildRatingBar('2', 0.03, 4),
                _buildRatingBar('1', 0.02, 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String rating, double percentage, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(rating, style: AppTextStyles.bodySmall),
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.backgroundDark,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                child: Text(
                  review['customerName'][0],
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['customerName'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            size: 12,
                            color: index < review['rating']
                                ? Colors.amber
                                : AppColors.borderLight,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          _getTimeAgo(review['date']),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '₱${review['orderValue'].toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            review['comment'],
            style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySummary() {
    final thisMonth = _collectorData['stats']['thisMonth'];
    final lastMonth = _collectorData['stats']['lastMonth'];

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Performance',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Row(
            children: [
              Expanded(child: _buildMonthStat('This Month', thisMonth)),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(child: _buildMonthStat('Last Month', lastMonth)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStat(String title, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Text(
          '${stats['collections']} collections',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '₱${stats['totalValue'].toStringAsFixed(0)}',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryGreen,
          ),
        ),
        Row(
          children: [
            const Icon(Icons.star, size: 12, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              stats['avgRating'].toString(),
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                collection['id'],
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Completed',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),

          Text(
            'Customer: ${collection['customer']}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing4),

          Wrap(
            spacing: 4,
            children: (collection['items'] as List<String>)
                .map(
                  (item) => Text(
                    item,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: AppDimensions.spacing8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getTimeAgo(collection['date']),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '₱${collection['value'].toStringAsFixed(2)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              onPressed: () => _callCollector(),
              text: 'Call',
              backgroundColor: AppColors.primaryBlue,
              textColor: Colors.white,
              icon: const Icon(Icons.phone, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: CustomButton(
              onPressed: () => _bookCollector(),
              text: 'Book Now',
              backgroundColor: AppColors.primaryGreen,
              textColor: Colors.white,
              icon: const Icon(Icons.schedule, color: Colors.white),
            ),
          ),
        ],
      ),
    );
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

  void _shareProfile() {
    // Implement share functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Profile'),
        content: const Text('Share this collector\'s profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement actual sharing
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _callCollector() async {
    final phoneNumber = _collectorData['phone'] as String?;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
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

  void _emailCollector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Collector'),
        content: Text('Open email to ${_collectorData['email']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement email functionality
            },
            child: const Text('Open Email'),
          ),
        ],
      ),
    );
  }

  void _openLocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Location'),
        content: const Text('Open location in maps?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement maps functionality
            },
            child: const Text('Open Maps'),
          ),
        ],
      ),
    );
  }

  void _bookCollector() {
    Navigator.pushNamed(
      context,
      '/household/post-waste',
      arguments: {'selectedCollector': _collectorData},
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
