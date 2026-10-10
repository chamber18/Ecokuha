import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../data/services/junkshop_query.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import 'collector_profile_screen.dart';
import 'package:ecokuha/core/di/service_locator.dart';
import 'package:ecokuha/features/junkshop/domain/repositories/collectors_repository.dart';
import 'package:ecokuha/features/junkshop/data/models/collector_model.dart'
    as model;

class CollectorsScreen extends StatefulWidget {
  const CollectorsScreen({super.key});

  @override
  State<CollectorsScreen> createState() => _CollectorsScreenState();
}

class _CollectorsScreenState extends State<CollectorsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All';

  String? _error;
  bool _isLoading = false;

  // Fetched data (mapped to UI-friendly maps for minimal UI changes)
  final List<Map<String, dynamic>> _collectors = [];

  @override
  void initState() {
    super.initState();
    _loadCollectors();
  }

  Future<void> _loadCollectors() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final repo = getIt<ICollectorsRepository>();
      // Only show collectors assigned to this junkshop and approved
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _collectors.clear();
          _error = 'Not authenticated';
        });
        return;
      }

      final List<model.Collector> items = await repo
          .getCollectorsAssignedToJunkshop(
            junkshopId: currentUser.id,
            limit: 100,
          );

      // Batch-fetch all completed postings for this junkshop to count per collector.
      final completedSnap = await JunkshopQuery.postings(
        currentUser.id,
        statuses: ['completed'],
      );

      // Count completed postings per collector (junkshop-scoped)
      final Map<String, Set<String>> collectorCompletedIds = {};
      for (final doc in completedSnap.docs) {
        final cId = doc.data()['collectorId'] as String?;
        if (cId != null) {
          collectorCompletedIds.putIfAbsent(cId, () => {}).add(doc.id);
        }
      }

      // Fetch additional stats for each collector
      final mappedFutures = items.map((c) async {
        final status = c.status.toLowerCase() == 'available'
            ? 'Active'
            : (c.status.toLowerCase() == 'busy' ? 'Busy' : 'Offline');

        // Debug: Check approvedAt value
        debugPrint('Collector ${c.id} (${c.name}) approvedAt: ${c.approvedAt}');

        // Build short location for card (first part of address before comma)
        final fullAddress = c.address ?? '';
        final shortLocation = fullAddress.isNotEmpty
            ? fullAddress.split(',')[0].trim()
            : '';

        // Fetch average rating and last login
        double averageRating = c.rating;
        int totalCollections = 0;
        int assignedToday = 0;
        bool isOnlineToday = false;

        try {
          final collectorData = await supabase
              .from('collectors')
              .select()
              .eq('id', c.id)
              .maybeSingle();

          if (collectorData != null) {
            averageRating =
                (collectorData['average_rating'] as num?)?.toDouble() ??
                c.rating;
            // total_collections is a global counter — do not use it here;
            // we use the junkshop-scoped count computed above instead.

            // Check if collector logged in today
            final lastLoginStr = collectorData['last_login_at'] as String?;
            if (lastLoginStr != null) {
              try {
                final lastLogin = DateTime.parse(lastLoginStr);
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final loginDate = DateTime(
                  lastLogin.year,
                  lastLogin.month,
                  lastLogin.day,
                );
                isOnlineToday = loginDate.compareTo(today) >= 0;
              } catch (e) {
                debugPrint('Error parsing last_login_at for ${c.id}: $e');
              }
            }
          }

          // Use junkshop-scoped completed count
          totalCollections = collectorCompletedIds[c.id]?.length ?? 0;

          // Count collections assigned today
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

          final todayAssignments = await supabase
              .from('postings')
              .select('id')
              .eq('collector_id', c.id)
              .inFilter('status', [
                'assigned',
                'in_transit',
                'arrived',
                'collecting',
              ])
              .gte('date_of_collection', startOfDay.toUtc().toIso8601String())
              .lte('date_of_collection', endOfDay.toUtc().toIso8601String());

          assignedToday = todayAssignments.length;
        } catch (e) {
          debugPrint('Error fetching collector stats for ${c.id}: $e');
        }

        return {
          'id': c.id,
          'name': _capitalizeName(c.name),
          'email': c.email ?? '',
          // Use the collector's profile image URL if available
          'avatarUrl': c.profileImageUrl,
          'status': status,
          'isOnlineToday': isOnlineToday,
          'collectionsToday': 0,
          'totalItems': 0,
          'rating': averageRating,
          'totalCollections': totalCollections,
          'totalWeight': 0.0,
          'assignedTasks': assignedToday,
          // Short location for card display (first part of address)
          'location': shortLocation.isNotEmpty ? shortLocation : '-',
          // Full address for profile details
          'fullAddress': (c.address != null && c.address!.trim().isNotEmpty)
              ? c.address!
              : '-',
          'phone': c.phoneNumber ?? '',
          'approvedAt': c.approvedAt,
        };
      });

      final mapped = await Future.wait(mappedFutures);

      setState(() {
        _collectors
          ..clear()
          ..addAll(mapped);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load collectors: $e';
        _isLoading = false;
      });
    }
  }

  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    return name
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : (w[0].toUpperCase() + w.substring(1).toLowerCase()),
        )
        .join(' ');
  }

  List<Map<String, dynamic>> get _filteredCollectors {
    var filtered = _collectors.where((collector) {
      final matchesSearch = collector['name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesFilter =
          _filterStatus == 'All' || collector['status'] == _filterStatus;
      return matchesSearch && matchesFilter;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Manage Collectors',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            initialValue: _filterStatus,
            onSelected: (value) => setState(() => _filterStatus = value),
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Status')),
              const PopupMenuItem(value: 'Online', child: Text('Online')),
              const PopupMenuItem(value: 'Offline', child: Text('Offline')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar - fixed at top
          Container(
            color: AppColors.backgroundDark,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search collectors...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF6B7280),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Error message if any
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.errorColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.errorColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadCollectors,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          // Scrollable collectors list with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCollectors,
              color: AppColors.primaryGreen,
              backgroundColor: Colors.white,
              child: NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (overscroll) {
                  overscroll.disallowIndicator();
                  return false;
                },
                child: _buildCollectorsList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Removed leaderboard helpers; leaderboard moved to Profile Settings

  Widget _buildCollectorsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.junkshopPrimary),
        ),
      );
    }

    if (_filteredCollectors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.group_outlined,
                  color: AppColors.textSecondary,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  'No approved collectors assigned yet',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      itemCount: _filteredCollectors.length,
      itemBuilder: (context, index) {
        final collector = _filteredCollectors[index];
        return _buildCollectorCard(collector);
      },
    );
  }

  Widget _buildCollectorCard(Map<String, dynamic> collector) {
    final isOnline = collector['isOnlineToday'] as bool? ?? false;
    final statusColor = isOnline ? AppColors.success : Colors.grey.shade400;
    final statusLabel = isOnline ? 'Online' : 'Offline';
    final rating = (collector['rating'] as num).toDouble();
    final completed = collector['totalCollections'] as int;
    final assigned = collector['assignedTasks'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _goToCollectorProfile(collector),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar ──────────────────────────────────────────
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final url = collector['avatarUrl'] as String?;
                        if (url != null && url.isNotEmpty) {
                          _showFullScreenImage(url);
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.1,
                          ),
                          border: Border.all(
                            color: isOnline
                                ? AppColors.success.withValues(alpha: 0.5)
                                : Colors.grey.shade200,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _buildCollectorAvatar(collector['avatarUrl']),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),

                // ── Name + badges ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collector['name'] as String,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          // Status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Rating pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Colors.amber.shade600,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ── Stats row ──────────────────────────────────
                      Row(
                        children: [
                          _miniStat(
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.successColor,
                            value: '$completed',
                            label: 'Done',
                          ),
                          const SizedBox(width: 14),
                          _miniStat(
                            icon: Icons.pending_actions_rounded,
                            color: AppColors.junkshopPrimary,
                            value: '$assigned',
                            label: 'Assigned',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Chevron ──────────────────────────────────────────
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade300,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _goToCollectorProfile(Map<String, dynamic> collector) async {
    // Fetch recent collections for this collector
    final collectorId = collector['id'] as String;
    final junkshopUid = currentUid;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    List<Map<String, dynamic>>? recentCollections;

    try {
      // Fetch all postings for this collector (both completed and assigned)
      final postingRows = await supabase
          .from('postings')
          .select()
          .eq('collector_id', collectorId);
      final querySnapshot = JSnap(
        rowsToDocs('postings', postingRows).map(JDoc.new).toList(),
      );
      debugPrint('Found ${querySnapshot.docs.length} postings for collector');

      recentCollections =
          querySnapshot.docs
              .where((doc) {
                // Only include postings that belong to the current junkshop
                if (junkshopUid == null) return true;
                final data = doc.data();
                final docJunkshopId = data['junkshopId'] as String?;
                return docJunkshopId == junkshopUid;
              })
              .map((doc) {
                final data = doc.data();
                debugPrint('🔍 PROCESSING DOC: ${doc.id}');

                // Try multiple date fields
                final collectionDate =
                    toDateTime(data['completedAt']) ??
                    toDateTime(data['updatedAt']) ??
                    toDateTime(data['createdAt']) ??
                    toDateTime(data['dateOfCollection']) ??
                    DateTime.now();

                // Extract items description, count, and total weight from purchasedItems
                String itemsDesc = 'Items';
                int itemCount = 0;
                double totalWeight = 0.0;
                double price = 0.0;

                // Debug: Log what fields are available in this document
                debugPrint('--- Processing posting ${doc.id} ---');
                debugPrint(
                  'Has purchasedItems: ${data['purchasedItems'] != null}',
                );
                debugPrint('Has items: ${data['items'] != null}');
                if (data['items'] != null) {
                  debugPrint('items type: ${data['items'].runtimeType}');
                }

                // Check purchasedItems first (what junkshop actually purchased)
                if (data['purchasedItems'] is Map) {
                  final purchasedItems =
                      data['purchasedItems'] as Map<String, dynamic>;

                  // Get price from 'total' field
                  price =
                      (purchasedItems['total'] as num?)?.toDouble() ??
                      (purchasedItems['totalEstimatedValue'] as num?)
                          ?.toDouble() ??
                      (purchasedItems['totalValue'] as num?)?.toDouble() ??
                      0.0;

                  debugPrint('From purchasedItems - price: $price');

                  // Get items list
                  if (purchasedItems['list'] is List) {
                    final itemsList = purchasedItems['list'] as List<dynamic>;
                    itemCount = itemsList.length;

                    final itemNames = itemsList
                        .map((item) {
                          if (item is Map) {
                            return item['name']?.toString() ??
                                item['type']?.toString() ??
                                item['material']?.toString() ??
                                'Item';
                          }
                          return 'Item';
                        })
                        .where((name) => name.isNotEmpty)
                        .toList();

                    if (itemNames.isNotEmpty) {
                      itemsDesc = itemNames.take(3).join(', ');
                      if (itemNames.length > 3) itemsDesc += ', ...';
                    }
                  }

                  // Get weight from items field (estimatedTotalWeight)
                  if (data['items'] is Map) {
                    final items = data['items'] as Map<String, dynamic>;
                    totalWeight =
                        (items['estimatedTotalWeight'] as num?)?.toDouble() ??
                        (items['totalWeight'] as num?)?.toDouble() ??
                        0.0;
                  }
                }
                // Fallback to items field (verified items)
                else if (data['items'] is Map) {
                  final items = data['items'] as Map<String, dynamic>;

                  totalWeight =
                      (items['estimatedTotalWeight'] as num?)?.toDouble() ??
                      (items['totalWeight'] as num?)?.toDouble() ??
                      0.0;

                  price =
                      (items['totalEstimatedValue'] as num?)?.toDouble() ??
                      (items['totalValue'] as num?)?.toDouble() ??
                      0.0;

                  debugPrint(
                    'From items (Map) - weight: $totalWeight, price: $price',
                  );

                  if (items['list'] is List) {
                    final itemsList = items['list'] as List<dynamic>;
                    itemCount = itemsList.length;

                    final itemNames = itemsList
                        .map((item) {
                          if (item is Map) {
                            return item['name']?.toString() ??
                                item['type']?.toString() ??
                                'Item';
                          }
                          return 'Item';
                        })
                        .where((name) => name.isNotEmpty)
                        .toList();

                    if (itemNames.isNotEmpty) {
                      itemsDesc = itemNames.take(3).join(', ');
                      if (itemNames.length > 3) itemsDesc += ', ...';
                    }
                  }
                }
                // Old format fallback
                else if (data['items'] is List) {
                  final itemsList = data['items'] as List<dynamic>;
                  itemCount = itemsList.length;

                  final itemNames = itemsList
                      .map((item) {
                        if (item is Map) {
                          final weight =
                              (item['weight'] as num?)?.toDouble() ?? 0.0;
                          totalWeight += weight;

                          return item['type']?.toString() ??
                              item['name']?.toString() ??
                              item['material']?.toString() ??
                              'Item';
                        }
                        return 'Item';
                      })
                      .where((name) => name.isNotEmpty)
                      .toList();

                  if (itemNames.isNotEmpty) {
                    itemsDesc = itemNames.take(3).join(', ');
                    if (itemNames.length > 3) itemsDesc += ', ...';
                  }

                  debugPrint(
                    'From items (List) - weight: $totalWeight, itemCount: $itemCount',
                  );
                }

                // If price wasn't found in items, check top-level fields
                if (price == 0.0) {
                  price =
                      (data['totalVerifiedValue'] as num?)?.toDouble() ??
                      (data['junkshopPurchaseTotal'] as num?)?.toDouble() ??
                      (data['totalPrice'] as num?)?.toDouble() ??
                      0.0;
                  debugPrint('From top-level - price: $price');
                }

                debugPrint(
                  'Final values - items: "$itemsDesc", count: $itemCount, weight: $totalWeight, price: $price',
                );

                return {
                  'date': collectionDate,
                  'items': itemsDesc,
                  'itemCount': itemCount,
                  'weight': totalWeight,
                  'price': price,
                  'status': data['status']?.toString() ?? 'pending',
                  'timestamp': collectionDate.millisecondsSinceEpoch,
                  'postingId': doc.id,
                  'householdId': data['householdId']?.toString() ?? '',
                };
              })
              .where((collection) {
                // Filter to show only completed collections
                final status = (collection['status'] as String).toLowerCase();
                return status == 'completed' ||
                    status == 'reviewed' ||
                    status == 'done';
              })
              .toList()
            ..sort(
              (a, b) =>
                  (b['timestamp'] as int).compareTo(a['timestamp'] as int),
            )
            ..take(5)
            ..toList();

      debugPrint('=== Recent Collections Fetch ===');
      debugPrint('Collector ID: $collectorId');
      debugPrint('Total docs fetched: ${querySnapshot.docs.length}');
      debugPrint('Completed collections: ${recentCollections.length}');
      if (recentCollections.isNotEmpty) {
        debugPrint('First collection full data: ${recentCollections.first}');
        final first = recentCollections.first;
        debugPrint('  - Items: ${first['items']}');
        debugPrint('  - ItemCount: ${first['itemCount']}');
        debugPrint('  - Price: ${first['price']}');
        debugPrint('  - Weight: ${first['weight']}');
        debugPrint('  - Date: ${first['date']}');

        // DEBUG: Show actual Firestore document to see what fields exist
        if (querySnapshot.docs.isNotEmpty) {
          final firstDoc = querySnapshot.docs.first;
          debugPrint('=== ACTUAL FIRESTORE DOCUMENT ===');
          debugPrint('Document ID: ${firstDoc.id}');
          final data = firstDoc.data();

          debugPrint(
            'Has purchasedItems field: ${data['purchasedItems'] != null}',
          );
          if (data['purchasedItems'] != null) {
            debugPrint(
              'purchasedItems type: ${data['purchasedItems'].runtimeType}',
            );
            debugPrint('purchasedItems content: ${data['purchasedItems']}');
          }

          debugPrint('Has items field: ${data['items'] != null}');
          if (data['items'] != null) {
            debugPrint('Items type: ${data['items'].runtimeType}');
            debugPrint('Items content: ${data['items']}');
          }

          debugPrint(
            'Has totalVerifiedValue: ${data['totalVerifiedValue'] != null}',
          );
          if (data['totalVerifiedValue'] != null) {
            debugPrint('totalVerifiedValue: ${data['totalVerifiedValue']}');
          }
          debugPrint('=================================');
        }
      }
      debugPrint('==============================');
    } catch (e) {
      debugPrint('Error fetching recent collections: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }

    // Calculate total sold from all collections
    double totalSold = 0.0;
    for (final collection in recentCollections ?? []) {
      totalSold += (collection['price'] as double?) ?? 0.0;
    }
    debugPrint('Total sold calculated: ₱${totalSold.toStringAsFixed(2)}');

    // Navigate to Collector's profile screen. Since this is the Junkshop app, we reuse
    // a local profile screen to display the selected collector's details.
    if (!context.mounted) return;

    // Use isOnlineToday to determine status for profile screen
    final isOnline = collector['isOnlineToday'] as bool? ?? false;
    final profileStatus = isOnline ? 'Online' : 'Offline';

    final result = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => CollectorProfileScreen(
          collectorId: collectorId,
          name: collector['name'] as String,
          phone: collector['phone'] as String,
          email: collector['email'] as String,
          address: collector['fullAddress'] as String,
          status: profileStatus,
          avatarUrl: collector['avatarUrl'] as String?,
          rating: (collector['rating'] as num).toDouble(),
          totalCollections: collector['totalCollections'] as int,
          totalSold: totalSold,
          assignedTasks: collector['assignedTasks'] as int,
          todayCollections: collector['collectionsToday'] as int,
          totalItems: collector['totalItems'] as int,
          approvedAt: collector['approvedAt'] as DateTime?,
          recentCollections: recentCollections,
          vehicle: collector['vehicle'] as Map<String, dynamic>?,
        ),
      ),
    );

    // Refresh list if collector was dismissed
    if (result == true) {
      await _loadCollectors();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${collector['name']} has been dismissed.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    }
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  // Use transparent to rely on barrierColor (80% opacity)
                  color: Colors.transparent,
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 80,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Helper method to safely display collector avatar
  Widget _buildCollectorAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          color: AppColors.junkshopPrimary,
          size: 22,
        ),
      );
    }

    // Validate URL format
    final bool isValidUrl =
        avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://');

    if (!isValidUrl) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          color: AppColors.junkshopPrimary,
          size: 22,
        ),
      );
    }

    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.junkshopPrimary,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.person_rounded,
            color: AppColors.junkshopPrimary,
            size: 22,
          ),
        );
      },
    );
  }
}
