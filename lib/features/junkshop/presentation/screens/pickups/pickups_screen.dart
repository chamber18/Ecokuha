import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../../../core/utils/app_image_provider.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/constants/firestore_fields/index.dart';
import '../../../../../../core/utils/phone_launcher.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../core/utils/formatters.dart';
import 'package:ecokuha/core/di/service_locator.dart';
import 'package:ecokuha/features/junkshop/data/repositories/pickups_repository.dart';
import 'package:ecokuha/features/junkshop/domain/repositories/collectors_repository.dart';
import 'package:ecokuha/features/junkshop/data/models/collector_model.dart';
import 'package:ecokuha/features/messaging/data/repositories/chat_repository.dart';
import '../../../../collector/data/services/date_validation_service.dart';
import '../messages/junkshop_chat_detail_screen.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../data/services/junkshop_query.dart';
import '../../../../messaging/data/models/conversation_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
// Details are shown in a bottom sheet, not a separate screen

class PickupsScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? targetPostingId;

  const PickupsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.targetPostingId,
  });

  @override
  State<PickupsScreen> createState() => _PickupsScreenState();
}

class _PickupsScreenState extends State<PickupsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _mainTabs = ['New', 'Assigned', 'Reassign', 'Pay'];

  // Remote-backed data for New tab (replaces mock)
  List<NewPickupItem> _newPickups = [];
  bool _loadingNew = false;
  String? _errorNew;
  String? _errorNewCode;

  // Remote-backed data for Assigned tab
  List<CollectorAssignment> _collectorAssignments = [];
  bool _loadingAssigned = false;
  String? _errorAssigned;
  String? _errorAssignedCode;

  // Remote-backed data for Completed/Review tab
  List<CollectorAssignment> _completedCollectorAssignments = [];
  bool _loadingCompleted = false;
  String? _errorCompleted;
  String? _errorCompletedCode;

  // Remote-backed data for Rescheduled (Reassigned) tab
  List<NewPickupItem> _rescheduleOnlyPickups = [];
  bool _loadingReschedule = false;
  String? _errorReschedule;
  String? _errorRescheduleCode;

  // Track locally reviewed pickup IDs to prevent them from reappearing
  final Set<String> _locallyReviewedPickupIds = {};

  // Search for Pay tab
  final TextEditingController _paySearchController = TextEditingController();

  // Search state for all tabs
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  // Filter state
  Set<String> _sortBy = {'date'};
  bool _sortAscending = false;

  int get _activeFilterCount {
    int count = 0;
    if (_sortBy.length > 1 || (!_sortBy.contains('date')) || _sortAscending) {
      count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _mainTabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _fetchNewPickups();
    _fetchAssignedPickups().then((_) {
      // Auto-open pickup details modal if targetPostingId is provided
      if (widget.targetPostingId != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openPickupDetailsForPosting(widget.targetPostingId!);
        });
      }
    });
    _fetchReschedulePickups();
    _fetchCompletedPickups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paySearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mirror collector header: green AppBar with white text and TabBar as bottom
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              'Pickups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (_isSearchExpanded) ...[
              const SizedBox(width: 26),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    maxHeight: 48,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search pickups...',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearchExpanded = false;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!_isSearchExpanded)
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearchExpanded = true;
                });
              },
              icon: const Icon(Icons.search, color: Colors.white),
            ),
          Stack(
            children: [
              IconButton(
                onPressed: _showFilterModal,
                icon: const Icon(Icons.filter_list, color: Colors.white),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        _activeFilterCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: [
            _buildTabWithBadge('New', _newPickups.isNotEmpty),
            Tab(text: 'Assigned'),
            _buildTabWithBadge('Reassign', _rescheduleOnlyPickups.isNotEmpty),
            _buildTabWithBadge(
              'Pay',
              _completedCollectorAssignments.isNotEmpty,
            ),
          ],
        ),
      ),
      body: _buildTabContent(),
    );
  }

  void _showFilterModal() {
    Set<String> tempSortBy = Set.from(_sortBy);
    bool tempSortAscending = _sortAscending;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Pickups',
                        style: AppTextStyles.h5.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing24),

                  // Sort By
                  Text(
                    'Sort By',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSortChip('date', 'Date', tempSortBy, setModalState),
                      _buildSortChip(
                        'name',
                        'Household Name',
                        tempSortBy,
                        setModalState,
                      ),
                      _buildSortChip(
                        'collector',
                        'Collector Name',
                        tempSortBy,
                        setModalState,
                      ),
                      _buildSortChip(
                        'items',
                        'Number of Items',
                        tempSortBy,
                        setModalState,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing20),

                  // Sort Direction
                  Text(
                    'Sort Direction',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSortAscending = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !tempSortAscending
                                  ? AppColors.junkshopPrimary
                                  : AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !tempSortAscending
                                    ? AppColors.junkshopPrimary
                                    : AppColors.borderLight,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 16,
                                  color: !tempSortAscending
                                      ? AppColors.textWhite
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Descending',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: !tempSortAscending
                                        ? AppColors.textWhite
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSortAscending = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: tempSortAscending
                                  ? AppColors.junkshopPrimary
                                  : AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tempSortAscending
                                    ? AppColors.junkshopPrimary
                                    : AppColors.borderLight,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  size: 16,
                                  color: tempSortAscending
                                      ? AppColors.textWhite
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ascending',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tempSortAscending
                                        ? AppColors.textWhite
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempSortBy = {'date'};
                              tempSortAscending = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Clear All',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _sortBy = tempSortBy;
                              _sortAscending = tempSortAscending;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.junkshopPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Apply Filters',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(
    String value,
    String label,
    Set<String> selectedSorts,
    StateSetter setModalState,
  ) {
    final isSelected = selectedSorts.contains(value);
    return GestureDetector(
      onTap: () {
        setModalState(() {
          if (isSelected) {
            selectedSorts.remove(value);
            if (selectedSorts.isEmpty) {
              selectedSorts.add('date');
            }
          } else {
            selectedSorts.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.junkshopPrimary
              : AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.junkshopPrimary
                : AppColors.borderLight,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.textWhite : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  List<NewPickupItem> _applyFilters(List<NewPickupItem> pickups) {
    List<NewPickupItem> filtered = List.from(pickups);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((pickup) {
        final householdName = pickup.householdName?.toLowerCase() ?? '';
        final collectorName = pickup.assignedCollectorName?.toLowerCase() ?? '';
        final address = pickup.addressShort?.toLowerCase() ?? '';

        return householdName.contains(query) ||
            collectorName.contains(query) ||
            address.contains(query);
      }).toList();
    }

    // Apply multi-criteria sorting
    filtered.sort((a, b) {
      // Iterate through selected sort criteria in order
      for (final sortCriteria in _sortBy) {
        int comparison = 0;

        switch (sortCriteria) {
          case 'date':
            final dateA = a.createdAt ?? DateTime(2020);
            final dateB = b.createdAt ?? DateTime(2020);
            comparison = dateA.compareTo(dateB);
            break;
          case 'name':
            final nameA = a.householdName?.toLowerCase() ?? '';
            final nameB = b.householdName?.toLowerCase() ?? '';
            comparison = nameA.compareTo(nameB);
            break;
          case 'collector':
            final collectorA = a.assignedCollectorName?.toLowerCase() ?? '';
            final collectorB = b.assignedCollectorName?.toLowerCase() ?? '';
            comparison = collectorA.compareTo(collectorB);
            break;
          case 'items':
            final itemsA = a.items.length;
            final itemsB = b.items.length;
            comparison = itemsA.compareTo(itemsB);
            break;
        }

        // If this criteria produces a difference, return it
        if (comparison != 0) {
          return _sortAscending ? comparison : -comparison;
        }
        // Otherwise continue to next criteria
      }

      return 0; // All criteria equal
    });

    return filtered;
  }

  List<CollectorAssignment> _applyFiltersToAssignments(
    List<CollectorAssignment> assignments,
  ) {
    List<CollectorAssignment> filtered = List.from(assignments);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((assignment) {
        final collectorName = assignment.collectorName.toLowerCase();

        // Check collector name
        if (collectorName.contains(query)) return true;

        // Check any pickup's household name or address
        for (final pickup in assignment.pickups) {
          final householdName = pickup.householdName?.toLowerCase() ?? '';
          final address = pickup.addressShort?.toLowerCase() ?? '';

          if (householdName.contains(query) || address.contains(query)) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    // Apply multi-criteria sorting
    filtered.sort((a, b) {
      // Iterate through selected sort criteria in order
      for (final sortCriteria in _sortBy) {
        int comparison = 0;

        switch (sortCriteria) {
          case 'date':
            final dateA = a.pickups.isNotEmpty
                ? (a.pickups.first.createdAt ?? DateTime(2020))
                : DateTime(2020);
            final dateB = b.pickups.isNotEmpty
                ? (b.pickups.first.createdAt ?? DateTime(2020))
                : DateTime(2020);
            comparison = dateA.compareTo(dateB);
            break;
          case 'name':
            final nameA = a.pickups.isNotEmpty
                ? (a.pickups.first.householdName?.toLowerCase() ?? '')
                : '';
            final nameB = b.pickups.isNotEmpty
                ? (b.pickups.first.householdName?.toLowerCase() ?? '')
                : '';
            comparison = nameA.compareTo(nameB);
            break;
          case 'collector':
            final collectorA = a.collectorName.toLowerCase();
            final collectorB = b.collectorName.toLowerCase();
            comparison = collectorA.compareTo(collectorB);
            break;
          case 'items':
            final itemsA = a.pickupCount;
            final itemsB = b.pickupCount;
            comparison = itemsA.compareTo(itemsB);
            break;
        }

        // If this criteria produces a difference, return it
        if (comparison != 0) {
          return _sortAscending ? comparison : -comparison;
        }
        // Otherwise continue to next criteria
      }

      return 0; // All criteria equal
    });

    return filtered;
  }

  // Top-level TabBar is moved into AppBar.bottom to mirror collector header

  Widget _buildTabWithBadge(String text, bool showBadge) {
    return Tab(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(text),
          if (showBadge)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.junkshopPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _capitalizeName(String? name) {
    if (name == null || name.isEmpty) return 'Household';
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildNewPickupsTab(),
        _buildAssignedPickupsTab(),
        _buildReassignedPickupsTab(),
        _buildPayTab(),
      ],
    );
  }

  Widget _buildNewPickupsTab() {
    // Filter out reschedule status - they should only appear in Reassigned tab
    final newOnly = _newPickups.where((p) => p.status != 'reschedule').toList();
    final filtered = _applyFilters(newOnly);

    if (_loadingNew) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorNew != null) {
      return _buildErrorState(
        code: _errorNewCode,
        message: _errorNew!,
        onRetry: _fetchNewPickups,
      );
    }
    if (filtered.isEmpty) {
      return _buildEmptyState(
        newOnly.isEmpty ? 'No new postings yet' : 'No pickups match filters',
        FluentIcons.document_24_regular,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchNewPickups,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final pickup = filtered[index];
          return _buildNewPickupCardFromPosting(pickup);
        },
      ),
    );
  }

  Future<void> _fetchNewPickups() async {
    setState(() {
      _loadingNew = true;
      _errorNew = null;
    });
    try {
      final repo = getIt<IJunkshopPickupsRepository>();
      final data = await repo.fetchNewPickups();
      if (!mounted) return;
      setState(() {
        _newPickups = data;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorNewCode = e.code;
        _errorNew = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorNew = e.toString();
        _errorNewCode = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingNew = false;
        });
      }
    }
  }

  Future<void> _fetchReschedulePickups() async {
    setState(() {
      _loadingReschedule = true;
      _errorReschedule = null;
    });
    try {
      final junkshopId = currentUid;
      if (junkshopId == null) {
        setState(() {
          _rescheduleOnlyPickups = [];
        });
      } else {
        final snapshot = await JunkshopQuery.postings(
          junkshopId,
          statuses: ['reschedule'],
        );

        final items = <NewPickupItem>[];
        for (final d in snapshot.docs) {
          final data = d.data();

          // Extract items (handle both legacy list and new nested structure)
          final itemsList = <String>[];
          final imageUrls = <String>[];
          final itemDetails = <ItemDetail>[];

          // Get totalEstimatedValue from items object
          double totalValue = 0.0;
          if (data['items'] is Map) {
            final itemsMap = data['items'] as Map;
            if (itemsMap['totalEstimatedValue'] is num) {
              totalValue = (itemsMap['totalEstimatedValue'] as num).toDouble();
            }
          }

          dynamic rawItems = data['items'];
          if (rawItems is Map) {
            rawItems = rawItems['list'];
          }

          if (rawItems is List) {
            for (final item in rawItems) {
              if (item is Map) {
                final name = item['name']?.toString() ?? '';
                final quantityStr = item['quantity']?.toString() ?? '';
                final unit = item['unit']?.toString() ?? '';
                final estimatedValue = (item['estimatedValue'] is num)
                    ? (item['estimatedValue'] as num).toDouble()
                    : 0.0;

                final quantity = double.tryParse(quantityStr) ?? 1.0;
                final pricePerUnit = quantity > 0
                    ? estimatedValue / quantity
                    : 0.0;

                if (name.isNotEmpty) {
                  itemsList.add('$name ($quantityStr $unit)');
                }

                // Extract images
                if (item['images'] is List) {
                  for (final img in item['images']) {
                    if (img is String && img.isNotEmpty) {
                      imageUrls.add(img);
                    }
                  }
                } else if (item['imagePaths'] is List) {
                  // Handle imagePaths field if present (seen in repository)
                  for (final img in item['imagePaths']) {
                    if (img is String && img.isNotEmpty) {
                      imageUrls.add(img);
                    }
                  }
                }

                // Create ItemDetail with prices
                itemDetails.add(
                  ItemDetail(
                    name: name,
                    quantity: quantityStr,
                    unit: unit,
                    condition: item['condition']?.toString() ?? '',
                    category: item['category']?.toString(),
                    imagePaths:
                        (item['images'] as List?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        (item['imagePaths'] as List?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [],
                    pricePerUnit: pricePerUnit,
                    totalPrice: estimatedValue,
                    promotionBoostPercentage:
                        (item['promotionBoostPercentage'] as num?)?.toDouble(),
                  ),
                );
              }
            }
          }

          final DateTime? createdAt = toDateTime(data['createdAt']);

          // Get collector info from reschedule object (new structure)
          String? previousCollectorName;
          String? previousCollectorId;
          String? previousCollectorPhoto;

          if (data['reschedule'] is Map) {
            final rescheduleData = data['reschedule'] as Map;
            previousCollectorName = rescheduleData['rescheduledByName']
                ?.toString();
            previousCollectorId = rescheduleData['rescheduledById']?.toString();
            previousCollectorPhoto = rescheduleData['rescheduledByPhoto']
                ?.toString();
          }

          // Fallback: try old top-level fields for backward compatibility
          if (previousCollectorName == null) {
            previousCollectorName = data['previousCollectorName']?.toString();
            previousCollectorId = data['previousCollectorId']?.toString();
            previousCollectorPhoto = data['previousCollectorPhoto']?.toString();
          }

          // If previousCollectorName is "Unknown Collector" and we have an ID, fetch from users collection
          if ((previousCollectorName == null ||
                  previousCollectorName == 'Unknown Collector') &&
              previousCollectorId != null) {
            try {
              final userData = await supabase
                  .from('collectors')
                  .select('full_name, profile_image_url')
                  .eq('id', previousCollectorId)
                  .maybeSingle();
              if (userData != null) {
                previousCollectorName = userData['full_name']?.toString();
                previousCollectorPhoto = userData['profile_image_url']
                    ?.toString();
              }

              // If still no name, use collector ID as fallback display
              if (previousCollectorName == null ||
                  previousCollectorName == 'Unknown Collector') {
                previousCollectorName =
                    'Collector ${previousCollectorId.substring(0, 8)}';
              }
            } catch (e) {
              // Use collector ID as fallback
              previousCollectorName =
                  'Collector ${previousCollectorId.substring(0, 8)}';
            }
          }

          // Fallback: try to get from collector field if previousCollectorName is still null
          if (previousCollectorName == null && data['collector'] is Map) {
            final collectorData = data['collector'] as Map;
            previousCollectorName =
                collectorData['full_name']?.toString() ??
                collectorData['name']?.toString();
            previousCollectorId = collectorData['id']?.toString();
            previousCollectorPhoto =
                collectorData['profile_image_url']?.toString() ??
                collectorData['photo']?.toString();
          }

          // Get household name - try multiple possible fields
          String? householdName;
          if (data['household'] is Map) {
            final householdData = data['household'] as Map;
            householdName =
                householdData['full_name']?.toString() ??
                householdData['name']?.toString();
          }
          if (householdName == null && data['householdName'] != null) {
            householdName = data['householdName']?.toString();
          }

          // Get profile image - try multiple possible fields
          String? profileImageUrl;
          if (data['household'] is Map) {
            final householdData = data['household'] as Map;
            profileImageUrl =
                householdData['profile_image_url']?.toString() ??
                householdData['profileImageUrl']?.toString();
          }
          profileImageUrl ??=
              data['profile_image_url']?.toString() ??
              data['profileImageUrl']?.toString();

          // Get reschedule request date
          DateTime? rescheduleRequestedAt;
          List<String>? rescheduleReasons;
          String? rescheduleDetail;

          if (data['reschedule'] is Map) {
            final rescheduleData = data['reschedule'] as Map;
            rescheduleRequestedAt = toDateTime(rescheduleData['rescheduledAt']);

            // Extract reschedule reasons and detail
            if (rescheduleData['rescheduleReasons'] is List) {
              rescheduleReasons = (rescheduleData['rescheduleReasons'] as List)
                  .map((e) => e.toString())
                  .toList();
            }
            rescheduleDetail = rescheduleData['rescheduleDetail']?.toString();
          }

          // Extract address
          String? addressShort;
          if (data['location'] is Map) {
            addressShort = data['location']['address']?.toString();
          }
          addressShort ??= data['address']?.toString();

          // Extract special instructions
          String? specialInstructions =
              data['specialInstructions']?.toString() ??
              data['notes']?.toString();

          // Extract unavailable dates (dates household is NOT available)
          List<DateTime>? unavailableDates;
          if (data['unavailableDates'] is List) {
            unavailableDates = (data['unavailableDates'] as List)
                .map((d) => toDateTime(d))
                .whereType<DateTime>()
                .toList();
          }

          // Extract scheduled date/time
          final DateTime? scheduledDate = toDateTime(data['scheduledDate']);
          String? scheduledTime = data['scheduledTime']?.toString();

          // Extract householdId
          final extractedHouseholdId = data['householdId']?.toString() ?? '';

          items.add(
            NewPickupItem(
              id: d.id,
              householdId: extractedHouseholdId,
              totalValue: totalValue,
              items: itemsList,
              itemDetails: itemDetails,
              status: data['status']?.toString(),
              previousCollector: previousCollectorName,
              previousCollectorId: previousCollectorId,
              previousCollectorPhoto: previousCollectorPhoto,
              rescheduleRequestedAt: rescheduleRequestedAt,
              rescheduleReasons: rescheduleReasons,
              rescheduleDetail: rescheduleDetail,
              householdName: householdName,
              profileImageUrl: profileImageUrl,
              imageUrls: imageUrls,
              categories: const [],
              createdAt: createdAt,
              addressShort: addressShort,
              specialInstructions: specialInstructions,
              unavailableDates: unavailableDates,
              scheduledDate: scheduledDate,
              scheduledTime: scheduledTime,
            ),
          );
        }

        setState(() {
          _rescheduleOnlyPickups = items;
        });
      }
    } catch (e) {
      setState(() {
        _errorReschedule = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingReschedule = false;
        });
      }
    }
  }

  Future<void> _fetchAssignedPickups() async {
    if (kDebugMode) print('DEBUG: _fetchAssignedPickups called');
    setState(() {
      _loadingAssigned = true;
      _errorAssigned = null;
    });
    try {
      final repo = getIt<IJunkshopPickupsRepository>();
      final collectorData = await repo.fetchAssignedPickupsByCollector();
      if (kDebugMode) {
        print('DEBUG: Fetched ${collectorData.length} collector assignments');
      }
      if (!mounted) return;
      setState(() {
        _collectorAssignments = collectorData;
        if (kDebugMode) {
          print(
            'DEBUG: Set state with ${_collectorAssignments.length} collector assignments',
          );
        }
      });
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        print(
          'DEBUG: PostgrestException in _fetchAssignedPickups: ${e.code} - ${e.message}',
        );
      }
      if (!mounted) return;
      setState(() {
        _errorAssignedCode = e.code;
        _errorAssigned = e.message;
      });
    } catch (e) {
      if (kDebugMode) print('DEBUG: Exception in _fetchAssignedPickups: $e');
      if (!mounted) return;
      setState(() {
        _errorAssigned = e.toString();
        _errorAssignedCode = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAssigned = false;
        });
      }
    }
  }

  Future<void> _fetchCompletedPickups() async {
    if (kDebugMode) print('DEBUG: _fetchCompletedPickups called');
    if (kDebugMode) {
      print('DEBUG: Locally reviewed pickup IDs: $_locallyReviewedPickupIds');
    }
    setState(() {
      _loadingCompleted = true;
      _errorCompleted = null;
    });
    try {
      final repo = getIt<IJunkshopPickupsRepository>();
      final collectorData = await repo.fetchCompletedPickupsByCollector();
      if (kDebugMode) {
        print(
          'DEBUG: Fetched ${collectorData.length} completed collector assignments',
        );
      }

      // Filter to show only unreviewed collections (isReviewed != true) in Pay tab
      // Also exclude locally reviewed items that might not have synced to Firestore yet
      final unreviewedAssignments = collectorData
          .map((assignment) {
            final unreviewedPickups = assignment.pickups.where((pickup) {
              final isReviewedInFirestore = pickup.isReviewed == true;
              final isLocallyReviewed = _locallyReviewedPickupIds.contains(
                pickup.id,
              );
              if (kDebugMode) {
                print(
                  'DEBUG: Pickup ${pickup.id}: isReviewed=${pickup.isReviewed}, locallyReviewed=$isLocallyReviewed',
                );
              }
              return !isReviewedInFirestore && !isLocallyReviewed;
            }).toList();

            if (unreviewedPickups.isEmpty) return null;

            return CollectorAssignment(
              collectorId: assignment.collectorId,
              collectorName: assignment.collectorName,
              collectorPhoto: assignment.collectorPhoto,
              pickups: unreviewedPickups,
              totalEstimatedValue: unreviewedPickups.fold<double>(
                0,
                (acc, p) => acc + p.totalValue,
              ),
              pickupCount: unreviewedPickups.length,
            );
          })
          .whereType<CollectorAssignment>()
          .toList();

      if (kDebugMode) {
        print(
          'DEBUG: Filtered to ${unreviewedAssignments.length} unreviewed assignments',
        );
      }

      if (!mounted) return;
      setState(() {
        _completedCollectorAssignments = unreviewedAssignments;
        if (kDebugMode) {
          print(
            'DEBUG: Set state with ${_completedCollectorAssignments.length} unreviewed assignments',
          );
        }
      });
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        print(
          'DEBUG: PostgrestException in _fetchCompletedPickups: ${e.code} - ${e.message}',
        );
      }
      if (!mounted) return;
      setState(() {
        _errorCompletedCode = e.code;
        _errorCompleted = e.message;
      });
    } catch (e) {
      if (kDebugMode) print('DEBUG: Exception in _fetchCompletedPickups: $e');
      if (!mounted) return;
      setState(() {
        _errorCompleted = e.toString();
        _errorCompletedCode = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCompleted = false;
        });
      }
    }
  }

  Widget _buildNewPickupCardFromPosting(NewPickupItem p) {
    // Adapt to existing card renderer by mapping to the expected structure
    if (kDebugMode) {
      print(
        'DEBUG _buildNewPickupCardFromPosting: p.imageUrls = ${p.imageUrls}',
      );
    }
    if (kDebugMode) {
      print(
        'DEBUG _buildNewPickupCardFromPosting: p.itemDetails = ${p.itemDetails}',
      );
    }
    if (kDebugMode) {
      print(
        'DEBUG _buildNewPickupCardFromPosting: p.itemDetails.length = ${p.itemDetails.length}',
      );
    }

    // Format distance - always show in km
    String distanceStr = '—';
    if (p.distanceKm != null) {
      distanceStr = '${p.distanceKm!.toStringAsFixed(2)}km';
    }

    // Use full address if available, otherwise fall back to addressShort
    final locationStr = (p.fullAddress != null && p.fullAddress!.isNotEmpty)
        ? p.fullAddress!
        : (p.addressShort != null && p.addressShort!.isNotEmpty)
        ? p.addressShort!
        : 'Location unavailable';

    final map = <String, dynamic>{
      'id': p.id, // Add posting ID
      'householdId': p.householdId, // Add household ID for Firebase query
      'status': 'pending', // New pickups are pending
      'avatar': p.profileImageUrl, // may be null
      'household': (p.householdName == null || p.householdName!.isEmpty)
          ? 'Household'
          : p.householdName!,
      'distance': distanceStr,
      'value': p.totalValue,
      'estimatedTotalWeight': p.estimatedTotalWeight,
      'items': p.items,
      'itemDetails':
          p.itemDetails, // Pass itemDetails for displaying material names
      'categories': p.categories, // Pass all categories
      'location': locationStr,
      'timePosted': p.createdAt != null
          ? _relativeTime(p.createdAt!)
          : 'Just now',
      'createdAt': p.createdAt, // Add createdAt timestamp
      'priority': 'medium',
      'postingId': p.id,
      'unavailableDates': p.unavailableDates,
      'scheduledDate': p.scheduledDate,
      'scheduledTime': p.scheduledTime,
      'specialInstructions': p.specialInstructions,
      'imageUrls': p.imageUrls,
    };
    return _buildNewPickupCard(map);
  }

  Widget _buildCollectorCard(CollectorAssignment assignment) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collector Header
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Collector Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      (assignment.collectorPhoto != null &&
                          assignment.collectorPhoto!.isNotEmpty &&
                          (assignment.collectorPhoto!.startsWith('http://') ||
                              assignment.collectorPhoto!.startsWith(
                                'https://',
                              )))
                      ? AppImageProvider(assignment.collectorPhoto!)
                      : null,
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.1,
                  ),
                  child:
                      (assignment.collectorPhoto == null ||
                          assignment.collectorPhoto!.isEmpty ||
                          !(assignment.collectorPhoto!.startsWith('http://') ||
                              assignment.collectorPhoto!.startsWith(
                                'https://',
                              )))
                      ? Text(
                          assignment.collectorName[0].toUpperCase(),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.collectorName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${assignment.pickupCount} ${assignment.pickupCount == 1 ? 'pickup' : 'pickups'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '₱${assignment.totalEstimatedValue.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: AppColors.borderLight),

          // Assigned Pickups List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            itemCount: assignment.pickups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final pickup = assignment.pickups[index];
              return _buildCollectorPickupCard(
                pickup,
                assignment.collectorName,
              );
            },
          ),
        ],
      ),
    );
  }

  // Compact pickup card for collector's assignment list
  Widget _buildCollectorPickupCard(NewPickupItem pickup, String collectorName) {
    return InkWell(
      onTap: () {
        if (kDebugMode) print('🔍 CARD TAP: Building pickupMap for modal');
        if (kDebugMode) print('  householdId: ${pickup.householdId}');
        if (kDebugMode) print('  householdName: ${pickup.householdName}');
        if (kDebugMode) print('  profileImageUrl: ${pickup.profileImageUrl}');
        if (kDebugMode) print('  addressShort: ${pickup.addressShort}');

        final pickupMap = {
          'id': pickup.id,
          'householdId': pickup.householdId,
          'household': pickup.householdName ?? 'Unknown Household',
          'householdName': pickup.householdName ?? 'Unknown Household',
          'addressShort': pickup.addressShort,
          'avatar': pickup.profileImageUrl,
          'profileImageUrl': pickup.profileImageUrl,
          'totalValue': pickup.totalValue,
          'items': pickup.items,
          'imageUrls': pickup.imageUrls,
          'createdAt': pickup.createdAt,
          'scheduledDate': pickup.scheduledDate,
          'scheduledTime': pickup.scheduledTime,
          'specialInstructions': pickup.specialInstructions,
          'unavailableDates': pickup.unavailableDates,
          'dateOfCollection': pickup.dateOfCollection,
          'status': 'assigned',
          'collectionFee': null,
        };

        if (kDebugMode) print('🔍 CARD TAP: pickupMap created:');
        if (kDebugMode) print('  household: ${pickupMap['household']}');
        if (kDebugMode) print('  avatar: ${pickupMap['avatar']}');

        _showPickupDetailsModal(pickupMap);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pickup.householdName ?? 'Household',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (pickup.distanceKm != null) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.junkshopPrimary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${pickup.distanceKm!.toStringAsFixed(1)} km',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.junkshopPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (pickup.distanceKm != null &&
                          pickup.dateOfCollection != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (pickup.dateOfCollection != null) ...[
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            _formatTimestamp(pickup.dateOfCollection!),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (pickup.items.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pickup.items.take(2).join(', '),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₱${pickup.totalValue.toStringAsFixed(0)}',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.junkshopPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hintForError(String? code, String message) {
    switch (code) {
      case 'permission-denied':
        return 'Firestore rules are blocking reads. Allow authenticated users to read collection group postings (households/*/postings).';
      case 'unauthenticated':
        return 'User session is not authenticated. Please log in again.';
      case 'unavailable':
        return 'Network/Firestore might be temporarily unavailable. Try again in a moment.';
      case 'failed-precondition':
        return 'A required index or precondition failed. We removed server-side ordering to avoid this; retry now.';
      default:
        return '';
    }
  }

  Widget _buildErrorState({
    String? code,
    required String message,
    required Future<void> Function() onRetry,
  }) {
    final hint = _hintForError(code, message);
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: CustomCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Something went wrong',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (code != null)
              Text(
                'Error code: $code',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 4),
            Text(message, style: AppTextStyles.bodySmall),
            if (hint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Fallback to a simple date
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAssignedPickupsTab() {
    // Filter out reschedule status pickups - they should only appear in Reassigned tab
    final assignedOnly = _collectorAssignments
        .map((assignment) {
          // Apply filters to each assignment's pickups
          final filteredPickups = _applyFilters(
            assignment.pickups.where((p) => p.status != 'reschedule').toList(),
          );

          return CollectorAssignment(
            collectorId: assignment.collectorId,
            collectorName: assignment.collectorName,
            collectorPhoto: assignment.collectorPhoto,
            pickups: filteredPickups,
            totalEstimatedValue: filteredPickups.fold<double>(
              0,
              (acc, p) => acc + p.totalValue,
            ),
            pickupCount: filteredPickups.length,
          );
        })
        .where((assignment) => assignment.pickupCount > 0)
        .toList();

    if (_loadingAssigned) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAssigned != null) {
      return _buildErrorState(
        code: _errorAssignedCode,
        message: _errorAssigned!,
        onRetry: _fetchAssignedPickups,
      );
    }
    if (assignedOnly.isEmpty) {
      final hasUnfilteredData = _collectorAssignments.any(
        (a) => a.pickups.where((p) => p.status != 'reschedule').isNotEmpty,
      );
      return _buildEmptyState(
        hasUnfilteredData ? 'No pickups match filters' : 'No assigned pickups',
        FluentIcons.box_24_regular,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAssignedPickups,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        itemCount: assignedOnly.length,
        itemBuilder: (context, index) {
          final assignment = assignedOnly[index];
          return _buildCollectorCard(assignment);
        },
      ),
    );
  }

  Widget _buildPayTab() {
    // Show error if any
    if (_errorCompleted != null) {
      return _buildErrorState(
        code: _errorCompletedCode,
        message: _errorCompleted!,
        onRetry: _fetchCompletedPickups,
      );
    }

    // Show loading
    if (_loadingCompleted) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    // Apply filters to assignments
    final filteredAssignments = _applyFiltersToAssignments(
      _completedCollectorAssignments,
    );

    // Show empty state if no results after filtering
    if (filteredAssignments.isEmpty) {
      return _buildEmptyState(
        'No collections to review',
        FluentIcons.checkmark_circle_24_regular,
      );
    }

    // Show collectors with their completed pickups
    return RefreshIndicator(
      onRefresh: _fetchCompletedPickups,
      color: AppColors.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        itemCount: filteredAssignments.length,
        itemBuilder: (context, index) {
          final assignment = filteredAssignments[index];
          return _buildCollectorReviewCard(
            assignment.collectorId,
            assignment.collectorName,
            assignment.pickups,
          );
        },
      ),
    );
  }

  Widget _buildReassignedPickupsTab() {
    final filtered = _applyFilters(_rescheduleOnlyPickups);

    if (_loadingReschedule) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorReschedule != null) {
      return _buildErrorState(
        code: _errorRescheduleCode,
        message: _errorReschedule!,
        onRetry: _fetchReschedulePickups,
      );
    }
    if (filtered.isEmpty) {
      return _buildEmptyState(
        _rescheduleOnlyPickups.isEmpty
            ? 'No reassignment requests'
            : 'No pickups match filters',
        FluentIcons.arrow_swap_24_regular,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReschedulePickups,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _buildReschedulePickupCard(filtered[index]),
      ),
    );
  }

  Widget _buildReschedulePickupCard(NewPickupItem pickup) {
    final previousCollectorName =
        pickup.previousCollector ?? 'Unknown Collector';
    final householdName = pickup.householdName ?? 'Household';
    final requestDate = pickup.rescheduleRequestedAt != null
        ? _formatTimestamp(pickup.rescheduleRequestedAt!)
        : 'Recently';

    // Debug: Print pickup data to verify
    if (kDebugMode) print('🔍 RESCHEDULE CARD DATA:');
    if (kDebugMode) print('  Household: $householdName');
    if (kDebugMode) print('  Collector: $previousCollectorName');
    if (kDebugMode) print('  Items count: ${pickup.items.length}');
    if (kDebugMode) print('  Items: ${pickup.items}');
    if (kDebugMode) print('  Address: ${pickup.addressShort}');
    if (kDebugMode) {
      print('  Special Instructions: ${pickup.specialInstructions}');
    }
    if (kDebugMode) print('  Images count: ${pickup.imageUrls.length}');

    return InkWell(
      onTap: () {
        // Convert ItemDetail objects to maps for the modal
        final itemsWithPrices = pickup.itemDetails.map((detail) {
          // Parse quantity - it's stored as a string like "1" or "2.5"
          final quantityNum = double.tryParse(detail.quantity) ?? 1.0;

          return {
            'name': detail.name,
            'quantity': quantityNum, // Convert to number
            'unit': detail.unit,
            'category': detail.category ?? 'Mixed',
            'condition': detail.condition,
            'estimatedValue': detail.totalPrice ?? 0.0,
            'pricePerUnit': detail.pricePerUnit ?? 0.0,
            'images': detail.imagePaths,
          };
        }).toList();

        final pickupMap = {
          'id': pickup.id,
          'householdId': pickup.householdId,
          'household': pickup.householdName ?? 'Unknown Household',
          'householdName': pickup.householdName ?? 'Unknown Household',
          'addressShort': pickup.addressShort,
          'avatar': pickup.profileImageUrl,
          'profileImageUrl': pickup.profileImageUrl,
          'totalValue': pickup.totalValue,
          'items':
              itemsWithPrices, // Use itemDetails with prices instead of string items
          'imageUrls': pickup.imageUrls,
          'createdAt': pickup.createdAt,
          'scheduledDate': pickup.scheduledDate,
          'scheduledTime': pickup.scheduledTime,
          'specialInstructions': pickup.specialInstructions,
          'unavailableDates': pickup.unavailableDates,
          'dateOfCollection': pickup.dateOfCollection,
          'status': 'reschedule',
          'rescheduleRequestedAt': pickup.rescheduleRequestedAt,
          'rescheduleReasons': pickup.rescheduleReasons,
          'rescheduleDetail': pickup.rescheduleDetail,
          'previousCollector': pickup.previousCollector,
          'previousCollectorId': pickup.previousCollectorId,
          'previousCollectorPhoto': pickup.previousCollectorPhoto,
          'collectionFee': null,
        };
        _showPickupDetailsModal(pickupMap);
      },
      borderRadius: BorderRadius.circular(8),
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Household name + value
              Row(
                children: [
                  Expanded(
                    child: Text(
                      householdName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₱${pickup.totalValue.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.junkshopPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reschedule status with orange indicator
              Row(
                children: [
                  Icon(
                    FluentIcons.arrow_sync_24_regular,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Reschedule Request',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    requestDate,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Previous collector info - inline with clear label
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Requested by: ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    previousCollectorName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Reassign Button - compact
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showReassignDialog(pickup);
                  },
                  icon: const Icon(FluentIcons.arrow_swap_24_regular, size: 16),
                  label: const Text('Reassign Collector'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectorReviewCard(
    String collectorId,
    String collectorName,
    List<NewPickupItem> pickups,
  ) {
    final totalValue = pickups.fold<double>(0, (acc, p) => acc + p.totalValue);
    final totalCollections = pickups.length;

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collector Header
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Collector Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      (pickups.first.assignedCollectorPhoto != null &&
                          pickups.first.assignedCollectorPhoto!.isNotEmpty &&
                          (pickups.first.assignedCollectorPhoto!.startsWith(
                                'http://',
                              ) ||
                              pickups.first.assignedCollectorPhoto!.startsWith(
                                'https://',
                              )))
                      ? AppImageProvider(
                          pickups.first.assignedCollectorPhoto!,
                        )
                      : null,
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.1,
                  ),
                  child:
                      (pickups.first.assignedCollectorPhoto == null ||
                          pickups.first.assignedCollectorPhoto!.isEmpty ||
                          !(pickups.first.assignedCollectorPhoto!.startsWith(
                                'http://',
                              ) ||
                              pickups.first.assignedCollectorPhoto!.startsWith(
                                'https://',
                              )))
                      ? Text(
                          collectorName[0].toUpperCase(),
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppDimensions.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collectorName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$totalCollections ${totalCollections == 1 ? 'collection' : 'collections'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₱${totalValue.toStringAsFixed(0)} total',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Household Collections List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            itemCount: pickups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildCompactCollectionReviewItem(pickups[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCollectionReviewItem(NewPickupItem pickup) {
    final householdName = pickup.householdName ?? 'Unknown Household';
    // Use dateOfCollection (scheduled date) or createdAt as fallback
    final collectionDate = pickup.dateOfCollection ?? pickup.createdAt;
    final completedDate = collectionDate != null
        ? _formatTimestamp(collectionDate)
        : 'No date';
    final itemCount = pickup.itemDetails.length;

    return InkWell(
      onTap: () => _showCollectionDetailsBottomSheet(pickup),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    householdName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        completedDate,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.recycling,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
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
            // Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${pickup.totalValue.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.junkshopPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCollectionDetailsBottomSheet(NewPickupItem pickup) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header with avatar, name, actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(pickup.profileImageUrl, size: 48),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _capitalizeName(
                                          pickup.householdName ?? 'Household',
                                        ),
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _buildContactActions(
                                      _capitalizeName(
                                        pickup.householdName ?? 'Household',
                                      ),
                                      postingId: pickup.id,
                                      householdId: pickup.householdId,
                                    ),
                                  ],
                                ),
                                // Posting ID
                                Transform.translate(
                                  offset: const Offset(0, -8),
                                  child: Text(
                                    pickup.id,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                // Created date/time
                                Transform.translate(
                                  offset: const Offset(0, -4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatFullDateTime(pickup.createdAt),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.spacing16),

                    // Proof photos - use same display as assigned tab
                    Builder(
                      builder: (context) {
                        // Combine all proof photos from collector
                        final List<String> allPhotos = [];

                        if (pickup.proofPhotos.containsKey('arrival')) {
                          allPhotos.addAll(pickup.proofPhotos['arrival']!);
                        }
                        if (pickup.proofPhotos.containsKey('collection')) {
                          allPhotos.addAll(pickup.proofPhotos['collection']!);
                        }
                        if (pickup.proofPhotos.containsKey('before_after')) {
                          allPhotos.addAll(pickup.proofPhotos['before_after']!);
                        }

                        // Add payment proof photos
                        allPhotos.addAll(pickup.paymentProofUrls);

                        // Convert to Map format expected by _buildModalImagesSection
                        final pickupMap = <String, dynamic>{
                          'imageUrls': allPhotos,
                        };

                        return _buildModalImagesSection(pickupMap);
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacing16),

                    // Schedule Section
                    if (pickup.dateOfCollection != null) ...[
                      Text(
                        'Schedule',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.event_available,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Collection Date',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTimestamp(
                                          pickup.dateOfCollection,
                                        ),
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Address / Location
                    if (pickup.addressShort != null) ...[
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Address',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    pickup.addressShort!,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Collection Summary
                    if (pickup.assignedCollectorName != null) ...[
                      Text(
                        'Collection Summary',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Collector: ${pickup.assignedCollectorName}',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ),
                                if (pickup.assignedCollectorId != null)
                                  IconButton(
                                    onPressed: () async => await _callCollector(
                                      pickup.assignedCollectorId,
                                    ),
                                    icon: const Icon(Icons.phone, size: 20),
                                    color: AppColors.junkshopPrimary,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    tooltip: 'Call collector',
                                  ),
                              ],
                            ),
                            // Add completed time if available in future
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Items Section (Compact Design)
                    if (pickup.itemDetails.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.junkshopPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_rounded,
                                    size: 16,
                                    color: AppColors.junkshopPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Items Collected',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundDark,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${pickup.itemDetails.length} items',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: AppColors.borderLight.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Compact item rows
                            ...pickup.itemDetails.asMap().entries.map((entry) {
                              final item = entry.value;
                              final quantity =
                                  double.tryParse(item.quantity) ?? 1.0;
                              final pricePerUnit = item.pricePerUnit ?? 0.0;
                              final totalPrice =
                                  item.totalPrice ?? (pricePerUnit * quantity);
                              final promotionBoostPercentage =
                                  item.promotionBoostPercentage;
                              final hasBoost =
                                  promotionBoostPercentage != null &&
                                  promotionBoostPercentage > 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.name,
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 14,
                                                      ),
                                                ),
                                              ),
                                              if (hasBoost) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFF10B981),
                                                            Color(0xFF059669),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.trending_up,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '+${promotionBoostPercentage.toStringAsFixed(0)}%',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item.quantity} ${item.unit} × ${AppFormatters.currency(pricePerUnit)}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(totalPrice),
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColors.junkshopPrimary,
                                                fontSize: 14,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Total',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Total divider
                            const SizedBox(height: 4),
                            Container(
                              height: 1,
                              color: AppColors.borderLight.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Total Amount Paid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount Paid',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          AppFormatters.currency(pickup.totalValue),
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.junkshopPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.spacing20),

                    // Review Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _reviewSingleCollection(pickup);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Review This Collection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppDimensions.spacing16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper: Get icon for waste category
  void _reviewSingleCollection(NewPickupItem pickup) {
    _showPricingReviewModal(pickup);
  }

  void _showPricingReviewModal(NewPickupItem pickup) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PricingReviewDialog(
        pickup: pickup,
        onApproved: () async {
          await _fetchCompletedPickups();
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData iconData) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPickupCard(Map<String, dynamic> pickup) {
    // Get materials from items list (same as Assigned tab)
    final items = pickup['items'] as List<dynamic>;
    final materialsText = items.join(', ');

    // Get estimated weight if available
    final estimatedWeight = pickup['estimatedTotalWeight'];

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showPickupDetailsModal(pickup),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatarWithFallback(
                    pickup['avatar'],
                    pickup['household'],
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalizeName(pickup['household']),
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.junkshopPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pickup['distance'],
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.junkshopPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    pickup['timePosted'],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      materialsText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₱${pickup['value'].toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.junkshopPrimary,
                    ),
                  ),
                ],
              ),
              if (estimatedWeight != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.scale_outlined,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${estimatedWeight.toStringAsFixed(1)} kg',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimensions.spacing12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showAssignCollectorModal(pickup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.junkshopPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacing12,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                  ),
                  child: Text(
                    'Assign Collector',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(dynamic avatar, {double size = 40}) {
    final String? imageUrl = avatar is String ? avatar : null;

    // Validate URL format
    final bool isValidUrl =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    if (isValidUrl) {
      return CustomAvatar(
        imageUrl: imageUrl,
        size: size,
        onTap: () => _showImagePreview(imageUrl),
      );
    }

    // For non-URL strings (like names), use first character as initial
    final String initial = imageUrl != null && imageUrl.isNotEmpty
        ? imageUrl[0].toUpperCase()
        : '?';

    // Fallback with initial
    return CustomAvatar(
      initial: initial,
      size: size,
      backgroundColor: AppColors.junkshopPrimary.withValues(alpha: 0.1),
      textColor: AppColors.junkshopPrimary,
    );
  }

  Widget _buildAvatarWithFallback(
    dynamic avatar,
    String name, {
    double size = 40,
  }) {
    final String? imageUrl = avatar is String ? avatar : null;

    // Validate URL format
    final bool isValidUrl =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    if (isValidUrl) {
      return CustomAvatar(
        imageUrl: imageUrl,
        size: size,
        onTap: () => _showImagePreview(imageUrl),
      );
    }

    // Use first letter of name as fallback
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CustomAvatar(
      initial: initial,
      size: size,
      backgroundColor: AppColors.junkshopPrimary.withValues(alpha: 0.1),
      textColor: AppColors.junkshopPrimary,
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;

      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return timestamp.toString();
      }

      // Format as "Mon 20 Oct"
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${days[dateTime.weekday - 1]} ${dateTime.day} ${months[dateTime.month - 1]}';
    } catch (e) {
      return timestamp.toString();
    }
  }

  String _formatFullDateTime(dynamic timestamp) {
    if (timestamp == null) {
      return 'N/A';
    }

    try {
      DateTime dateTime;

      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return timestamp.toString();
      }

      // Format as "Mon 20 Oct, 2:30 PM"
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour == 0 ? 12 : hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '${days[dateTime.weekday - 1]} ${dateTime.day} ${months[dateTime.month - 1]}, $formattedHour:$minute $period';
    } catch (e) {
      return 'Error: ${timestamp.toString()}';
    }
  }

  String _formatRescheduleReason(String reasonKey) {
    const reasonLabels = {
      'bad_weather': 'Bad Weather',
      'traffic_delay': 'Traffic Delay',
      'vehicle_issue': 'Vehicle Issue',
      'time_conflict': 'Schedule Conflict',
      'personal_emergency': 'Personal Emergency',
      'route_optimization': 'Route Optimization',
      'late_running': 'Running Late',
      'equipment_needed': 'Equipment Needed',
      'other': 'Other Reason',
    };

    return reasonLabels[reasonKey] ??
        reasonKey
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
  }

  // Contact actions (call and message) compact row
  Widget _buildContactActions(
    String householdName, {
    String? postingId,
    String? householdId,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _callHousehold(householdId),
          icon: const Icon(Icons.phone, size: 24),
          color: AppColors.junkshopPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Call',
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () =>
              _messageHousehold(householdName, postingId: postingId),
          icon: const Icon(Icons.chat_bubble_outline, size: 24),
          color: AppColors.junkshopPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Message',
        ),
      ],
    );
  }

  Future<void> _callHousehold(String? householdId) async {
    if (householdId == null || householdId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Household ID not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Fetch household phone
      final data = await supabase
          .from('households')
          .select('phone')
          .eq('id', householdId)
          .maybeSingle();

      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Household not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final phoneNumber = data['phone'] as String?;

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await PhoneLauncher.makePhoneCall(phoneNumber);
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
  }

  Future<void> _callCollector(String? collectorId) async {
    if (collectorId == null || collectorId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collector ID not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Fetch collector phone
      final collectorRow = await supabase
          .from('collectors')
          .select()
          .eq('id', collectorId)
          .maybeSingle();

      if (collectorRow == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collector not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ignore: unnecessary_nullable_for_final_variable_declarations
      final Map<String, dynamic>? data = rowToDoc('collectors', collectorRow);

      // Extract from nested collector_profile if needed
      final collectorProfile =
          data?[UserFields.collectorProfile] as Map<String, dynamic>?;
      final contact = collectorProfile?['contact'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;

      // Try multiple field locations for phone number
      final phoneNumber =
          (personal?[UserFields.phone] ??
                  personal?[UserFields.phoneNumber] ??
                  contact?[UserFields.phone] ??
                  contact?[UserFields.phoneNumber] ??
                  data?[UserFields.phone] ??
                  data?[UserFields.phoneNumber] ??
                  data?['phone'] ??
                  '')
              .toString();

      if (phoneNumber.isNotEmpty) {
        await PhoneLauncher.makePhoneCall(phoneNumber);
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
  }

  Future<void> _messageHousehold(String name, {String? postingId}) async {
    if (postingId != null && postingId.isNotEmpty) {
      // Navigate to the conversation for this posting
      if (kDebugMode) print('💬 Fetching conversation for posting: $postingId');

      try {
        final chatRepo = ChatRepository();
        final conversation = await chatRepo.getConversationByPostingId(
          postingId,
        );

        if (conversation != null) {
          if (kDebugMode) print('💬 Conversation found, navigating to chat');
          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  JunkshopChatDetailScreen(conversation: conversation),
            ),
          );
        } else {
          if (kDebugMode) {
            print('❌ Conversation not found for posting: $postingId');
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation not found for this pickup'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error fetching conversation: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening chat with $name...'),
          backgroundColor: AppColors.junkshopPrimary,
        ),
      );
    }
  }

  // Helper method to open pickup details modal for a specific posting ID
  void _openPickupDetailsForPosting(String postingId) {
    // Search in assigned pickups for the matching posting
    for (final assignment in _collectorAssignments) {
      for (final pickup in assignment.pickups) {
        if (pickup.id == postingId) {
          // Found the posting, show its details
          _showPickupDetailsModal({
            'id': pickup.id,
            'postingId': pickup.id,
            'householdId': pickup.householdId,
            'household': pickup.householdName ?? 'Unknown Household',
            'collector': assignment.collectorName,
            'status': 'assigned',
            'avatar': (pickup.householdName?.isNotEmpty ?? false)
                ? pickup.householdName![0].toUpperCase()
                : '?',
          });
          return;
        }
      }
    }

    if (kDebugMode) {
      print(
        '⚠️ Could not find posting with ID: $postingId in assigned pickups',
      );
    }
  }

  // Bottom sheet with full pickup details (images, category price breakdown, location, totals)
  void _showPickupDetailsModal(Map<String, dynamic> pickup) async {
    // Fetch full posting data from Firebase to get complete item details
    final postingId = pickup['id'] ?? pickup['postingId'];
    final householdId = pickup['householdId'];

    Map<String, dynamic>? fullPostingData;
    List<Map<String, dynamic>> detailedItems = [];

    // Validate that both IDs are non-empty strings before attempting to fetch
    if (postingId != null &&
        householdId != null &&
        postingId.toString().isNotEmpty &&
        householdId.toString().isNotEmpty) {
      try {
        if (kDebugMode) {
          print(
            '🔍 Fetching full posting data for: $postingId from household: $householdId',
          );
        }
        final postingRow = await supabase
            .from('postings')
            .select()
            .eq('id', postingId.toString())
            .maybeSingle();

        if (postingRow != null) {
          fullPostingData = rowToDoc('postings', postingRow);
          if (kDebugMode) {
            print('🔍 Full posting data retrieved: ${fullPostingData.keys}');
          }
          if (kDebugMode) {
            print('🔍 RAW items from Firebase: ${fullPostingData['items']}');
          }

          // Extract household data from full posting if available
          final householdData =
              fullPostingData['household'] as Map<String, dynamic>?;
          if (kDebugMode) {
            print('🔍 MODAL: Household data from Firestore: $householdData');
          }
          if (kDebugMode) {
            print(
              '🔍 MODAL: Current pickup map - household: ${pickup["household"]}, avatar: ${pickup["avatar"]}',
            );
          }

          if (householdData != null) {
            // Use Firestore data if available
            if (householdData['full_name'] != null) {
              pickup['household'] = householdData['full_name'];
              pickup['householdName'] = householdData['full_name'];
              if (kDebugMode) {
                print(
                  '🔍 MODAL: Set household name from Firestore: ${pickup["household"]}',
                );
              }
            }
            if (householdData['profile_image_url'] != null) {
              pickup['avatar'] = householdData['profile_image_url'];
              pickup['profileImageUrl'] = householdData['profile_image_url'];
              if (kDebugMode) {
                print(
                  '🔍 MODAL: Set avatar from Firestore: ${pickup["avatar"]}',
                );
              }
            }
          } else {
            // No household data in Firestore, pickup map data should already be set from card
            if (kDebugMode) {
              print(
                '🔍 MODAL: No household data in Firestore, using pickup map data',
              );
            }
            if (kDebugMode) {
              print(
                '🔍 MODAL: household: ${pickup["household"]}, avatar: ${pickup["avatar"]}',
              );
            }
          }

          if (kDebugMode) {
            print(
              '🔍 MODAL: Final values - household: ${pickup["household"]}, avatar: ${pickup["avatar"]}',
            );
          }

          // Extract items with full details - support nested structure
          List? itemsList;
          final itemsData = fullPostingData['items'];
          if (itemsData is Map && itemsData.containsKey('list')) {
            // Nested structure: items.list
            itemsList = itemsData['list'] as List?;
            if (kDebugMode) print('🔍 Using nested items.list structure');
          } else if (itemsData is List) {
            // Legacy structure: items as direct list
            itemsList = itemsData;
            if (kDebugMode) print('🔍 Using legacy items list structure');
          }

          itemsList ??= [];
          if (kDebugMode) print('🔍 Items list length: ${itemsList.length}');

          detailedItems = itemsList.map((item) {
            if (item is Map) {
              final itemMap = Map<String, dynamic>.from(item);
              if (kDebugMode) print('🔍 RAW item map from Firebase: $itemMap');
              if (kDebugMode) {
                print(
                  '🔍 Item fields - name: ${itemMap['name']}, category: ${itemMap['category']}, estimatedValue: ${itemMap['estimatedValue']}, type: ${itemMap['estimatedValue'].runtimeType}',
                );
              }
              return itemMap;
            }
            return <String, dynamic>{
              'name': item.toString(),
              'quantity': 1,
              'unit': 'pcs',
              'category': 'Mixed',
              'estimatedValue': 0.0,
            };
          }).toList();

          if (kDebugMode) {
            print('🔍 Detailed items extracted: ${detailedItems.length} items');
          }
          for (var item in detailedItems) {
            if (kDebugMode) {
              print(
                '🔍 FINAL Item: ${item['name']}, Category: ${item['category']}, Value: ${item['estimatedValue']}, Full item: $item',
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error fetching full posting data: $e');
      }
    }

    if (!mounted) return;
    // Show the modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          // Use the detailed items fetched from Firebase if available
          // Otherwise fall back to parsing from pickup data
          List<Map<String, dynamic>> items = detailedItems;

          if (items.isEmpty) {
            // Fallback: parse from pickup data
            final itemsList = pickup['items'] as List? ?? const [];
            try {
              items = itemsList.map((item) {
                if (item is Map) {
                  return Map<String, dynamic>.from(item);
                } else {
                  return <String, dynamic>{
                    'name': item.toString(),
                    'quantity': 1,
                    'unit': 'pcs',
                    'category': 'Mixed',
                    'estimatedValue': 0.0,
                  };
                }
              }).toList();
            } catch (e) {
              if (kDebugMode) print('❌ Error parsing items: $e');
              items = itemsList
                  .map(
                    (item) => <String, dynamic>{
                      'name': item.toString(),
                      'quantity': 1,
                      'unit': 'pcs',
                      'category': 'Mixed',
                      'estimatedValue': 0.0,
                    },
                  )
                  .toList();
            }
          }

          // Get total estimated value from Firebase (sum of all items calculated when posting was created)
          final double total =
              (fullPostingData?['totalEstimatedValue'] as num?)?.toDouble() ??
              (pickup['value'] as num?)?.toDouble() ??
              // Calculate from items if not available
              items.fold<double>(0.0, (acc, item) {
                final estValue =
                    (item['estimatedValue'] as num?)?.toDouble() ??
                    (item['priceMin'] as num?)?.toDouble() ??
                    (item['priceMax'] as num?)?.toDouble() ??
                    (item['value'] as num?)?.toDouble() ??
                    0.0;
                return acc + estValue;
              });

          if (kDebugMode) {
            print(
              '🔍 Total estimated value: $total (from Firebase: ${fullPostingData?['totalEstimatedValue']}, from pickup: ${pickup['value']}, calculated from items)',
            );
          }

          // Get weight from Firebase data if available, otherwise from pickup map
          final estimatedWeight =
              (fullPostingData?['estimatedTotalWeight'] as num?)?.toDouble() ??
              pickup['estimatedTotalWeight'] as double?;

          if (kDebugMode) {
            print(
              '🔍 Estimated weight: $estimatedWeight (from Firebase: ${fullPostingData?['estimatedTotalWeight']}, from pickup: ${pickup['estimatedTotalWeight']})',
            );
          }

          final collectionFee =
              (fullPostingData?['collectionFee'] as num?)?.toDouble() ??
              (pickup['collectionFee'] as num?)?.toDouble();

          final status = pickup['status']?.toString().toLowerCase() ?? '';
          final canDecline = status == 'pending' || status == 'queued';

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header with avatar, name, actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(
                          pickup['avatar'] ?? pickup['household'] ?? '?',
                          size: 48,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _capitalizeName(pickup['household']),
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _buildContactActions(
                                      _capitalizeName(pickup['household']),
                                      postingId: pickup['id'],
                                      householdId: pickup['householdId'],
                                    ),
                                  ],
                                ),
                                // Posting ID
                                Transform.translate(
                                  offset: const Offset(0, -8),
                                  child: Text(
                                    pickup['id'] ?? 'N/A',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                // Created date/time
                                Transform.translate(
                                  offset: const Offset(0, -4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatFullDateTime(
                                          pickup['createdAt'],
                                        ),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.spacing16),

                    // Images carousel / display - moved to top
                    _buildModalImagesSection(pickup),

                    const SizedBox(height: AppDimensions.spacing16),

                    // Reschedule Information (for reschedule status)
                    if (pickup['status'] == 'reschedule' &&
                        (pickup['rescheduleReasons'] != null ||
                            pickup['rescheduleDetail'] != null ||
                            pickup['rescheduleRequestedAt'] != null)) ...[
                      Builder(
                        builder: (context) {
                          if (kDebugMode) print('🔍 RESCHEDULE MODAL DATA:');
                          if (kDebugMode) {
                            print('  Status: ${pickup['status']}');
                          }
                          if (kDebugMode) {
                            print('  Reasons: ${pickup['rescheduleReasons']}');
                          }
                          if (kDebugMode) {
                            print('  Detail: ${pickup['rescheduleDetail']}');
                          }
                          if (kDebugMode) {
                            print(
                              '  Requested At: ${pickup['rescheduleRequestedAt']}',
                            );
                          }
                          if (kDebugMode) {
                            print(
                              '  Previous Collector: ${pickup['previousCollector']}',
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Text(
                        'Reschedule Request',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Previous collector info
                            if (pickup['previousCollector'] != null) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Requested by',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                        ),
                                        Text(
                                          pickup['previousCollector'],
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade900,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Reschedule date
                            if (pickup['rescheduleRequestedAt'] != null) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Requested on',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                        ),
                                        Text(
                                          _formatFullDateTime(
                                            pickup['rescheduleRequestedAt'],
                                          ),
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade900,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Reschedule reasons
                            if (pickup['rescheduleReasons'] != null &&
                                (pickup['rescheduleReasons'] as List)
                                    .isNotEmpty) ...[
                              const Divider(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reason',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children:
                                              (pickup['rescheduleReasons']
                                                      as List)
                                                  .map((reason) {
                                                    final label =
                                                        _formatRescheduleReason(
                                                          reason.toString(),
                                                        );
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .orange
                                                              .shade400,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        label,
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                              color: Colors
                                                                  .orange
                                                                  .shade900,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    );
                                                  })
                                                  .toList(),
                                        ),

                                        // Show detail right below the reason badges
                                        if (pickup['rescheduleDetail'] !=
                                                null &&
                                            pickup['rescheduleDetail']
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            pickup['rescheduleDetail']
                                                .toString(),
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color: Colors.orange.shade900,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Schedule Information
                    if (pickup['unavailableDates'] != null ||
                        pickup['scheduledDate'] != null) ...[
                      Text(
                        'Schedule',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Scheduled Date & Time (if confirmed)
                            if (pickup['scheduledDate'] != null) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event_available,
                                    size: 18,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Scheduled Pickup',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        Text(
                                          '${_formatTimestamp(pickup['scheduledDate'])}${pickup['scheduledTime'] != null ? ' • ${pickup['scheduledTime']}' : ''}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryGreen,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (pickup['unavailableDates'] != null)
                                const Divider(height: 16),
                            ],

                            // Available Dates (household-provided options)
                            if (pickup['unavailableDates'] != null) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.date_range,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unavailable Dates (Blocked)',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children:
                                              (pickup['unavailableDates']
                                                      as List)
                                                  .map((date) {
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .errorColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: AppColors
                                                              .primaryGreen
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        _formatTimestamp(date),
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppColors
                                                                  .primaryGreen,
                                                              fontSize: 11,
                                                            ),
                                                      ),
                                                    );
                                                  })
                                                  .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Collection Date (assigned by junkshop)
                            if (pickup['dateOfCollection'] != null) ...[
                              const Divider(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.event_available,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Scheduled Collection',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatTimestamp(
                                              pickup['dateOfCollection'],
                                            ),
                                            style: AppTextStyles.bodyLarge
                                                .copyWith(
                                                  color: AppColors.primaryGreen,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Preferred Time (if provided)
                            if (pickup['scheduledTime'] != null &&
                                pickup['scheduledDate'] == null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Preferred Time',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        Text(
                                          pickup['scheduledTime'].toString(),
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Address / Location
                    if (pickup['pickupLocation'] != null ||
                        pickup['addressShort'] != null ||
                        pickup['location'] != null) ...[
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (pickup['pickupLocation'] != null) ...[
                                    Text(
                                      'Pickup Location',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      pickup['pickupLocation'].toString(),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (pickup['addressShort'] != null ||
                                        pickup['location'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        (pickup['addressShort'] ??
                                                pickup['location'])
                                            .toString(),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    Text(
                                      'Address',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      (pickup['addressShort'] ??
                                              pickup['location'] ??
                                              'No address')
                                          .toString(),
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Notes and Special Instructions
                    if (pickup['notes'] != null ||
                        pickup['specialInstructions'] != null) ...[
                      Text(
                        'Additional Information',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pickup['notes'] != null) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.notes,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notes',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        Text(
                                          pickup['notes'].toString(),
                                          style: AppTextStyles.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (pickup['specialInstructions'] != null)
                                const Divider(height: 16),
                            ],
                            if (pickup['specialInstructions'] != null) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.warningColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Special Instructions',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        Text(
                                          pickup['specialInstructions']
                                              .toString(),
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // If this is a completed pickup, show collection summary
                    if (pickup['collector'] != null ||
                        pickup['completedTime'] != null ||
                        pickup['rating'] != null) ...[
                      Text(
                        'Collection Summary',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pickup['collector'] != null)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Collector: ${pickup['collector']}',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            if (pickup['completedTime'] != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Completed ${pickup['completedTime']}',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (pickup['rating'] != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 18,
                                    color: AppColors.warningColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    pickup['rating'].toString(),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Items Section (Compact Design)
                    if (items.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          if (kDebugMode) print('🔍 ITEMS DISPLAY IN MODAL:');
                          if (kDebugMode) {
                            print('  Total items: ${items.length}');
                          }
                          for (var i = 0; i < items.length; i++) {
                            final item = items[i];
                            if (kDebugMode) print('  Item $i: ${item['name']}');
                            if (kDebugMode) {
                              print('    Quantity: ${item['quantity']}');
                            }
                            if (kDebugMode) print('    Unit: ${item['unit']}');
                            if (kDebugMode) {
                              print(
                                '    estimatedValue: ${item['estimatedValue']} (${item['estimatedValue'].runtimeType})',
                              );
                            }
                            if (kDebugMode) print('    Full item data: $item');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.junkshopPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_rounded,
                                    size: 16,
                                    color: AppColors.junkshopPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Items to Collect',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundDark,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${items.length} items',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: AppColors.borderLight.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Compact item rows
                            ...items.asMap().entries.map((entry) {
                              final item = entry.value;
                              final estValue =
                                  (item['estimatedValue'] as num?)
                                      ?.toDouble() ??
                                  (item['priceMin'] as num?)?.toDouble() ??
                                  (item['priceMax'] as num?)?.toDouble() ??
                                  (item['value'] as num?)?.toDouble() ??
                                  0.0;

                              final quantity =
                                  (item['quantity'] as num?)?.toDouble() ?? 1.0;
                              final pricePerUnit = quantity > 0
                                  ? estValue / quantity
                                  : 0.0;

                              final promotionBoostPercentage =
                                  (item['promotionBoostPercentage'] as num?)
                                      ?.toDouble();
                              final hasBoost =
                                  promotionBoostPercentage != null &&
                                  promotionBoostPercentage > 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item['name'] ??
                                                      'Unknown Item',
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 14,
                                                      ),
                                                ),
                                              ),
                                              if (hasBoost) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFF10B981),
                                                            Color(0xFF059669),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.trending_up,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '+${promotionBoostPercentage.toStringAsFixed(0)}%',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['quantity'] ?? 1} ${item['unit'] ?? 'pc'} × ${AppFormatters.currency(pricePerUnit)}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(estValue),
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColors.junkshopPrimary,
                                                fontSize: 14,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Total',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Total earnings divider
                            const SizedBox(height: 4),
                            Container(
                              height: 1,
                              color: AppColors.borderLight.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Estimated Total Weight section
                    if (estimatedWeight != null && estimatedWeight > 0) ...[
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.scale,
                                color: AppColors.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estimated Total Weight',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${estimatedWeight.toStringAsFixed(2)} kg',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                    ],

                    // Totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated Total',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.junkshopPrimary,
                          ),
                        ),
                      ],
                    ),

                    if (collectionFee != null && collectionFee > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Collection Fee',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '₱${collectionFee.toStringAsFixed(2)}',
                            style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.junkshopPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppDimensions.spacing20),

                    // Footer actions
                    if (canDecline) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeclineConfirmation(pickup);
                              },
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Decline'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.errorColor,
                                ),
                                foregroundColor: AppColors.errorColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (_tabController.index == 0) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showAssignCollectorModal(pickup);
                                },
                                icon: const Icon(Icons.assignment_ind),
                                label: const Text('Assign'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.junkshopPrimary,
                                  ),
                                  foregroundColor: AppColors.junkshopPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else if ((_tabController.index == 0))
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAssignCollectorModal(pickup);
                          },
                          icon: const Icon(Icons.assignment_ind),
                          label: const Text('Assign Collector'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.junkshopPrimary,
                            ),
                            foregroundColor: AppColors.junkshopPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      )
                    else if (_tabController.index == 1)
                      // Reassign Collector button for assigned pickups
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAssignCollectorModal(pickup);
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Reassign Collector'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppDimensions.spacing16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeclineConfirmation(Map<String, dynamic> pickup) async {
    final controller = TextEditingController();
    String? errorText;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.errorColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.errorColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Decline Pickup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please provide a reason for declining this pickup request. The household will be notified.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        maxLength: 200,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Reason for declining',
                          errorText: errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: AppColors.errorColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.errorColor),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: AppColors.errorColor,
                              width: 2,
                            ),
                          ),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: AppColors.backgroundLight,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final value = controller.text.trim();
                                if (value.isEmpty) {
                                  setState(
                                    () => errorText = 'Please provide a reason',
                                  );
                                  return;
                                }
                                if (value.length < 10) {
                                  setState(
                                    () => errorText =
                                        'Minimum 10 characters required',
                                  );
                                  return;
                                }
                                Navigator.of(sheetContext).pop(value);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.errorColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (reason != null && reason.trim().isNotEmpty) {
      await _declinePickup(pickup, reason.trim());
    }
  }

  Future<void> _declinePickup(
    Map<String, dynamic> pickup,
    String reason,
  ) async {
    try {
      final pickupId = pickup['id'] as String?;
      final householdId = pickup['householdId'] as String?;

      if (pickupId == null) {
        throw Exception('Pickup ID not found');
      }

      if (householdId == null) {
        throw Exception('Household ID not found');
      }

      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current posting data to check post_attempt
      final postingData = await supabase
          .from('postings')
          .select('post_attempt, scheduled_date, declines')
          .eq('id', pickupId)
          .maybeSingle();

      final currentAttempt = ((postingData?['post_attempt'] ?? 0) as num)
          .toInt();
      final newAttempt = currentAttempt + 1;

      // Check if scheduled date is in the past
      bool shouldClearSchedule = false;
      final scheduleDateTime = toDateTime(postingData?['scheduled_date']);
      if (scheduleDateTime != null && scheduleDateTime.isBefore(DateTime.now())) {
        shouldClearSchedule = true;
        if (kDebugMode) {
          print('📅 Clearing past scheduled date: $scheduleDateTime');
        }
      }

      // Determine decline count label (1st, 2nd, 3rd)
      String declineCount;
      if (newAttempt == 1) {
        declineCount = '1st';
      } else if (newAttempt == 2) {
        declineCount = '2nd';
      } else if (newAttempt == 3) {
        declineCount = '3rd';
      } else {
        declineCount = '${newAttempt}th'; // Fallback for more than 3
      }

      // Nested decline data (declines.{1st|2nd|3rd})
      final declines = Map<String, dynamic>.from(
        (postingData?['declines'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      declines[declineCount] = {
        'declinedAt': DateTime.now().toUtc().toIso8601String(),
        'declinedBy': currentUser.id,
        'declineReason': reason,
      };

      // Update pickup status with nested decline structure
      await supabase
          .from('postings')
          .update({
            'status': 'declined',
            'post_attempt': newAttempt,
            'declines': declines,
            // Clear scheduled date and time if they're in the past
            if (shouldClearSchedule) 'scheduled_date': null,
            if (shouldClearSchedule) 'scheduled_time': null,
          })
          .eq('id', pickupId);

      // Log activity
      final householdName =
          pickup['householdName'] ??
          pickup['household']?['full_name'] ??
          'Customer';
      await supabase.from('activity_logs').insert({
        'junkshop_id': currentUser.id,
        'type': 'collection_declined',
        'title': 'Declined collection from $householdName',
        'details': {
          'postingId': pickupId,
          'householdId': householdId,
          'householdName': householdName,
          'reason': reason,
          'attempt': newAttempt,
        },
      });

      // Send system message to conversation
      try {
        final chatRepo = getIt<ChatRepository>();
        final conversationId = 'posting_$pickupId';

        // Get conversation to verify it exists
        final conversation = await chatRepo.getConversationByPostingId(
          pickupId,
        );

        if (conversation != null) {
          String declineMessage;
          if (newAttempt == 1) {
            declineMessage =
                'Your collection request has been declined. Reason: $reason';
          } else {
            declineMessage =
                'Your collection request has been declined again ($declineCount time). Reason: $reason';
          }

          await chatRepo.sendSystemMessage(
            conversationId: conversationId,
            text: declineMessage,
            action: 'posting_declined',
            additionalMetadata: {
              'postingId': pickupId,
              'attempt': newAttempt,
              'reason': reason,
            },
          );
          if (kDebugMode) {
            print('✅ Sent decline system message to conversation');
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ Failed to send decline system message: $e');
        // Don't throw - decline still succeeded even if message failed
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup declined successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );

        // Refresh the pickups list based on current tab
        final currentTab = _tabController.index;
        if (currentTab == 0) {
          // New pickups tab
          await _fetchNewPickups();
        } else if (currentTab == 1) {
          // Assigned pickups tab
          await _fetchAssignedPickups();
        } else if (currentTab == 2) {
          // Completed pickups tab
          await _fetchCompletedPickups();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline pickup: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  // Decline bottom sheet widget declared at file end.

  void _showAssignCollectorModal(Map<String, dynamic> pickup) async {
    // Show loading modal first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      // Fetch real collectors from database
      final collectorsRepository = getIt<ICollectorsRepository>();
      final collectors = await collectorsRepository.getAvailableCollectors(
        // latitude: pickup['latitude'],
        // longitude: pickup['longitude'],
        limit: 10,
      );

      if (!mounted) return;
      // Close loading modal and show collectors
      Navigator.of(context).pop();

      _showCollectorsListModal(pickup, collectors);
    } catch (e) {
      if (!mounted) return;
      // Close loading modal and show error
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load collectors: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  void _showCollectorsListModal(
    Map<String, dynamic> pickup,
    List<Collector> collectors,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(
                    FluentIcons.people_24_regular,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Assign Collector',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Collectors list
            Expanded(
              child: collectors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🚫', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text(
                            'No collectors available',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: collectors.length,
                      itemBuilder: (context, index) {
                        final collector = collectors[index];
                        // For testing: allow assigning any collector regardless of status

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _assignCollectorToPickup(pickup, collector);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: CustomCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    _buildAvatar(
                                      collector.profileImageUrl ??
                                          collector.name,
                                      size: 50,
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _capitalizeName(collector.name),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                size: 14,
                                                color: Colors.amber,
                                              ),
                                              Text(
                                                ' ${collector.rating.toStringAsFixed(1)} • ${collector.activeJobs} jobs • ${collector.displayStatus}',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog for the junkshop to enter a Collection Fee for this collection.
  /// Returns the fee as a double (0.0 = no fee), or null if cancelled.
  Future<double?> _showcollectionFeeDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.junkshopPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Collection Fee')),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Collection Fee the collector will deduct from the total payout to the household. Leave blank or enter 0 for no fee.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Collection Fee (₱)',
                  prefixText: '₱ ',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.junkshopPrimary,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final parsed = double.tryParse(v);
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid amount';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.junkshopPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final fee = double.tryParse(controller.text.trim()) ?? 0.0;
                Navigator.of(context).pop(fee);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showDateSelectionDialog(
    List<DateTime> unavailableDates,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // Disable dates in unavailableDates list
        final dateOnly = DateTime(date.year, date.month, date.day);
        return !unavailableDates.any((unavailable) {
          final unavailableOnly = DateTime(
            unavailable.year,
            unavailable.month,
            unavailable.day,
          );
          return dateOnly.isAtSameMomentAs(unavailableOnly);
        });
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return null;

    // Use midday (12:00 PM) as default time to avoid timezone issues
    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      12,
      0,
    );

    return selectedDateTime;
  }

  void _assignCollectorToPickup(
    Map<String, dynamic> pickup,
    Collector collector,
  ) async {
    // Get unavailable dates (dates household is NOT available)
    final unavailableDates = pickup['unavailableDates'] as List<DateTime>?;

    // Show date selection dialog - all future dates except unavailable ones
    final selectedDate = await _showDateSelectionDialog(unavailableDates ?? []);

    if (selectedDate == null) {
      // User cancelled date selection
      return;
    }

    if (!mounted) return;

    // Show Collection Fee input dialog
    final collectionFee = await _showcollectionFeeDialog();
    if (collectionFee == null) {
      // User cancelled
      return;
    }

    if (!mounted) return;
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get the posting document reference - try both 'id' and 'postingId' keys
      final postingId = pickup['id'] ?? pickup['postingId'];
      if (postingId == null) {
        throw Exception('Posting ID not found');
      }

      // Get householdId from the pickup map directly, or search in lists
      String? householdId = pickup['householdId'];

      // If not in pickup map, try to find in new pickups list
      if (householdId == null) {
        try {
          final pickupItem = _newPickups.firstWhere(
            (item) => item.id == postingId,
          );
          householdId = pickupItem.householdId;
        } catch (e) {
          // Not in new pickups, try assigned pickups via collector assignments
          for (final assignment in _collectorAssignments) {
            final foundPickup = assignment.pickups.firstWhere(
              (item) => item.id == postingId,
              orElse: () => throw Exception('Continue search'),
            );
            if (foundPickup.id == postingId) {
              householdId = foundPickup.householdId;
              break;
            }
          }
        }
      }

      if (householdId == null) {
        throw Exception('Household ID not found for posting $postingId');
      }

      // Fetch full collector profile data from collectors table
      final collectorRow = await supabase
          .from('collectors')
          .select()
          .eq('id', collector.id)
          .maybeSingle();

      final collectorData = collectorRow == null
          ? <String, dynamic>{}
          : rowToDoc('collectors', collectorRow);

      if (kDebugMode) print('📱 DEBUG: Collector document data:');
      if (kDebugMode) print('   Collector ID: ${collector.id}');
      if (kDebugMode) print('   Row exists: ${collectorRow != null}');
      if (kDebugMode) print('   All fields: ${collectorData.keys.toList()}');
      if (kDebugMode) {
        print('   phone field: ${collectorData[UserFields.phone]}');
      }
      if (kDebugMode) {
        print(
          '   phone_number field: ${collectorData[UserFields.phoneNumber]}',
        );
      }

      // Extract from nested collector_profile if needed
      final collectorProfile =
          collectorData[UserFields.collectorProfile] as Map<String, dynamic>?;
      final contact = collectorProfile?['contact'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;

      final collectorRating =
          (collectorData[UserFields.rating] as num?)?.toDouble() ??
          collector.rating;
      final collectorTrips =
          (collectorData['total_trips'] as int?) ??
          (collectorData['totalTrips'] as int?) ??
          0;
      final collectorPhone =
          (personal?[UserFields.phone] ??
                  personal?[UserFields.phoneNumber] ??
                  contact?[UserFields.phone] ??
                  contact?[UserFields.phoneNumber] ??
                  collectorData[UserFields.phone] ??
                  collectorData[UserFields.phoneNumber] ??
                  '')
              .toString();

      if (kDebugMode) print('   📱 Final phone value: "$collectorPhone"');

      // Get current posting data to check for existing collector (for reassignment)
      final postingRowBeforeUpdate = await supabase
          .from('postings')
          .select('collector')
          .eq('id', postingId)
          .maybeSingle();

      final oldCollectorData = postingRowBeforeUpdate?['collector'] as Map?;
      final oldCollectorId = oldCollectorData?['id'] as String?;
      final oldCollectorName = oldCollectorData?['full_name'] as String?;

      // Update the posting document with collector assignment and collection date
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: ========================================');
      }
      if (kDebugMode) print('DEBUG ASSIGNMENT: Assigning collector to posting');
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: Old Collector ID: $oldCollectorId');
      }
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: Old Collector Name: $oldCollectorName');
      }
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: New Collector ID: ${collector.id}');
      }
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: New Collector Name: ${collector.name}');
      }
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: Collector Rating: $collectorRating');
      }
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: Collector Trips: $collectorTrips');
      }
      if (kDebugMode) print('DEBUG ASSIGNMENT: Posting ID: $postingId');
      if (kDebugMode) print('DEBUG ASSIGNMENT: Household ID: $householdId');
      if (kDebugMode) print('DEBUG ASSIGNMENT: Collection Date: $selectedDate');
      if (kDebugMode) {
        print('DEBUG ASSIGNMENT: ========================================');
      }

      await supabase
          .from('postings')
          .update({
            'status': 'assigned',
            'collector_id': collector.id,
            // Nested collector snapshot (no lat/lng - uses current location)
            'collector': {
              'id': collector.id,
              'full_name': collector.name,
              'profile_image_url': collector.profileImageUrl,
              'rating': collectorRating,
              'total_trips': collectorTrips,
              'phone': collectorPhone,
            },
            'date_of_collection': selectedDate.toUtc().toIso8601String(),
            'collection_fee': collectionFee,
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', postingId);

      if (kDebugMode) {
        print(
          'DEBUG ASSIGNMENT: Assignment successful! Collector ${collector.id} assigned to posting $postingId for ${_formatTimestamp(selectedDate)}',
        );
      }

      // Remove previous collector failure info if this is a new assignment
      try {
        final dateValidationService = DateValidationService();
        await dateValidationService.removePreviousCollectorOnNewAssignment(
          householdId: householdId,
          postingId: postingId,
        );
        if (kDebugMode) print('✅ Removed previous collector failure info');
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to remove previous collector info: $e');
        }
        // Continue with assignment even if cleanup fails
      }

      // Update conversation - handle both new assignment and reassignment
      try {
        if (kDebugMode) print('💬 Updating conversation...');
        final chatRepo = ChatRepository();
        final conversationId = 'posting_$postingId';

        // Get current conversation to check participants
        final conversation = await chatRepo.getConversationByPostingId(
          postingId,
        );
        final currentParticipants = conversation?.participants ?? [];

        if (kDebugMode) {
          print('💬 Current conversation participants: $currentParticipants');
        }
        if (kDebugMode) print('💬 Old collector ID: $oldCollectorId');
        if (kDebugMode) print('💬 New collector ID: ${collector.id}');

        // If there's an old collector, remove them from the conversation
        if (oldCollectorId != null && oldCollectorId != collector.id) {
          if (kDebugMode) {
            print(
              '💬 Removing old collector: $oldCollectorId ($oldCollectorName)',
            );
          }

          try {
            await chatRepo.removeParticipant(
              conversationId: conversationId,
              userId: oldCollectorId,
              systemMessage:
                  '🔄 ${oldCollectorName ?? 'Previous collector'} has been reassigned',
            );
            if (kDebugMode) print('✅ Old collector removed from conversation');
          } catch (e) {
            if (kDebugMode) print('⚠️ Failed to remove old collector: $e');
          }
        }

        // Add new collector to the conversation (only if not already a participant)
        if (!currentParticipants.contains(collector.id)) {
          if (kDebugMode) {
            print(
              '💬 Adding new collector: ${collector.id} (${collector.name})',
            );
          }

          // Format the collection date for the message
          final formattedDate = _formatTimestamp(selectedDate);

          // Determine if this is a reassignment or initial assignment
          final isReassignment =
              oldCollectorId != null && oldCollectorId != collector.id;
          final feeText = collectionFee > 0
              ? '\n🚚 Collection Fee: ₱${collectionFee.toStringAsFixed(2)}'
              : '';
          final assignmentMessage = isReassignment
              ? '🔄 ${collector.name} has been assigned as the new collector\n📅 Collection date: $formattedDate$feeText'
              : '👤 ${collector.name} has been assigned to this collection\n📅 Collection date: $formattedDate$feeText';

          try {
            await chatRepo.addParticipant(
              conversationId: conversationId,
              userId: collector.id,
              participantDetails: ParticipantDetails(
                name: collector.name,
                role: 'collector',
                profileImage: collector.profileImageUrl,
                joinedAt: DateTime.now(),
              ),
              systemMessage: assignmentMessage,
            );
            if (kDebugMode) {
              print('✅ New collector added to conversation successfully');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ Failed to add new collector to conversation: $e');
            }
            rethrow; // Re-throw to see the actual error
          }
        } else {
          if (kDebugMode) {
            print(
              'ℹ️ Collector ${collector.id} is already a participant in the conversation',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to update conversation: $e');
        if (kDebugMode) print('⚠️ Stack trace: ${StackTrace.current}');
        // Don't fail the assignment if conversation update fails
      }

      if (!mounted) return;
      // Close loading dialog
      Navigator.of(context).pop();

      // Log activity
      try {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final isReassignment =
              oldCollectorId != null && oldCollectorId != collector.id;
          final householdName =
              pickup['householdName'] ??
              pickup['household']?['full_name'] ??
              'Customer';

          await supabase.from('activity_logs').insert({
            'junkshop_id': user.id,
            'type': 'collector_assigned',
            'title': isReassignment
                ? 'Reassigned ${collector.name} to pickup from $householdName'
                : 'Assigned ${collector.name} to pickup from $householdName',
            'details': {
              'postingId': postingId,
              'householdId': householdId,
              'collectorId': collector.id,
              'collectorName': collector.name,
              'householdName': householdName,
              'collectionDate': selectedDate.toUtc().toIso8601String(),
              'isReassignment': isReassignment,
              if (oldCollectorId != null) 'oldCollectorId': oldCollectorId,
              if (oldCollectorName != null)
                'oldCollectorName': oldCollectorName,
            },
          });
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to log activity: $e');
        // Don't fail the assignment if logging fails
      }

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assigned ${_capitalizeName(collector.name)} for collection on ${_formatTimestamp(selectedDate)}',
          ),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh the pickups list
      await _fetchNewPickups();
      await _fetchAssignedPickups();

      // Switch to Assigned tab to show the newly assigned pickup
      _tabController.animateTo(1); // Index 1 is the Assigned tab
    } on PostgrestException {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign collector. Please try again.'),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign collector. Please try again.'),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildModalImagesSection(Map<String, dynamic> pickup) {
    final List<dynamic>? imageUrls = pickup['imageUrls'] as List<dynamic>?;

    if (kDebugMode) print('🔍 MODAL: _buildModalImagesSection called');
    if (kDebugMode) print('🔍 MODAL: imageUrls = $imageUrls');

    // If no images, show placeholder
    if (imageUrls == null || imageUrls.isEmpty) {
      if (kDebugMode) print('🔍 MODAL: No images, showing placeholder');
      return SizedBox(
        height: 180,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: AppColors.backgroundDark,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No photos attached',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Remove duplicate images (same URL used for multiple items)
    final uniqueImageUrls = imageUrls.toSet().toList();

    if (kDebugMode) {
      print(
        '🔍 MODAL: Original images: ${imageUrls.length}, Unique images: ${uniqueImageUrls.length}',
      );
    }
    for (int i = 0; i < uniqueImageUrls.length; i++) {
      if (kDebugMode) print('🔍 MODAL: Image $i URL: ${uniqueImageUrls[i]}');
    }

    // Display images in horizontal scrollable list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Item Photos (${uniqueImageUrls.length})',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: uniqueImageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = uniqueImageUrls[index].toString();
              if (kDebugMode) {
                print('🔍 MODAL: Building image widget for: $imageUrl');
              }

              // Check if it's a local file path or network URL
              final bool isLocalFile =
                  imageUrl.startsWith('/') || imageUrl.startsWith('file://');
              final bool isNetworkUrl =
                  imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://');

              if (kDebugMode) {
                print(
                  '🔍 MODAL: Image $index - isLocalFile: $isLocalFile, isNetworkUrl: $isNetworkUrl',
                );
              }

              return GestureDetector(
                onTap: () => _showFullScreenImages(uniqueImageUrls, index),
                child: Container(
                  width: 180,
                  margin: EdgeInsets.only(
                    right: index < uniqueImageUrls.length - 1 ? 12 : 0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isLocalFile
                        ? Image.file(
                            File(imageUrl.replaceFirst('file://', '')),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              if (kDebugMode) {
                                print(
                                  '🔍 MODAL: Error loading local file: $error',
                                );
                              }
                              return Container(
                                color: AppColors.backgroundDark,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'File not found',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.backgroundDark,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              if (kDebugMode) {
                                print('🔍 MODAL: Error loading image: $error');
                              }
                              return Container(
                                color: AppColors.backgroundDark,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Failed to load',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFullScreenImages(List<dynamic> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = imageUrls[index].toString();
                final bool isLocalFile =
                    imageUrl.startsWith('/') || imageUrl.startsWith('file://');

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: isLocalFile
                        ? Image.file(
                            File(imageUrl.replaceFirst('file://', '')),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 60,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'File not found',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 60,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
            // Image counter
            if (imageUrls.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${initialIndex + 1} / ${imageUrls.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReassignDialog(NewPickupItem pickup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        title: Row(
          children: [
            Icon(
              FluentIcons.arrow_swap_24_filled,
              color: AppColors.primaryGreen,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              'Reassign Collection',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose what to reassign:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Option 1: Reassign to another collector
            InkWell(
              onTap: () async {
                Navigator.pop(context);

                // Validate that required IDs exist before proceeding
                if (pickup.id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Posting ID is missing'),
                      backgroundColor: AppColors.errorColor,
                    ),
                  );
                  return;
                }
                if (pickup.householdId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Household ID is missing'),
                      backgroundColor: AppColors.errorColor,
                    ),
                  );
                  return;
                }

                // Convert NewPickupItem to Map for assignment
                final pickupMap = {
                  'id': pickup.id,
                  'householdId': pickup.householdId,
                  'household': pickup.householdName ?? 'Unknown Household',
                  'unavailableDates': pickup.unavailableDates,
                };

                if (kDebugMode) {
                  print('🔍 DEBUG: Opening reassignment modal with:');
                }
                if (kDebugMode) print('   Posting ID: ${pickupMap['id']}');
                if (kDebugMode) {
                  print('   Household ID: ${pickupMap['householdId']}');
                }

                await _showReassignCollectorModal(pickupMap, pickup);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        FluentIcons.person_swap_24_regular,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reassign to Another Collector',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select a different collector',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Option 2: Reschedule date
            InkWell(
              onTap: () async {
                Navigator.pop(context);

                if (kDebugMode) {
                  print('🔍 DEBUG: Change date tapped for pickup:');
                }
                if (kDebugMode) print('   Pickup ID: ${pickup.id}');
                if (kDebugMode) print('   Household ID: ${pickup.householdId}');
                if (kDebugMode) {
                  print(
                    '   Household ID isEmpty: ${pickup.householdId.isEmpty}',
                  );
                }

                await _showChangeDateModal(pickup);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        FluentIcons.calendar_edit_24_regular,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Collection Date',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Schedule a new date/time',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reassign to another collector
  Future<void> _showReassignCollectorModal(
    Map<String, dynamic> pickup,
    NewPickupItem pickupItem,
  ) async {
    // Show loading modal first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      // Fetch collectors - use same simple strategy as New tab for speed
      final collectorsRepository = getIt<ICollectorsRepository>();
      final collectors = await collectorsRepository.getAvailableCollectors(
        limit: 10,
      );

      if (!mounted) return;
      // Close loading modal and show collectors
      Navigator.of(context).pop();

      _showReassignCollectorsList(pickup, pickupItem, collectors);
    } catch (e) {
      if (!mounted) return;
      // Close loading modal and show error
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load collectors: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  void _showReassignCollectorsList(
    Map<String, dynamic> pickup,
    NewPickupItem pickupItem,
    List<Collector> collectors,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.person_swap_24_filled,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select New Collector',
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Choose a collector to reassign',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Collectors list
            Expanded(
              child: collectors.isEmpty
                  ? Center(
                      child: Text(
                        'No collectors available',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: collectors.length,
                      itemBuilder: (context, index) {
                        final collector = collectors[index];
                        return _buildCollectorSelectionCard(
                          collector,
                          () async {
                            Navigator.pop(context);
                            await _reassignToCollector(
                              pickup,
                              pickupItem,
                              collector,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorSelectionCard(Collector collector, VoidCallback onTap) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildAvatar(collector.profileImageUrl ?? collector.name, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalizeName(collector.name),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      Text(
                        ' ${collector.rating.toStringAsFixed(1)} • ${collector.activeJobs} jobs • ${collector.displayStatus}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reassignToCollector(
    Map<String, dynamic> pickup,
    NewPickupItem pickupItem,
    Collector newCollector,
  ) async {
    // Get unavailable dates (dates household is NOT available)
    final unavailableDates = pickup['unavailableDates'] as List<DateTime>?;

    // Show date selection dialog - all future dates except unavailable ones
    final selectedDate = await _showDateSelectionDialog(unavailableDates ?? []);

    if (selectedDate == null) {
      // User cancelled date selection
      return;
    }

    if (!mounted) return;
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final postingId = pickup['id'];
      final householdId = pickup['householdId'];

      // Validate IDs are non-empty strings before using in Firestore paths
      if (postingId == null || postingId.toString().isEmpty) {
        throw Exception('Invalid posting ID: must be a non-empty string');
      }
      if (householdId == null || householdId.toString().isEmpty) {
        throw Exception('Invalid household ID: must be a non-empty string');
      }
      if (newCollector.id.isEmpty) {
        throw Exception('Invalid collector ID: must be a non-empty string');
      }

      // Fetch full collector profile data
      final collectorRow = await supabase
          .from('collectors')
          .select()
          .eq('id', newCollector.id)
          .maybeSingle();

      final collectorData = collectorRow == null
          ? <String, dynamic>{}
          : rowToDoc('collectors', collectorRow);

      final collectorProfile =
          collectorData[UserFields.collectorProfile] as Map<String, dynamic>?;
      final contact = collectorProfile?['contact'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;

      final collectorRating =
          (collectorData[UserFields.rating] as num?)?.toDouble() ??
          newCollector.rating;
      final collectorTrips =
          (collectorData['total_trips'] as int?) ??
          (collectorData['totalTrips'] as int?) ??
          0;
      final collectorPhone =
          (personal?[UserFields.phone] ??
                  personal?[UserFields.phoneNumber] ??
                  contact?[UserFields.phone] ??
                  contact?[UserFields.phoneNumber] ??
                  collectorData[UserFields.phone] ??
                  collectorData[UserFields.phoneNumber] ??
                  '')
              .toString();

      // Get old collector data
      final oldCollectorId = pickupItem.previousCollectorId;
      final oldCollectorName = pickupItem.previousCollector;

      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: ========================================');
      }
      if (kDebugMode) print('DEBUG REASSIGNMENT: Reassigning posting');
      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: Old Collector ID: $oldCollectorId');
      }
      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: Old Collector Name: $oldCollectorName');
      }
      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: New Collector ID: ${newCollector.id}');
      }
      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: New Collector Name: ${newCollector.name}');
      }
      if (kDebugMode) print('DEBUG REASSIGNMENT: Posting ID: $postingId');
      if (kDebugMode) print('DEBUG REASSIGNMENT: Household ID: $householdId');
      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: Collection Date: $selectedDate');
      }
      if (kDebugMode) {
        print('DEBUG REASSIGNMENT: ========================================');
      }

      // Update the posting with new collector
      await supabase
          .from('postings')
          .update({
            'status': 'assigned',
            'collector_id': newCollector.id,
            'collector': {
              'id': newCollector.id,
              'full_name': newCollector.name,
              'profile_image_url': newCollector.profileImageUrl,
              'rating': collectorRating,
              'total_trips': collectorTrips,
              'phone': collectorPhone,
            },
            'date_of_collection': selectedDate.toUtc().toIso8601String(),
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
            // Clear reschedule data since it's been reassigned
            'reschedule': null,
          })
          .eq('id', postingId);

      // Update conversation
      try {
        final chatRepo = ChatRepository();
        final conversationId = 'posting_$postingId';

        // Remove old collector
        if (oldCollectorId != null) {
          await chatRepo.removeParticipant(
            conversationId: conversationId,
            userId: oldCollectorId,
            systemMessage:
                '🔄 ${oldCollectorName ?? 'Previous collector'} has been reassigned',
          );
        }

        // Add new collector
        final formattedDate = _formatTimestamp(selectedDate);
        await chatRepo.addParticipant(
          conversationId: conversationId,
          userId: newCollector.id,
          participantDetails: ParticipantDetails(
            name: newCollector.name,
            role: 'collector',
            profileImage: newCollector.profileImageUrl,
            joinedAt: DateTime.now(),
          ),
          systemMessage:
              '👤 ${newCollector.name} has been assigned as the new collector\n📅 Collection date: $formattedDate',
        );
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to update conversation: $e');
      }

      if (!mounted) return;
      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully reassigned to ${newCollector.name} for ${_formatTimestamp(selectedDate)}',
          ),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh the pickups list
      await _fetchReschedulePickups();
      await _fetchAssignedPickups();
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reassign collector: $e'),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Change collection date only
  Future<void> _showChangeDateModal(NewPickupItem pickup) async {
    // Validate IDs before proceeding
    if (pickup.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Posting ID is missing'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }
    if (pickup.householdId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Household ID is missing'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    // Show date selection dialog (allow any future date)
    final selectedDate = await _showDateSelectionDialog(
      pickup.unavailableDates ?? [],
    );

    if (selectedDate == null) {
      // User cancelled
      return;
    }

    if (!mounted) return;
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get current posting data to restore collector info from reschedule
      final postingData = await supabase
          .from('postings')
          .select('reschedule')
          .eq('id', pickup.id)
          .maybeSingle();

      // Get collector info from reschedule object
      final rescheduleData =
          postingData?['reschedule'] as Map<String, dynamic>?;
      final collectorId = rescheduleData?['rescheduledById']?.toString();
      final collectorName = rescheduleData?['rescheduledByName']?.toString();
      final collectorPhoto = rescheduleData?['rescheduledByPhoto']?.toString();

      // Fetch full collector data to get rating and trips
      Map<String, dynamic>? collectorDetails;
      if (collectorId != null) {
        final collectorRow = await supabase
            .from('collectors')
            .select()
            .eq('id', collectorId)
            .maybeSingle();

        if (collectorRow != null) {
          final collectorData = rowToDoc('collectors', collectorRow);
          final collectorProfile =
              collectorData[UserFields.collectorProfile]
                  as Map<String, dynamic>?;
          final contact = collectorProfile?['contact'] as Map<String, dynamic>?;
          final personal =
              collectorProfile?['personal'] as Map<String, dynamic>?;

          final collectorRating =
              (collectorData[UserFields.rating] as num?)?.toDouble() ?? 0.0;
          final collectorTrips =
              (collectorData['total_trips'] as int?) ??
              (collectorData['totalTrips'] as int?) ??
              0;
          final collectorPhone =
              (personal?[UserFields.phone] ??
                      personal?[UserFields.phoneNumber] ??
                      contact?[UserFields.phone] ??
                      contact?[UserFields.phoneNumber] ??
                      collectorData[UserFields.phone] ??
                      collectorData[UserFields.phoneNumber] ??
                      '')
                  .toString();

          collectorDetails = {
            'id': collectorId,
            'full_name': collectorName,
            'profile_image_url': collectorPhoto,
            'rating': collectorRating,
            'total_trips': collectorTrips,
            'phone': collectorPhone,
          };
        }
      }

      // Update the collection date and status, restoring collector info from reschedule
      await supabase
          .from('postings')
          .update({
            'status': 'assigned',
            'date_of_collection': selectedDate.toUtc().toIso8601String(),
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
            // Restore collector info from reschedule data
            if (collectorDetails != null) 'collector': collectorDetails,
            if (collectorDetails != null) 'collector_id': collectorId,
            // Clear reschedule data since date has been changed
            'reschedule': null,
          })
          .eq('id', pickup.id);

      // Send message to conversation about date change and restore collector
      try {
        final chatRepo = ChatRepository();
        final conversationId = 'posting_${pickup.id}';
        final formattedDate = _formatTimestamp(selectedDate);
        final systemMessage =
            '📅 Collection date has been rescheduled to $formattedDate';

        // If we have collector details, ensure they're added back to conversation
        if (collectorId != null && collectorName != null) {
          // Check if collector is already a participant
          final conversation = await chatRepo.getConversationByPostingId(
            pickup.id,
          );
          final currentParticipants = conversation?.participants ?? [];

          if (!currentParticipants.contains(collectorId)) {
            // Add collector back to conversation with system message
            await chatRepo.addParticipant(
              conversationId: conversationId,
              userId: collectorId,
              participantDetails: ParticipantDetails(
                name: collectorName,
                role: 'collector',
                profileImage: collectorPhoto,
                joinedAt: DateTime.now(),
              ),
              systemMessage: systemMessage,
            );
          } else {
            // Collector already in conversation, send system message
            await chatRepo.sendSystemMessage(
              conversationId: conversationId,
              text: systemMessage,
              action: 'date_rescheduled',
            );
          }
        } else {
          // No collector info, still send system message
          await chatRepo.sendSystemMessage(
            conversationId: conversationId,
            text: systemMessage,
            action: 'date_rescheduled',
          );
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to update conversation: $e');
      }

      if (!mounted) return;
      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Collection date updated to ${_formatTimestamp(selectedDate)}',
          ),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh the pickups list
      await _fetchReschedulePickups();
      await _fetchAssignedPickups();
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update date: $e'),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// Extracted decline bottom sheet widget (top-level)
class DeclinePickupSheet extends StatefulWidget {
  const DeclinePickupSheet({super.key});

  @override
  State<DeclinePickupSheet> createState() => _DeclinePickupSheetState();
}

class _DeclinePickupSheetState extends State<DeclinePickupSheet> {
  final TextEditingController _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.errorColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Decline Pickup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Please provide a reason for declining this pickup request. The household will be notified.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                maxLength: 200,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Reason for declining',
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                      color: AppColors.errorColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.errorColor),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                      color: AppColors.errorColor,
                      width: 2,
                    ),
                  ),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final reason = _reasonController.text.trim();
                        if (reason.isEmpty) {
                          setState(() {
                            _errorText = 'Please provide a reason';
                          });
                          return;
                        }
                        if (reason.length < 10) {
                          setState(() {
                            _errorText = 'Minimum 10 characters required';
                          });
                          return;
                        }
                        Navigator.of(context).pop(reason);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}

// Pricing Review Dialog - allows junkshop to set buying prices for collector's items
class _PricingReviewDialog extends StatefulWidget {
  final NewPickupItem pickup;
  final VoidCallback onApproved;

  const _PricingReviewDialog({required this.pickup, required this.onApproved});

  @override
  State<_PricingReviewDialog> createState() => _PricingReviewDialogState();
}

class _PricingReviewDialogState extends State<_PricingReviewDialog> {
  List<_EditableItem> _editableItems = [];
  Map<String, dynamic> _materialPrices = {};
  Map<String, double> _junkshopMaterialCommissions = {};
  bool _isInitializing = true;
  double _totalJunkshopCost = 0.0;
  double _totalCollectorPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMaterialPrices();
    _loadDataAndInitialize();
  }

  Future<void> _loadDataAndInitialize() async {
    await _loadJunkshopCommissions();
    _initializeEditableItems();
    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _loadMaterialPrices() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/config/material_prices.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      setState(() {
        _materialPrices = data;
      });
    } catch (e) {
      if (kDebugMode) print('Error loading material prices: $e');
    }
  }

  Future<void> _loadJunkshopCommissions() async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      final materialRows = await supabase
          .from('junkshop_materials')
          .select('name, commission')
          .eq('junkshop_id', uid);

      final commissions = <String, double>{};
      for (final data in materialRows) {
        final name = (data['name'] as String?)?.toLowerCase() ?? '';
        final commission = (data['commission'] as num?)?.toDouble() ?? 0.0;
        if (name.isNotEmpty) {
          commissions[name] = commission;
        }
      }

      _junkshopMaterialCommissions = commissions;

      if (kDebugMode) {
        print(
          '📊 Loaded ${commissions.length} material commissions: $commissions',
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error loading junkshop material commissions: $e');
    }
  }

  void _initializeEditableItems() {
    _editableItems = widget.pickup.itemDetails.map((item) {
      final quantity = double.tryParse(item.quantity) ?? 0.0;

      // Collector's price (what they paid to household)
      final collectorTotalPrice = item.totalPrice ?? 0.0;
      final collectorPricePerUnit =
          item.pricePerUnit ??
          (quantity > 0 ? collectorTotalPrice / quantity : 0.0);

      // Suggested junkshop price (with margin)
      final suggestedPrice = _getSuggestedJunkshopPrice(
        item.name,
        item.category,
        collectorPricePerUnit,
      );

      final junkshopPricePerUnit = suggestedPrice;
      final junkshopTotalPrice = junkshopPricePerUnit * quantity;

      return _EditableItem(
        name: item.name,
        quantity: quantity,
        unit: item.unit,
        condition: item.condition,
        category: item.category,
        imagePaths: item.imagePaths,
        collectorPricePerUnit: collectorPricePerUnit,
        collectorTotalPrice: collectorTotalPrice,
        junkshopPricePerUnit: junkshopPricePerUnit,
        junkshopTotalPrice: junkshopTotalPrice,
        controller: TextEditingController(
          text: junkshopPricePerUnit.toStringAsFixed(2),
        ),
        promotionBoostPercentage: item.promotionBoostPercentage,
      );
    }).toList();

    _calculateTotals();
  }

  double _getSuggestedJunkshopPrice(
    String itemName,
    String? category,
    double collectorPrice,
  ) {
    // Get commission per unit from junkshop's material settings
    final commissionPerUnit = _getCommissionForMaterial(itemName);

    // Junkshop pays collector: collector price per unit + commission per unit
    final junkshopPricePerUnit = collectorPrice + commissionPerUnit;

    // Get market price from material_prices.json as a sanity check
    final marketPrice = _getMarketPrice(itemName, category);

    if (marketPrice > 0 && junkshopPricePerUnit > marketPrice) {
      // If suggested price exceeds market max, cap it at market price
      if (kDebugMode) {
        print(
          '⚠️ Suggested price ₱$junkshopPricePerUnit for $itemName exceeds market max ₱$marketPrice',
        );
      }
      return marketPrice;
    }

    return junkshopPricePerUnit;
  }

  double _getCommissionForMaterial(String itemName) {
    final searchName = itemName.toLowerCase();

    // Try exact match first
    if (_junkshopMaterialCommissions.containsKey(searchName)) {
      final commission = _junkshopMaterialCommissions[searchName]!;
      if (kDebugMode) {
        print(
          '💰 Found exact commission for "$itemName": ₱$commission per unit',
        );
      }
      return commission;
    }

    // Try partial match
    for (final entry in _junkshopMaterialCommissions.entries) {
      if (searchName.contains(entry.key) || entry.key.contains(searchName)) {
        final commission = entry.value;
        if (kDebugMode) {
          print(
            '💰 Found partial commission match for "$itemName" (matched "${entry.key}"): ₱$commission per unit',
          );
        }
        return commission;
      }
    }

    // Default commission if not found
    if (kDebugMode) {
      print('⚠️ No commission found for "$itemName", using default ₱0.0');
    }
    return 0.0;
  }

  double _getMarketPrice(String itemName, String? category) {
    if (_materialPrices.isEmpty) return 0.0;

    final categories = _materialPrices['categories'] as List?;
    if (categories == null) return 0.0;

    for (final cat in categories) {
      if (cat is! Map<String, dynamic>) continue;

      final materials = cat['materials'] as List?;
      if (materials == null) continue;

      for (final material in materials) {
        if (material is! Map<String, dynamic>) continue;

        final materialName = material['name']?.toString().toLowerCase() ?? '';
        final searchName = itemName.toLowerCase();

        // Match by name similarity
        if (materialName.contains(searchName) ||
            searchName.contains(materialName)) {
          return (material['max_price'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    return 0.0;
  }

  void _calculateTotals() {
    double junkshopTotal = 0.0;
    double collectorTotal = 0.0;

    for (final item in _editableItems) {
      junkshopTotal += item.junkshopTotalPrice;
      collectorTotal += item.collectorTotalPrice;
    }

    setState(() {
      _totalJunkshopCost = junkshopTotal;
      _totalCollectorPaid = collectorTotal;
    });
  }

  void _onPriceChanged(_EditableItem item, String value) {
    final newPrice = double.tryParse(value) ?? 0.0;
    setState(() {
      item.junkshopPricePerUnit = newPrice;
      item.junkshopTotalPrice = newPrice * item.quantity;
      _calculateTotals();
    });
  }

  Future<void> _approveAndSave() async {
    // Validate all prices
    for (final item in _editableItems) {
      if (item.junkshopPricePerUnit <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set valid prices for all items'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Build purchasedItems list
      final purchasedItems = _editableItems.map((item) {
        return ItemDetail(
          name: item.name,
          quantity: item.quantity.toString(),
          unit: item.unit,
          condition: item.condition,
          category: item.category,
          imagePaths: item.imagePaths,
          pricePerUnit: item.collectorPricePerUnit,
          totalPrice: item.collectorTotalPrice,
          junkshopPricePerUnit: item.junkshopPricePerUnit,
          junkshopTotalPrice: item.junkshopTotalPrice,
          promotionBoostPercentage: item.promotionBoostPercentage,
        );
      }).toList();

      // Save to Firebase
      final repo = getIt<IJunkshopPickupsRepository>();
      await repo.markCollectionAsReviewed(
        widget.pickup.householdId,
        widget.pickup.id,
        purchasedItems: purchasedItems,
        junkshopPurchaseTotal: _totalJunkshopCost,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Close review dialog
      if (mounted) Navigator.of(context).pop();

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Collection approved! Total cost: ₱${_totalJunkshopCost.toStringAsFixed(2)}',
            ),
            backgroundColor: AppColors.successColor,
          ),
        );
      }

      // Refresh parent list (will also refresh history)
      widget.onApproved();
    } catch (e) {
      // Close loading
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final item in _editableItems) {
      item.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(40),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading pricing information...'),
            ],
          ),
        ),
      );
    }

    final profit = _totalJunkshopCost - _totalCollectorPaid;
    final profitPercentage = _totalCollectorPaid > 0
        ? (profit / _totalCollectorPaid) * 100
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minimal Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Review Collection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Items list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _editableItems.length,
                      itemBuilder: (context, index) {
                        final item = _editableItems[index];
                        return _buildEditableItemCard(item);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Collector Paid',
                            '₱${_totalCollectorPaid.toStringAsFixed(2)}',
                            Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Your Price',
                            '₱${_totalJunkshopCost.toStringAsFixed(2)}',
                            Colors.black87,
                            isLarge: true,
                          ),
                          if (profit != 0) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Collector Margin',
                              '${profit >= 0 ? '+' : ''}₱${profit.toStringAsFixed(2)} (${profitPercentage.toStringAsFixed(1)}%)',
                              profit >= 0
                                  ? AppColors.primaryGreen
                                  : AppColors.errorColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _approveAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Approve & Pay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableItemCard(_EditableItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with item name & quantity
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Text(
                    '${item.quantity} ${item.unit}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Price information section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Collector paid & Your price row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collector paid',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₱${item.collectorPricePerUnit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your price',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: item.controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onTap: () {
                              item.controller.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: item.controller.text.length,
                              );
                            },
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixText: '₱ ',
                              prefixStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: (value) => _onPriceChanged(item, value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Total row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '₱${item.junkshopTotalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 14 : 13,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EditableItem {
  final String name;
  final double quantity;
  final String unit;
  final String condition;
  final String? category;
  final List<String> imagePaths;
  final double collectorPricePerUnit;
  final double collectorTotalPrice;
  double junkshopPricePerUnit;
  double junkshopTotalPrice;
  final TextEditingController controller;
  final double? promotionBoostPercentage;

  _EditableItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.condition,
    this.category,
    required this.imagePaths,
    required this.collectorPricePerUnit,
    required this.collectorTotalPrice,
    required this.junkshopPricePerUnit,
    required this.junkshopTotalPrice,
    required this.controller,
    this.promotionBoostPercentage,
  });
}
