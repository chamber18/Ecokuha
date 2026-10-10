import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/collector_bottom_nav.dart';
import 'home_screen.dart' as collector_home;
import 'collections_history_screen.dart' as collector_history;
import 'messages_screen.dart' as collector_messages;
import 'profile/profile_screen.dart' as collector_profile;

class CollectorDashboardShell extends StatefulWidget {
  final int initialIndex;
  const CollectorDashboardShell({super.key, this.initialIndex = 0});

  @override
  State<CollectorDashboardShell> createState() =>
      _CollectorDashboardShellState();
}

class _CollectorDashboardShellState extends State<CollectorDashboardShell> {
  late int _currentIndex;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      collector_home.HomeScreen(
        showBottomNav: false,
        onNavSelected: _onNavSelected,
      ),
      const collector_history.CollectionsHistoryScreen(),
      const collector_messages.CollectorMessagesScreen(),
      collector_profile.ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
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
        }
      },
      child: Scaffold(
        backgroundColor:
            AppColors.backgroundDark, // Changed to make cards pop more
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: CollectorBottomNav(
          currentIndex: _currentIndex,
          onSelect: _onNavSelected,
          isAvailable: _isAvailable,
          onToggleAvailability: () =>
              setState(() => _isAvailable = !_isAvailable),
        ),
      ),
    );
  }

  void _onNavSelected(int index) {
    setState(() => _currentIndex = index);
  }

  // Legacy _buildBottomNav method replaced by CollectorBottomNav

  // _navItem removed in favor of CollectorBottomNav

  // Legacy _navIcon method no longer used.

  // Style cycling removed; Hybrid is the single nav style now.
}
