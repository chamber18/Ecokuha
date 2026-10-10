import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as sb;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';
import 'package:ecokuha/core/theme/app_dimensions.dart';
import 'package:ecokuha/core/di/service_locator.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:ecokuha/shared/widgets/common/common_widgets.dart';
import '../../bloc/profile/collector_profile_bloc.dart';
import '../../bloc/profile/collector_profile_event.dart';
import '../../bloc/profile/collector_profile_state.dart';
import 'account_settings_screen.dart';
import 'reviews_screen.dart';
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<File?> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 100,
        maxWidth: 1000,
        maxHeight: 1000,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: AppColors.collectorPrimary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 800, height: 800),
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error cropping image: $e');
      return File(imagePath);
    }
  }

  Future<void> _pickImageFromGallery(
    CollectorProfileBloc profileBloc,
    BuildContext messengerContext,
  ) async {
    final messenger = ScaffoldMessenger.of(messengerContext);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        return;
      }

      File? imageFile;
      try {
        final croppedFile = await _cropImage(image.path);
        imageFile = croppedFile ?? File(image.path);
      } catch (e) {
        if (kDebugMode) print('Cropping failed, using original image: $e');
        imageFile = File(image.path);
      }

      setState(() {
        _selectedImage = imageFile;
      });

      await _uploadProfileImage(_selectedImage!, profileBloc, messenger);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _uploadProfileImage(
    File file,
    CollectorProfileBloc profileBloc,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      if (!file.existsSync()) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Selected file no longer exists')),
        );
        return;
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      if (kDebugMode) print('=== COLLECTOR IMAGE UPLOAD ===');
      if (kDebugMode) print('User ID: ${user.id}');
      if (kDebugMode) print('File path: ${file.path}');

      final imageBytes = await file.readAsBytes();
      final decodedImage = image_lib.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception(
          'Invalid image format. Please select a JPEG or PNG image.',
        );
      }

      int targetWidth = decodedImage.width;
      int targetHeight = decodedImage.height;

      if (targetWidth == targetHeight) {
        if (targetWidth > 800) {
          targetWidth = 800;
          targetHeight = 800;
        }
      } else {
        if (targetWidth > 800 || targetHeight > 800) {
          if (targetWidth > targetHeight) {
            targetHeight = (800 * targetHeight / targetWidth).round();
            targetWidth = 800;
          } else {
            targetWidth = (800 * targetWidth / targetHeight).round();
            targetHeight = 800;
          }
        }
      }

      final resized = image_lib.copyResize(
        decodedImage,
        width: targetWidth,
        height: targetHeight,
      );
      final compressedBytes = image_lib.encodeJpg(resized, quality: 85);

      try {
        if (kDebugMode) print('Attempting Supabase Storage upload...');
        final tempDir = file.parent;
        final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(compressedBytes);

        try {
          // Path must start with the uploader's uid folder (storage RLS)
          final downloadUrl = await sb
              .uploadPublicFile(
                bucket: 'profile-images',
                path: '${user.id}/profile.jpg',
                file: tempFile,
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Upload timeout'),
              );
          if (kDebugMode) print('Download URL: $downloadUrl');

          if (!mounted) return;
          messenger.hideCurrentSnackBar();
          profileBloc.add(
            UpdateCollectorProfileEvent({'profile_image_url': downloadUrl}),
          );
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
            ),
          );
          return;
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      } catch (e) {
        if (kDebugMode) print('Upload failed: $e');
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString()}\nIf this is a permission error, ensure Storage policies allow writing to profile-images/{uid}/** for the signed-in user.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
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
    CollectorProfileBloc profileBloc,
    BuildContext anchorContext,
  ) {
    if (kDebugMode) {
      print(
        '=== _showImagePickerOptions called with explicit bloc & local context ===',
      );
    }
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
                    final messenger = ScaffoldMessenger.of(messengerContext);
                    try {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 100,
                      );
                      if (image == null) {
                        return;
                      }

                      // Try to crop the captured image
                      File? imageFile;
                      try {
                        final croppedFile = await _cropImage(image.path);
                        imageFile = croppedFile ?? File(image.path);
                      } catch (e) {
                        if (kDebugMode) {
                          print('Cropping failed, using original image: $e');
                        }
                        // If cropping fails completely, use original
                        imageFile = File(image.path);
                      }

                      setState(() {
                        _selectedImage = imageFile;
                      });
                      await _uploadProfileImage(
                        _selectedImage!,
                        profileBloc,
                        messenger,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to capture image: $e')),
                      );
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.collectorPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: AppColors.collectorPrimary,
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
                          color: AppColors.collectorPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          size: 32,
                          color: AppColors.collectorPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Gallery'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('=== CollectorProfileScreen build() called ===');

    return BlocProvider<CollectorProfileBloc>(
      create: (_) {
        if (kDebugMode) {
          print('=== Creating CollectorProfileBloc from getIt ===');
        }
        final bloc = getIt<CollectorProfileBloc>();
        if (kDebugMode) print('=== Created bloc: $bloc ===');
        bloc.add(const LoadCollectorProfileEvent());
        return bloc;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: const Text(
            'My Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.collectorPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        body: BlocBuilder<CollectorProfileBloc, CollectorProfileState>(
          builder: (context, state) {
            if (state is CollectorProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CollectorProfileError) {
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
                        context.read<CollectorProfileBloc>().add(
                          const RefreshCollectorProfileEvent(),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else if (state is CollectorProfileLoaded) {
              // Debug prints to help diagnose missing fields
              try {
                if (kDebugMode) {
                  print(
                    'Collector profile loaded: keys=${state.profileData.keys.toList()}',
                  );
                }
                if (kDebugMode) {
                  print(
                    'profile_image_url=${state.profileData[UserFields.profileImageUrl]}',
                  );
                }
                if (kDebugMode) {
                  print('address=${state.profileData[UserFields.address]}');
                }
              } catch (e) {
                if (kDebugMode) print('Error printing profileData debug: $e');
              }
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
            builderContext.read<CollectorProfileBloc>().add(
              const RefreshCollectorProfileEvent(),
            );
            // Wait for the refresh to complete
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ScrollConfiguration(
            behavior: _NoGlowScrollBehavior(),
            child: NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (overscroll) {
                overscroll.disallowIndicator();
                return false;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Profile Header
                        _buildProfileHeader(profileData),

                        const SizedBox(height: AppDimensions.spacing20),

                        // Stats Cards section
                        _buildStatsCards(profileData),

                        const SizedBox(height: AppDimensions.spacing20),

                        // Settings Section
                        _buildSettingsSection(),

                        const SizedBox(height: AppDimensions.spacing20),

                        // Logout button
                        _buildLogoutButton(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profileData) {
    final collectorProfile =
        profileData[UserFields.collectorProfile] as Map<String, dynamic>?;
    final personalInfo = collectorProfile?['personal'] as Map<String, dynamic>?;

    final topLevelName =
        profileData[UserFields.fullName]?.toString().trim() ?? '';
    final nestedName = personalInfo?['full_name']?.toString().trim() ?? '';
    final name = topLevelName.isNotEmpty
        ? topLevelName
        : (nestedName.isNotEmpty ? nestedName : 'Collector');

    final photoUrl =
        profileData[UserFields.profileImageUrl] ??
        profileData['profileImageUrl'];

    return Column(
      children: [
        // Avatar
        Builder(
          builder: (iconContext) {
            final bloc = iconContext.read<CollectorProfileBloc>();
            return Stack(
              children: [
                GestureDetector(
                  onTap: () =>
                      _showFullScreenProfileImage(photoUrl, _selectedImage, ''),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.collectorPrimary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.collectorPrimary.withValues(
                          alpha: 0.15,
                        ),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => _defaultAvatar(),
                            )
                          : _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : _defaultAvatar(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showImagePickerOptions(bloc, iconContext),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.collectorPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // Name
        Text(
          name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 6),

        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.collectorPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Collector',
            style: TextStyle(
              color: AppColors.collectorPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() => Container(
    color: AppColors.collectorPrimary.withValues(alpha: 0.1),
    child: const Center(
      child: Icon(Icons.person, color: AppColors.collectorPrimary, size: 36),
    ),
  );

  void _showFullScreenProfileImage(
    String? photoUrl,
    File? localFile,
    String address,
  ) {
    if (photoUrl == null && localFile == null) {
      // No image available; optionally show a toast/snackbar
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        Widget imageWidget;
        if (localFile != null) {
          imageWidget = Image.file(localFile, fit: BoxFit.contain);
        } else {
          imageWidget = Image.network(
            photoUrl!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 80),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: imageWidget,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 24,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            // Address overlay at bottom
            if (address.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Text(
                      address,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> profileData) {
    // Extract stats from profile data with safe defaults
    final totalCollections =
        (profileData['totalCollections'] as num?)?.toInt() ?? 0;
    final rating = (profileData['rating'] as num?)?.toDouble() ?? 0.0;
    final assignedTasks = (profileData['assignedTasks'] as num?)?.toInt() ?? 0;
    final totalEarned = (profileData['totalEarned'] as num?)?.toDouble() ?? 0.0;

    // Get user info for navigation
    final currentUser = Supabase.instance.client.auth.currentUser;
    final collectorName =
        (profileData['name'] ??
                profileData['displayName'] ??
                currentUser?.userMetadata?['full_name'] ??
                'Collector')
            .toString();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          icon: Icons.star,
          label: 'Rating',
          value: rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
          color: AppColors.warningColor,
          onTap: () {
            if (currentUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User not logged in')),
              );
              return;
            }

            final navigator = Navigator.of(context);
            final reviewsMessenger = ScaffoldMessenger.of(context);
            Supabase.instance.client
                .from('ratings')
                .select('id')
                .eq('target_type', 'collector')
                .eq('target_id', currentUser.id)
                .then((snapshot) {
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => CollectorReviewsScreen(
                        collectorId: currentUser.id,
                        collectorName: collectorName,
                        averageRating: rating,
                        totalReviews: snapshot.length,
                      ),
                    ),
                  );
                })
                .catchError((error) {
                  reviewsMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to load reviews: $error')),
                  );
                });
          },
        ),
        _buildStatCard(
          icon: Icons.check_circle,
          label: 'Collections',
          value: NumberFormat('#,##0').format(totalCollections),
          color: AppColors.successColor,
          onTap: () {
            Navigator.pushReplacementNamed(context, '/collector/collections');
          },
        ),
        _buildStatCard(
          icon: Icons.assignment,
          label: 'Assigned',
          value: NumberFormat('#,##0').format(assignedTasks),
          color: AppColors.collectorPrimary,
          onTap: () {
            Navigator.pushReplacementNamed(context, '/collector-home');
          },
        ),
        _buildStatCard(
          icon: Icons.account_balance_wallet,
          label: 'Total Commission',
          value: '₱${NumberFormat('#,##0.00').format(totalEarned)}',
          color: AppColors.primaryGreen,
          onTap: () {
            Navigator.pushReplacementNamed(context, '/collector/collections');
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (onTap != null)
                Icon(
                  FluentIcons.chevron_right_24_regular,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
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
        Builder(
          builder: (builderContext) {
            return _buildSettingsList([
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
                      builder: (_) => BlocProvider.value(
                        value: builderContext.read<CollectorProfileBloc>(),
                        child: const AccountSettingsScreen(),
                      ),
                    ),
                  );
                },
              },
            ]);
          },
        ),
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
          final subtitleWidget = item['subtitleWidget'] as Widget?;
          final isInfo = item['isInfo'] as bool? ?? false;

          return InkWell(
            onTap: isInfo ? null : item['onTap'] as VoidCallback,
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
                    color: AppColors.collectorPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitleWidget != null) ...[
                          const SizedBox(height: 6),
                          subtitleWidget,
                        ] else if (subtitle != null) ...[
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
                  if (!isInfo)
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

  // Old per-row action UI replaced by _buildSettingsList

  // Deprecated placeholder handlers removed; navigation added in Settings section

  void _showEmailVerificationDialog() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.collectorPrimary,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await Supabase.instance.client.auth.resend(
                  type: OtpType.signup,
                  email: user.email,
                );
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
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
                navigator.pop();
                messenger.showSnackBar(
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

  void _showLogoutConfirmation() {
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return CustomButton(
      text: 'Logout',
      backgroundColor: AppColors.errorColor,
      onPressed: _showLogoutConfirmation,
      icon: const Icon(Icons.logout, color: Colors.white, size: 20),
    );
  }
}
