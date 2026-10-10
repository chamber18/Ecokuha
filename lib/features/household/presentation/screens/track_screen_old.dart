import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  String _selectedFilter = 'En Route';

  final List<CollectionItem> _collections = [
    CollectionItem(
      id: 'ECO-A1B2C3',
      title: 'Plastic Bottles & Containers',
      junkshop: 'GreenEarth Junkshop',
      value: 125.50,
      status: 'En Route',
      collectorName: 'Juan Carlos',
      collectorPhoto: '🧑',
      estimatedTime: '15 mins',
      items: ['5x Plastic Bottles', '2x Food Containers'],
    ),
    CollectionItem(
      id: 'ECO-D4E5F6',
      title: 'Mixed Paper & Cardboard',
      junkshop: 'RecycleHub Station',
      value: 89.20,
      status: 'Pending',
      collectorName: 'Maria Santos',
      collectorPhoto: '👩',
      estimatedTime: '2 hours',
      items: ['3x Cardboard Boxes', '1x Paper Bundle'],
    ),
    CollectionItem(
      id: 'ECO-G7H8I9',
      title: 'Glass Bottles',
      junkshop: 'EcoWaste Solutions',
      value: 45.75,
      status: 'Completed',
      collectorName: 'Pedro Cruz',
      collectorPhoto: '👨',
      estimatedTime: 'Yesterday',
      items: ['8x Glass Bottles'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildCollectionsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [Text('My Collections', style: AppTextStyles.headerMedium)],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['En Route', 'Pending', 'Completed'];

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: filters.map((filter) => _buildFilterChip(filter)).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? AppColors.textWhite : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionsList() {
    final filteredCollections = _collections
        .where((c) => c.status == _selectedFilter)
        .toList();

    if (filteredCollections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text('No collections found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: filteredCollections.length,
      itemBuilder: (context, index) {
        return _buildCollectionCard(filteredCollections[index]);
      },
    );
  }

  Widget _buildCollectionCard(CollectionItem item) {
    Color statusColor;
    switch (item.status) {
      case 'En Route':
        statusColor = AppColors.primaryBlue;
        break;
      case 'Pending':
        statusColor = AppColors.warningColor;
        break;
      case 'Completed':
        statusColor = AppColors.successColor;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Text(item.junkshop, style: AppTextStyles.cardSubtitle),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Collector info (for En Route/Pending)
            if (item.status != 'Completed') ...[
              Row(
                children: [
                  Text(
                    item.collectorPhoto,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collector: ${item.collectorName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'ETA: ${item.estimatedTime}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingM),
            ],

            // Items list
            Text(
              'Items:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: item.items.map((itemName) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Bottom row with value and actions
            Row(
              children: [
                Text(
                  'Est. Value: ₱${item.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.successColor,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (item.status == 'En Route') ...[
                  OutlinedButton(
                    onPressed: () => _trackCollection(item),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Track Live',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (item.status == 'Pending') ...[
                  OutlinedButton(
                    onPressed: () => _contactCollector(item),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: AppColors.warningColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Contact',
                      style: TextStyle(
                        color: AppColors.warningColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _trackCollection(CollectionItem item) {
    // Show live tracking modal or navigate to tracking screen
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildTrackingModal(item),
    );
  }

  void _contactCollector(CollectionItem item) {
    // Navigate to chat or show contact options
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contacting ${item.collectorName}...'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildTrackingModal(CollectionItem item) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live Tracking', style: AppTextStyles.headerSmall),
                      Text(item.id, style: AppTextStyles.cardSubtitle),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Map placeholder
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: AppColors.textSecondary),
                    SizedBox(height: 16),
                    Text('Live Map Tracking', style: AppTextStyles.bodyMedium),
                    Text(
                      'Collector is on the way',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collector info
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(
                    item.collectorPhoto,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.collectorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'ETA: ${item.estimatedTime}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('Call')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionItem {
  final String id;
  final String title;
  final String junkshop;
  final double value;
  final String status;
  final String collectorName;
  final String collectorPhoto;
  final String estimatedTime;
  final List<String> items;

  CollectionItem({
    required this.id,
    required this.title,
    required this.junkshop,
    required this.value,
    required this.status,
    required this.collectorName,
    required this.collectorPhoto,
    required this.estimatedTime,
    required this.items,
  });
}
