import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import 'household_detail_screen.dart';

class FullLeaderboardScreen extends StatefulWidget {
  const FullLeaderboardScreen({super.key});

  @override
  State<FullLeaderboardScreen> createState() => _FullLeaderboardScreenState();
}

class _FullLeaderboardScreenState extends State<FullLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardRepository _leaderboardRepo = LeaderboardRepository();
  List<Map<String, dynamic>> _leaderboardData = [];
  Map<String, dynamic>? _currentUserRanking;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // 0=week, 1=month, 2=all time (null = no date filter)
  String? get _timePeriod {
    switch (_tabController.index) {
      case 0:
        return 'week';
      case 1:
        return 'month';
      default:
        return null;
    }
  }

  static const _tabLabels = ['Week', 'Month', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLeaderboard();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      final topHouseholds = await _leaderboardRepo.getTopHouseholds(
        limit: 50,
        timePeriod: _timePeriod,
      );

      Map<String, dynamic>? currentUserRank;
      for (final h in topHouseholds) {
        if (h['id'] == currentUser.id) {
          currentUserRank = h;
          break;
        }
      }

      setState(() {
        _leaderboardData = topHouseholds;
        _currentUserRanking = currentUserRank;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 2.5,
                    ),
                  )
                : _error != null
                ? _buildError()
                : _leaderboardData.isEmpty
                ? _buildEmpty()
                : _buildContent(currentUserId),
          ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 4,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              FluentIcons.arrow_left_24_regular,
              size: 20,
              color: Color(0xFF1A1A2E),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadLeaderboard,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                FluentIcons.arrow_counterclockwise_24_regular,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.all(3),
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
    );
  }

  // ─── Main content ─────────────────────────────────────────────────────────────
  Widget _buildContent(String? currentUserId) {
    final top3 = _leaderboardData.take(3).toList();
    final rest = _leaderboardData.skip(3).toList();
    final currentUserInList = _leaderboardData.any(
      (h) => h['id'] == currentUserId,
    );

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppColors.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Podium
          SliverToBoxAdapter(child: _buildPodium(top3, currentUserId)),
          // Rankings header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Rankings',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_leaderboardData.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Rank 4+ list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final item = rest[i];
                return _buildListTile(
                  item: item,
                  rank: item['rank'] as int? ?? (i + 4),
                  isCurrentUser: item['id'] == currentUserId,
                );
              }, childCount: rest.length),
            ),
          ),
          // Pinned current-user card when not in top 50
          if (!currentUserInList && _currentUserRanking != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildCurrentUserCard(_currentUserRanking!),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ─── Podium ───────────────────────────────────────────────────────────────────
  Widget _buildPodium(List<Map<String, dynamic>> top3, String? currentUserId) {
    if (top3.isEmpty) return const SizedBox.shrink();

    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.08),
            AppColors.primaryGreen.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _buildPodiumSlot(
                    item: second,
                    rank: 2,
                    height: 88,
                    avatarSize: 56,
                    isCurrentUser: second['id'] == currentUserId,
                    onTap: () => _navigateToDetail(second, 2),
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: first != null
                ? _buildPodiumSlot(
                    item: first,
                    rank: 1,
                    height: 110,
                    avatarSize: 68,
                    isCurrentUser: first['id'] == currentUserId,
                    onTap: () => _navigateToDetail(first, 1),
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: third != null
                ? _buildPodiumSlot(
                    item: third,
                    rank: 3,
                    height: 72,
                    avatarSize: 50,
                    isCurrentUser: third['id'] == currentUserId,
                    onTap: () => _navigateToDetail(third, 3),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> item, int rank) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HouseholdDetailScreen(householdData: {...item, 'rank': rank}),
      ),
    );
  }

  Widget _buildPodiumSlot({
    required Map<String, dynamic> item,
    required int rank,
    required double height,
    required double avatarSize,
    required bool isCurrentUser,
    VoidCallback? onTap,
  }) {
    final name =
        (item['full_name'] as String? ?? item['name'] as String? ?? 'User')
            .split(' ')
            .first;
    final score = (item['score'] as num?)?.toDouble() ?? 0.0;
    final profileImage = item['profile_image_url'] as String?;

    const medalColors = {
      1: Color(0xFFFFD700),
      2: Color(0xFFB8C4CC),
      3: Color(0xFFCD9A6A),
    };
    const podiumColors = {
      1: AppColors.primaryGreen,
      2: Color(0xFF7A8FA6),
      3: Color(0xFFA07850),
    };

    final medalColor = medalColors[rank]!;
    final podiumColor = podiumColors[rank]!;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with crown for rank 1
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrentUser ? AppColors.primaryGreen : medalColor,
                    width: 2.5,
                  ),
                  color: Colors.grey.shade200,
                ),
                child: ClipOval(
                  child: profileImage != null && profileImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profileImage,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            size: avatarSize * 0.45,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: avatarSize * 0.45,
                          color: Colors.grey.shade400,
                        ),
                ),
              ),
              if (rank == 1)
                Positioned(
                  top: -16,
                  child: Icon(
                    FluentIcons.crown_24_filled,
                    size: 22,
                    color: medalColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: rank == 1 ? 13 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Podium block
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: podiumColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              boxShadow: [
                BoxShadow(
                  color: podiumColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: rank == 1 ? 18 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── List tile ────────────────────────────────────────────────────────────────
  Widget _buildListTile({
    required Map<String, dynamic> item,
    required int rank,
    required bool isCurrentUser,
  }) {
    final fullName = item['full_name'] as String? ?? 'Anonymous';
    final score = (item['score'] as num?)?.toDouble() ?? 0.0;
    final profileImage = item['profile_image_url'] as String?;

    return GestureDetector(
      onTap: () => _navigateToDetail(item, rank),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppColors.primaryGreen.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentUser
                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                : Colors.grey.shade100,
            width: isCurrentUser ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3
                      ? AppColors.primaryGreen
                      : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            _buildAvatar(profileImage, 42, isCurrentUser: isCurrentUser),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fullName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'EcoKuha Household',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isCurrentUser
                        ? AppColors.primaryGreen
                        : const Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'pts',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Current user card (when not in top 50) ───────────────────────────────────
  Widget _buildCurrentUserCard(Map<String, dynamic> item) {
    final rank = item['rank'] as int? ?? 0;
    final score = (item['score'] as num?)?.toDouble() ?? 0.0;
    final fullName = item['full_name'] as String? ?? 'You';
    final profileImage = item['profile_image_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.1),
            AppColors.primaryGreen.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(width: 12),
          _buildAvatar(profileImage, 40, isCurrentUser: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Your ranking',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 17,
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

  // ─── Empty state ──────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    const emptyMessages = [
      'No rankings this week yet',
      'No rankings this month yet',
      'No rankings available yet',
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.trophy_24_regular,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessages[_tabController.index],
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start recycling to appear here!',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(
              FluentIcons.arrow_counterclockwise_24_regular,
              size: 16,
            ),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.warning_24_regular,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(
              FluentIcons.arrow_counterclockwise_24_regular,
              size: 16,
            ),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Avatar helper ────────────────────────────────────────────────────────────
  Widget _buildAvatar(String? url, double size, {bool isCurrentUser = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrentUser ? AppColors.primaryGreen : Colors.grey.shade200,
          width: 1.5,
        ),
        color: Colors.grey.shade100,
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade100),
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  size: size * 0.45,
                  color: Colors.grey.shade400,
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.45,
                color: Colors.grey.shade400,
              ),
      ),
    );
  }
}
