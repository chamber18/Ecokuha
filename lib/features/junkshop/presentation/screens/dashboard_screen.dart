import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/di/service_locator.dart';
import 'inventory/inventory_screen.dart';
import 'inventory/sell_bulk_screen.dart';
import 'collectors/collectors_screen.dart';
import 'analytics/analytics_screen.dart';
import 'history/history_screen.dart';
import 'prices/prices_screen.dart';
import '../../data/repositories/pickups_repository.dart';
import '../../data/services/junkshop_query.dart';
import '../../data/services/material_analytics_service.dart';
import 'pickups/pickups_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final IJunkshopPickupsRepository _pickupsRepo =
      getIt<IJunkshopPickupsRepository>();

  List<NewPickupItem> _recentPurchases = [];

  // Real business metrics
  double _inventoryValue = 0.0;
  int _totalCollections = 0;
  int _activeCollectors = 0;
  int _pendingPickups = 0;
  bool _isLoadingMetrics = true;
  List<Map<String, dynamic>> _materialHealthMetrics = [];
  bool _isLoadingHealthMetrics = true;
  List<Map<String, dynamic>> _activeCollectorsOnRoute = [];
  bool _isLoadingCollectors = true;
  List<Map<String, dynamic>> _purchasesTrend = [];
  List<Map<String, dynamic>> _salesTrend = [];
  final String _selectedTrendPeriod = 'Week';

  // Recent activity
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoadingActivity = true;

  // Welcome dashboard for first-time users
  bool _isFirstTimeUser = true;
  bool _isCheckingFirstTime = true;

  // Setup step completion status
  bool _step1Done = false;
  bool _step2Done = false;
  bool _step3Done = false;

  // Budget and Health Score
  double _monthlyBudget = 0.0;
  double _previousBudget =
      0.0; // Track previous budget to detect actual changes
  double _currentMonthSpending = 0.0;
  double _budgetPercentage = 0.0;
  int _ruleHealthScore = 0;
  bool _isLoadingBudgetHealth = true;
  StreamSubscription<List<Map<String, dynamic>>>? _settingsSubscription;

  // Real-time listeners for critical metrics
  StreamSubscription<List<Map<String, dynamic>>>? _pendingPickupsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _activeCollectorsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _purchasesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _completedPostingsSubscription;

  // Debounce timer for spending recalculation
  Timer? _spendingRecalcTimer;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _checkIfFirstTimeUser();
    _loadRecentPurchases();
    _loadBusinessMetrics();
    _loadMaterialBreakdown();
    _loadMaterialHealthMetrics();
    _loadActiveCollectors();
    _loadPurchasesTrend();
    _loadSalesTrend();
    _loadRecentActivity();
    _loadBudgetAndHealth();
    _setupSettingsListener();
    _setupPendingPickupsListener();
    _setupActiveCollectorsListener();
    _setupSpendingListeners();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _pendingPickupsSubscription?.cancel();
    _activeCollectorsSubscription?.cancel();
    _purchasesSubscription?.cancel();
    _completedPostingsSubscription?.cancel();
    _spendingRecalcTimer?.cancel();
    super.dispose();
  }

  void refreshData() {
    if (!mounted) return;
    _loadRecentPurchases();
    _loadBusinessMetrics();
    _loadMaterialBreakdown();
    _loadMaterialHealthMetrics();
    _loadActiveCollectors();
    _loadPurchasesTrend();
    _loadSalesTrend();
    _loadRecentActivity();
    _loadBudgetAndHealth();
  }

  /// Postings of this junkshop (status filter applied server-side). The docs
  /// carry the legacy `assignedJunkshopId` / `assignedCollectorId` aliases.
  Future<JSnap> _postingsQ({List<String>? statuses}) =>
      JunkshopQuery.postings(currentUid ?? '', statuses: statuses);

  JSnap _withStock(JSnap snap) {
    snap.docs.removeWhere(
      (d) => ((d.data()['stock'] as num?)?.toDouble() ?? 0.0) <= 0,
    );
    return snap;
  }

  void _setupSettingsListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Listen to settings to keep budget and health score in sync
    _settingsSubscription = supabase
        .from('junkshops')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((rows) async {
          if (rows.isEmpty || !mounted) return;

          final data = rows.first;
          final settings = data['settings'] as Map<String, dynamic>?;

          if (settings != null) {
            final budget =
                (settings['monthlyBudget'] as num?)?.toDouble() ?? 0.0;

            final storedHealthScore = (settings['ruleHealthScore'] as num?)
                ?.toInt();

            // Only recalculate spending if budget actually changed
            final budgetChanged = budget != _previousBudget;

            if (mounted) {
              setState(() {
                _monthlyBudget = budget;
                _previousBudget = budget;
                // Recalculate percentage with current spending value
                if (_monthlyBudget > 0) {
                  _budgetPercentage =
                      (_currentMonthSpending / _monthlyBudget) * 100;
                } else {
                  _budgetPercentage = 0;
                }
                if (storedHealthScore != null) {
                  _ruleHealthScore = storedHealthScore;
                } else {
                  _updateHealthScore();
                }
                _isLoadingBudgetHealth = false;
              });

              // Only trigger spending recalculation when budget actually changes
              if (budgetChanged) {
                _scheduleSpendingRecalc();
              }
            }
          }
        });
  }

  void _setupPendingPickupsListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Real-time listener for pending pickups count
    _pendingPickupsSubscription = supabase
        .from('postings')
        .stream(primaryKey: ['id'])
        .eq('junkshop_id', user.id)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _pendingPickups = rows
                .where((r) => r['status'] == 'pending' || r['status'] == 'assigned')
                .length;
          });
        });
  }

  void _setupActiveCollectorsListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Real-time listener for collectors currently on route
    _activeCollectorsSubscription = supabase
        .from('postings')
        .stream(primaryKey: ['id'])
        .eq('junkshop_id', user.id)
        .listen((rows) {
          if (!mounted) return;

          // Extract unique collector IDs of collectors currently on route
          final collectorIds = <String>{};
          for (final row in rows) {
            final status = row['status'];
            if (status != 'in_transit' &&
                status != 'arrived' &&
                status != 'collecting') {
              continue;
            }
            final collectorId = row['collector_id'] as String?;
            if (collectorId != null) collectorIds.add(collectorId);
          }

          setState(() {
            _activeCollectors = collectorIds.length;
          });
        });
  }

  void _setupSpendingListeners() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    if (kDebugMode) {
      print(
        '🔔 DASHBOARD: Setting up real-time spending listeners for junkshop ${user.id}',
      );
    }
    if (kDebugMode) {
      print(
        '   Monitoring purchases and completed postings from ${startOfMonth.day}/${startOfMonth.month}/${startOfMonth.year}',
      );
    }

    // Listen to purchases of this junkshop (recalculate on any change)
    _purchasesSubscription = supabase
        .from('purchases')
        .stream(primaryKey: ['id'])
        .eq('junkshop_id', user.id)
        .listen((rows) {
          if (!mounted) return;
          if (kDebugMode) {
            print('💰 PURCHASE LISTENER: Change detected! ${rows.length} purchases');
          }
          _scheduleSpendingRecalc();
        });

    // Listen to postings of this junkshop (completed ones count as spending)
    _completedPostingsSubscription = supabase
        .from('postings')
        .stream(primaryKey: ['id'])
        .eq('junkshop_id', user.id)
        .listen((rows) {
          if (!mounted) return;
          if (kDebugMode) {
            print('📦 POSTING LISTENER: Change detected! ${rows.length} postings');
          }
          _scheduleSpendingRecalc();
        });
  }

  void _scheduleSpendingRecalc() {
    // Debounce: wait 500ms before recalculating to batch multiple changes
    _spendingRecalcTimer?.cancel();
    _spendingRecalcTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _recalculateSpending();
      }
    });
  }

  Future<void> _recalculateSpending() async {
    if (_isRecalculating) {
      if (kDebugMode) print('⏭️  Skipping recalc - already in progress');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;

    _isRecalculating = true;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      double totalSpending = 0.0;

      if (kDebugMode) {
        print(
          '🔄 RECALCULATING SPENDING for ${now.year}-${now.month} (from ${startOfMonth.day}/${startOfMonth.month}/${startOfMonth.year} to ${now.day}/${now.month}/${now.year})',
        );
      }

      // 1. Calculate from manual purchases THIS MONTH ONLY
      final purchasesSnapshot = await JunkshopQuery.table('purchases', user.id);

      int purchaseCount = 0;
      double purchasesTotal = 0.0;

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final createdAt = toDateTime(data['createdAt']);

        // Only count purchases from THIS month (same year and month)
        if (createdAt != null &&
            createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.isAfter(startOfMonth.subtract(const Duration(days: 1)))) {
          final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          purchasesTotal += amount;
          purchaseCount++;
          if (kDebugMode) {
            print(
              '  💵 Purchase #$purchaseCount on ${createdAt.day}/${createdAt.month}: ₱${amount.toStringAsFixed(2)}',
            );
          }
        }
      }

      if (kDebugMode) {
        print(
          '💰 Manual purchases THIS MONTH: $purchaseCount items = ₱${purchasesTotal.toStringAsFixed(2)}',
        );
      }
      totalSpending = purchasesTotal;

      // 2. Calculate from completed pickups THIS MONTH ONLY
      final completedQuery = await _postingsQ(statuses: ['completed']);
      final allDocs = <String, JDoc>{
        for (final doc in completedQuery.docs) doc.id: doc,
      };

      int pickupCount = 0;
      double pickupsTotal = 0.0;

      for (final postingDoc in allDocs.values) {
        final postingData = postingDoc.data();

        // Only count postings completed THIS MONTH (same year and month)
        final updatedAt = toDateTime(postingData['updatedAt']);
        if (updatedAt == null ||
            updatedAt.year != now.year ||
            updatedAt.month != now.month ||
            updatedAt.isBefore(startOfMonth)) {
          continue;
        }

        double pickupTotal = 0.0;

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

        for (final item in purchasedItems) {
          if (item is Map<String, dynamic>) {
            double quantity = 0.0;
            final qtyValue = item['quantity'];
            if (qtyValue is num) {
              quantity = qtyValue.toDouble();
            } else if (qtyValue is String) {
              quantity = double.tryParse(qtyValue) ?? 0.0;
            }

            final subtotal =
                (item['junkshopTotalPrice'] as num?)?.toDouble() ??
                (quantity *
                    ((item['junkshopPricePerUnit'] as num?)?.toDouble() ??
                        0.0));

            pickupTotal += subtotal;
          }
        }

        if (pickupTotal > 0) {
          pickupsTotal += pickupTotal;
          pickupCount++;
          if (kDebugMode) {
            print(
              '  📦 Pickup #$pickupCount on ${updatedAt.day}/${updatedAt.month}: ₱${pickupTotal.toStringAsFixed(2)}',
            );
          }
        }
      }

      if (kDebugMode) {
        print(
          '📦 Completed pickups THIS MONTH: $pickupCount items = ₱${pickupsTotal.toStringAsFixed(2)}',
        );
      }

      totalSpending += pickupsTotal;

      if (kDebugMode) {
        print(
          '💵 TOTAL SPENDING THIS MONTH (${now.month}/${now.year}): ₱${totalSpending.toStringAsFixed(2)} (Purchases: ₱${purchasesTotal.toStringAsFixed(2)} + Pickups: ₱${pickupsTotal.toStringAsFixed(2)})',
        );
      }

      // Update UI immediately with calculated values
      if (mounted) {
        setState(() {
          _currentMonthSpending = totalSpending;
          if (_monthlyBudget > 0) {
            _budgetPercentage = (totalSpending / _monthlyBudget) * 100;
          } else {
            _budgetPercentage = 0;
          }
          _updateHealthScore();
        });
        if (kDebugMode) {
          print(
            '✅ UI updated immediately with spending = ₱${totalSpending.toStringAsFixed(2)}, percentage = ${_budgetPercentage.toStringAsFixed(1)}%',
          );
        }
      }

      // Also persist the spending in settings for other screens/sessions
      // (don't wait for it)
      supabase
          .from('junkshops')
          .select('settings')
          .eq('id', user.id)
          .maybeSingle()
          .then((row) async {
            final settings = Map<String, dynamic>.from(
              (row?['settings'] as Map?) ?? {},
            );
            settings['currentMonthSpending'] = totalSpending;
            settings['lastSpendingUpdate'] = DateTime.now()
                .toUtc()
                .toIso8601String();
            await supabase
                .from('junkshops')
                .update({'settings': settings})
                .eq('id', user.id);
            if (kDebugMode) print('✅ Junkshop settings updated in background');
          })
          .catchError((e) {
            if (kDebugMode) {
              print('⚠️ Error updating settings: $e (UI already updated)');
            }
          });
    } catch (e) {
      if (kDebugMode) print('❌ Error recalculating spending: $e');
    } finally {
      _isRecalculating = false;
    }
  }

  void _updateHealthScore() {
    int healthScore = 100;

    if (_monthlyBudget > 0) {
      final percentage = _currentMonthSpending / _monthlyBudget;
      if (percentage >= 1.0) {
        healthScore = 0;
      } else if (percentage >= 0.9) {
        healthScore -= 30;
      } else if (percentage >= 0.8) {
        healthScore -= 15;
      }
    }

    _ruleHealthScore = healthScore.clamp(0, 100);
  }

  Future<void> _checkIfFirstTimeUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isCheckingFirstTime = false);
        return;
      }

      if (kDebugMode) print('🆕 Checking if first-time junkshop user...');

      // Step 1: business controls configured
      final junkshopData = await supabase
          .from('junkshops')
          .select('settings')
          .eq('id', user.id)
          .maybeSingle();
      final settings = junkshopData?['settings'] as Map<String, dynamic>?;
      final step1Done = settings?['hasBusinessControls'] == true;

      // Step 2: at least one material added
      final materialsSnapshot = await JunkshopQuery.table('junkshop_materials', user.id, limit: 1);
      final step2Done = materialsSnapshot.docs.isNotEmpty;

      // Step 3: at least one approved collector linked to this junkshop.
      // Registration stores preferred_junkshop_id nested inside collector_profile.
      bool step3Done = false;

      final collectorSnap = await supabase
          .from('collectors')
          .select('id')
          .eq('preferred_junkshop_id', user.id)
          .eq('application_status', 'approved')
          .limit(1);
      step3Done = collectorSnap.isNotEmpty;

      final allDone = step1Done && step2Done && step3Done;

      if (kDebugMode) {
        print(
          '🆕 Setup: step1=$step1Done step2=$step2Done step3=$step3Done → ${allDone ? "regular dashboard" : "welcome dashboard"}',
        );
      }

      setState(() {
        _step1Done = step1Done;
        _step2Done = step2Done;
        _step3Done = step3Done;
        _isFirstTimeUser = !allDone;
        _isCheckingFirstTime = false;
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error checking first-time status: $e');
      setState(() {
        _isFirstTimeUser = false; // Default to regular dashboard on error
        _isCheckingFirstTime = false;
      });
    }
  }

  Future<void> _loadRecentPurchases() async {
    try {
      if (kDebugMode) print('🏠 Dashboard: Loading recent purchases...');
      final result = await _pickupsRepo.fetchReviewedPurchasesPaginated(
        limit: 5,
      );
      final purchases = result['items'] as List<NewPickupItem>;
      setState(() {
        _recentPurchases = purchases; // Already limited to 5
      });
      if (kDebugMode) {
        print(
          '🏠 Dashboard: Loaded ${_recentPurchases.length} recent purchases',
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Dashboard: Error loading purchases: $e');
    }
  }

  Future<void> _loadPurchasesTrend() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      final now = DateTime.now();
      DateTime startDate;
      int days;

      // Calculate start date based on calendar period
      if (_selectedTrendPeriod == 'Week') {
        // Start from Monday of current week
        final weekday = now.weekday; // Monday = 1, Sunday = 7
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        days = 7;
      } else if (_selectedTrendPeriod == 'Month') {
        // Start from 1st of current month
        startDate = DateTime(now.year, now.month, 1);
        days = DateTime(
          now.year,
          now.month + 1,
          0,
        ).day; // Days in current month
      } else {
        // Start from January 1st of current year
        startDate = DateTime(now.year, 1, 1);
        days = DateTime(now.year, 12, 31).difference(startDate).inDays + 1;
      }

      if (kDebugMode) {
        print(
          '📈 Loading purchases trend for $_selectedTrendPeriod from ${DateFormat('MMM d').format(startDate)} to ${DateFormat('MMM d').format(now)}...',
        );
      }

      // Initialize trend data for the selected period
      final Map<String, Map<String, dynamic>> trendByDay = {};
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        final dayLabel = _selectedTrendPeriod == 'Week'
            ? DateFormat('EEE').format(date) // Mon, Tue for week
            : _selectedTrendPeriod == 'Month'
            ? DateFormat('M/d').format(date) // 1/15 for month
            : DateFormat('MMM').format(date); // Jan, Feb for year
        trendByDay[dayKey] = {
          'day': dayLabel,
          'amount': 0.0,
          'collections': 0,
          'date': date,
        };
      }

      // 1. Load manual payouts
      final manualPayouts = await JunkshopQuery.table('purchases', user.id, from: startDate, eq: {'type': 'manual_onsite'});

      if (kDebugMode) {
        print('📦 Found ${manualPayouts.docs.length} manual payouts in period');
      }

      for (final doc in manualPayouts.docs) {
        final data = doc.data();
        final createdAt = toDateTime(data['createdAt']);
        if (createdAt != null) {
          final dayKey = DateFormat('yyyy-MM-dd').format(createdAt);
          if (trendByDay.containsKey(dayKey)) {
            final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            trendByDay[dayKey]!['amount'] =
                (trendByDay[dayKey]!['amount'] as double) + amount;
            trendByDay[dayKey]!['collections'] =
                (trendByDay[dayKey]!['collections'] as int) + 1;
          }
        }
      }

      // 2. Load household collections (reviewed postings)
      final postings = await _postingsQ(statuses: ['completed']);

      if (kDebugMode) {
        print('🏠 Found ${postings.docs.length} completed postings');
      }

      int includedPostings = 0;
      for (final doc in postings.docs) {
        final data = doc.data();

        // Check if assigned to this junkshop
        final junkshopData = data['junkshop'] as Map<String, dynamic>?;
        final assignedJunkshopId =
            junkshopData?['id']?.toString() ??
            data['assignedJunkshopId']?.toString();

        if (assignedJunkshopId == user.id) {
          final reviewedAt = toDateTime(data['reviewedAt']);
          if (reviewedAt != null) {
            final dayKey = DateFormat('yyyy-MM-dd').format(reviewedAt);
            if (trendByDay.containsKey(dayKey)) {
              final itemsMapData = data['verifiedItems'] ?? data['items'];
              final valueFromNested = (itemsMapData is Map<String, dynamic>)
                  ? itemsMapData['totalEstimatedValue']
                  : null;
              final amount = (valueFromNested is num)
                  ? valueFromNested.toDouble()
                  : (data['totalValue'] as num?)?.toDouble() ??
                        (data['totalEstimatedValue'] as num?)?.toDouble() ??
                        0.0;

              trendByDay[dayKey]!['amount'] =
                  (trendByDay[dayKey]!['amount'] as double) + amount;
              trendByDay[dayKey]!['collections'] =
                  (trendByDay[dayKey]!['collections'] as int) + 1;
              includedPostings++;
            }
          }
        }
      }

      if (kDebugMode) {
        print(
          '📊 Included $includedPostings household collections assigned to this junkshop',
        );
      }

      // Convert to sorted list
      final trendList = trendByDay.values.toList()
        ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
        );

      setState(() {
        _purchasesTrend = trendList;
      });

      if (kDebugMode) {
        print(
          '📈 Purchases trend loaded: ${_purchasesTrend.length} data points',
        );
      }
      for (final day in _purchasesTrend) {
        if (kDebugMode) {
          print(
            '  ${day['day']}: ₱${day['amount'].toStringAsFixed(2)}, ${day['collections']} collections',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading purchases trend: $e');
    }
  }

  Future<void> _loadSalesTrend() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      DateTime startDate;
      int days;

      // Calculate start date based on calendar period (same logic as purchases)
      if (_selectedTrendPeriod == 'Week') {
        // Start from Monday of current week
        final weekday = now.weekday; // Monday = 1, Sunday = 7
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        days = 7;
      } else if (_selectedTrendPeriod == 'Month') {
        // Start from 1st of current month
        startDate = DateTime(now.year, now.month, 1);
        days = DateTime(
          now.year,
          now.month + 1,
          0,
        ).day; // Days in current month
      } else {
        // Start from January 1st of current year
        startDate = DateTime(now.year, 1, 1);
        days = DateTime(now.year, 12, 31).difference(startDate).inDays + 1;
      }

      if (kDebugMode) {
        print(
          '📈 Loading sales trend for $_selectedTrendPeriod from ${DateFormat('MMM d').format(startDate)} to ${DateFormat('MMM d').format(now)}...',
        );
      }

      // Initialize trend data for the selected period
      final Map<String, Map<String, dynamic>> trendByDay = {};
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        final dayLabel = _selectedTrendPeriod == 'Week'
            ? DateFormat('EEE').format(date) // Mon, Tue for week
            : _selectedTrendPeriod == 'Month'
            ? DateFormat('M/d').format(date) // 1/15 for month
            : DateFormat('MMM').format(date); // Jan, Feb for year
        trendByDay[dayKey] = {
          'day': dayLabel,
          'amount': 0.0,
          'sales': 0,
          'date': date,
        };
      }

      // Load actual sales transactions from Sales collection
      final salesSnapshot = await JunkshopQuery.table('sales', user.id, from: startDate);

      if (kDebugMode) {
        print('📦 Found ${salesSnapshot.docs.length} sales in period');
      }

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final createdAt = toDateTime(data['createdAt']);
        if (createdAt != null) {
          final dayKey = DateFormat('yyyy-MM-dd').format(createdAt);
          if (trendByDay.containsKey(dayKey)) {
            final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            trendByDay[dayKey]!['amount'] =
                (trendByDay[dayKey]!['amount'] as double) + amount;
            trendByDay[dayKey]!['sales'] =
                (trendByDay[dayKey]!['sales'] as int) + 1;
          }
        }
      }

      final trendList = trendByDay.values.toList()
        ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
        );

      setState(() {
        _salesTrend = trendList;
      });

      if (kDebugMode) {
        print('📈 Sales trend loaded: ${_salesTrend.length} data points');
      }
      for (final day in _salesTrend) {
        if (kDebugMode) {
          print(
            '  ${day['day']}: ₱${day['amount'].toStringAsFixed(2)}, ${day['sales']} sales',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading sales trend: $e');
    }
  }

  Future<void> _loadMaterialBreakdown() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      if (kDebugMode) {
        print('📊 Loading material breakdown from all sources...');
      }

      // Aggregate materials from all sources
      final Map<String, Map<String, dynamic>> materialTotals = {};
      double totalValue = 0.0;

      // 1. Fetch manual purchases (from cashier)
      final purchasesSnapshot = await JunkshopQuery.table('purchases', user.id, eq: {'status': 'completed'});

      if (kDebugMode) {
        print(
          '📦 Processing ${purchasesSnapshot.docs.length} manual purchases',
        );
      }

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        final verifiedItems = data['verifiedItems'] as List<dynamic>?;
        final itemsToUse = verifiedItems ?? items;

        for (final item in itemsToUse) {
          final itemMap = item as Map<String, dynamic>;
          final materialName = itemMap['name'] as String? ?? 'Unknown';
          final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
          final subtotal = (itemMap['subtotal'] as num?)?.toDouble() ?? 0.0;
          final unit = itemMap['unit'] as String? ?? 'kg';

          if (!materialTotals.containsKey(materialName)) {
            materialTotals[materialName] = {
              'material': materialName,
              'weight': 0.0,
              'value': 0.0,
              'unit': unit,
            };
          }

          materialTotals[materialName]!['weight'] =
              (materialTotals[materialName]!['weight'] as double) + quantity;
          materialTotals[materialName]!['value'] =
              (materialTotals[materialName]!['value'] as double) + subtotal;
          totalValue += subtotal;
        }
      }

      // 2. Fetch collector pickups (completed postings)
      // Try several strategies to support both legacy flat fields and nested structures
      final pickupsSnapshot = await _postingsQ(statuses: ['completed']);

      int processedPickups = 0;
      for (final doc in pickupsSnapshot.docs) {
        final data = doc.data();

        // Client-side filter: accept postings where either assignedJunkshopId matches
        // or nested junkshop.id matches. Also accept if posting explicitly lists the junkshop.
        final assignedFlat = data['assignedJunkshopId'] as String?;
        final junkshopNested = (data['junkshop'] is Map)
            ? (data['junkshop']['id'] as String?)
            : null;
        final junkshopIdAlt =
            data['assigned_junkshop_id'] as String?; // possible variants

        final matches =
            (assignedFlat != null && assignedFlat == user.id) ||
            (junkshopNested != null && junkshopNested == user.id) ||
            (junkshopIdAlt != null && junkshopIdAlt == user.id);

        if (!matches) continue;

        // IMPORTANT: Only include pickups that have been reviewed by the junkshop
        final reviewedAt = data['reviewedAt'];
        if (reviewedAt == null) {
          if (kDebugMode) {
            print('  Skipping pickup ${doc.id} - not yet reviewed by junkshop');
          }
          continue;
        }

        processedPickups++;

        // Handle items - could be List or Map structure
        List<Map<String, dynamic>> itemsList = [];

        // Try verifiedItems first (actual collection data), fall back to items (original posting)
        final verifiedItems = data['verifiedItems'];
        final items = data['items'];

        if (verifiedItems is List) {
          // VerifiedItems is an array (most common case)
          itemsList = (verifiedItems)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } else if (items is List) {
          // Items is an array (fallback)
          itemsList = (items)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } else if (verifiedItems is Map) {
          // VerifiedItems is a map structure
          final itemsMap = verifiedItems as Map<String, dynamic>;

          // Check if has a 'list' field (wrapped structure)
          if (itemsMap.containsKey('list') && itemsMap['list'] is List) {
            itemsList = (itemsMap['list'] as List)
                .map((item) => item as Map<String, dynamic>)
                .toList();
          } else {
            // Map with keys as item IDs
            for (final entry in itemsMap.entries) {
              if (entry.value != null && entry.value is Map) {
                itemsList.add(Map<String, dynamic>.from(entry.value as Map));
              }
            }
          }
        } else if (items is Map) {
          // Items is a map structure (fallback)
          final itemsMap = items as Map<String, dynamic>;

          if (itemsMap.containsKey('list') && itemsMap['list'] is List) {
            itemsList = (itemsMap['list'] as List)
                .map((item) => item as Map<String, dynamic>)
                .toList();
          } else {
            for (final entry in itemsMap.entries) {
              if (entry.value != null && entry.value is Map) {
                itemsList.add(Map<String, dynamic>.from(entry.value as Map));
              }
            }
          }
        }

        for (final itemMap in itemsList) {
          final materialName = itemMap['name'] as String? ?? 'Unknown';
          final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = itemMap['unit'] as String? ?? 'kg';

          // For pickups, calculate value using estimatedValue, priceMax, or priceMin
          final estimatedValue =
              (itemMap['estimatedValue'] as num?)?.toDouble() ?? 0.0;
          final priceMax = (itemMap['priceMax'] as num?)?.toDouble() ?? 0.0;
          final priceMin = (itemMap['priceMin'] as num?)?.toDouble() ?? 0.0;

          // Use estimatedValue if available, otherwise calculate from price
          final subtotal = estimatedValue > 0
              ? estimatedValue
              : (priceMax > 0 ? quantity * priceMax : quantity * priceMin);

          if (!materialTotals.containsKey(materialName)) {
            materialTotals[materialName] = {
              'material': materialName,
              'weight': 0.0,
              'value': 0.0,
              'unit': unit,
            };
          }

          materialTotals[materialName]!['weight'] =
              (materialTotals[materialName]!['weight'] as double) + quantity;
          materialTotals[materialName]!['value'] =
              (materialTotals[materialName]!['value'] as double) + subtotal;
          totalValue += subtotal;
        }
      }

      if (kDebugMode) {
        print(
          '🚛 Processed $processedPickups collector pickups (after client-side filtering)',
        );
      }
      if (kDebugMode) {
        print(
          '📊 Material breakdown: ${materialTotals.length} unique materials, total value: ₱${totalValue.toStringAsFixed(2)}',
        );
      }

      // Calculate percentages and sort by value
      final breakdown = materialTotals.values.map((material) {
        final value = material['value'] as double;
        final percentage = totalValue > 0 ? (value / totalValue * 100) : 0.0;
        return {...material, 'percentage': percentage};
      }).toList();

      breakdown.sort(
        (a, b) => (b['value'] as double).compareTo(a['value'] as double),
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error loading material breakdown: $e');
    }
  }

  Future<void> _loadMaterialHealthMetrics() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ HEALTH METRICS: No user logged in');
        setState(() => _isLoadingHealthMetrics = false);
        return;
      }

      debugPrint('🏥 HEALTH METRICS: Starting to load...');
      debugPrint('🏥 HEALTH METRICS: User ID = ${user.id}');

      // 1. Get all materials with current stock > 0 (only materials with actual inventory)
      final materialsSnapshot = _withStock(await JunkshopQuery.table('junkshop_materials', user.id));

      debugPrint(
        '📦 HEALTH METRICS: Found ${materialsSnapshot.docs.length} materials with stock > 0',
      );

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        debugPrint('  📦 Material: ${data['name']}, stock: ${data['stock']}');
      }

      if (materialsSnapshot.docs.isEmpty) {
        debugPrint(
          '📦 HEALTH METRICS: No materials with stock found - hiding dashboard',
        );
        setState(() {
          _materialHealthMetrics = [];
          _isLoadingHealthMetrics = false;
        });
        return;
      }

      // 2. Get sales data from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      debugPrint(
        '📊 HEALTH METRICS: Querying sales since ${thirtyDaysAgo.toString()}',
      );

      final salesSnapshot = await JunkshopQuery.table('sales', user.id, from: thirtyDaysAgo);

      debugPrint(
        '📊 HEALTH METRICS: Found ${salesSnapshot.docs.length} sales in last 30 days',
      );

      // 3. Calculate total quantity sold and revenue per material
      final Map<String, double> materialSales = {};
      final Map<String, double> materialRevenue = {};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        debugPrint('  📊 Sale doc ${doc.id}: ${items.length} items');

        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          // Sales items use 'name' field, not 'materialName'
          final materialName =
              (itemMap['name'] as String?) ??
              (itemMap['materialName'] as String?) ??
              'Unknown';
          final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
          final pricePerUnit =
              (itemMap['pricePerUnit'] as num?)?.toDouble() ??
              (itemMap['price'] as num?)?.toDouble() ??
              0.0;

          debugPrint(
            '    - Item: $materialName, qty: $quantity, price: $pricePerUnit',
          );

          materialSales[materialName] =
              (materialSales[materialName] ?? 0.0) + quantity;
          materialRevenue[materialName] =
              (materialRevenue[materialName] ?? 0.0) +
              (quantity * pricePerUnit);
        }
      }

      debugPrint(
        '📈 HEALTH METRICS: Sales velocity calculated for ${materialSales.length} materials',
      );
      materialSales.forEach((name, qty) {
        debugPrint('  📈 $name: ${qty.toStringAsFixed(2)} kg sold in 30 days');
      });

      // 3.5. Get first purchase date for each material to exclude newly added materials
      debugPrint('📅 HEALTH METRICS: Querying purchase history...');

      // Get current time for date calculations
      final now = DateTime.now();

      final purchasesSnapshot = await JunkshopQuery.table('purchases', user.id, orderBy: 'created_at');

      // Build a map of material name -> first purchase date
      final Map<String, DateTime> materialFirstPurchase = {};

      debugPrint('🛒 Processing onsite purchases...');
      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        final verifiedItems = data['verifiedItems'] as List<dynamic>?;
        final itemsToUse = verifiedItems ?? items;
        final createdAt = toDateTime(data['createdAt']);

        if (createdAt == null) continue;

        for (final item in itemsToUse) {
          final itemMap = item as Map<String, dynamic>;
          final materialName = itemMap['name'] as String? ?? 'Unknown';

          // Update first purchase if this is earlier than existing record
          final existingDate = materialFirstPurchase[materialName];
          if (existingDate == null || createdAt.isBefore(existingDate)) {
            materialFirstPurchase[materialName] = createdAt;
            debugPrint(
              '    🛒 Onsite purchase: $materialName @ $createdAt '
              '(${now.difference(createdAt).inDays} days ago)'
              '${existingDate != null ? ' [UPDATED - earlier than $existingDate]' : ' [NEW]'}',
            );
          }
        }
      }

      // Also check postings (collector pickups)
      debugPrint('📦 Processing collection postings...');
      try {
        final postingsSnapshot = await _postingsQ(statuses: ['completed']);

        int processedCount = 0;
        for (final doc in postingsSnapshot.docs) {
          final data = doc.data();

          // Client-side filter: check multiple possible junkshop ID fields
          final assignedFlat = data['assignedJunkshopId'] as String?;
          final junkshopNested = (data['junkshop'] is Map)
              ? (data['junkshop']['id'] as String?)
              : null;
          final junkshopIdAlt = data['assigned_junkshop_id'] as String?;

          final matches =
              (assignedFlat != null && assignedFlat == user.id) ||
              (junkshopNested != null && junkshopNested == user.id) ||
              (junkshopIdAlt != null && junkshopIdAlt == user.id);

          if (!matches) continue;

          // Only process completed postings
          final status = data['status'] as String?;
          if (status != 'completed') continue;

          // Handle items - might be nested lists, maps, or mixed primitives
          List<dynamic> itemsToUse = [];
          try {
            final verifiedItems = data['verifiedItems'];
            final purchasedItems = data['purchasedItems'];

            void addItems(dynamic source) {
              if (source == null) return;
              if (source is Map) {
                // Check if map has a 'list' key containing the actual items
                if (source.containsKey('list') && source['list'] is List) {
                  final itemList = source['list'] as List;
                  for (final item in itemList) {
                    if (item is Map) itemsToUse.add(item);
                  }
                  return;
                }
                // Otherwise treat map values as items
                itemsToUse.addAll(source.values.whereType<Map>());
                return;
              }
              if (source is List) {
                for (final elem in source) {
                  if (elem is Map) {
                    // Check if this map has a 'list' key
                    if (elem.containsKey('list') && elem['list'] is List) {
                      final itemList = elem['list'] as List;
                      for (final item in itemList) {
                        if (item is Map) itemsToUse.add(item);
                      }
                    } else {
                      itemsToUse.add(elem);
                    }
                  } else if (elem is List) {
                    // Flatten one level of nested lists
                    for (final sub in elem) {
                      if (sub is Map) itemsToUse.add(sub);
                    }
                  }
                }
              }
            }

            // Try purchasedItems first, then verifiedItems
            addItems(purchasedItems);
            if (itemsToUse.isEmpty) {
              addItems(verifiedItems);
            }

            if (processedCount < 3) {
              debugPrint(
                '    📊 Extracted ${itemsToUse.length} material items',
              );
            }
          } catch (e) {
            debugPrint('    ⚠️  Error parsing items for posting ${doc.id}: $e');
            continue;
          }

          // Try multiple date fields
          DateTime? reviewedAt;
          if (data['reviewedAt'] != null) {
            reviewedAt = toDateTime(data['reviewedAt']);
          } else if (data['completedAt'] != null) {
            reviewedAt = toDateTime(data['completedAt']);
          } else if (data['updatedAt'] != null) {
            reviewedAt = toDateTime(data['updatedAt']);
          }

          if (reviewedAt == null || itemsToUse.isEmpty) continue;

          processedCount++;
          if (processedCount <= 3) {
            debugPrint(
              '  📋 Posting ${doc.id}: status=$status, reviewedAt=$reviewedAt, items=${itemsToUse.length}',
            );
          }

          for (final item in itemsToUse) {
            // Skip non-map items (might be primitives like doubles, strings, etc.)
            if (item is! Map) {
              if (processedCount <= 3) {
                debugPrint(
                  '    ⚠️  Skipping non-map item: $item (type: ${item.runtimeType})',
                );
              }
              continue;
            }

            final itemMap = item as Map<String, dynamic>;
            final materialName = itemMap['name'] as String? ?? 'Unknown';

            // Skip items without a valid name
            if (materialName == 'Unknown' || materialName.isEmpty) continue;

            // Update first purchase if this is earlier than existing record
            final existingDate = materialFirstPurchase[materialName];
            if (existingDate == null || reviewedAt.isBefore(existingDate)) {
              final daysAgo = now.difference(reviewedAt).inDays;
              materialFirstPurchase[materialName] = reviewedAt;
              debugPrint(
                '    📦 Collection posting: $materialName @ $reviewedAt '
                '($daysAgo days ago)'
                '${existingDate != null ? ' [UPDATED - earlier than $existingDate]' : ' [NEW]'}',
              );
            }
          }
        }

        debugPrint(
          '📦 Processed $processedCount completed collection postings',
        );
      } catch (e, stackTrace) {
        debugPrint('❌ Error processing collection postings: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      debugPrint(
        '📅 HEALTH METRICS: Found first purchase dates for ${materialFirstPurchase.length} materials',
      );

      // 4. Fetch profit margins from MaterialAnalyticsService (same data source as Analytics screen)
      //    This uses actual purchase cost totals vs. actual sale revenue totals — far more accurate
      //    than comparing avgSellingPrice to the stored costPerUnit field.
      final Map<String, double> analyticsMargins = {};
      try {
        final analyticsService = MaterialAnalyticsService();
        final analyticsMetrics = await analyticsService.getMaterialAnalytics(
          junkshopId: user.id,
          startDate: thirtyDaysAgo,
          forceRefresh: true,
        );
        for (final m in analyticsMetrics) {
          analyticsMargins[m.materialName] = m.profitMargin;
        }
        debugPrint(
          '📊 HEALTH METRICS: Analytics margins loaded for ${analyticsMargins.length} materials',
        );
        analyticsMargins.forEach((name, margin) {
          debugPrint('  📊 $name: profitMargin=${margin.toStringAsFixed(1)}%');
        });
      } catch (e) {
        debugPrint('⚠️ HEALTH METRICS: Analytics margin load failed: $e');
      }

      // 5. Build health metrics for each material
      List<Map<String, dynamic>> healthMetrics = [];

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final materialName = data['name'] as String? ?? 'Unknown';
        final stock = (data['stock'] as num?)?.toDouble() ?? 0.0;
        final avgPurchaseCost = (data['avgPurchaseCost'] as num?)?.toDouble();
        final priceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
        final priceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
        final unit = data['unit'] as String? ?? 'kg';

        debugPrint('  🔍 Checking material: "$materialName"');

        // Check if material is newly purchased (within last 30 days)
        final firstPurchase = materialFirstPurchase[materialName];
        final daysSinceFirstPurchase = firstPurchase != null
            ? now.difference(firstPurchase).inDays
            : null;
        final isNewMaterial =
            firstPurchase != null && daysSinceFirstPurchase! < 30;

        debugPrint(
          '    📅 First purchase: ${firstPurchase?.toString() ?? "UNKNOWN"} '
          '(${daysSinceFirstPurchase ?? "N/A"} days ago) - '
          '${isNewMaterial ? "🆕 NEW" : "📊 EVALUATE"}',
        );

        // Calculate cost and value
        final costPerUnit =
            avgPurchaseCost ??
            (priceMin > 0 ? (priceMin + priceMax) / 2 : priceMax);
        final inventoryValue = stock * costPerUnit;

        // Get sales for this material - check exact match
        final totalSold = materialSales[materialName] ?? 0.0;
        debugPrint('    - Sales found for "$materialName": $totalSold kg');

        final dailyVelocity = totalSold / 30.0; // kg per day

        // Calculate turnover rate: how fast inventory moves (higher = better)
        // Turnover = sales / average inventory (approximated as current stock)
        double turnoverRate;
        String healthStatus;
        String performanceLabel;

        // Special handling for new materials (< 30 days old)
        if (isNewMaterial) {
          turnoverRate = 0.0;
          healthStatus = 'new';
          performanceLabel = 'New material';
        } else if (dailyVelocity <= 0.0) {
          // No sales in 30 days - slow mover or dead stock
          turnoverRate = 0.0;
          healthStatus = 'slow';
          performanceLabel = 'Not selling';
        } else {
          // Turnover rate per month = total sold / current stock
          turnoverRate = stock > 0 ? totalSold / stock : 0.0;

          // Categorize by turnover performance
          if (turnoverRate >= 3.0) {
            // Selling 3x+ the current stock per month - FAST MOVER
            healthStatus = 'hot';
            performanceLabel = 'Hot seller';
          } else if (turnoverRate >= 1.0) {
            // Selling at least as much as current stock - GOOD MOVER
            healthStatus = 'good';
            performanceLabel = 'Good mover';
          } else if (turnoverRate >= 0.3) {
            // Selling 30%+ of stock - MODERATE
            healthStatus = 'moderate';
            performanceLabel = 'Moderate';
          } else {
            // Selling less than 30% of stock - SLOW MOVER
            healthStatus = 'slow';
            performanceLabel = 'Slow mover';
          }
        }

        // Use analytics service profit margin for loss detection
        // (profitMargin = (netProfit / totalPurchaseCost) × 100 — same as Analytics screen)
        final totalRevenue30Days = materialRevenue[materialName] ?? 0.0;
        final avgSellingPrice = totalSold > 0 && totalRevenue30Days > 0
            ? totalRevenue30Days / totalSold
            : 0.0;
        final marginPct = analyticsMargins[materialName];

        if (marginPct != null && marginPct < 0 && dailyVelocity > 0) {
          healthStatus = 'loss';
          performanceLabel = 'Selling at a loss';
          debugPrint(
            '  ⚠️  $materialName: analytics profitMargin=${marginPct.toStringAsFixed(1)}% → SELLING AT LOSS',
          );
        }

        healthMetrics.add({
          'materialName': materialName,
          'stock': stock,
          'unit': unit,
          'inventoryValue': inventoryValue,
          'totalSold30Days': totalSold,
          'dailyVelocity': dailyVelocity,
          'turnoverRate': turnoverRate,
          'avgSellingPrice': avgSellingPrice,
          'marginPct': marginPct,
          'performanceLabel': performanceLabel,
          'healthStatus': healthStatus,
        });

        debugPrint(
          '  🏥 $materialName: stock=$stock $unit, sold30d=${totalSold.toStringAsFixed(2)}, velocity=${dailyVelocity.toStringAsFixed(2)} $unit/day, turnover=${turnoverRate.toStringAsFixed(2)}x, status=$healthStatus',
        );
      }

      // Sort by performance (hot sellers first, then by turnover rate)
      healthMetrics.sort((a, b) {
        // Priority order: loss (alert) > hot > good > moderate > slow > new
        final statusOrder = {
          'loss': 0,
          'hot': 1,
          'good': 2,
          'moderate': 3,
          'slow': 4,
          'new': 5,
        };

        final statusComparison = (statusOrder[a['healthStatus']] ?? 5)
            .compareTo(statusOrder[b['healthStatus']] ?? 5);

        if (statusComparison != 0) return statusComparison;

        // Within same status, sort by turnover rate (descending - higher is better)
        final aTurnover = a['turnoverRate'] as double;
        final bTurnover = b['turnoverRate'] as double;

        return bTurnover.compareTo(aTurnover);
      });

      final hotCount = healthMetrics
          .where((m) => m['healthStatus'] == 'hot')
          .length;
      final goodCount = healthMetrics
          .where((m) => m['healthStatus'] == 'good')
          .length;
      final moderateCount = healthMetrics
          .where((m) => m['healthStatus'] == 'moderate')
          .length;
      final slowCount = healthMetrics
          .where((m) => m['healthStatus'] == 'slow')
          .length;
      final newCount = healthMetrics
          .where((m) => m['healthStatus'] == 'new')
          .length;

      debugPrint('🏥 HEALTH METRICS SUMMARY:');
      debugPrint('  🔥 Hot Sellers: $hotCount');
      debugPrint('  ✅ Good Movers: $goodCount');
      debugPrint('  ⚠️  Moderate: $moderateCount');
      debugPrint('  🐌 Slow Movers: $slowCount');
      debugPrint('  🆕 New Materials: $newCount');
      debugPrint('  📊 Total: ${healthMetrics.length}');

      setState(() {
        _materialHealthMetrics = healthMetrics;
        _isLoadingHealthMetrics = false;
      });

      debugPrint('✅ HEALTH METRICS: Successfully loaded and set state');
    } catch (e, stackTrace) {
      debugPrint('❌ HEALTH METRICS ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _isLoadingHealthMetrics = false);
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingActivity = false);
        return;
      }

      if (kDebugMode) print('📝 Loading recent activity from activity logs...');

      final activityLogs = await JunkshopQuery.table('activity_logs', user.id, orderBy: 'created_at', desc: true, limit: 5);

      List<Map<String, dynamic>> activities = [];

      for (final doc in activityLogs.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'unknown';
        final title = data['title'] as String? ?? 'Activity';
        final message = data['message'] as String?;
        final timestamp = toDateTime(data['timestamp']);
        final details = data['details'] as Map<String, dynamic>?;

        if (timestamp != null) {
          IconData icon;
          Color color;

          switch (type) {
            case 'price_update':
              icon = Icons.attach_money;
              color = AppColors.junkshopPrimary;
              break;
            case 'purchase':
              icon = Icons.payments_outlined;
              color = AppColors.warningColor;
              break;
            case 'collection_completed':
              icon = Icons.check_circle_outline;
              color = AppColors.successColor;
              break;
            case 'collector_assigned':
              icon = Icons.assignment_turned_in;
              color = AppColors.primaryBlue;
              break;
            case 'collector_approved':
              icon = Icons.check_circle;
              color = AppColors.successColor;
              break;
            case 'collector_rejected':
              icon = Icons.cancel;
              color = AppColors.errorColor;
              break;
            case 'material_updated':
              icon = Icons.inventory;
              color = AppColors.infoColor;
              break;
            case 'settings_updated':
              icon = Icons.settings;
              color = AppColors.textSecondary;
              break;
            default:
              icon = Icons.info_outline;
              color = AppColors.textSecondary;
          }

          activities.add({
            'type': type,
            'title': title,
            'message': message,
            'time': timestamp,
            'icon': icon,
            'color': color,
            'details': details,
          });
        }
      }

      if (kDebugMode) print('✅ Loaded ${activities.length} activity logs');

      setState(() {
        _recentActivity = activities;
        _isLoadingActivity = false;
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error loading recent activity: $e');
      setState(() => _isLoadingActivity = false);
    }
  }

  Future<void> _loadActiveCollectors() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingCollectors = false);
        return;
      }

      if (kDebugMode) print('🚛 Loading active collectors on route...');

      // Query postings assigned to this junkshop with active statuses
      // Status flow: assigned → in_transit → arrived → collecting → completed
      final activeStatuses = ['in_transit', 'arrived', 'collecting'];

      List<Map<String, dynamic>> collectors = [];

      // Try multiple strategies to support different field structures
      final postingsSnapshot = await _postingsQ(statuses: activeStatuses);

      // Process postings to extract collector information
      for (final doc in postingsSnapshot.docs) {
        final data = doc.data();

        if (kDebugMode) print('  Checking posting ${doc.id}');
        if (kDebugMode) print('    Raw status: ${data['status']}');

        // Client-side filter for junkshop match
        final assignedFlat = data['assignedJunkshopId'] as String?;
        final junkshopNested = (data['junkshop'] is Map)
            ? (data['junkshop']['id'] as String?)
            : null;

        if (kDebugMode) print('    assignedJunkshopId: $assignedFlat');
        if (kDebugMode) print('    junkshop.id: $junkshopNested');
        if (kDebugMode) print('    Current user: ${user.id}');

        final matches =
            (assignedFlat != null && assignedFlat == user.id) ||
            (junkshopNested != null && junkshopNested == user.id);

        if (!matches) {
          if (kDebugMode) print('    ❌ Junkshop ID does not match, skipping');
          continue;
        }

        // Check status (normalize to lowercase and check variations)
        final rawStatus = data['status'] as String? ?? '';
        final status = rawStatus.toLowerCase().replaceAll('_', ' ').trim();

        if (kDebugMode) print('    Normalized status: "$status"');

        final isActiveStatus =
            status == 'in transit' ||
            status == 'arrived' ||
            status == 'collecting' ||
            status == 'in progress';

        if (!isActiveStatus) {
          if (kDebugMode) {
            print('    ❌ Status "$status" is not active, skipping');
          }
          continue;
        }

        if (kDebugMode) {
          print('  ✅ Found active posting ${doc.id} with status: $status');
        }

        // Extract collector information - check multiple field names
        String? collectorId = data['assignedCollectorId'] as String?;

        // Try alternative field names if first one is null
        collectorId ??= data['assigned_collector_id'] as String?;

        // Check nested collector object
        if (collectorId == null && data['collector'] is Map) {
          collectorId =
              (data['collector'] as Map<String, dynamic>)['id'] as String?;
        }

        // Check assignedTo field (some postings might use this)
        if (collectorId == null && data['assignedTo'] is Map) {
          final assignedTo = data['assignedTo'] as Map<String, dynamic>;
          if (assignedTo['role'] == 'collector') {
            collectorId = assignedTo['id'] as String?;
          }
        }

        if (kDebugMode) print('    Collector field check:');
        if (kDebugMode) {
          print('      assignedCollectorId: ${data['assignedCollectorId']}');
        }
        if (kDebugMode) {
          print(
            '      assigned_collector_id: ${data['assigned_collector_id']}',
          );
        }
        if (kDebugMode) print('      collector: ${data['collector']}');
        if (kDebugMode) print('      assignedTo: ${data['assignedTo']}');
        if (kDebugMode) print('    Resolved collectorId: $collectorId');

        if (collectorId == null) {
          if (kDebugMode) print('    ❌ No collector assigned yet');
          continue;
        }

        // Extract collector details from embedded collector object
        if (kDebugMode) {
          print('    🔍 Using embedded collector data from posting');
        }

        final collectorData = data['collector'] as Map<String, dynamic>?;
        final householdData = data['household'] as Map<String, dynamic>?;

        if (collectorData == null) {
          if (kDebugMode) print('    ❌ Collector object is null in posting');
          continue;
        }

        if (kDebugMode) {
          print('    📋 Collector data keys: ${collectorData.keys.toList()}');
        }

        // Extract household name from nested household object
        final householdName =
            householdData?['name'] as String? ??
            householdData?['full_name'] as String? ??
            householdData?['displayName'] as String? ??
            'Unknown Household';

        final collectorName =
            collectorData['name'] ??
            collectorData['full_name'] ??
            collectorData['displayName'] ??
            'Unknown Collector';

        if (kDebugMode) print('    📍 Household name: $householdName');
        if (kDebugMode) print('    👤 Collector name: $collectorName');

        collectors.add({
          'id': collectorId,
          'name': collectorName,
          'status': _formatStatus(status),
          'avatar': '🧑',
          'currentLocation': data['location']?['address'] ?? 'En route',
          'currentPickup': householdName,
          'postingId': doc.id,
          'postingData': data, // Include full posting data for navigation
        });

        if (kDebugMode) {
          print(
            '    ✅ Successfully added collector: $collectorName (status: $status, posting: ${doc.id})',
          );
        }
      }

      setState(() {
        _activeCollectorsOnRoute = collectors;
        _isLoadingCollectors = false;
      });

      if (kDebugMode) {
        print('🚛 Loaded ${collectors.length} active collectors on route');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading active collectors: $e');
      setState(() => _isLoadingCollectors = false);
    }
  }

  String _formatStatus(String status) {
    // Normalize status: lowercase, replace underscores with spaces, trim
    final normalized = status.toLowerCase().replaceAll('_', ' ').trim();

    if (normalized == 'in transit') return 'On Route';
    if (normalized == 'arrived') return 'Arrived';
    if (normalized == 'collecting') return 'Collecting';
    if (normalized == 'in progress') return 'In Progress';

    // Fallback: capitalize first letter of each word
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  Future<void> _loadBudgetAndHealth() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingBudgetHealth = false);
        return;
      }

      if (kDebugMode) {
        print('🔄 LOAD BUDGET AND HEALTH: Starting initial load...');
      }

      // Fetch settings from junkshop document to get budget
      final data = await supabase
          .from('junkshops')
          .select('settings')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        setState(() => _isLoadingBudgetHealth = false);
        return;
      }

      final settings = data['settings'] as Map<String, dynamic>?;

      if (settings != null) {
        final budget = (settings['monthlyBudget'] as num?)?.toDouble() ?? 0.0;
        final storedHealthScore = (settings['ruleHealthScore'] as num?)
            ?.toInt();

        if (kDebugMode) print('💰 Initial budget loaded: ₱$budget');
        if (kDebugMode) print('📊 Stored health score: $storedHealthScore');

        setState(() {
          _monthlyBudget = budget;
          _previousBudget = budget;
          _ruleHealthScore = storedHealthScore ?? 100;
          _isLoadingBudgetHealth = false;
        });

        // Calculate spending fresh from actual transactions (don't read from settings)
        if (kDebugMode) print('🔄 Triggering initial spending calculation...');
        await _recalculateSpending();
      } else {
        setState(() => _isLoadingBudgetHealth = false);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading budget and health: $e');
      setState(() => _isLoadingBudgetHealth = false);
    }
  }

  Future<void> _loadBusinessMetrics() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingMetrics = false);
        return;
      }

      // Fetch all materials to calculate inventory value
      final materialsSnapshot = await JunkshopQuery.table('junkshop_materials', user.id);

      if (kDebugMode) {
        print(
          '📦 DEBUG Inventory: Found ${materialsSnapshot.docs.length} materials in /junkshops/${user.id}/materials',
        );
      }

      // Calculate inventory value using queries (optimized for dashboard)
      // Sum totalValue directly in queries instead of loading all documents
      if (kDebugMode) {
        print('💰 Calculating inventory value using aggregation...');
      }

      // 1. Sum reviewed purchases (collections) totalValue
      final collectionsSnapshot = await JunkshopQuery.collections(user.id);

      double totalPurchasesValue = collectionsSnapshot.docs.fold<double>(0.0, (
        acc,
        doc,
      ) {
        final data = doc.data();
        final value = (data['totalJunkshopCost'] is num)
            ? (data['totalJunkshopCost'] as num).toDouble()
            : (data['totalValue'] is num)
            ? (data['totalValue'] as num).toDouble()
            : 0.0;
        return acc + value;
      });
      if (kDebugMode) {
        print(
          '💰 Collections purchases: ₱${totalPurchasesValue.toStringAsFixed(2)}',
        );
      }

      // 2. Sum manual payouts (onsite purchases)
      final payoutsSnapshot = await JunkshopQuery.table('purchases', user.id, eq: {'status': 'completed'});

      final manualPayoutsValue = payoutsSnapshot.docs.fold<double>(0.0, (
        acc,
        doc,
      ) {
        final data = doc.data();
        final value = (data['totalCost'] is num)
            ? (data['totalCost'] as num).toDouble()
            : (data['totalAmount'] is num)
            ? (data['totalAmount'] as num).toDouble()
            : 0.0;
        return acc + value;
      });
      totalPurchasesValue += manualPayoutsValue;
      if (kDebugMode) {
        print(
          '💰 Total Purchases (all time): ₱${totalPurchasesValue.toStringAsFixed(2)}',
        );
      }

      // 3. Sum sales totalValue
      final salesSnapshot = await JunkshopQuery.table('sales', user.id);

      final totalSalesValue = salesSnapshot.docs.fold<double>(0.0, (acc, doc) {
        final data = doc.data();
        final value = (data['totalAmount'] is num)
            ? (data['totalAmount'] as num).toDouble()
            : 0.0;
        return acc + value;
      });
      if (kDebugMode) {
        print(
          '💰 Total Sales (all time): ₱${totalSalesValue.toStringAsFixed(2)}',
        );
      }

      // Current inventory value = Sum of (stock × average purchase price) for each material
      double inventoryValue = 0.0;

      // Build a map of material name → list of purchase prices
      final Map<String, List<double>> materialPurchasePrices = {};
      for (final doc in payoutsSnapshot.docs) {
        final data = doc.data();
        if (data['items'] != null && data['items'] is List) {
          for (final item in data['items']) {
            final materialName = item['material'] as String? ?? '';
            final pricePerUnit = (item['pricePerUnit'] as num?)?.toDouble();
            if (materialName.isNotEmpty &&
                pricePerUnit != null &&
                pricePerUnit > 0) {
              materialPurchasePrices.putIfAbsent(materialName, () => []);
              materialPurchasePrices[materialName]!.add(pricePerUnit);
            }
          }
        }
      }

      // Calculate total inventory value using current stock × average purchase price
      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final materialName = data['name'] as String? ?? 'Unknown';
        final stock = (data['stock'] as num?)?.toDouble() ?? 0.0;

        if (stock <= 0) continue; // Skip materials with no stock

        // Calculate average purchase price from actual purchases
        double avgPurchasePrice = 0.0;
        if (materialPurchasePrices.containsKey(materialName) &&
            materialPurchasePrices[materialName]!.isNotEmpty) {
          final prices = materialPurchasePrices[materialName]!;
          avgPurchasePrice = prices.reduce((a, b) => a + b) / prices.length;
        } else {
          // Fallback: use stored avgPurchaseCost or selling price average
          final avgPurchaseCost = (data['avgPurchaseCost'] as num?)?.toDouble();
          final priceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
          final priceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
          avgPurchasePrice =
              avgPurchaseCost ??
              (priceMin > 0 ? (priceMin + priceMax) / 2 : priceMax);
        }

        final itemValue = stock * avgPurchasePrice;
        inventoryValue += itemValue;
      }

      if (kDebugMode) {
        print(
          '💰 Current Inventory Value: ₱${inventoryValue.toStringAsFixed(2)} (Stock × Avg Purchase Price)',
        );
      }

      // Calculate gross profit (Sales - Purchases) for last 30 days
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Get total purchases in last 30 days
      final purchasesSnapshot = await JunkshopQuery.table('purchases', user.id, from: thirtyDaysAgo);

      double totalPurchases = 0.0;
      for (final doc in purchasesSnapshot.docs) {
        totalPurchases +=
            (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      // Get total sales in last 30 days
      final salesSnapshot30Days = await JunkshopQuery.table('sales', user.id, from: thirtyDaysAgo);

      double totalSales = 0.0;
      for (final doc in salesSnapshot30Days.docs) {
        totalSales += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      final grossProfit = totalSales - totalPurchases;
      if (kDebugMode) {
        print(
          '💰 Gross Profit (30 days): ₱${grossProfit.toStringAsFixed(2)} (Sales: ₱${totalSales.toStringAsFixed(2)}, Purchases: ₱${totalPurchases.toStringAsFixed(2)})',
        );
      }

      // Count TODAY's collections from junkshop's collections subcollection
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      if (kDebugMode) {
        print('🔍 Querying collections for junkshop: ${user.id}');
      }
      if (kDebugMode) print('🔍 Today range: $todayStart to $todayEnd');

      // Query collections subcollection with server-side filtering
      final collectionsSnapshotToday = await JunkshopQuery.collections(user.id, from: todayStart, to: todayEnd);

      final totalCollections = collectionsSnapshotToday.docs.length;

      if (kDebugMode) {
        print('🔍 Collections completed today: $totalCollections');
      }
      if (kDebugMode) {
        print(
          '📊 Today\'s Collections: $totalCollections (server-side filtered)',
        );
      }

      // Count active collectors - collectors associated with this junkshop who logged in today
      if (kDebugMode) print('👷 Querying collectors for junkshop: ${user.id}');
      final startOfToday = DateTime(now.year, now.month, now.day);

      final activeCollectorsSnapshot = JSnap(
        rowsToDocs(
          'collectors',
          await supabase
              .from('collectors')
              .select()
              .eq('preferred_junkshop_id', user.id)
              .eq('application_status', 'approved'),
        ).map(JDoc.new).toList(),
      );

      // Filter collectors who are assigned to this junkshop AND logged in today
      int activeCollectors = 0;
      for (final doc in activeCollectorsSnapshot.docs) {
        final data = doc.data();

        // Check if collector is assigned to this junkshop
        final preferredJunkshopId = data['preferred_junkshop_id'] as String?;
        final collectorProfile =
            data['collector_profile'] as Map<String, dynamic>?;
        final nestedPreferredJunkshopId =
            collectorProfile?['preferred_junkshop_id'] as String?;

        final isAssignedToThisJunkshop =
            preferredJunkshopId == user.id ||
            nestedPreferredJunkshopId == user.id;

        if (!isAssignedToThisJunkshop) continue;

        // Check if collector logged in today
        final lastLoginStr = data['last_login_at'] as String?;
        if (lastLoginStr != null) {
          try {
            final lastLogin = DateTime.parse(lastLoginStr);
            final loginDate = DateTime(
              lastLogin.year,
              lastLogin.month,
              lastLogin.day,
            );

            if (loginDate.compareTo(startOfToday) >= 0) {
              activeCollectors++;
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '⚠️ Error parsing last_login_at for collector ${doc.id}: $e',
              );
            }
          }
        }
      }

      if (kDebugMode) {
        print(
          '👷 Active Collectors: $activeCollectors collectors logged in today (junkshop: ${user.id})',
        );
      }

      // Count pending pickups (only 'pending' status - not yet assigned to collector)
      if (kDebugMode) {
        print('📋 Querying pending pickups for junkshop: ${user.id}');
      }

      final pendingPickupsSnapshot = await _postingsQ(statuses: ['pending']);

      // Filter client-side for junkshop match and pending status
      int pendingPickups = 0;

      for (final doc in pendingPickupsSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';

        // Check if status is pending
        if (status != 'pending') continue;

        // Check junkshop match (both flat and nested)
        final assignedFlat = data['assignedJunkshopId'] as String?;
        final junkshopNested = (data['junkshop'] is Map)
            ? (data['junkshop']['id'] as String?)
            : null;

        final matches =
            (assignedFlat != null && assignedFlat == user.id) ||
            (junkshopNested != null && junkshopNested == user.id);

        if (matches) {
          pendingPickups++;
          if (kDebugMode) print('  ✓ Pending pickup ${doc.id}: status=$status');
        }
      }

      if (kDebugMode) print('📋 Total pending pickups: $pendingPickups');

      // Calculate average cycle time (createdAt to reviewedAt)
      final completedPostings = await _postingsQ(statuses: ['completed']);

      double totalCycleHours = 0.0;
      int cycleCount = 0;

      for (final doc in completedPostings.docs) {
        final data = doc.data();
        final createdAt = toDateTime(data['createdAt']);
        final reviewedAt = toDateTime(data['reviewedAt']);

        if (createdAt != null && reviewedAt != null) {
          final cycleHours = reviewedAt.difference(createdAt).inHours;
          totalCycleHours += cycleHours;
          cycleCount++;
        }
      }

      final averageCycleTime = cycleCount > 0
          ? totalCycleHours / cycleCount / 24
          : 0.0; // Convert to days
      if (kDebugMode) {
        print(
          '⏱️ Average Cycle Time: ${averageCycleTime.toStringAsFixed(1)} days (from $cycleCount postings)',
        );
      }

      setState(() {
        _inventoryValue = inventoryValue;
        _totalCollections = totalCollections;
        _activeCollectors = activeCollectors;
        _pendingPickups = pendingPickups;
        _isLoadingMetrics = false;
      });

      if (kDebugMode) {
        print(
          '📊 Dashboard metrics loaded: Inventory=₱${inventoryValue.toStringAsFixed(2)}, Collections=$totalCollections, Collectors=$activeCollectors, Pending=$pendingPickups',
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Dashboard: Error loading metrics: $e');
      setState(() => _isLoadingMetrics = false);
    }
  }

  // Collection volume by material type
  final List<Map<String, dynamic>> materialBreakdown = [
    {
      'material': 'Plastic',
      'weight': 245.5,
      'value': 735.25,
      'percentage': 35.2,
    },
    {'material': 'Paper', 'weight': 189.2, 'value': 567.60, 'percentage': 27.8},
    {'material': 'Metal', 'weight': 156.8, 'value': 940.80, 'percentage': 23.1},
    {'material': 'Glass', 'weight': 98.3, 'value': 196.60, 'percentage': 14.0},
  ];

  List<Map<String, dynamic>> get quickActions => [
    {
      'icon': FluentIcons.box_multiple_24_regular,
      'label': 'Inventory',
      'color': AppColors.primaryBlue,
      'action': () => _navigateToInventory(),
    },
    {
      'icon': FluentIcons.people_24_regular,
      'label': 'Collectors',
      'color': AppColors.successColor,
      'action': () => _navigateToCollectors(),
    },
    {
      'icon': FluentIcons.money_24_regular,
      'label': 'Sale',
      'color': AppColors.junkshopPrimary,
      'action': () => _navigateToSellBulk(),
    },
    {
      'icon': FluentIcons.box_24_regular,
      'label': 'Materials',
      'color': AppColors.warningColor,
      'action': () => _navigateToPrices(),
    },
    {
      'icon': FluentIcons.megaphone_24_regular,
      'label': 'Promotions',
      'color': AppColors.errorColor,
      'action': () => _navigateToPromotions(),
    },
    {
      'icon': FluentIcons.data_area_24_regular,
      'label': 'Analytics',
      'color': AppColors.junkshopPrimary,
      'action': () => _navigateToAnalytics(),
    },
    {
      'icon': FluentIcons.history_24_regular,
      'label': 'History',
      'color': AppColors.textSecondary,
      'action': () => _navigateToHistory(),
    },
  ];

  final List<Map<String, dynamic>> activeCollectors = [
    {
      'id': '1',
      'name': 'Juan Santos',
      'status': 'On Route',
      'avatar': '🧑',
      'currentLocation': 'Apokon, Tagum',
      'eta': '15 minutes',
      'currentPickup': 'Anna B.',
    },
    {
      'id': '2',
      'name': 'Pedro L.',
      'status': 'Arrived',
      'avatar': '👨‍🦱',
      'currentLocation': 'Central, Tagum',
      'currentPickup': 'Maria C.',
    },
  ];

  final List<Map<String, dynamic>> recentActivity = [
    {
      'type': 'collection_completed',
      'message': 'Pedro L. completed pickup from Lisa T.',
      'time': '10 minutes ago',
      'icon': '✅',
      'color': AppColors.successColor,
    },
    {
      'type': 'new_request',
      'message': 'New collection request from Roberto M.',
      'time': '25 minutes ago',
      'icon': '📋',
      'color': AppColors.primaryBlue,
    },
    {
      'type': 'collector_assigned',
      'message': 'Maria Santos assigned to pickup #104',
      'time': '1 hour ago',
      'icon': '🚛',
      'color': AppColors.warningColor,
    },
  ];

  Future<void> _refreshDashboard() async {
    // Refresh all dashboard data
    await Future.wait([
      _loadRecentPurchases(),
      _loadBusinessMetrics(),
      _loadMaterialBreakdown(),
      _loadMaterialHealthMetrics(),
      _loadActiveCollectors(),
      _loadPurchasesTrend(),
      _loadSalesTrend(),
      _loadRecentActivity(),
      _loadBudgetAndHealth(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking first-time status
    if (_isCheckingFirstTime) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.junkshopPrimary),
      );
    }

    // Show welcome dashboard for first-time users
    if (_isFirstTimeUser) {
      return _buildWelcomeDashboard();
    }

    // Regular dashboard for existing users
    return Column(
      children: [
        // Top greeting header
        _buildDashboardHeader(),
        // Scrollable Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshDashboard,
            color: AppColors.junkshopPrimary,
            backgroundColor: Colors.white,
            child: ScrollConfiguration(
              behavior: _NoGlowScrollBehavior(),
              child: NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (overscroll) {
                  overscroll.disallowIndicator();
                  return false;
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Overview Header
                      _buildBusinessOverview(),

                      // Analytics Section
                      _buildAnalyticsSection(),

                      // Operations Section
                      _buildOperationsSection(),

                      // Bottom Padding for Navigation
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 16,
        left: AppDimensions.spacing24,
        right: AppDimensions.spacing24,
        bottom: 16,
      ),
      decoration: const BoxDecoration(color: AppColors.junkshopPrimary),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset(
              'assets/images/logos/bbp logo-50px.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Text(
              'B.B.P. Tracker',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        await _checkIfFirstTimeUser();
      },
      color: AppColors.junkshopPrimary,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Getting Started',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.junkshopPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Set up your\njunkshop',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Complete these 3 steps to start accepting\nwaste collections.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Setup Steps
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetupStep(
                    step: 1,
                    color: AppColors.junkshopPrimary,
                    title: 'Business Controls',
                    description:
                        'Configure operating hours, service area, and collection settings.',
                    isDone: _step1Done,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/junkshop/business-controls',
                      );
                    },
                  ),
                  _buildStepConnector(),
                  _buildSetupStep(
                    step: 2,
                    color: const Color(0xFF0EA5E9),
                    title: 'Add Materials & Prices',
                    description:
                        'Set the waste materials you accept and the price per kilogram.',
                    isDone: _step2Done,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PricesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildStepConnector(),
                  _buildSetupStep(
                    step: 3,
                    color: const Color(0xFF8B5CF6),
                    title: 'Add Collectors',
                    description:
                        'Invite or assign collectors who will handle pickups for your shop.',
                    isDone: _step3Done,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/junkshop/worker-applications',
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          FluentIcons.info_24_regular,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your dashboard will show live stats and activity once your setup is complete.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep({
    required int step,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isDone = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone ? const Color(0xFF86EFAC) : const Color(0xFFE8EDF2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFF16A34A) : color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : Text(
                                  '$step',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Done',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : FluentIcons.chevron_right_24_regular,
              size: isDone ? 22 : 18,
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 42, top: 4, bottom: 4),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessOverview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing16,
        4,
        AppDimensions.spacing16,
        AppDimensions.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isLoadingMetrics
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(
                      color: AppColors.junkshopPrimary,
                    ),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppDimensions.spacing16,
                  crossAxisSpacing: AppDimensions.spacing16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatsCard(
                      title: 'Pending Pickups',
                      value: AppFormatters.number(_pendingPickups),
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.warningColor,
                      onTap: () {
                        widget.onNavigateToTab?.call(1);
                      },
                    ),
                    _buildStatsCard(
                      title: 'Active Collectors',
                      value: AppFormatters.number(_activeCollectors),
                      icon: Icons.people_outline,
                      color: AppColors.junkshopPrimary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CollectorsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildStatsCard(
                      title: 'Today\'s Collections',
                      value: AppFormatters.number(_totalCollections),
                      icon: Icons.recycling_outlined,
                      color: AppColors.primaryBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                    _buildStatsCard(
                      title: 'Current Inventory',
                      value: AppFormatters.currencyWhole(_inventoryValue),
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.successColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InventoryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
          // Budget and Health Score Section - Stacked
          const SizedBox(height: AppDimensions.spacing16),
          if (_isLoadingBudgetHealth)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: AppColors.junkshopPrimary,
                ),
              ),
            )
          else
            Column(
              children: [
                // Budget Status - Compact
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/junkshop/business-controls');
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _monthlyBudget == 0
                          ? Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warningColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Set Your Monthly Budget',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Configure business rules to track spending',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: _budgetPercentage >= 100
                                          ? AppColors.errorColor
                                          : _budgetPercentage >= 90
                                          ? AppColors.warningColor
                                          : AppColors.junkshopPrimary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Monthly Budget',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppColors.textSecondary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppFormatters.currency(
                                        _currentMonthSpending,
                                      ),
                                      style: AppTextStyles.h5.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: _budgetPercentage >= 100
                                            ? AppColors.errorColor
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'of ${AppFormatters.currencyWhole(_monthlyBudget)}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (_budgetPercentage / 100).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    minHeight: 6,
                                    backgroundColor: AppColors.backgroundDark,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _budgetPercentage >= 100
                                          ? AppColors.errorColor
                                          : _budgetPercentage >= 90
                                          ? AppColors.warningColor
                                          : AppColors.successColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_budgetPercentage.toStringAsFixed(0)}% used',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _budgetPercentage >= 100
                                        ? AppColors.errorColor
                                        : _budgetPercentage >= 90
                                        ? AppColors.warningColor
                                        : AppColors.successColor,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing12),
                // Rule Health Score - Only show when <= 70
                if (_ruleHealthScore <= 70)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.health_and_safety_outlined,
                                color: _getHealthColor(_ruleHealthScore),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Business Rule Health',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _ruleHealthScore.toString(),
                                      style: AppTextStyles.h3.copyWith(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: _getHealthColor(
                                          _ruleHealthScore,
                                        ),
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getHealthLabel(_ruleHealthScore),
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _getHealthColor(
                                          _ruleHealthScore,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _getHealthColor(_ruleHealthScore),
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getHealthIcon(_ruleHealthScore),
                                    color: _getHealthColor(_ruleHealthScore),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getHealthColor(int score) {
    if (score >= 80) return AppColors.successColor;
    if (score >= 60) return AppColors.warningColor;
    return AppColors.errorColor;
  }

  String _getHealthLabel(int score) {
    if (score >= 80) return 'Healthy';
    if (score >= 60) return 'Needs Attention';
    return 'Critical';
  }

  IconData _getHealthIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.warning;
    return Icons.error;
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLg,
          vertical: AppDimensions.paddingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: AppDimensions.iconMd),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 14),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing4),
            Text(value, style: AppTextStyles.cardValue.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  Widget _buildAnalyticsSection() {
    return Column(
      children: [
        // Quick Actions
        _buildQuickActions(),

        // Material Stock Overview
        _buildMaterialStockOverview(),
      ],
    );
  }

  Widget _buildMaterialStockOverview() {
    if (_isLoadingHealthMetrics) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.spacing24),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.junkshopPrimary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    if (_materialHealthMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if all materials are new (less than 30 days old)
    final hasNonNewMaterials = _materialHealthMetrics.any(
      (m) => m['healthStatus'] != 'new',
    );

    // Only show stock health if there are materials outside the "new" category
    if (!hasNonNewMaterials) {
      return const SizedBox.shrink();
    }

    // Group materials by performance status
    final lossMaterials = _materialHealthMetrics
        .where((m) => m['healthStatus'] == 'loss')
        .toList();
    final hotMaterials = _materialHealthMetrics
        .where((m) => m['healthStatus'] == 'hot')
        .toList();
    final goodMaterials = _materialHealthMetrics
        .where((m) => m['healthStatus'] == 'good')
        .toList();
    final moderateMaterials = _materialHealthMetrics
        .where((m) => m['healthStatus'] == 'moderate')
        .toList();
    final slowMaterials = _materialHealthMetrics
        .where((m) => m['healthStatus'] == 'slow')
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacing24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stock Health',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const AnalyticsScreen(initialTabIndex: 1),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Materials',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.junkshopPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.junkshopPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.junkshopPrimary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loss Makers - Selling at a loss (top priority warning)
                if (lossMaterials.isNotEmpty) ...[
                  _buildHealthStatusHeader(
                    '⚠️ Selling at a Loss',
                    lossMaterials.length,
                    Colors.deepOrange.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildMaterialHealthItem(lossMaterials.first, isLast: false),
                  if (lossMaterials.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${lossMaterials.length - 1} more loss-making materials',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                ],

                // Hot Sellers - Priority to buy more
                if (hotMaterials.isNotEmpty) ...[
                  _buildHealthStatusHeader(
                    '🔥 Hot Sellers - Buy More',
                    hotMaterials.length,
                    Colors.red.shade600,
                  ),
                  const SizedBox(height: 12),
                  _buildMaterialHealthItem(hotMaterials.first, isLast: false),
                  if (hotMaterials.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${hotMaterials.length - 1} more hot materials',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                ],

                // Good Movers - Performing well
                if (goodMaterials.isNotEmpty) ...[
                  _buildHealthStatusHeader(
                    '✅ Good Movers',
                    goodMaterials.length,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildMaterialHealthItem(goodMaterials.first, isLast: false),
                  if (goodMaterials.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${goodMaterials.length - 1} more good materials',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (moderateMaterials.isNotEmpty || slowMaterials.isNotEmpty)
                    const Divider(height: 24),
                ],

                // Moderate - Average performance
                if (moderateMaterials.isNotEmpty) ...[
                  _buildHealthStatusHeader(
                    '⚠️ Moderate Movers',
                    moderateMaterials.length,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildMaterialHealthItem(
                    moderateMaterials.first,
                    isLast: false,
                  ),
                  if (moderateMaterials.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${moderateMaterials.length - 1} more moderate materials',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (slowMaterials.isNotEmpty) const Divider(height: 24),
                ],

                // Slow Movers - Consider reducing
                if (slowMaterials.isNotEmpty) ...[
                  _buildHealthStatusHeader(
                    '🐌 Slow Movers - Reduce Buying',
                    slowMaterials.length,
                    Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  _buildMaterialHealthItem(slowMaterials.first, isLast: false),
                  if (slowMaterials.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${slowMaterials.length - 1} more slow materials',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatusHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialHealthItem(
    Map<String, dynamic> material, {
    required bool isLast,
  }) {
    final materialName = material['materialName'] as String;
    final stock = material['stock'] as double;
    final unit = material['unit'] as String;
    final dailyVelocity = material['dailyVelocity'] as double;
    final turnoverRate = material['turnoverRate'] as double;
    final inventoryValue = material['inventoryValue'] as double;
    final healthStatus = material['healthStatus'] as String;
    final totalSold = material['totalSold30Days'] as double;
    final marginPct = material['marginPct'] as double?;

    Color statusColor;
    switch (healthStatus) {
      case 'loss':
        statusColor = Colors.deepOrange.shade700;
        break;
      case 'hot':
        statusColor = Colors.red.shade600;
        break;
      case 'good':
        statusColor = Colors.green;
        break;
      case 'moderate':
        statusColor = Colors.orange;
        break;
      case 'slow':
        statusColor = Colors.grey;
        break;
      case 'new':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  materialName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${stock.toStringAsFixed(1)} $unit',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Show different layout based on whether we have sales data
              if (dailyVelocity > 0) ...[
                // Has sales data - show performance metrics
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sold/Month',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalSold.toStringAsFixed(1)} $unit',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        healthStatus == 'loss' ? 'Margin' : 'Turnover',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        healthStatus == 'loss' && marginPct != null
                            ? '${marginPct.toStringAsFixed(1)}%'
                            : '${turnoverRate.toStringAsFixed(1)}x',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: healthStatus == 'loss'
                              ? Colors.deepOrange.shade700
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Value',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.currency(inventoryValue),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // No sales data - show just stock info and value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No sales in 30 days',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Value',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.currency(inventoryValue),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsSection() {
    return Column(
      children: [
        // Active Collectors (if any)
        _buildActiveCollectors(),

        // Recent Activity Feed
        _buildRecentActivityFeed(),
      ],
    );
  }

  Widget _buildRecentActivityFeed() {
    if (_isLoadingActivity) {
      return const SizedBox.shrink();
    }

    if (_recentActivity.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacing24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/junkshop/profile/logs');
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.junkshopPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.junkshopPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.junkshopPrimary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _recentActivity.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                final showDivider = index < _recentActivity.length - 1;

                return Column(
                  children: [
                    _buildActivityItem(activity),
                    if (showDivider)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final title = activity['title'] as String;
    final time = activity['time'] as DateTime;
    final icon = activity['icon'] as IconData;
    final color = activity['color'] as Color;
    final details = activity['details'] as Map<String, dynamic>?;

    final now = DateTime.now();
    final difference = now.difference(time);

    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours} hr ago';
    } else {
      timeAgo =
          '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }

    return InkWell(
      onTap: details != null
          ? () => _showActivityLogDetails(context, activity)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (details != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  void _showActivityLogDetails(BuildContext context, Map<String, dynamic> log) {
    final details = log['details'] as Map<String, dynamic>?;
    if (details == null) return;

    final type = log['type'] as String? ?? 'system';
    final message =
        log['message'] as String? ?? log['title'] as String? ?? 'No message';
    final timestamp = log['time'] as DateTime?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
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
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Activity Details',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Details Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Basic info
                  _buildDetailRow('Type', type),
                  _buildDetailRow('Message', message),
                  _buildDetailRow(
                    'Timestamp',
                    timestamp != null
                        ? DateFormat('MMMM d, y • h:mm:ss a').format(timestamp)
                        : 'Unknown',
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  Text(
                    'Additional Details',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // All detail fields
                  ...details.entries.map((entry) {
                    return _buildDetailRow(
                      entry.key,
                      entry.value?.toString() ?? 'N/A',
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spacing12),
              Text(
                'Quick Actions',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing16),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < quickActions.length - 1 ? 12 : 0,
                ),
                child: SizedBox(
                  width: 67,
                  child: _buildQuickActionItem(
                    icon: action['icon']!,
                    label: action['label']!,
                    color: action['color']!,
                    onTap: action['action']!,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 53,
              height: 53,
              decoration: const BoxDecoration(
                color: AppColors.containerGray,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCollectors() {
    // Show loading state
    if (_isLoadingCollectors) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collectors on Route',
                  style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: _navigateToPickupsAssigned,
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.junkshopPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.junkshopPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(
                  color: AppColors.junkshopPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Hide section if no active collectors
    if (_activeCollectorsOnRoute.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacing32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collectors on Route',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _navigateToPickupsAssigned,
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.junkshopPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.junkshopPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _activeCollectorsOnRoute.length,
            itemBuilder: (context, index) {
              final collector = _activeCollectorsOnRoute[index];
              return _buildActiveCollectorCard(collector);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCollectorCard(Map<String, dynamic> collector) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: InkWell(
        onTap: () {
          // Navigate to pickups screen Assigned tab and show the collector details
          final postingData = collector['postingData'] as Map<String, dynamic>?;
          final postingId = collector['postingId'] as String?;
          if (postingData != null && postingId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PickupsScreen(
                  initialTabIndex: 1,
                  targetPostingId: postingId,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collector['name'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      collector['status'] == 'On Route'
                          ? 'Currently collecting from ${collector['currentPickup']}'
                          : 'Arrived at ${collector['currentPickup']}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: collector['status'] == 'On Route'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  collector['status'],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: collector['status'] == 'On Route'
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InventoryScreen()),
    );
  }

  void _navigateToCollectors() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CollectorsScreen()),
    );
  }

  Future<void> _navigateToSellBulk() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final snapshot = rowsToDocs(
      'junkshop_materials',
      await supabase
          .from('junkshop_materials')
          .select()
          .eq('junkshop_id', user.id),
    );

    final materialsMap = <String, Map<String, dynamic>>{};
    for (final data in snapshot) {
      final materialId = data['id'];
      if (materialsMap.containsKey(materialId)) continue;
      materialsMap[materialId] = {
        'id': materialId,
        'docId': materialId,
        'name': data['name'] ?? '',
        'price': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
        'cost':
            (data['avgPurchaseCost'] as num?)?.toDouble() ??
            (data['priceMax'] as num?)?.toDouble() ??
            0.0,
        'unit': data['unit'] ?? 'kg',
        'stock': (data['stock'] as num?)?.toDouble() ?? 0.0,
      };
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellBulkScreen(
          materials: materialsMap.values.toList(),
          onConfirm: (_) {},
        ),
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  void _navigateToPrices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PricesScreen()),
    );
  }

  void _navigateToAnalytics() {
    Navigator.pushNamed(context, '/junkshop/analytics');
  }

  void _navigateToPickupsAssigned() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PickupsScreen(initialTabIndex: 1),
      ),
    );
  }

  void _navigateToPromotions() {
    Navigator.pushNamed(context, '/junkshop/promotions');
  }
}
