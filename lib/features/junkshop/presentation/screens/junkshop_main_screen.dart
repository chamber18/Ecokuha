import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/di/service_locator.dart';
import 'dashboard_screen.dart' as dashboard;
import 'pickups/pickups_screen.dart';

import 'profile/profile_screen.dart';
import 'messages/messages_screen.dart';
import '../widgets/cashier_modal.dart';
import '../bloc/profile/profile_bloc.dart';
import '../bloc/profile/profile_event.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class JunkshopMainScreen extends StatefulWidget {
  final int initialIndex;

  const JunkshopMainScreen({super.key, this.initialIndex = 0});

  @override
  State<JunkshopMainScreen> createState() => _JunkshopMainScreenState();
}

class _JunkshopMainScreenState extends State<JunkshopMainScreen> {
  late int _currentIndex;
  final GlobalKey<dashboard.DashboardScreenState> _dashboardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _refreshDashboard() {
    _dashboardKey.currentState?.refreshData();
  }

  Stream<bool> _hasPickupsNeedingAction() {
    final userId = currentUid;
    if (userId == null) return Stream.value(false);

    // Check for pickups in New (pending), Reassign (reschedule), or Pay (reviewed) tabs
    return supabase
        .from('postings')
        .stream(primaryKey: ['id'])
        .eq('junkshop_id', userId)
        .map(
          (rows) => rows.any(
            (r) => const {
              'pending',
              'reschedule',
              'reviewed',
            }.contains(r['status']),
          ),
        );
  }

  Stream<bool> _hasUnreadMessages() {
    final userId = currentUid;
    if (userId == null) {
      if (kDebugMode) print('📬 _hasUnreadMessages: No user logged in');
      return Stream.value(false);
    }

    if (kDebugMode)
      print('📬 _hasUnreadMessages: Listening for userId=$userId');

    // RLS already limits conversations to the ones the user participates in.
    return supabase.from('conversations').stream(primaryKey: ['id']).map((
      rows,
    ) {
      final docs = rowsToDocs('conversations', rows);
      if (kDebugMode) {
        print('📬 Found ${docs.length} conversations for user $userId');
      }

      for (final data in docs) {
        final participants = List<String>.from(
          (data['participants'] as List? ?? []).map((e) => e.toString()),
        );
        if (!participants.contains(userId)) continue;
        final deletedBy = List<String>.from(
          (data['deletedBy'] as List? ?? []).map((e) => e.toString()),
        );

        if (deletedBy.contains(userId)) {
          if (kDebugMode)
            print('📬 Conversation ${data['id']}: Skipped (deleted by user)');
          continue;
        }

        final unreadCounts =
            data['unreadCounts'] as Map<String, dynamic>? ?? {};
        final unreadCount = (unreadCounts[userId] as num?)?.toInt() ?? 0;

        if (kDebugMode) {
          print(
            '📬 Conversation ${data['id']}: unreadCount for $userId = $unreadCount',
          );
        }

        if (unreadCount > 0) {
          if (kDebugMode) print('📬 ✅ Found unread messages! Showing badge.');
          return true;
        }
      }

      if (kDebugMode) print('📬 ❌ No unread messages found');
      return false;
    });
  }

  Stream<bool> _hasPendingApplications() {
    final userId = currentUid;
    if (userId == null) return Stream.value(false);
    return supabase
        .from('collectors')
        .stream(primaryKey: ['id'])
        .eq('preferred_junkshop_id', userId)
        .map(
          (rows) => rows.any((data) {
            final status = data['application_status'] as String?;
            if (status != 'pending' && status != 'reapplying') return false;
            final junkshopId =
                data['preferred_junkshop_id'] as String? ??
                ((data['collector_profile'] is Map)
                    ? (data['collector_profile']
                              as Map)['preferred_junkshop_id']
                          as String?
                    : null);
            return junkshopId == userId;
          }),
        );
  }

  List<Widget> get _screens => [
    dashboard.DashboardScreen(
      key: _dashboardKey,
      onNavigateToTab: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) _refreshDashboard();
      },
    ),
    const PickupsScreen(),
    const MessagesScreen(), // Messages/Inbox screen
    BlocProvider<ProfileBloc>(
      create: (_) => getIt<ProfileBloc>()..add(const LoadProfileEvent()),
      child: const ProfileScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );

        if (shouldExit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModernNavItem(
                          activeIcon: FluentIcons.home_24_filled,
                          inactiveIcon: FluentIcons.home_24_regular,
                          label: 'Home',
                          index: 0,
                        ),
                        StreamBuilder<bool>(
                          stream: _hasPickupsNeedingAction(),
                          builder: (context, snapshot) {
                            final showBadge = snapshot.data ?? false;
                            return _buildModernNavItem(
                              activeIcon: FluentIcons.box_24_filled,
                              inactiveIcon: FluentIcons.box_24_regular,
                              label: 'Pickups',
                              index: 1,
                              showBadge: showBadge,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  _buildCenterCashierButton(),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<bool>(
                          stream: _hasUnreadMessages(),
                          builder: (context, snapshot) {
                            final showBadge = snapshot.data ?? false;
                            return _buildModernNavItem(
                              activeIcon: FluentIcons.mail_24_filled,
                              inactiveIcon: FluentIcons.mail_24_regular,
                              label: 'Inbox',
                              index: 2,
                              showBadge: showBadge,
                            );
                          },
                        ),
                        StreamBuilder<bool>(
                          stream: _hasPendingApplications(),
                          builder: (context, snapshot) {
                            final showBadge = snapshot.data ?? false;
                            return _buildModernNavItem(
                              activeIcon: FluentIcons.person_24_filled,
                              inactiveIcon: FluentIcons.person_24_regular,
                              label: 'Profile',
                              index: 3,
                              showBadge: showBadge,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required int index,
    bool showBadge = false,
  }) {
    return _ModernNavItem(
      activeIcon: activeIcon,
      inactiveIcon: inactiveIcon,
      label: label,
      index: index,
      currentIndex: _currentIndex,
      showBadge: showBadge,
      onTap: (idx) {
        setState(() => _currentIndex = idx);
        if (idx == 0) _refreshDashboard();
      },
    );
  }

  Widget _buildHeader() => const SizedBox.shrink();

  Widget _buildCenterCashierButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.junkshopPrimary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.junkshopPrimary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showCashierModal,
              customBorder: const CircleBorder(),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.add_24_filled,
                  color: AppColors.junkshopPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCashierModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CashierModal(),
    );
  }
}

class _ModernNavItem extends StatefulWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showBadge;

  const _ModernNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  State<_ModernNavItem> createState() => _ModernNavItemState();
}

class _ModernNavItemState extends State<_ModernNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentIndex == widget.index;
    final color = isActive
        ? AppColors.junkshopPrimary
        : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0);
        widget.onTap(widget.index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Icon(
                    isActive ? widget.activeIcon : widget.inactiveIcon,
                    color: color,
                    size: 20,
                  ),
                ),
                if (widget.showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
