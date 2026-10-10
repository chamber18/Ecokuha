import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../data/services/junkshop_query.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class CollectorsTab extends StatefulWidget {
  const CollectorsTab({super.key});

  @override
  State<CollectorsTab> createState() => _CollectorsTabState();
}

class _CollectorsTabState extends State<CollectorsTab> {
  List<Map<String, dynamic>> _collectorPerformance = [];
  bool _isLoadingCollectors = true;
  String _selectedCollectorSort = 'collections';

  @override
  void initState() {
    super.initState();
    _loadCollectorPerformance();
  }

  Future<void> _loadCollectorPerformance() async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      if (kDebugMode) print('👥 Loading collector performance data...');
      if (kDebugMode) print('🔍 Junkshop ID: $uid');

      Map<String, Map<String, dynamic>> collectorStats = {};

      final postings = await JunkshopQuery.postings(
        uid,
        statuses: [
          'completed',
          'in_transit',
          'arrived',
          'collecting',
          'assigned',
        ],
      );
      final allPostings = <String, JDoc>{
        for (final doc in postings.docs) doc.id: doc,
      };

      if (kDebugMode) print('📦 Total unique postings: ${allPostings.length}');

      for (var doc in allPostings.values) {
        final data = doc.data();

        // Try multiple possible field names for collector ID
        String? collectorId = data['assignedCollectorId'] as String?;
        collectorId ??= data['assigned_collector_id'] as String?;

        // Check nested collector object
        if (collectorId == null && data['collector'] is Map) {
          collectorId =
              (data['collector'] as Map<String, dynamic>)['id'] as String?;
        }

        // Check nested assignedTo object
        if (collectorId == null && data['assignedTo'] is Map) {
          final assignedTo = data['assignedTo'] as Map<String, dynamic>;
          collectorId = assignedTo['id'] as String?;
        }

        // Try to get collector name from multiple possible fields
        String collectorName = 'Unknown';
        if (data['assignedCollectorName'] != null) {
          collectorName = data['assignedCollectorName'] as String;
        } else if (data['collector'] is Map) {
          final collectorMap = data['collector'] as Map<String, dynamic>;
          collectorName =
              collectorMap['full_name'] as String? ??
              collectorMap['name'] as String? ??
              'Unknown';
        } else if (data['assignedTo'] is Map) {
          final assignedToMap = data['assignedTo'] as Map<String, dynamic>;
          collectorName =
              assignedToMap['full_name'] as String? ??
              assignedToMap['name'] as String? ??
              'Unknown';
        }

        if (kDebugMode) print('  🔍 Fields in posting: ${data.keys.toList()}');
        if (kDebugMode) {
          print('  📝 assignedCollectorName: ${data['assignedCollectorName']}');
        }
        if (kDebugMode) print('  📝 collector object: ${data['collector']}');
        if (kDebugMode) print('  📝 assignedTo object: ${data['assignedTo']}');

        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

        if (kDebugMode) {
          print(
            '  📄 Posting ${doc.id}: collectorId=$collectorId, status=$status, name=$collectorName',
          );
        }

        if (collectorId == null) {
          if (kDebugMode) print('    ⚠️ Skipping - no collector assigned');
          continue;
        }

        if (!collectorStats.containsKey(collectorId)) {
          collectorStats[collectorId] = {
            'id': collectorId,
            'name': collectorName,
            'totalCollections': 0,
            'completedCollections': 0,
            'inProgressCollections': 0,
            'assignedCollections': 0,
            'totalTime': 0.0,
            'completionTimes': <double>[],
            'totalValue': 0.0,
          };
        } else {
          // Update name if we found a better one (not "Unknown")
          if (collectorName != 'Unknown' &&
              collectorStats[collectorId]!['name'] == 'Unknown') {
            collectorStats[collectorId]!['name'] = collectorName;
          }
        }

        collectorStats[collectorId]!['totalCollections'] =
            (collectorStats[collectorId]!['totalCollections'] as int) + 1;

        if (status == 'completed') {
          collectorStats[collectorId]!['completedCollections'] =
              (collectorStats[collectorId]!['completedCollections'] as int) + 1;

          if (createdAt != null && completedAt != null) {
            final hours = completedAt.difference(createdAt).inMinutes / 60.0;
            (collectorStats[collectorId]!['completionTimes'] as List<double>)
                .add(hours);
            collectorStats[collectorId]!['totalTime'] =
                (collectorStats[collectorId]!['totalTime'] as double) + hours;
          }

          // Calculate total value from purchased items only
          if (kDebugMode) print('    Checking purchasedItems field:');
          if (kDebugMode) {
            print('      Type: ${data['purchasedItems']?.runtimeType}');
          }
          if (kDebugMode) print('      Value: ${data['purchasedItems']}');

          if (data['purchasedItems'] == null) {
            if (kDebugMode) print('    ⚠️ No purchasedItems field found');
            continue;
          }

          List<dynamic> purchasedItems = [];

          // purchasedItems is a Map with 'list' key containing the actual items
          if (data['purchasedItems'] is Map) {
            final purchasedData =
                data['purchasedItems'] as Map<String, dynamic>;
            if (purchasedData['list'] is List) {
              purchasedItems = purchasedData['list'] as List<dynamic>;
              if (kDebugMode) {
                print(
                  '    ✓ Found ${purchasedItems.length} purchased items in list',
                );
              }
            } else {
              if (kDebugMode) print('    ⚠️ purchasedItems.list is not a List');
            }
          } else if (data['purchasedItems'] is List) {
            purchasedItems = data['purchasedItems'] as List<dynamic>;
            if (kDebugMode) {
              print('    ✓ Found ${purchasedItems.length} purchased items');
            }
          } else {
            if (kDebugMode) {
              print(
                '    ⚠️ purchasedItems is not a Map or List, skipping value calculation',
              );
            }
          }

          double postingValue = 0.0;

          for (var item in purchasedItems) {
            if (item is Map<String, dynamic>) {
              // Handle both num and String types for quantity and price
              final quantityValue = item['quantity'];
              final quantity = quantityValue is num
                  ? quantityValue.toDouble()
                  : (quantityValue is String
                        ? double.tryParse(quantityValue) ?? 0.0
                        : 0.0);

              final priceValue =
                  item['junkshopPricePerUnit'] ?? item['pricePerUnit'];
              final price = priceValue is num
                  ? priceValue.toDouble()
                  : (priceValue is String
                        ? double.tryParse(priceValue) ?? 0.0
                        : 0.0);

              final itemValue = quantity * price;

              if (kDebugMode) {
                print(
                  '      Item: ${item['name']} | qty: $quantity | price: $price | value: $itemValue',
                );
              }

              postingValue += itemValue;
            }
          }

          if (kDebugMode) print('    Total posting value: ₱$postingValue');

          collectorStats[collectorId]!['totalValue'] =
              (collectorStats[collectorId]!['totalValue'] as double) +
              postingValue;
        } else if (status == 'in_transit' ||
            status == 'arrived' ||
            status == 'collecting') {
          collectorStats[collectorId]!['inProgressCollections'] =
              (collectorStats[collectorId]!['inProgressCollections'] as int) +
              1;
        } else if (status == 'assigned') {
          collectorStats[collectorId]!['assignedCollections'] =
              (collectorStats[collectorId]!['assignedCollections'] as int) + 1;
        }
      }

