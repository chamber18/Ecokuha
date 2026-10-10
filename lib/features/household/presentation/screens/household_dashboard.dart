import 'package:flutter/material.dart';
import 'household_home_screen.dart';
import 'post_items_screen.dart';
import 'track_screen.dart';
import 'chat_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/household_bottom_navigation.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/posting_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class HouseholdDashboard extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? editPostingData;
  final String? mode;
  final String? postingId;
  final bool isRepost;
  final String? junkshopId;
  final String? promotionId;
  final Map<String, dynamic>? promotionData;

  const HouseholdDashboard({
    super.key,
    this.initialIndex = 0,
    this.editPostingData,
    this.mode,
    this.postingId,
    this.isRepost = false,
    this.junkshopId,
    this.promotionId,
    this.promotionData,
  });

  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Build screens dynamically to allow passing arguments
  List<Widget> _buildScreens() {
    // Determine if in edit mode from either editPostingData or mode parameter
    final isEditMode = widget.editPostingData != null || widget.mode == 'edit';
    final postingId = widget.postingId ?? widget.editPostingData?['id'];
    final postingData = widget.editPostingData;

    return [
      HouseholdHomeScreen(onNavigateToTab: _onBottomNavTap),
      PostItemsScreen(
        onBackToHome: () => _onBottomNavTap(0),
        editMode: isEditMode,
        postingId: postingId,
        postingData: postingData,
        isRepost: widget.isRepost,
        preSelectedJunkshopId: widget.junkshopId,
        promotionId: widget.promotionId,
        promotionData: widget.promotionData,
      ),
      const TrackScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppColors.backgroundDark,
        body: Column(
          children: [
            _buildUploadStatusBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _buildScreens(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: HouseholdBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onBottomNavTap,
        ),
      ),
    );
  }

  Widget _buildUploadStatusBanner() {
    if (!getIt.isRegistered<PostingUploadService>()) {
      return const SizedBox.shrink();
    }
    final service = getIt<PostingUploadService>();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.isActive) return const SizedBox.shrink();

        final isUploading = service.status == PostingUploadStatus.uploading;
        final isFailed = service.status == PostingUploadStatus.failed;

        final Color bg = isFailed
            ? const Color(0xFFFFEBEE)
            : isUploading
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFE8F5E9);
        final Color accent = isFailed
            ? const Color(0xFFC62828)
            : isUploading
            ? AppColors.primaryGreen
            : const Color(0xFF2E7D32);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (isUploading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  )
                else
                  Icon(
                    isFailed ? Icons.error_rounded : Icons.check_circle_rounded,
                    color: accent,
                    size: 18,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        service.message,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      if (isFailed && service.errorMessage != null)
                        Text(
                          service.errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: accent.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!isUploading)
                  GestureDetector(
                    onTap: service.dismiss,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: accent.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Placeholder screens for the other tabs
class PostScreen extends StatelessWidget {
  const PostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 64,
              color: AppColors.primaryBlue,
            ),
            SizedBox(height: 16),
            Text(
              'Post Items',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Schedule your waste collection',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed local placeholder TrackScreen to use the real one from track_screen.dart

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.primaryBlue,
            ),
            SizedBox(height: 16),
            Text(
              'Chat',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Communicate with collectors',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed local placeholder ProfileScreen to use the real one from profile_screen.dart
