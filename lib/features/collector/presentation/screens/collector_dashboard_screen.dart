import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/collector_tasks_repository.dart';
import '../../data/models/collection_task_model.dart';
import '../widgets/availability_toggle.dart';
// Removed StatsSummaryCard in favor of a Leaderboard section
import '../widgets/earnings_overview_card.dart';
import '../widgets/task_summary_card.dart';
import '../widgets/quick_action_grid.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() =>
      _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  bool _isAvailable = true;

  // Real data from Firestore
  List<CollectorTask> _myTasks = [];
  bool _loadingTasks = true; // Start as true to show loading on first load
  String? _errorTasks;
  bool _isInitialLoad = true; // Track if this is the first load

  // Leaderboard filter state: Day, Week, Month, Year, All Time
  String _leaderboardFilter = 'Week';

  final List<Map<String, dynamic>> _leaderboard = const [
    {'name': 'Juan Santos', 'kg': 145.2},
    {'name': 'Maria Dela Cruz', 'kg': 132.8},
    {'name': 'Pedro Reyes', 'kg': 120.4},
    {'name': 'Ana Lopez', 'kg': 108.9},
    {'name': 'Rico Tan', 'kg': 97.3},
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyTasks();
  }

  Future<void> _fetchMyTasks() async {
    final uid = currentUid;
    if (uid == null) {
      setState(() {
        _errorTasks = 'Not logged in';
        _loadingTasks = false;
      });
      return;
    }

    // Only show loading spinner on initial load
    if (_isInitialLoad) {
      setState(() {
        _loadingTasks = true;
        _errorTasks = null;
      });
    }

    try {
      final repo = getIt<ICollectorTasksRepository>();
      final tasks = await repo.fetchMyTasks(uid);

      if (!mounted) return;

      setState(() {
        _myTasks = tasks;
        _loadingTasks = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorTasks = e.toString();
        _loadingTasks = false;
        _isInitialLoad = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.backgroundDark, // Changed to make cards pop more
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, '/collector-notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.pushNamed(context, '/collector-profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header
              _buildGreetingHeader(),

              const SizedBox(height: 20),

              // Availability Toggle
              AvailabilityToggle(
                isAvailable: _isAvailable,
                onToggle: _toggleAvailability,
              ),

              const SizedBox(height: 24),

              // Leaderboard - Highest Collection
              _buildLeaderboardSection(),

              const SizedBox(height: 20),

              // Earnings Overview
              const EarningsOverviewCard(
                todayEarnings: 385.00,
                weeklyEarnings: 1250.50,
                monthlyEarnings: 4820.75,
                pendingAmount: 150.00,
              ),

              const SizedBox(height: 20),

              // Task Summary Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Tasks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/collector-tasks'),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Active Tasks - Replace mock data with real data
              if (_loadingTasks)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorTasks != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.errorColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load tasks',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorTasks!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (_myTasks.isNotEmpty) ...[
                // Display real tasks from Firestore
                for (final task in _myTasks) ...[
                  TaskSummaryCard(
                    title: task.items.isNotEmpty
                        ? task.items.first
                        : 'Collection Task',
                    address: task.addressShort ?? 'Address not available',
                    estimatedEarnings: task.totalValue,
                    timeSlot: _formatTimeSlot(task.assignedAt),
                    status: task.status,
                    priority: _determinePriority(task.totalValue),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/collector-task-details',
                      arguments: {
                        'taskId': task.id,
                        'householdId': task.householdId,
                        // If this screen uses CollectorTask, expose its docPath
                        'docPath': (task as dynamic).docPath,
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No active tasks. Check back later for new collection tasks.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Quick Actions Grid
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 12),

              QuickActionGrid(
                actions: [
                  QuickActionItem(
                    icon: Icons.history,
                    label: 'Collections\nHistory',
                    color: const Color(0xFF10B981),
                    onTap: () =>
                        Navigator.pushNamed(context, '/collector-collections'),
                  ),
                  QuickActionItem(
                    icon: Icons.message_outlined,
                    label: 'Messages',
                    color: const Color(0xFF3B82F6),
                    onTap: () =>
                        Navigator.pushNamed(context, '/collector-messages'),
                  ),
                  QuickActionItem(
                    icon: Icons.attach_money,
                    label: 'Earnings',
                    color: const Color(0xFF059669),
                    onTap: () =>
                        Navigator.pushNamed(context, '/collector-earnings'),
                  ),
                  QuickActionItem(
                    icon: Icons.route_outlined,
                    label: 'Routes',
                    color: const Color(0xFFF59E0B),
                    onTap: () =>
                        Navigator.pushNamed(context, '/collector-routes'),
                  ),
                  QuickActionItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    color: const Color(0xFF06B6D4),
                    onTap: () =>
                        Navigator.pushNamed(context, '/collector-settings'),
                  ),
                  QuickActionItem(
                    icon: Icons.help_outline,
                    label: 'Help &\nSupport',
                    color: const Color(0xFF64748B),
                    onTap: () =>
                        Navigator.pushNamed(context, '/collector-help'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Performance Insights
              _buildPerformanceInsights(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final now = DateTime.now();
    String greeting;

    if (now.hour < 12) {
      greeting = 'Good Morning';
    } else if (now.hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF10B981), const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Juan Santos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAvailable ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAvailable ? 'Available' : 'Off Duty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: const Color(0xFF059669), size: 24),
              const SizedBox(width: 8),
              Text(
                'Performance Insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Removed Avg. Rating card per request; keep a single metric row
          _buildInsightItem(
            'Completion Rate',
            '95%',
            Icons.check_circle_outline,
            const Color(0xFF059669),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'On-Time Rate',
                  '92%',
                  Icons.access_time,
                  const Color(0xFF06B6D4),
                ),
              ),
              Expanded(
                child: _buildInsightItem(
                  'This Week',
                  '12 tasks',
                  Icons.assignment,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: const Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Great work! Your performance this week is above average.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w500,
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

  Widget _buildLeaderboardSection() {
    final filters = ['Day', 'Week', 'Month', 'Year', 'All Time'];
    // In a real app, you would fetch/sort based on _leaderboardFilter
    final items = _leaderboard;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                'Leaderboard: Highest Collection',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _leaderboardFilter,
                onSelected: (v) => setState(() => _leaderboardFilter = v),
                itemBuilder: (_) => filters
                    .map((f) => PopupMenuItem(value: f, child: Text(f)))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _leaderboardFilter,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...List.generate(items.length, (i) {
            final rank = i + 1;
            final entry = items[i];
            final isTop = i == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTop
                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isTop
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: isTop ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry['name'] as String,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Collected ${(entry['kg'] as num).toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.trending_up, color: const Color(0xFF10B981)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _toggleAvailability(bool isAvailable) {
    setState(() {
      _isAvailable = isAvailable;
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAvailable
              ? 'You are now available for collections'
              : 'You are now off duty',
        ),
        backgroundColor: isAvailable
            ? const Color(0xFF059669)
            : const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );

    // In real app: Update availability status on server
    _updateAvailabilityStatus(isAvailable);
  }

  Future<void> _updateAvailabilityStatus(bool isAvailable) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));

    // Handle success/error states
    if (mounted) {
      // Update local state or show error if API call fails
    }
  }

  Future<void> _onRefresh() async {
    // Refresh tasks from Firestore
    await _fetchMyTasks();
  }

  String _formatTimeSlot(DateTime? assignedTime) {
    if (assignedTime == null) return 'Time not set';

    final now = DateTime.now();
    final diff = now.difference(assignedTime);

    if (diff.inMinutes < 60) {
      return 'Assigned ${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return 'Assigned ${diff.inHours} hours ago';
    } else {
      return 'Assigned ${diff.inDays} days ago';
    }
  }

  String _determinePriority(double value) {
    if (value >= 100) return 'high';
    if (value >= 50) return 'medium';
    return 'low';
  }
}