      final collectorList = collectorStats.values.map((stats) {
        final totalCollections = stats['totalCollections'] as int;
        final completedCollections = stats['completedCollections'] as int;
        final completionTimes = stats['completionTimes'] as List<double>;
        final totalValue = (stats['totalValue'] as double?) ?? 0.0;

        final completionRate = totalCollections > 0
            ? (completedCollections / totalCollections) * 100
            : 0.0;

        final avgCompletionTime = completionTimes.isNotEmpty
            ? completionTimes.reduce((a, b) => a + b) / completionTimes.length
            : 0.0;

        final avgValuePerCollection = completedCollections > 0
            ? totalValue / completedCollections
            : 0.0;

        return {
          'id': stats['id'],
          'name': stats['name'],
          'collections': totalCollections,
          'completed': completedCollections,
          'inProgress': stats['inProgressCollections'],
          'assigned': stats['assignedCollections'],
          'completionRate': completionRate,
          'avgTime': avgCompletionTime,
          'totalValue': totalValue,
          'avgValue': avgValuePerCollection,
        };
      }).toList();

      collectorList.sort(
        (a, b) => (b['collections'] as int).compareTo(a['collections'] as int),
      );

      if (kDebugMode) {
        print(
          '👥 Collector performance loaded: ${collectorList.length} collectors',
        );
      }

