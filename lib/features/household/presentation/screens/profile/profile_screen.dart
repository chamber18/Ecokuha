import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/supabase/supabase_helpers.dart' as sb;
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as image_lib;
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../../../../core/constants/firestore_fields/user_fields.dart';
import 'full_leaderboard_screen.dart';
import 'account_settings_screen.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final LeaderboardRepository _leaderboardRepo = LeaderboardRepository();
  List<Map<String, dynamic>> _leaderboardData = [];
  Map<String, dynamic>? _currentUserRanking;
  bool _isLoadingLeaderboard = true;
  String? _leaderboardError;
  String? _userCity;

  @override
  void initState() {
    super.initState();
    _initializeLeaderboard();
  }

  Future<void> _initializeLeaderboard() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    if (kDebugMode) print('🔍 Current user ID: ${currentUser.id}');
    if (kDebugMode) print('🔍 Current user email: ${currentUser.email}');

    // Don't filter by city - show all households globally
    _userCity = null;

    if (kDebugMode) print('🔍 Fetching global leaderboard (no city filter)');

    // Fetch leaderboard globally
    await _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoadingLeaderboard = true;
      _leaderboardError = null;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _leaderboardError = 'Not logged in';
          _isLoadingLeaderboard = false;
        });
        return;
      }

      // SKIP CACHE - Always fetch fresh data for debugging
      if (kDebugMode) {
        print('⚠️ SKIPPING CACHE - Fetching fresh data from Firestore');
      }

      // Check cache (use 'global' as key if city is null)
      // final cacheKey = _userCity ?? 'global';
      // final cachedData = await _cacheService.getLeaderboard(cacheKey);
      // final lastSync = await _cacheService.getLeaderboardLastSync(cacheKey);

      // final isCacheValid = cachedData != null &&
      //     lastSync != null &&
      //     DateTime.now().difference(lastSync) < const Duration(hours: 24);

      // if (isCacheValid) {
      //   setState(() {
      //     _leaderboardData = cachedData['topHouseholds'] as List<Map<String, dynamic>>;
      //     _currentUserRanking = cachedData['userRanking'] as Map<String, dynamic>?;
      //     _isLoadingLeaderboard = false;
      //   });
      //   return;
      // }

      // Fetch from Firestore in parallel
      final results = await Future.wait([
        _leaderboardRepo.getTopHouseholds(city: _userCity, limit: 5),
        _leaderboardRepo.getUserRanking(
          userId: currentUser.id,
          city: _userCity,
        ),
      ]);

      final topHouseholds = results[0] as List<Map<String, dynamic>>;
      final userRanking = results[1] as Map<String, dynamic>?;

      if (kDebugMode) {
        print('🔍 DEBUG: Top households count: ${topHouseholds.length}');
      }
      if (topHouseholds.isNotEmpty) {
        if (kDebugMode) {
          print('🔍 DEBUG: First household data: ${topHouseholds[0]}');
        }
        if (kDebugMode) {
          print(
            '🔍 DEBUG: First household full_name: ${topHouseholds[0]['full_name']}',
          );
        }
        if (kDebugMode) {
          print(
            '🔍 DEBUG: First household total_collections: ${topHouseholds[0]['total_collections']}',
          );
        }
        if (kDebugMode) {
          print(
            '🔍 DEBUG: First household total_earnings: ${topHouseholds[0]['total_earnings']}',
          );
        }
        if (kDebugMode) {
          print(
            '🔍 DEBUG: First household score: ${topHouseholds[0]['score']}',
          );
        }
      }
      if (kDebugMode) print('🔍 DEBUG: User ranking: $userRanking');

      // Don't cache for now - debugging
      // await _cacheService.saveLeaderboard(
      //   city: cacheKey,
      //   topHouseholds: topHouseholds,
      //   userRanking: userRanking,
      // );

      setState(() {
        _leaderboardData = topHouseholds.take(5).toList();
        _currentUserRanking = userRanking;
        _isLoadingLeaderboard = false;
      });
    } catch (e) {
      setState(() {
        _leaderboardError = 'Failed to load leaderboard: $e';
        _isLoadingLeaderboard = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ProfileBloc>()..add(const LoadProfileEvent()),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: const Text(
            'My Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.householdPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
        ),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.message}',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                          const RefreshProfileEvent(),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else if (state is ProfileLoaded) {
              return _buildProfileContent(state.profileData);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> profileData) {
    return Builder(
      builder: (builderContext) {
        return RefreshIndicator(
          onRefresh: () async {
            final bloc = builderContext.read<ProfileBloc>();
            await Future.wait([
              _fetchLeaderboard(),
              Future(() => bloc.add(const RefreshProfileEvent())),
            ]);
          },
          color: AppColors.householdPrimary,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildProfileHeader(profileData),
                    const SizedBox(height: AppDimensions.spacing20),
                    _buildLeaderboardSection(profileData),
                    const SizedBox(height: AppDimensions.spacing20),
                    _buildSettingsSection(),
                    const SizedBox(height: AppDimensions.spacing20),
                    _buildLogoutButton(),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profileData) {
    final name = profileData[UserFields.fullName] ?? 'User';
    final location = profileData[UserFields.location] as Map<String, dynamic>?;
    final address = location?[UserFields.address] ?? 'No address provided';
    final photoUrl = profileData[UserFields.profileImageUrl] as String?;

    return Container(
      alignment: Alignment.center,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.householdPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.householdPrimary,
                                      size: 40,
                                    ),
                                  );
                          },
                        )
                      : _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        )
                      : const Center(
                          child: Icon(
                            Icons.person,
                            color: AppColors.householdPrimary,
                            size: 40,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Builder(
                  builder: (iconContext) {
                    final bloc = iconContext.read<ProfileBloc>();
                    return GestureDetector(
                      onTap: () => _showImagePickerOptions(bloc, iconContext),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.householdPrimary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            name,
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Old image section removed — unified header like junkshop

  // Old edit sections removed

  // Old edit sections removed

  // Old edit sections removed

  // Preferences moved out; using unified settings section like junkshop

  // Stats replaced by _buildHouseholdStats()

  Widget _buildLeaderboardSection(Map<String, dynamic> profileData) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FullLeaderboardScreen(),
                ),
              );
            },
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.householdPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leaderboard',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'All Households',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Score = Collections (60%) + Earnings (40%)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingLeaderboard)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_leaderboardError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(
                      _leaderboardError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _fetchLeaderboard,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_leaderboardData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No leaderboard data available',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ..._buildLeaderboardItems(currentUserId),
        ],
      ),
    );
  }

  List<Widget> _buildLeaderboardItems(String? currentUserId) {
    final items = <Widget>[];

    // Check if current user is in the top 5 list
    final userInTop5 = _leaderboardData.any(
      (item) => item['id'] == currentUserId,
    );

    // Build tiles for top households
    for (int i = 0; i < _leaderboardData.length; i++) {
      final item = _leaderboardData[i];
      final rank = item['rank'] as int;
      final isCurrentUser = item['id'] == currentUserId;
      final isTop = rank == 1;

      items.add(
        _buildLeaderboardItem(
          rank: rank,
          item: item,
          isCurrentUser: isCurrentUser,
          isTop: isTop,
        ),
      );
    }

    // Show current user if they're not in top 5 but have a ranking,
    // only if we haven't reached the 5-item cap yet
    if (!userInTop5 && _currentUserRanking != null && items.length < 5) {
      items.add(
        _buildLeaderboardItem(
          rank: _currentUserRanking!['rank'] as int,
          item: _currentUserRanking!,
          isCurrentUser: true,
          isTop: false,
        ),
      );
    }

    return items;
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required Map<String, dynamic> item,
    required bool isCurrentUser,
    required bool isTop,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FullLeaderboardScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTop
              ? AppColors.householdPrimary.withValues(alpha: 0.06)
              : isCurrentUser
              ? AppColors.householdPrimary.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser
                ? AppColors.householdPrimary.withValues(alpha: 0.3)
                : AppColors.borderLight,
            width: isCurrentUser ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isTop
                  ? AppColors.householdPrimary
                  : isCurrentUser
                  ? AppColors.householdPrimary.withValues(alpha: 0.2)
                  : AppColors.backgroundDark,
              child: Text(
                '$rank',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isTop
                      ? Colors.white
                      : isCurrentUser
                      ? AppColors.householdPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentUser
                        ? '${item['full_name'] as String? ?? item['name'] as String? ?? 'You'} (You)'
                        : (item['full_name'] as String? ??
                              item['name'] as String? ??
                              'User'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser
                          ? AppColors.householdPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Score: ${NumberFormat('#,##0.0').format((item['score'] ?? 0) as num)} pts',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.householdPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isTop)
              const Icon(
                Icons.emoji_events,
                color: AppColors.householdPrimary,
                size: 24,
              )
            else if (isCurrentUser)
              const Icon(
                Icons.person,
                color: AppColors.householdPrimary,
                size: 20,
              )
            else
              const Icon(
                Icons.trending_up,
                color: AppColors.householdPrimary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final user = Supabase.instance.client.auth.currentUser;
    final isEmailVerified = user?.emailConfirmedAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _buildSettingsList([
          if (!isEmailVerified)
            {
              'iconData': Icons.mark_email_unread_outlined,
              'title': 'Verify Email',
              'onTap': () {
                _showEmailVerificationDialog();
              },
            },
          {
            'iconData': Icons.person,
            'title': 'Account',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              );
            },
          },
          {
            'iconData': Icons.help_outline,
            'title': 'Help & Support',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
          },
          {
            'iconData': Icons.info_outline_rounded,
            'title': 'About EcoKuha',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          },
        ]),
      ],
    );
  }

  Widget _buildSettingsList(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;
          final subtitle = item['subtitle'] as String?;

          return InkWell(
            onTap: item['onTap'] as VoidCallback,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Icon(
                    item['iconData'] as IconData,
                    color: AppColors.householdPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return CustomButton(
      onPressed: () {
        _showLogoutDialog();
      },
      text: 'Logout',
      backgroundColor: AppColors.errorColor,
      textColor: AppColors.textWhite,
    );
  }

  Future<File?> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Image',
            toolbarColor: AppColors.householdPrimary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      } else {
        // Return original file if cropper was canceled or failed
        return File(imagePath);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      // Return original file on error
      return File(imagePath);
    }
  }

  Future<void> _pickImageFromGallery(
    ProfileBloc profileBloc,
    BuildContext messengerContext,
  ) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        final croppedFile = await _cropImage(pickedFile.path);
        if (croppedFile != null) {
          setState(() {
            _selectedImage = croppedFile;
          });
          if (!messengerContext.mounted) return;
          await _uploadProfileImage(croppedFile, profileBloc, messengerContext);
        }
      }
    } catch (e) {
      if (!messengerContext.mounted) return;
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        SnackBar(
          content: Text('Could not select an image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage(
    File file,
    ProfileBloc profileBloc,
    BuildContext messengerContext,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!messengerContext.mounted) return;
        ScaffoldMessenger.of(messengerContext).showSnackBar(
          const SnackBar(
            content: Text('No user is currently signed in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Resize image while preserving aspect ratio
      final bytes = await file.readAsBytes();
      var image = image_lib.decodeImage(bytes);

      if (image != null) {
        // Resize to max 400px maintaining aspect ratio
        if (image.width > image.height) {
          if (image.width > 400) {
            image = image_lib.copyResize(image, width: 400);
          }
        } else {
          if (image.height > 400) {
            image = image_lib.copyResize(image, height: 400);
          }
        }

        // Convert to JPEG
        final compressedBytes = image_lib.encodeJpg(image, quality: 85);

        // Upload to Supabase Storage (profile-images/{uid}/profile.jpg)
        final downloadUrl = await sb.uploadPublicFile(
          bucket: 'profile-images',
          path: '${user.id}/profile.jpg',
          bytes: Uint8List.fromList(compressedBytes),
        );

        // Update profile with the URL using bloc
        profileBloc.add(
          UpdateProfileEvent(updates: {'profile_image_url': downloadUrl}),
        );

        if (!messengerContext.mounted) return;
        ScaffoldMessenger.of(messengerContext).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!messengerContext.mounted) return;
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        SnackBar(
          content: Text(
            'Upload failed. Please check your connection and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerOptions(
    ProfileBloc profileBloc,
    BuildContext anchorContext,
  ) {
    final messengerContext = anchorContext;

    showModalBottomSheet(
      context: messengerContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    try {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 100,
                      );
                      if (image == null) return;

                      File? imageFile;
                      try {
                        final croppedFile = await _cropImage(image.path);
                        imageFile = croppedFile ?? File(image.path);
                      } catch (e) {
                        imageFile = File(image.path);
                      }

                      setState(() {
                        _selectedImage = imageFile;
                      });
                      if (!messengerContext.mounted) return;
                      await _uploadProfileImage(
                        _selectedImage!,
                        profileBloc,
                        messengerContext,
                      );
                    } catch (e) {
                      if (!messengerContext.mounted) return;
                      ScaffoldMessenger.of(messengerContext).showSnackBar(
                        SnackBar(content: Text('Failed to capture image: $e')),
                      );
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.householdPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: AppColors.householdPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Camera'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickImageFromGallery(profileBloc, messengerContext);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.householdPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          size: 32,
                          color: AppColors.householdPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Gallery'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailVerificationDialog() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.householdPrimary,
            ),
            const SizedBox(width: 12),
            const Text('Email Verification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your email address: ${user.email}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'We\'ll send a verification email to your address. Click the link in the email to verify.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.resend(
                  type: OtpType.signup,
                  email: user.email,
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Verification email sent! Check your inbox.',
                    ),
                    backgroundColor: AppColors.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send email. Please try again.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: Text(
              'Logout',
              style: TextStyle(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  // Legacy editable form code removed for unified design
}
