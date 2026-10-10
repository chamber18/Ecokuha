import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../../../data/services/junkshop_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/services/cache_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class BusinessControlsScreen extends StatefulWidget {
  const BusinessControlsScreen({super.key});

  @override
  State<BusinessControlsScreen> createState() => _BusinessControlsScreenState();
}

class _BusinessControlsScreenState extends State<BusinessControlsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<List<Map<String, dynamic>>>? _settingsSubscription;
  final CacheService _cacheService = CacheService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isInitialLoad = true; // Prevent marking changes during initial load

  // Budget & Distance Controllers
  double _baseFee = 50.0;
  double _costPerKm = 10.0;
  double _serviceRadius = 15.0; // Loaded from profile location.service_radius
  double _maxWeightPerValueRatio =
      2.0; // Max kg per ₱100 value (minimum: 1kg, max: 10kg)

  // Original values to compare against
  double _originalBaseFee = 50.0;
  double _originalCostPerKm = 10.0;
  double _originalMaxWeightPerValueRatio = 2.0;
  String _originalMonthlyBudget = '';
  final TextEditingController _monthlyBudgetController = TextEditingController(
    text: '',
  );
  double _currentMonthSpending = 0.0;
  int _lastCalculatedMonth = DateTime.now().month;
  int _lastCalculatedYear = DateTime.now().year;

  // Material Rules State (loaded from Firebase /junkshops/{uid}/materials)
  Map<String, Map<String, dynamic>> _materialRules = {};

  // Customer Management State
  final TextEditingController _customerSearchController =
      TextEditingController();
  String _searchQuery = '';
  final Map<String, bool> _customerBlockState =
      {}; // Local block state for instant UI
  List<Map<String, dynamic>>?
  _cachedCustomers; // Cache customer data to prevent reloading

  // Rule Simulator State
  double _testDistance = 5.0;
  final TextEditingController _testValueController = TextEditingController();
  final TextEditingController _testWeightController = TextEditingController();
  Set<String> _testCategories = {};
  bool _testResultsVisible = false;
  bool _testPassed = false;
  List<String> _testFailureReasons = [];
  List<String> _testSuggestions = [];
  String? _bouncingChip;
  String? _tappedPreset; // Track which preset is being tapped for animation
  bool _hasTestedRules = false; // Track if user has tested the current rules

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Don't add listeners yet - wait until after initial load
    _loadSettings();
    _setupRealtimeListener();
  }

  void _markAsChanged() {
    if (_isInitialLoad || !mounted) return;

    // Check if any values actually changed from originals
    final hasChanges =
        _baseFee != _originalBaseFee ||
        _costPerKm != _originalCostPerKm ||
        _maxWeightPerValueRatio != _originalMaxWeightPerValueRatio ||
        _monthlyBudgetController.text != _originalMonthlyBudget;

    if (_hasUnsavedChanges != hasChanges) {
      setState(() => _hasUnsavedChanges = hasChanges);
    }
  }

  void _onTabChanged() {
    if (_tabController.index == 0) {
      // Budget & Distance tab
      _checkAndRefreshMonthlySpending();
    }
  }

  Future<void> _checkAndRefreshMonthlySpending() async {
    final now = DateTime.now();
    final user = supabase.auth.currentUser;

    if (user == null) return;

    // Check if month has changed since last calculation
    if (now.month != _lastCalculatedMonth || now.year != _lastCalculatedYear) {
      if (kDebugMode) {
        print(
          'BUDGET: Month changed from $_lastCalculatedYear-$_lastCalculatedMonth to ${now.year}-${now.month}, recalculating spending',
        );
      }
      final actualSpending = await _calculateMonthlySpending(user.id);
      setState(() {
        _currentMonthSpending = actualSpending;
        _lastCalculatedMonth = now.month;
        _lastCalculatedYear = now.year;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Load service radius from junkshops/{uid}.junkshop_profile.location.service_radius
      double loadedServiceRadius = 15.0;
      double parseRadius(dynamic value, double current) {
        if (value == null) return current;
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          return parsed ?? current;
        }
        return current;
      }

      // Load from junkshops/{uid}
      final junkshopRow = await supabase
          .from('junkshops')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (junkshopRow != null) {
        final junkshopData = junkshopRow;
        // Dedicated column (kept in sync with junkshop_profile.location)
        loadedServiceRadius = parseRadius(
          junkshopData['service_radius'],
          loadedServiceRadius,
        );
        final junkshopProfile = (junkshopData['junkshop_profile'] as Map?)
            ?.cast<String, dynamic>();
        final locationMap = (junkshopProfile?['location'] as Map?)
            ?.cast<String, dynamic>();
        final businessMap = (junkshopProfile?['business'] as Map?)
            ?.cast<String, dynamic>();

        final rawLocationRadius = locationMap?['service_radius'];
        final rawBusinessServiceRadius = businessMap?['service_radius'];
        final rawBusinessOperationRadius = businessMap?['operation_radius'];

        loadedServiceRadius = parseRadius(
          rawLocationRadius,
          loadedServiceRadius,
        );
        loadedServiceRadius = parseRadius(
          rawBusinessServiceRadius,
          loadedServiceRadius,
        );
        loadedServiceRadius = parseRadius(
          rawBusinessOperationRadius,
          loadedServiceRadius,
        );

        if (kDebugMode) {
          print(
            'RADIUS DEBUG: Loaded from junkshops/{uid} -> junkshop_profile.location.service_radius=$rawLocationRadius, final=$loadedServiceRadius',
          );
        }
      } else {
        if (kDebugMode) {
          print(
            'RADIUS DEBUG: junkshops/{uid} doc does NOT exist, using default 15.0',
          );
        }
      }

      // Calculate actual monthly spending from purchases and completed pickups
      final actualMonthlySpending = await _calculateMonthlySpending(user.id);

      // Load materials with cache-first strategy
      Map<String, Map<String, dynamic>> materialRulesMap;

      // Try cache first
      final cachedMaterials = await _cacheService.getMaterials(user.id);
      if (cachedMaterials != null && cachedMaterials.isNotEmpty) {
        if (kDebugMode) {
          print(
            'MATERIALS: ✅ Loaded ${cachedMaterials.length} material categories from cache (instant)',
          );
        }
        materialRulesMap = cachedMaterials;
        // Refresh in background
        Future.microtask(() => _refreshMaterialsInBackground(user.id));
      } else {
        materialRulesMap = await _fetchMaterials(user.id);
      }

      // Load business control settings from the junkshop row
      if (junkshopRow != null) {
        final data = junkshopRow;
        final settings = (data['settings'] as Map?)?.cast<String, dynamic>();

        setState(() {
          _serviceRadius = loadedServiceRadius;
          _materialRules = materialRulesMap;
          _currentMonthSpending = actualMonthlySpending;
          _lastCalculatedMonth = DateTime.now().month;
          _lastCalculatedYear = DateTime.now().year;

          if (settings != null) {
            _baseFee = (settings['baseFee'] as num?)?.toDouble() ?? 50.0;
            _costPerKm = 0.0;
            _maxWeightPerValueRatio =
                ((settings['maxWeightPerValueRatio'] as num?)?.toDouble() ??
                        2.0)
                    .clamp(1.0, 10.0);
            _monthlyBudgetController.text =
                (settings['monthlyBudget'] as num?)?.toStringAsFixed(0) ?? '0';

            // Store original values for comparison
            _originalBaseFee = _baseFee;
            _originalCostPerKm = _costPerKm;
            _originalMaxWeightPerValueRatio = _maxWeightPerValueRatio;
            _originalMonthlyBudget = _monthlyBudgetController.text;

            // Load category min weights from settings
            final categories = (settings['categories'] as Map?)
                ?.cast<String, dynamic>();
            if (categories != null) {
              categories.forEach((key, value) {
                if (_materialRules.containsKey(key)) {
                  _materialRules[key]!['minWeight'] =
                      (value['minWeight'] as num?)?.toDouble() ?? 0.0;
                }
              });
            }
          }

          if (kDebugMode) {
            print(
              'DEBUG: Loaded settings - baseFee: ₱$_baseFee, costPerKm: ₱$_costPerKm, budget: ${_monthlyBudgetController.text}, spending: ₱${_currentMonthSpending.toStringAsFixed(2)}, radius: ${_serviceRadius}km',
            );
          }

          _isLoading = false;
          _isInitialLoad = false;
        });

        // Add listeners after initial data is loaded to prevent false positive changes
        _monthlyBudgetController.addListener(_markAsChanged);
        _customerSearchController.addListener(_markAsChanged);
        _testValueController.addListener(_markAsChanged);
        _testWeightController.addListener(_markAsChanged);

        // Load simulator cache after materials are loaded and normalized
        _loadSimulatorCache();
      } else {
        setState(() {
          _materialRules = materialRulesMap;
          _serviceRadius = loadedServiceRadius;

          _isLoading = false;
          _isInitialLoad = false;
        });

        // Add listeners after initial data is loaded to prevent false positive changes
        _monthlyBudgetController.addListener(_markAsChanged);
        _customerSearchController.addListener(_markAsChanged);
        _testValueController.addListener(_markAsChanged);
        _testWeightController.addListener(_markAsChanged);

        // Load simulator cache after materials are loaded
        _loadSimulatorCache();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });

      // Add listeners even if loading fails to ensure normal operation
      _monthlyBudgetController.addListener(_markAsChanged);
      _customerSearchController.addListener(_markAsChanged);
      _testValueController.addListener(_markAsChanged);
      _testWeightController.addListener(_markAsChanged);
    }
  }

  /// Calculate actual monthly spending from purchases and completed pickups
  Future<double> _calculateMonthlySpending(String junkshopId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      double totalSpending = 0.0;

      if (kDebugMode) {
        print(
          'BUDGET: Calculating spending from ${startOfMonth.toString()} to ${now.toString()}',
        );
      }

      // 1. Get manual onsite purchases from Purchase collection
      final purchasesSnapshot = await JunkshopQuery.table(
        'purchases',
        junkshopId,
        from: startOfMonth,
      );

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalSpending += amount;
      }

      if (kDebugMode) {
        print(
          'BUDGET: Manual purchases this month (since ${startOfMonth.day}/${startOfMonth.month}): ₱${totalSpending.toStringAsFixed(2)}',
        );
      }

      // 2. Get completed pickups using server-side filtered queries
      // Query BOTH assignedJunkshopId and nested junkshop.id
      // Filter by updatedAt >= startOfMonth to only get completions from this month
      // Postings completed this month (filtered by updated_at)
      final completedSnapshot = await JunkshopQuery.postings(
        junkshopId,
        statuses: ['completed'],
      );
      final allDocs = <String, JDoc>{
        for (final doc in completedSnapshot.docs)
          if ((toDateTime(doc.data()['updatedAt']) ?? DateTime(1970)).isAfter(
            startOfMonth.subtract(const Duration(milliseconds: 1)),
          ))
            doc.id: doc,
      };

      if (kDebugMode) {
        print(
          'BUDGET: Found ${allDocs.length} unique completed postings since ${startOfMonth.day}/${startOfMonth.month}/${startOfMonth.year}',
        );
      }

      int matchedCount = 0;
      for (final postingDoc in allDocs.values) {
        final postingData = postingDoc.data();

        // Sum up the total from purchasedItems (junkshop's actual purchase prices)
        double pickupTotal = 0.0;

        // Get purchasedItems - can be Map with 'list' or direct List
        List<dynamic> purchasedItems = [];
        if (postingData['purchasedItems'] is Map) {
          final purchasedData =
              postingData['purchasedItems'] as Map<String, dynamic>;
          if (purchasedData['list'] is List) {
            purchasedItems = purchasedData['list'] as List<dynamic>;
          }
        } else if (postingData['purchasedItems'] is List) {
          purchasedItems = postingData['purchasedItems'] as List<dynamic>;
        }

        // Calculate total from purchasedItems
        for (final item in purchasedItems) {
          if (item is Map<String, dynamic>) {
            // Handle quantity - might be string or number
            double quantity = 0.0;
            final qtyValue = item['quantity'];
            if (qtyValue is num) {
              quantity = qtyValue.toDouble();
            } else if (qtyValue is String) {
              quantity = double.tryParse(qtyValue) ?? 0.0;
            }

            // Use junkshopTotalPrice if available, otherwise calculate
            final subtotal =
                (item['junkshopTotalPrice'] as num?)?.toDouble() ??
                (quantity *
                    ((item['junkshopPricePerUnit'] as num?)?.toDouble() ??
                        0.0));

            pickupTotal += subtotal;
          }
        }

        if (pickupTotal > 0) {
          matchedCount++;
          totalSpending += pickupTotal;
        }
      }

      if (kDebugMode) {
        print(
          'BUDGET: Matched $matchedCount postings this month (since 1st) for junkshop $junkshopId',
        );
      }
      if (kDebugMode) {
        print(
          'BUDGET: Total monthly spending (purchases + pickups): ₱${totalSpending.toStringAsFixed(2)}',
        );
      }
      return totalSpending;
    } catch (e) {
      if (kDebugMode) print('Error calculating monthly spending: $e');
      return 0.0;
    }
  }

  void _setupRealtimeListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _settingsSubscription = supabase
        .from('junkshops')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((rows) {
          if (kDebugMode) print('🔔 LISTENER TRIGGERED: Document changed');
          if (rows.isNotEmpty && mounted) {
            final data = rows.first;
            final settings = data['settings'] as Map<String, dynamic>?;

            // Update budget spending in real-time
            if (settings != null) {
              setState(() {
                _currentMonthSpending =
                    (settings['currentMonthSpending'] as num?)?.toDouble() ??
                    0.0;
              });
            }

            // Update service radius in real-time when changed in Account settings
            final junkshopProfile = (data['junkshop_profile'] as Map?)
                ?.cast<String, dynamic>();
            final locationMap = (junkshopProfile?['location'] as Map?)
                ?.cast<String, dynamic>();
            final businessMap = (junkshopProfile?['business'] as Map?)
                ?.cast<String, dynamic>();

            if (locationMap != null || businessMap != null) {
              final rawLocationRadius = locationMap?['service_radius'];
              final rawBusinessServiceRadius = businessMap?['service_radius'];
              final rawBusinessOperationRadius =
                  businessMap?['operation_radius'];

              if (kDebugMode) print('  📍 Raw values from junkshop row:');
              if (kDebugMode) {
                print(
                  '     location.service_radius = $rawLocationRadius (${rawLocationRadius?.runtimeType})',
                );
              }
              if (kDebugMode) {
                print(
                  '     business.service_radius = $rawBusinessServiceRadius (${rawBusinessServiceRadius?.runtimeType})',
                );
              }
              if (kDebugMode) {
                print(
                  '     business.operation_radius = $rawBusinessOperationRadius (${rawBusinessOperationRadius?.runtimeType})',
                );
              }

              double updatedRadius = _serviceRadius;

              if (rawLocationRadius != null) {
                updatedRadius = (rawLocationRadius is num)
                    ? rawLocationRadius.toDouble()
                    : updatedRadius;
              } else if (rawBusinessServiceRadius != null) {
                updatedRadius = (rawBusinessServiceRadius is num)
                    ? rawBusinessServiceRadius.toDouble()
                    : updatedRadius;
              } else if (rawBusinessOperationRadius != null) {
                updatedRadius = (rawBusinessOperationRadius is num)
                    ? rawBusinessOperationRadius.toDouble()
                    : updatedRadius;
              }

              if (kDebugMode) {
                print(
                  '  🎯 Comparison: updatedRadius=$updatedRadius vs _serviceRadius=$_serviceRadius',
                );
              }

              if (updatedRadius != _serviceRadius) {
                setState(() {
                  _serviceRadius = updatedRadius;
                });
                if (kDebugMode) {
                  print(
                    '✅ RADIUS DEBUG: Real-time update -> new radius: $_serviceRadius km',
                  );
                }
              }
            }
          }
        });
  }

  Future<void> _loadSimulatorCache() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'junkshop_${user.id}_simulator_cache';
      final cache = prefs.getString(cacheKey);

      if (cache != null) {
        final parts = cache.split('|');
        if (parts.length == 4) {
          setState(() {
            _testDistance = double.tryParse(parts[0]) ?? 5.0;
            _testValueController.text = parts[1];
            _testWeightController.text = parts[2];
            // Parse comma-separated categories
            final categories = parts[3]
                .split(',')
                .where((c) => c.isNotEmpty)
                .map(_normalizeCategoryKey)
                .toSet();
            // Only keep valid categories
            _testCategories = categories
                .where((c) => _materialRules.containsKey(c))
                .toSet();
            if (kDebugMode) {
              print(
                'DEBUG: After cache load - _testCategories: $_testCategories',
              );
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading simulator cache: $e');
    }
  }

  Future<void> _saveSimulatorCache() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'junkshop_${user.id}_simulator_cache';
      final cache =
          '$_testDistance|${_testValueController.text}|${_testWeightController.text}|${_testCategories.join(',')}';
      await prefs.setString(cacheKey, cache);
    } catch (e) {
      if (kDebugMode) print('Error saving simulator cache: $e');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _settingsSubscription?.cancel();
    _tabController.dispose();
    _monthlyBudgetController.dispose();
    _customerSearchController.dispose();
    _testValueController.dispose();
    _testWeightController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(amount);
  }

  String _formatNumber(double number, int decimals) {
    final formatter = NumberFormat('#,##0.${'0' * decimals}', 'en_US');
    return formatter.format(number);
  }

  int _calculateRuleHealthScore() {
    int score = 100;

    int totalMaterials = 0;
    int activeMaterials = 0;

    for (final rule in _materialRules.values) {
      final materials = rule['materials'] as List<dynamic>? ?? [];
      totalMaterials += materials.length;
      activeMaterials += materials
          .where(
            (m) => ((m as Map).cast<String, dynamic>())['isActive'] == true,
          )
          .length;
    }

    if (totalMaterials > 0) {
      final inactiveCount = totalMaterials - activeMaterials;
      final inactiveRatio = inactiveCount / totalMaterials;
      // Max penalty of 60 points if all materials are disabled
      score -= (inactiveRatio * 60).round();
    }

    // Penalty for budget status
    final budget = double.tryParse(_monthlyBudgetController.text) ?? 0.0;
    if (budget > 0) {
      final percentage = _currentMonthSpending / budget;
      if (percentage >= 1.0) {
        // Budget exhausted - CRITICAL, cannot accept new collections
        score = 0;
      } else if (percentage >= 0.9) {
        score -= 30;
      } else if (percentage >= 0.8) {
        score -= 15;
      }
    }

    return score.clamp(0, 100);
  }

  Color _getHealthScoreColor(int score) {
    if (score > 80) return AppColors.primaryGreen;
    if (score >= 50) return Colors.orange;
    return AppColors.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.junkshopPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Business Controls',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            isScrollable: true,
            tabs: const [
              Tab(text: 'Budget & Distance'),
              Tab(text: 'Material Rules'),
              Tab(text: 'Customers'),
              Tab(text: 'Simulator'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.junkshopPrimary,
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildBudgetTab(),
                  _buildMaterialRulesTab(),
                  _buildCustomersTab(),
                  _buildSimulatorTab(),
                ],
              ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.junkshopPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                disabledBackgroundColor: AppColors.junkshopPrimary.withValues(
                  alpha: 0.6,
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: EdgeInsets.zero,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warningColor,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unsaved Changes',
                          style: AppTextStyles.h5.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Message
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'You have unsaved changes. What would you like to do?',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(false);
                              _saveSettings();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.junkshopPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Discard button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.errorColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: AppColors.errorColor.withValues(
                                  alpha: 0.5,
                                ),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Discard Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Cancel button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  Widget _buildBudgetTab() {
    final budget = double.tryParse(_monthlyBudgetController.text) ?? 0.0;
    final budgetPercentage = budget > 0
        ? (_currentMonthSpending / budget).clamp(0.0, 1.0)
        : 0.0;
    final remaining = budget - _currentMonthSpending;
    final healthScore = _calculateRuleHealthScore();

    return RefreshIndicator(
      color: AppColors.junkshopPrimary,
      onRefresh: () async {
        await _loadSettings();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Rule Health Score
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getHealthScoreColor(healthScore).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getHealthScoreColor(
                          healthScore,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.health_and_safety,
                        color: _getHealthScoreColor(healthScore),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rule Health Score',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            healthScore > 80
                                ? 'Excellent - Accepting most posts'
                                : healthScore >= 50
                                ? 'Moderate - Some restrictions'
                                : 'Restrictive - Limited acceptance',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$healthScore',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _getHealthScoreColor(healthScore),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Monthly Budget
          _buildSectionHeader('Monthly Budget Limit'),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              if (kDebugMode) {
                print(
                  'UI RENDER: _currentMonthSpending = ₱${_currentMonthSpending.toStringAsFixed(2)}',
                );
              }
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _monthlyBudgetController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Budget Amount',
                        prefixText: '₱',
                        hintText: '50000',
                        helperText: 'Maximum spending per month on collections',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.junkshopPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Budget Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Month Progress',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(budgetPercentage * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: budgetPercentage >= 1.0
                                ? AppColors.errorColor
                                : budgetPercentage >= 0.8
                                ? Colors.orange
                                : AppColors.junkshopPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: budgetPercentage,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          budgetPercentage >= 1.0
                              ? AppColors.errorColor
                              : budgetPercentage >= 0.8
                              ? Colors.orange
                              : AppColors.junkshopPrimary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent: ₱${_formatCurrency(_currentMonthSpending)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Remaining: ₱${_formatCurrency(remaining)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: remaining < 0
                                ? AppColors.errorColor
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Distance Pricing
          _buildSectionHeader('Dynamic Distance Pricing'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Formula Display
                Row(
                  children: [
                    Icon(
                      Icons.calculate,
                      color: AppColors.junkshopPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Minimum Value Formula',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.junkshopPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Min Value = ₱${_formatNumber(_baseFee, 0)} (flat base fee)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Example: Any distance requires ₱${_formatNumber(_baseFee, 0)} minimum',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Base Fee Slider
                Text(
                  'Base Fee: ₱${_formatNumber(_baseFee, 0)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _baseFee,
                  min: 0,
                  max: 500,
                  divisions: 50,
                  label: '₱${_formatNumber(_baseFee, 0)}',
                  activeColor: AppColors.junkshopPrimary,
                  onChanged: (value) {
                    setState(() => _baseFee = value);
                    _markAsChanged();
                  },
                ),
                Text(
                  'Flat fee charged regardless of distance',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 16),

                // Cost Per Km (disabled — set per-collection during assignment)
                Opacity(
                  opacity: 0.45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cost per Kilometer: ₱${_formatNumber(_costPerKm, 0)}/km',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Set per-collection',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IgnorePointer(
                        child: Slider(
                          value: _costPerKm,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '₱${_formatNumber(_costPerKm, 0)}/km',
                          activeColor: Colors.grey.shade400,
                          onChanged: (_) {},
                        ),
                      ),
                      Text(
                        'Collection Fee is set individually when assigning a collector',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Service Radius Info (from profile)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Service Radius: ${_serviceRadius.toStringAsFixed(0)} km (set in Account settings)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Max Weight-to-Value Ratio Slider
                Text(
                  'Max Weight per ₱100 Value: ${_maxWeightPerValueRatio.toStringAsFixed(1)} kg',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _maxWeightPerValueRatio.clamp(1.0, 10.0),
                  min: 1.0,
                  max: 10.0,
                  divisions: 90,
                  label:
                      '${_maxWeightPerValueRatio.toStringAsFixed(1)} kg/₱100',
                  activeColor: AppColors.junkshopPrimary,
                  onChanged: (value) {
                    setState(() => _maxWeightPerValueRatio = value);
                    _markAsChanged();
                  },
                ),
                Text(
                  'Reject postings with too much weight for their value (e.g., 50kg @ ₱200 = 25 kg/₱100)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Industry Presets
          _buildSectionHeader('Quick Presets'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPresetButton(
                  'Warehouse',
                  Icons.warehouse,
                  '₱30 base fee',
                  '',
                  () {
                    setState(() {
                      _baseFee = 30;
                      _maxWeightPerValueRatio = 15.0;
                    });
                    _markAsChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPresetButton(
                  'Retail',
                  Icons.store,
                  '₱50 base fee',
                  '',
                  () {
                    setState(() {
                      _baseFee = 50;
                      _maxWeightPerValueRatio = 10.0;
                    });
                    _markAsChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPresetButton(
                  'Mobile',
                  Icons.local_shipping,
                  '₱20 base fee',
                  '',
                  () {
                    setState(() {
                      _baseFee = 20;
                      _maxWeightPerValueRatio = 8.0;
                    });
                    _markAsChanged();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPresetButton(
    String title,
    IconData icon,
    String formula,
    String radius,
    VoidCallback onTap,
  ) {
    final isTapped = _tappedPreset == title;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _tappedPreset = title);
      },
      onTapUp: (_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _tappedPreset = null);
        });
        onTap();
      },
      onTapCancel: () {
        setState(() => _tappedPreset = null);
      },
      child: AnimatedScale(
        scale: isTapped ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formula,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.junkshopPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (radius.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  radius,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialRulesTab() {
    return RefreshIndicator(
      color: AppColors.junkshopPrimary,
      onRefresh: () async {
        await _loadSettings();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Control which material categories you accept.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ..._materialRules.entries.map((entry) {
            final key = entry.key;
            final rule = entry.value;
            final isStopped = rule['stopped'] as bool;

            final materials = rule['materials'] as List<dynamic>?;
            int activeCount = 0;
            int totalCount = 0;
            if (materials != null) {
              totalCount = materials.length;
              activeCount = materials
                  .where(
                    (m) =>
                        ((m as Map).cast<String, dynamic>())['isActive'] ==
                        true,
                  )
                  .length;
            }

            String statusLabel;
            Color statusColor;

            if (isStopped || (totalCount > 0 && activeCount == 0)) {
              statusLabel = 'Not accepting';
              statusColor = AppColors.errorColor;
            } else if (totalCount > 0 && activeCount < totalCount) {
              statusLabel = 'Accepting $activeCount/$totalCount materials';
              statusColor = Colors.orange;
            } else {
              statusLabel = 'Accepting all materials';
              statusColor = AppColors.primaryGreen;
            }

            return Column(
              children: [
                Container(
                  color: Colors.transparent,
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule['name'],
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  statusLabel,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: !isStopped,
                              activeColor: AppColors.primaryGreen,
                              inactiveThumbColor: Colors.grey[400],
                              inactiveTrackColor: Colors.grey[300],
                              onChanged: (value) {
                                final user = supabase.auth.currentUser;
                                if (user == null) return;

                                final newStoppedValue = !value;

                                // Update UI immediately for instant feedback
                                setState(() {
                                  _materialRules[key]!['stopped'] =
                                      newStoppedValue;

                                  // Also update all local materials to match the category state
                                  final materials =
                                      _materialRules[key]!['materials']
                                          as List<dynamic>?;
                                  if (materials != null) {
                                    for (var mat in materials) {
                                      if (mat is Map<String, dynamic>) {
                                        mat['isActive'] = value;
                                      }
                                    }
                                  }
                                });

                                // Update Firebase in background
                                Future(() async {
                                  final materialIds =
                                      _materialRules[key]!['materialIds']
                                          as List?;
                                  if (materialIds != null) {
                                    for (final matId in materialIds) {
                                      await supabase
                                          .from('junkshop_materials')
                                          .update({'is_active': value})
                                          .eq('id', matId);
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      children: [
                        if (rule['materials'] != null)
                          ...(rule['materials'] as List).map((material) {
                            final matData = (material as Map)
                                .cast<String, dynamic>();
                            final matName = matData['name'] as String;
                            final matId = matData['id'] as String;
                            final matIsActive = matData['isActive'] as bool;

                            return Column(
                              children: [
                                Divider(
                                  height: 1,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  indent: 20,
                                  endIndent: 20,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          matName,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ),
                                      Transform.scale(
                                        scale: 0.8,
                                        child: Switch(
                                          value: matIsActive,
                                          activeColor: AppColors.primaryGreen,
                                          onChanged: (value) {
                                            final user =
                                                supabase.auth.currentUser;
                                            if (user == null) return;

                                            setState(() {
                                              matData['isActive'] = value;
                                              // If we turn one on, ensure category is active
                                              if (value) {
                                                _materialRules[key]!['stopped'] =
                                                    false;
                                              }
                                            });

                                            supabase
                                                .from('junkshop_materials')
                                                .update({'is_active': value})
                                                .eq('id', matId);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
              ],
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Not authenticated'));
    }

    // If we have cached data, use it immediately to avoid reloading
    if (_cachedCustomers != null) {
      return _buildCustomersList(user, _cachedCustomers!);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCustomersData(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  Text(
                    'Junkshop ID: ${user.id}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.junkshopPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading customers...',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          );
        }

        final customers = snapshot.data ?? [];
        // Cache the data
        _cachedCustomers = customers;

        return _buildCustomersList(user, customers);
      },
    );
  }

  /// Adds/removes [householdId] in junkshops.blocked_households (uuid[]).
  Future<void> _setHouseholdBlocked(
    String junkshopId,
    String householdId,
    bool blocked,
  ) async {
    try {
      final row = await supabase
          .from('junkshops')
          .select('blocked_households')
          .eq('id', junkshopId)
          .maybeSingle();
      final list = <String>{
        ...((row?['blocked_households'] as List?) ?? const []).map(
          (e) => e.toString(),
        ),
      };
      if (blocked) {
        list.add(householdId);
      } else {
        list.remove(householdId);
      }
      await supabase
          .from('junkshops')
          .update({'blocked_households': list.toList()})
          .eq('id', junkshopId);
    } catch (e) {
      if (kDebugMode) print('Error updating blocked households: $e');
    }
  }

  Widget _buildCustomersList(User user, List<Map<String, dynamic>> customers) {
    final filteredCustomers = customers.where((customer) {
      if (_searchQuery.isEmpty) return true;
      final name = (customer['name'] as String).toLowerCase();
      final phone = (customer['phone'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _customerSearchController,
            decoration: InputDecoration(
              hintText: 'Search customers...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _customerSearchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.junkshopPrimary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Customer List
        Expanded(
          child: filteredCustomers.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => RefreshIndicator(
                    color: AppColors.junkshopPrimary,
                    onRefresh: () async {
                      setState(() {
                        _cachedCustomers = null;
                      });
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No customers found',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.junkshopPrimary,
                  onRefresh: () async {
                    setState(() {
                      _cachedCustomers = null;
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      return _buildCustomerCard(customer);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final collections = customer['collections'] as int;
    final customerId = customer['id'] as String;
    // Use local state if available, otherwise use customer data
    final isBlocked =
        _customerBlockState[customerId] ??
        (customer['blocked'] as bool? ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.junkshopPrimary.withValues(alpha: 0.1),
            child: Text(
              customer['name'].toString().substring(0, 1),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.junkshopPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['name'] as String,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer['phone'] as String,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$collections collections completed',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Block Toggle
          Column(
            children: [
              Switch(
                value: isBlocked,
                activeColor: AppColors.errorColor,
                onChanged: (value) {
                  // Update UI immediately
                  setState(() {
                    _customerBlockState[customerId] = value;
                  });

                  // Update Firebase in background
                  final user = supabase.auth.currentUser;
                  if (user != null) {
                    _setHouseholdBlocked(user.id, customerId, value);
                  }
                },
              ),
              Text(
                isBlocked ? 'Unblock' : 'Block',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isBlocked
                      ? AppColors.errorColor
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorTab() {
    return RefreshIndicator(
      color: AppColors.junkshopPrimary,
      onRefresh: () async {
        await _loadSettings();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Test your business rules to see if a posting would be accepted or rejected.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Test Inputs
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.science,
                      color: AppColors.junkshopPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Test Parameters',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Distance Slider
                Text(
                  'Distance: ${_testDistance.toStringAsFixed(1)} km',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _testDistance,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: '${_testDistance.toStringAsFixed(1)} km',
                  activeColor: AppColors.junkshopPrimary,
                  onChanged: (value) => setState(() => _testDistance = value),
                ),

                const SizedBox(height: 16),

                // Estimated Value and Total Weight in a Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _testValueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Estimated Value',
                          prefixText: '₱',
                          hintText: '150',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.junkshopPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _testWeightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total Weight',
                          suffixText: 'kg',
                          hintText: '10',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.junkshopPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Category Selection - Grid of selectable cards
                if (_materialRules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.junkshopPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading material categories...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Categories to Test',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _materialRules.entries.map((entry) {
                          final key = entry.key;
                          final rule = entry.value;
                          final isSelected = _testCategories.contains(key);
                          final isBouncing = _bouncingChip == key;

                          return AnimatedScale(
                            scale: isBouncing ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            onEnd: () {
                              if (_bouncingChip == key) {
                                setState(() => _bouncingChip = null);
                              }
                            },
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _bouncingChip = key;
                                  if (isSelected) {
                                    _testCategories.remove(key);
                                  } else {
                                    _testCategories.add(key);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.junkshopPrimary
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.junkshopPrimary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  rule['name'],
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Test Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _runSimulatorTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Test Rules',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.junkshopPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Test Results
          if (_testResultsVisible) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _testPassed
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : AppColors.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _testPassed ? Icons.check_circle : Icons.cancel,
                        color: _testPassed
                            ? AppColors.primaryGreen
                            : AppColors.errorColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _testPassed ? 'ACCEPTED' : 'REJECTED',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _testPassed
                              ? AppColors.primaryGreen
                              : AppColors.errorColor,
                        ),
                      ),
                    ],
                  ),
                  if (!_testPassed) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Reasons for Rejection',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._testFailureReasons.map((reason) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.errorColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reason,
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_testSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Suggestions',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.junkshopPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._testSuggestions.map((suggestion) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb,
                                size: 16,
                                color: AppColors.junkshopPrimary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: AppTextStyles.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'plastic':
      case 'plastics':
        return 'Plastic';
      case 'metal':
      case 'metals':
        return 'Metal';
      case 'paper':
      case 'papers':
        return 'Paper';
      case 'glass':
        return 'Glass';
      case 'electronics':
      case 'electronic':
        return 'Electronics';
      case 'others':
      case 'other':
        return 'Others';
      default:
        return category;
    }
  }

  String _normalizeCategoryKey(String category) {
    // Normalize category keys to prevent duplicates in dropdown
    switch (category.toLowerCase()) {
      case 'plastic':
      case 'plastics':
        return 'plastic';
      case 'metal':
      case 'metals':
        return 'metal';
      case 'paper':
      case 'papers':
        return 'paper';
      case 'glass':
        return 'glass';
      case 'electronics':
      case 'electronic':
        return 'electronics';
      case 'others':
      case 'other':
        return 'others';
      default:
        return category.toLowerCase();
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plastic':
      case 'plastics':
        return '🥤';
      case 'metal':
      case 'metals':
        return '🔩';
      case 'paper':
      case 'papers':
        return '📄';
      case 'glass':
        return '🪟';
      case 'electronics':
      case 'electronic':
        return '📱';
      case 'others':
      case 'other':
        return '♻️';
      default:
        return '📦';
    }
  }

  Future<List<Map<String, dynamic>>> _loadCustomersData(
    String junkshopId,
  ) async {
    try {
      if (kDebugMode) print('CUSTOMERS: Loading customers for $junkshopId');

      // Step 1: Try loading from cache first
      final cachedCustomers = await _cacheService.getCustomers(junkshopId);
      if (cachedCustomers != null) {
        if (kDebugMode) {
          print(
            'CUSTOMERS: ✅ Loaded ${cachedCustomers.length} customers from cache (instant)',
          );
        }
        // Return cached data immediately, then refresh in background
        Future.microtask(() => _refreshCustomersInBackground(junkshopId));
        return cachedCustomers;
      }

      // Step 2: No cache, fetch from DB
      return await _fetchCustomers(junkshopId);
    } catch (e) {
      if (kDebugMode) print('Error loading customers: $e');
      return [];
    }
  }

  Future<void> _refreshCustomersInBackground(String junkshopId) async {
    try {
      final freshCustomers = await _fetchCustomers(junkshopId);
      // Cache for next time
      await _cacheService.saveCustomers(
        junkshopId: junkshopId,
        customers: freshCustomers,
      );
      // Only update UI if data changed
      if (mounted &&
          _cachedCustomers != null &&
          freshCustomers.length != _cachedCustomers!.length) {
        setState(() {
          _cachedCustomers = freshCustomers;
        });
      }
    } catch (e) {
      if (kDebugMode) print('CUSTOMERS: Background refresh failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCustomers(
    String junkshopId,
  ) async {
    try {
      if (kDebugMode) print('CUSTOMERS: Fetching...');

      // Load blocked households list first
      final junkshopRow = await supabase
          .from('junkshops')
          .select('blocked_households')
          .eq('id', junkshopId)
          .maybeSingle();

      final blockedHouseholds = <String>{
        ...((junkshopRow?['blocked_households'] as List?) ?? const []).map(
          (e) => e.toString(),
        ),
      };

      // Completed postings of this junkshop
      final completedPostings = await JunkshopQuery.postings(
        junkshopId,
        statuses: ['completed'],
      );

      // Aggregate households from BOTH query results
      final householdData = <String, Map<String, dynamic>>{};

      for (final doc in completedPostings.docs) {
        final postingData = doc.data();
        final householdId = postingData['householdId'] as String?;
        if (householdId == null || householdId.isEmpty) continue;

        // Initialize household entry if first time seeing this household
        if (!householdData.containsKey(householdId)) {
          householdData[householdId] = {
            'collections': 0,
            'nestedHousehold': (postingData['household'] as Map?)
                ?.cast<String, dynamic>(),
          };
        }

        // Increment collection count
        householdData[householdId]!['collections'] =
            (householdData[householdId]!['collections'] as int) + 1;
      }

      if (householdData.isEmpty) {
        if (kDebugMode) print('CUSTOMERS: No households found for $junkshopId');
        return [];
      }

      // Batch fetch household documents (max 10 at a time due to whereIn limit)
      final householdIds = householdData.keys.toList();
      final householdDocs = <String, Map<String, dynamic>>{};

      if (householdIds.isNotEmpty) {
        for (var i = 0; i < householdIds.length; i += 10) {
          final batch = householdIds.skip(i).take(10).toList();
          final rows = await supabase
              .from('households')
              .select('id, full_name, phone')
              .inFilter('id', batch);

          for (final row in rows) {
            householdDocs[row['id'].toString()] = row;
          }
        }
      }

      if (kDebugMode) {
        print(
          'CUSTOMERS: Fetched ${householdDocs.length} household documents from households collection',
        );
      }
      if (kDebugMode) {
        print(
          'CUSTOMERS: ${householdData.length - householdDocs.length} households will use nested data',
        );
      }

      // Build final customer list
      final customers = <Map<String, dynamic>>[];

      for (final entry in householdData.entries) {
        final householdId = entry.key;
        final collections = entry.value['collections'] as int;
        final nestedHousehold = (entry.value['nestedHousehold'] as Map?)
            ?.cast<String, dynamic>();

        // Only display customers with at least one collection
        if (collections < 1) {
          continue;
        }

        // Try household document first, fallback to nested data
        Map<String, dynamic>? data = householdDocs[householdId];

        if (data == null && nestedHousehold != null) {
          data = {
            'full_name':
                nestedHousehold['full_name'] ??
                nestedHousehold['name'] ??
                'Unknown',
            'phone': nestedHousehold['phone'] ?? '',
          };
          if (kDebugMode) {
            print(
              'CUSTOMERS: Household $householdId using nested data: ${data['full_name']}, phone: ${data['phone']}, collections: $collections',
            );
          }
        }

        if (data == null) {
          if (kDebugMode) {
            print(
              'CUSTOMERS: Skipping household $householdId (no data available, nestedHousehold was null)',
            );
          }
          continue;
        }

        // Calculate loyalty badge
        String badge;
        if (collections >= 30) {
          badge = 'VIP';
        } else if (collections >= 16) {
          badge = 'Gold';
        } else if (collections >= 6) {
          badge = 'Silver';
        } else {
          badge = 'Bronze';
        }

        customers.add({
          'id': householdId,
          'name': data['full_name'] ?? data['name'] ?? 'Unknown',
          'phone': data['phone'] ?? '',
          'collections': collections,
          'badge': badge,
          'blocked': blockedHouseholds.contains(householdId),
        });
      }

      // Cache for next time
      await _cacheService.saveCustomers(
        junkshopId: junkshopId,
        customers: customers,
      );

      return customers;
    } catch (e) {
      if (kDebugMode) print('Error fetching customers from Firebase: $e');
      return [];
    }
  }

  Future<void> _refreshMaterialsInBackground(String junkshopId) async {
    try {
      final freshMaterials = await _fetchMaterials(junkshopId);
      // Cache for next time
      await _cacheService.saveMaterials(
        junkshopId: junkshopId,
        materials: freshMaterials,
      );
      // Update UI if data changed
      if (mounted && freshMaterials.length != _materialRules.length) {
        setState(() {
          _materialRules = freshMaterials;
        });
      }
    } catch (e) {
      if (kDebugMode) print('MATERIALS: Background refresh failed: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchMaterials(
    String junkshopId,
  ) async {
    try {
      if (kDebugMode) print('MATERIALS: Fetching...');

      final materialsSnapshot = await JunkshopQuery.table(
        'junkshop_materials',
        junkshopId,
      );

      final materialRulesMap = <String, Map<String, dynamic>>{};
      for (final matDoc in materialsSnapshot.docs) {
        final matData = matDoc.data();
        final rawCategory = (matData['category'] ?? 'others').toString();
        final category = _normalizeCategoryKey(rawCategory);

        if (!materialRulesMap.containsKey(category)) {
          materialRulesMap[category] = {
            'name': _getCategoryDisplayName(category),
            'icon': _getCategoryIcon(category),
            'stopped': true,
            'minWeight': 0.0,
            'materialIds': <String>[matDoc.id],
            'materials': <Map<String, dynamic>>[
              {
                'id': matDoc.id,
                'name': matData['name'] ?? 'Unknown',
                'isActive': matData['isActive'] as bool? ?? true,
              },
            ],
          };
        } else {
          (materialRulesMap[category]!['materialIds'] as List).add(matDoc.id);
          (materialRulesMap[category]!['materials'] as List).add({
            'id': matDoc.id,
            'name': matData['name'] ?? 'Unknown',
            'isActive': matData['isActive'] as bool? ?? true,
          });
        }

        if (matData['isActive'] as bool? ?? true) {
          materialRulesMap[category]!['stopped'] = false;
        }
      }

      // Save to cache
      await _cacheService.saveMaterials(
        junkshopId: junkshopId,
        materials: materialRulesMap,
      );

      if (kDebugMode) {
        print(
          'MATERIALS: ✅ Loaded ${materialsSnapshot.docs.length} materials into ${materialRulesMap.keys.length} categories',
        );
      }
      return materialRulesMap;
    } catch (e) {
      if (kDebugMode) print('Error fetching materials from Firebase: $e');
      return {};
    }
  }

  void _runSimulatorTest() {
    _saveSimulatorCache();

    final testValue = double.tryParse(_testValueController.text) ?? 0.0;
    final testWeight = double.tryParse(_testWeightController.text) ?? 0.0;
    if (kDebugMode) {
      print(
        'SIM TEST DEBUG: start -> distance=$_testDistance, value=$testValue, weight=$testWeight, categories=$_testCategories, serviceRadius=$_serviceRadius',
      );
    }
    final reasons = <String>[];
    final suggestions = <String>[];

    // 1. Distance pricing validation
    final minRequiredValue = _baseFee + (_testDistance * _costPerKm);
    if (testValue < minRequiredValue) {
      reasons.add(
        'Value below minimum required (₱${_formatNumber(minRequiredValue, 2)} needed for ${_testDistance.toStringAsFixed(1)} km)',
      );
      suggestions.add(
        'Increase estimated value to at least ₱${_formatNumber(minRequiredValue, 2)}',
      );
    }

    // 2. Service radius check
    if (_testDistance > _serviceRadius) {
      reasons.add(
        'Distance exceeds service radius (${_serviceRadius.toStringAsFixed(0)} km)',
      );
      suggestions.add(
        'Reduce distance to ${_serviceRadius.toStringAsFixed(0)} km or less, or update service radius in Account settings',
      );
      if (kDebugMode) {
        print(
          'SIM TEST DEBUG: distance $_testDistance exceeds serviceRadius $_serviceRadius',
        );
      }
    } else {
      if (kDebugMode) {
        print(
          'SIM TEST DEBUG: distance $_testDistance within serviceRadius $_serviceRadius',
        );
      }
    }

    // 3. Weight-to-value ratio check (prevent unrealistic heavy/low-value posts)
    if (testValue > 0) {
      final weightPerValue = (testWeight / testValue) * 100; // kg per ₱100
      if (weightPerValue > _maxWeightPerValueRatio) {
        reasons.add(
          'Weight-to-value ratio too high (${weightPerValue.toStringAsFixed(2)} kg/₱100, max: ${_maxWeightPerValueRatio.toStringAsFixed(1)} kg/₱100)',
        );
        suggestions.add(
          'This posting has ${testWeight.toStringAsFixed(1)}kg worth only ₱${_formatNumber(testValue, 0)}, which is unprofitable. Increase value or reduce acceptable ratio.',
        );
      }
    }

    // 4. Material category rules - check all selected categories
    if (_testCategories.isEmpty) {
      reasons.add('No material categories selected');
      suggestions.add('Select at least one material category to test');
    } else {
      for (final categoryKey in _testCategories) {
        final categoryRule = _materialRules[categoryKey];
        if (categoryRule != null && categoryRule['stopped'] == true) {
          reasons.add(
            'Category "${categoryRule['name']}" is currently stopped',
          );
          suggestions.add(
            'Enable "${categoryRule['name']}" category in Material Rules tab',
          );
        }
      }
    }

    // 5. Budget check
    final budget = double.tryParse(_monthlyBudgetController.text) ?? 0.0;
    final remainingBudget = budget - _currentMonthSpending;
    if (budget > 0 && testValue > remainingBudget) {
      reasons.add(
        'Insufficient budget remaining (₱${_formatCurrency(remainingBudget)} available)',
      );
      suggestions.add('Wait until next month or increase monthly budget limit');
    }

    setState(() {
      _testResultsVisible = true;
      _testPassed = reasons.isEmpty;
      _testFailureReasons = reasons;
      _testSuggestions = suggestions;
      _hasTestedRules = true; // Mark that user has tested the rules
    });
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;

    // Only show warning if user hasn't tested the rules yet
    bool confirmed = true;
    if (!_hasTestedRules) {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      color: AppColors.junkshopPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Test Rules First',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We recommend testing your new rules before saving to ensure they work as expected.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.junkshopPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.junkshopPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.junkshopPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use the simulator to verify your settings with different scenarios',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                          // Switch to simulation tab (index 3)
                          _tabController.animateTo(3);
                        },
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text(
                          'Go to Simulator',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.junkshopPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save Anyway',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed) return;

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Save settings in the same structure as loaded (flat settings object)
      final budget = double.tryParse(_monthlyBudgetController.text) ?? 0.0;
      final budgetPercentage = budget > 0
          ? (_currentMonthSpending / budget)
          : 0.0;
      final isAvailableForCollections = budgetPercentage < 1.0;
      final ruleHealthScore = _calculateRuleHealthScore();

      final existing = await supabase
          .from('junkshops')
          .select('settings, junkshop_profile')
          .eq('id', user.id)
          .maybeSingle();
      final mergedSettings = <String, dynamic>{
        ...((existing?['settings'] as Map?)?.cast<String, dynamic>() ?? {}),
        'baseFee': _baseFee,
        'costPerKm': _costPerKm,
        'maxWeightPerValueRatio': _maxWeightPerValueRatio,
        'monthlyBudget': budget,
        'currentMonthSpending': _currentMonthSpending,
        'isAvailableForCollections': isAvailableForCollections,
        'budgetPercentage': budgetPercentage,
        'ruleHealthScore': ruleHealthScore,
        // Mark that business controls are configured
        'hasBusinessControls': true,
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
      };
      final profile = Map<String, dynamic>.from(
        (existing?['junkshop_profile'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      final profileLocation = Map<String, dynamic>.from(
        (profile['location'] as Map?)?.cast<String, dynamic>() ?? {},
      )..['service_radius'] = _serviceRadius;
      final profileBusiness = Map<String, dynamic>.from(
        (profile['business'] as Map?)?.cast<String, dynamic>() ?? {},
      )
        ..['service_radius'] = _serviceRadius
        ..['operation_radius'] = _serviceRadius;
      profile['location'] = profileLocation;
      profile['business'] = profileBusiness;

      final settingsData = {
        'settings': mergedSettings,
        'service_radius': _serviceRadius,
        'junkshop_profile': profile,
      };

      if (kDebugMode) {
        print(
          'SAVE DEBUG: Saving settings with ruleHealthScore $ruleHealthScore -> $settingsData',
        );
      }
      if (kDebugMode) {
        print(
          'SAVE DEBUG: Budget status - ${budgetPercentage * 100}% used, Available: $isAvailableForCollections',
        );
      }

      await supabase.from('junkshops').update(settingsData).eq('id', user.id);

      // Verify the save by reading back
      final verifyRow = await supabase
          .from('junkshops')
          .select('settings')
          .eq('id', user.id)
          .maybeSingle();
      final verifySettings = verifyRow?['settings'] as Map<String, dynamic>?;
      final verifiedScore = verifySettings?['ruleHealthScore'];
      if (kDebugMode) {
        print('SAVE DEBUG: Verified ruleHealthScore: $verifiedScore');
      }

      // Update material rules (isActive status)
      int updateCount = 0;

      for (final entry in _materialRules.entries) {
        final rule = entry.value;
        final isStopped = rule['stopped'] as bool;
        final materialIds = rule['materialIds'] as List?;

        if (materialIds != null && materialIds.isNotEmpty) {
          await supabase
              .from('junkshop_materials')
              .update({'is_active': !isStopped})
              .inFilter('id', materialIds.map((e) => e.toString()).toList());
          updateCount += materialIds.length;
        }
      }

      if (kDebugMode) {
        print(
          updateCount > 0
              ? 'SAVE DEBUG: Material rules updated successfully ($updateCount materials)'
              : 'SAVE DEBUG: No material rules to update',
        );
      }

      // Log activity for business control changes
      final changedSettings = <String>[];
      if (_baseFee != 0.0) {
        changedSettings.add('Base Fee: ₱${_baseFee.toStringAsFixed(2)}');
      }
      if (_costPerKm != 0.0) {
        changedSettings.add('Cost/km: ₱${_costPerKm.toStringAsFixed(2)}');
      }
      if (_serviceRadius != 0.0) {
        changedSettings.add(
          'Service Radius: ${_serviceRadius.toStringAsFixed(1)} km',
        );
      }
      if (_monthlyBudgetController.text.isNotEmpty) {
        changedSettings.add(
          'Monthly Budget: ₱${_monthlyBudgetController.text}',
        );
      }
      changedSettings.add('Rule Health Score: $ruleHealthScore');

      await supabase.from('activity_logs').insert({
        'junkshop_id': user.id,
        'type': 'settings_updated',
        'title': 'Updated business controls',
        'details': {
          'baseFee': _baseFee,
          'costPerKm': _costPerKm,
          'maxWeightPerValueRatio': _maxWeightPerValueRatio,
          'serviceRadius': _serviceRadius,
          'monthlyBudget':
              double.tryParse(_monthlyBudgetController.text) ?? 0.0,
          'summary': changedSettings.join(', '),
        },
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Settings saved successfully!'),
          backgroundColor: AppColors.junkshopPrimary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      // Reset unsaved changes flag after successful save
      // Update original values to match current values
      setState(() {
        _hasUnsavedChanges = false;
        _originalBaseFee = _baseFee;
        _originalCostPerKm = _costPerKm;
        _originalMaxWeightPerValueRatio = _maxWeightPerValueRatio;
        _originalMonthlyBudget = _monthlyBudgetController.text;
      });

      // Navigate back to profile screen after successful save
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