      setState(() {
        _collectorPerformance = collectorList;
        _isLoadingCollectors = false;
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error loading collector performance: $e');
      setState(() => _isLoadingCollectors = false);
    }
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₱0';

    // Format with comma separator for thousands
    final intValue = value.toInt();
    final decimalValue = value - intValue;

    String formattedInt = intValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Include decimals only if not zero
    if (decimalValue > 0) {
      return '₱$formattedInt${decimalValue.toStringAsFixed(2).substring(1)}';
    }

    return '₱$formattedInt';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadCollectorPerformance,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoadingCollectors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_collectorPerformance.isEmpty) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: AppColors.junkshopPrimary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  Text(
                    'No Collector Data',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Text(
                    'Collector performance data will appear here once assignments are made',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final sortedCollectors = List<Map<String, dynamic>>.from(
      _collectorPerformance,
    );
    switch (_selectedCollectorSort) {
      case 'collections':
        sortedCollectors.sort(
          (a, b) => ((b['collections'] as int?) ?? 0).compareTo(
            (a['collections'] as int?) ?? 0,
          ),
        );
        break;
      case 'rate':
        sortedCollectors.sort(
          (a, b) => ((b['completionRate'] as double?) ?? 0.0).compareTo(
            (a['completionRate'] as double?) ?? 0.0,
          ),
        );
        break;
      case 'efficiency':
        sortedCollectors.sort(
          (a, b) => ((a['avgTime'] as double?) ?? 0.0).compareTo(
            (b['avgTime'] as double?) ?? 0.0,
          ),
        );
        break;
      case 'value':
        sortedCollectors.sort(
          (a, b) => ((b['totalValue'] as double?) ?? 0.0).compareTo(
            (a['totalValue'] as double?) ?? 0.0,
          ),
        );
        break;
    }

    // Calculate summary statistics
    final totalCollectors = sortedCollectors.length;
    final totalCompletedCollections = sortedCollectors.fold<int>(
      0,
      (acc, c) => acc + ((c['completed'] as int?) ?? 0),
    );
    final totalValue = sortedCollectors.fold<double>(
      0.0,
      (acc, c) => acc + ((c['totalValue'] as double?) ?? 0.0),
    );

    return Column(
      children: [
        // Summary header - simplified
        Container(
          margin: const EdgeInsets.all(AppDimensions.spacing16),
          padding: const EdgeInsets.all(AppDimensions.spacing20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.people_outline,
                label: 'Active Collectors',
                value: totalCollectors.toString(),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildSummaryItem(
                icon: Icons.check_circle_outline,
                label: 'Total Collections',
                value: totalCompletedCollections.toString(),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildSummaryItem(
                icon: Icons.payments_outlined,
                label: 'Total Value',
                value: _formatCurrency(totalValue),
              ),
            ],
          ),
        ),

        // Sort chips - simplified
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing8,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('Most Collections', 'collections'),
                const SizedBox(width: AppDimensions.spacing8),
                _buildSortChip('Best Rate', 'rate'),
                const SizedBox(width: AppDimensions.spacing8),
                _buildSortChip('Fastest', 'efficiency'),
                const SizedBox(width: AppDimensions.spacing8),
                _buildSortChip('Highest Value', 'value'),
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            itemCount: sortedCollectors.length,
            itemBuilder: (context, index) {
              final collector = sortedCollectors[index];
              return _buildCollectorCard(collector, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _selectedCollectorSort == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCollectorSort = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primaryGreen),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCollectorCard(Map<String, dynamic> collector, int rank) {
    final name = (collector['name'] as String?) ?? 'Unknown';
    final collections = (collector['collections'] as int?) ?? 0;
    final completed = (collector['completed'] as int?) ?? 0;
    final inProgress = (collector['inProgress'] as int?) ?? 0;
    final assigned = (collector['assigned'] as int?) ?? 0;
    final completionRate = (collector['completionRate'] as double?) ?? 0.0;
    final totalValue = (collector['totalValue'] as double?) ?? 0.0;
    final avgValue = (collector['avgValue'] as double?) ?? 0.0;

    final bool isTopPerformer = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTopPerformer
              ? AppColors.primaryGreen.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          children: [
            Row(
              children: [
                // Rank badge - simplified
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isTopPerformer
                        ? AppColors.primaryGreen.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isTopPerformer
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.h5.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusBadge(
                            Icons.check_circle,
                            completed,
                            Colors.green.shade700,
                          ),
                          if (inProgress > 0) ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge(
                              Icons.schedule,
                              inProgress,
                              Colors.orange.shade700,
                            ),
                          ],
                          if (assigned > 0) ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge(
                              Icons.assignment,
                              assigned,
                              Colors.blue.shade700,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Total collections badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$collections',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'total',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spacing16),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.spacing12),

            // Metrics - redesigned grid
            Row(
              children: [
                Expanded(
                  child: _buildSimpleMetric(
                    'Completed',
                    '$completed',
                    Colors.green.shade700,
                  ),
                ),
                Expanded(
                  child: _buildSimpleMetric(
                    'In Progress',
                    '$inProgress',
                    Colors.orange.shade700,
                  ),
                ),
                Expanded(
                  child: _buildSimpleMetric(
                    'Total Value',
                    _formatCurrency(totalValue),
                    AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
            if (avgValue > 0) ...[
              const SizedBox(height: AppDimensions.spacing8),
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleMetric(
                      'Avg Value/Collection',
                      _formatCurrency(avgValue),
                      AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _buildSimpleMetric(
                      'Completion Rate',
                      '${completionRate.toStringAsFixed(0)}%',
                      completionRate >= 90
                          ? Colors.green.shade700
                          : completionRate >= 70
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
