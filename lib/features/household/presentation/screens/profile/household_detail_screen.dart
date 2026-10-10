import 'package:flutter/material.dart';
import '../../../../../core/supabase/supabase_helpers.dart' as sb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class HouseholdDetailScreen extends StatefulWidget {
  final Map<String, dynamic> householdData;

  const HouseholdDetailScreen({super.key, required this.householdData});

  @override
  State<HouseholdDetailScreen> createState() => _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState extends State<HouseholdDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadDetailedStats();
  }

  Future<void> _loadDetailedStats() async {
    setState(() => _isLoading = true);

    try {
      final householdId = widget.householdData['id'] as String;

      final postingRows = await sb.supabase
          .from('postings')
          .select()
          .eq('household_id', householdId)
          .eq('status', 'completed');
      final postingsSnapshot = sb.rowsToDocs('postings', postingRows);

      final materialWeights = <String, double>{};
      var totalWeight = 0.0;
      var totalItems = 0;
      DateTime? firstCollection;
      DateTime? lastCollection;
      var maxEarning = 0.0;
      String? bestCollectionDate;

      for (final data in postingsSnapshot) {
        totalItems++;

        final completedAt =
            sb.toDateTime(data['completedAt']) ??
            sb.toDateTime(data['updatedAt']);
        if (completedAt != null) {
          if (firstCollection == null ||
              completedAt.isBefore(firstCollection)) {
            firstCollection = completedAt;
          }
          if (lastCollection == null || completedAt.isAfter(lastCollection)) {
            lastCollection = completedAt;
          }
        }

        final purchasedItems = data['purchasedItems'];
        final verifiedItems = data['verifiedItems'];
        final items = data['items'];

        List<dynamic> itemsList = [];
        double collectionValue = 0.0;

        if (purchasedItems != null) {
          if (purchasedItems is Map && purchasedItems['list'] != null) {
            itemsList = purchasedItems['list'] as List<dynamic>;
            final totalValue = purchasedItems['total'];
            if (totalValue is num) {
              collectionValue = totalValue.toDouble();
            } else if (totalValue is String) {
              collectionValue = double.tryParse(totalValue) ?? 0.0;
            }
          }
        } else if (verifiedItems != null) {
          if (verifiedItems is Map && verifiedItems['items'] != null) {
            itemsList = verifiedItems['items'] as List<dynamic>;
            final totalValue = verifiedItems['totalValue'];
            if (totalValue is num) {
              collectionValue = totalValue.toDouble();
            } else if (totalValue is String) {
              collectionValue = double.tryParse(totalValue) ?? 0.0;
            }
          }
        } else if (items != null && items is List) {
          itemsList = items;
        } else if (items is Map && items['list'] is List) {
          itemsList = items['list'] as List<dynamic>;
        }

        if (collectionValue > maxEarning) {
          maxEarning = collectionValue;
          bestCollectionDate = completedAt != null
              ? DateFormat('MMM d, yyyy').format(completedAt)
              : null;
        }

        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            final category = item['category'] as String? ?? 'Other';

            // Handle quantity/weight that might be stored as String or num
            double quantity = 1.0;
            final quantityValue = item['quantity'] ?? item['weight'];
            if (quantityValue != null) {
              if (quantityValue is num) {
                quantity = quantityValue.toDouble();
              } else if (quantityValue is String) {
                quantity = double.tryParse(quantityValue) ?? 1.0;
              }
            }

            materialWeights[category] =
                (materialWeights[category] ?? 0.0) + quantity;
            totalWeight += quantity;
          }
        }
      }

      final materialPercentages = <String, double>{};
      if (totalWeight > 0) {
        materialWeights.forEach((category, weight) {
          materialPercentages[category] = (weight / totalWeight) * 100;
        });
      }

      final sortedMaterials = materialPercentages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      debugPrint('📊 Household materials loaded:');
      debugPrint('  - Total postings: ${postingsSnapshot.length}');
      debugPrint(
        '  - Material categories found: ${materialWeights.keys.length}',
      );
      debugPrint('  - Total weight: $totalWeight');
      for (final material in sortedMaterials.take(5)) {
        debugPrint(
          '  - ${material.key}: ${material.value.toStringAsFixed(1)}%',
        );
      }

      final daysSinceFirst = firstCollection != null
          ? DateTime.now().difference(firstCollection).inDays
          : 0;
      final avgPerWeek = daysSinceFirst > 0
          ? (totalItems / (daysSinceFirst / 7)).toStringAsFixed(1)
          : '0';

      setState(() {
        _stats = {
          'topMaterials': sortedMaterials.take(5).toList(),
          'totalWeight': totalWeight,
          'firstCollection': firstCollection,
          'lastCollection': lastCollection,
          'avgPerWeek': avgPerWeek,
          'maxEarning': maxEarning,
          'bestCollectionDate': bestCollectionDate,
          'daysSinceFirst': daysSinceFirst,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading household details: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Recycled Materials',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.householdPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.householdPrimary,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDetailedStats,
              color: AppColors.householdPrimary,
              child:
                  _stats['topMaterials'] != null &&
                      (_stats['topMaterials'] as List).isNotEmpty
                  ? ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: (_stats['topMaterials'] as List).length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildProfileHeader();
                        final entry =
                            (_stats['topMaterials']
                                as List<MapEntry<String, double>>)[index - 1];
                        return _buildMaterialCard(
                          category: entry.key,
                          percentage: entry.value,
                          index: index - 1,
                        );
                      },
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildProfileHeader(),
                        SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.recycling,
                                  size: 80,
                                  color: AppColors.textSecondary.withValues(alpha: 
                                    0.3,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No Materials Yet',
                                  style: AppTextStyles.h5.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This household hasn\'t recycled any materials yet',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary.withValues(alpha: 
                                      0.7,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Pull down to refresh',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.householdPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final rank = widget.householdData['rank'] as int? ?? 0;
    final fullName =
        widget.householdData['full_name'] as String? ??
        widget.householdData['name'] as String? ??
        'Anonymous';
    final profileImage = widget.householdData['profile_image_url'] as String?;
    final city = widget.householdData['city'] as String?;
    final address = widget.householdData['address'] as String?;
    final score = (widget.householdData['score'] as num?)?.toDouble() ?? 0.0;

    final location = [
      address,
      city,
    ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                width: 2,
              ),
              color: Colors.grey.shade100,
            ),
            child: ClipOval(
              child: profileImage != null && profileImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profileImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey.shade100),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.person,
                        size: 28,
                        color: Colors.grey.shade400,
                      ),
                    )
                  : Icon(Icons.person, size: 28, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 14),
          // Name + location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (location.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        FluentIcons.location_24_regular,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'EcoKuha Household',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Rank + score
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
              Text(
                'pts',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard({
    required String category,
    required double percentage,
    required int index,
  }) {
    final colors = [
      AppColors.householdPrimary,
      Colors.blue,
      Colors.orange,
      Colors.teal,
      Colors.purple,
      Colors.amber,
      Colors.indigo,
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Recycled material',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
