import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../../../../../../core/supabase/supabase_helpers.dart' as sb;
import 'package:image/image.dart' as image_lib;
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/constants/firestore_fields/index.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../history/history_screen.dart';
import '../prices/prices_screen.dart';
import '../inventory/inventory_screen.dart';
import '../collectors/collectors_screen.dart';
import 'account_screen.dart';
import 'business_controls_screen.dart';
import 'logs_screen.dart';
import '../../widgets/budget_alert_banner.dart';
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

  int _pendingApplicationCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>?
  _pendingApplicationsSubscription;

  @override
  void initState() {
    super.initState();
    _setupPendingApplicationsListener();
  }

  @override
  void dispose() {
    _pendingApplicationsSubscription?.cancel();
    super.dispose();
  }

  void _setupPendingApplicationsListener() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    // Stream on the junkshop filter; filter application status client-side
    _pendingApplicationsSubscription = Supabase.instance.client
        .from('collectors')
        .stream(primaryKey: ['id'])
        .eq('preferred_junkshop_id', userId)
        .listen((rows) {
          if (!mounted) return;
          final count = rows.where((data) {
            final status = data['application_status'] as String?;
            return status == 'pending' || status == 'reapplying';
          }).length;
          setState(() => _pendingApplicationCount = count);
        });
  }

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
            toolbarColor: AppColors.junkshopPrimary,
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
      // Return original image path if cropper fails
      return File(imagePath);
    }
  }

  Future<void> _pickImageFromGallery(
    ProfileBloc profileBloc,
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

      // Try to crop the selected image
      File? imageFile;
      try {
        final croppedFile = await _cropImage(image.path);
        imageFile = croppedFile ?? File(image.path);
      } catch (e) {
        if (kDebugMode) print('Cropping failed, using original image: $e');
        // If cropping fails completely, use original
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
    ProfileBloc profileBloc,
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

      if (kDebugMode) print('=== HYBRID IMAGE UPLOAD ===');
      if (kDebugMode) print('User ID: ${user.id}');
      if (kDebugMode) print('File path: ${file.path}');
      if (kDebugMode) print('File size: ${file.lengthSync()} bytes');

      final imageBytes = await file.readAsBytes();
      final decodedImage = image_lib.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception(
          'Invalid image format. Please select a JPEG or PNG image.',
        );
      }

      // Calculate target dimensions (prefer square, maintain aspect ratio if needed)
      int targetWidth = decodedImage.width;
      int targetHeight = decodedImage.height;

      // If image is already square or cropped, just resize
      if (targetWidth == targetHeight) {
        if (targetWidth > 800) {
          targetWidth = 800;
          targetHeight = 800;
        }
      } else {
        // Image not square (cropper may have failed), maintain aspect ratio
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

      // Resize image
      final resized = image_lib.copyResize(
        decodedImage,
        width: targetWidth,
        height: targetHeight,
      );
      final compressedBytes = image_lib.encodeJpg(resized, quality: 85);

      if (kDebugMode) print('Original size: ${imageBytes.length} bytes');
      if (kDebugMode) {
        print(
          'Original dimensions: ${decodedImage.width}x${decodedImage.height}',
        );
      }
      if (kDebugMode) print('Resized to: ${targetWidth}x$targetHeight');
      if (kDebugMode) print('Compressed size: ${compressedBytes.length} bytes');

      // First, try Supabase Storage (the proper way)
      try {
        if (kDebugMode) print('Attempting Supabase Storage upload...');
        final tempDir = file.parent;
        final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(compressedBytes);

        try {
          if (kDebugMode) print('Current user UID: ${user.id}');
          if (kDebugMode) print('User email: ${user.email}');

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
            UpdateProfileEvent({'profile_image_url': downloadUrl}),
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
      } catch (storageError) {
        if (kDebugMode) print('Storage upload failed: $storageError');
        if (kDebugMode) print('Falling back to base64 profile image...');

        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Using backup storage method...'),
            backgroundColor: Colors.orange,
          ),
        );

        // Calculate dimensions for fallback storage (max 300px, maintain aspect ratio)
        int fallbackWidth = decodedImage.width;
        int fallbackHeight = decodedImage.height;

        if (fallbackWidth > 300 || fallbackHeight > 300) {
          if (fallbackWidth > fallbackHeight) {
            fallbackHeight = (300 * fallbackHeight / fallbackWidth).round();
            fallbackWidth = 300;
          } else {
            fallbackWidth = (300 * fallbackWidth / fallbackHeight).round();
            fallbackHeight = 300;
          }
        }

        // Resize for fallback (already square)
        int fallbackSize = decodedImage.width;
        if (fallbackSize > 300) {
          fallbackSize = 300;
        }

        final smallResized = image_lib.copyResize(
          decodedImage,
          width: fallbackSize,
          height: fallbackSize,
        );
        final smallCompressedBytes = image_lib.encodeJpg(
          smallResized,
          quality: 70,
        );
        final base64String = base64Encode(smallCompressedBytes);

        if (kDebugMode) {
          print('Fallback image size: ${smallCompressedBytes.length} bytes');
        }
        if (kDebugMode) {
          print('Fallback dimensions: ${fallbackSize}x$fallbackSize');
        }
        if (kDebugMode) {
          print('Base64 string length: ${base64String.length} chars');
        }

        if (base64String.length > 1000000) {
          throw Exception(
            'Image too large even after compression. Please select a smaller image.',
          );
        }

        final imageDataUrl = 'data:image/jpeg;base64,$base64String';

        if (!mounted) return;
        profileBloc.add(
          UpdateProfileEvent({'profile_image_url': imageDataUrl}),
        );
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Profile picture updated successfully! (Backup method)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('=== IMAGE UPLOAD COMPLETELY FAILED ===');
      if (kDebugMode) print('Error type: ${e.runtimeType}');
      if (kDebugMode) print('Error message: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');

      String userMessage;
      if (e.toString().contains('Invalid image format')) {
        userMessage =
            'Upload failed: Invalid image format. Please select a JPEG or PNG image.';
      } else if (e.toString().contains('Image too large')) {
        userMessage =
            'Upload failed: Image too large even after compression. Please select a smaller image.';
      } else if (e.toString().contains('timeout')) {
        userMessage =
            'Upload failed: Network timeout. Please check your connection and try again.';
      } else {
        userMessage = 'Upload failed: ${e.toString()}';
      }

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    final messengerContext = context;
    ProfileBloc? profileBloc;
    try {
      profileBloc = messengerContext.read<ProfileBloc>();
    } catch (_) {
      profileBloc = null;
    }

    if (profileBloc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        const SnackBar(
          content: Text('Profile data unavailable. Please try again later.'),
        ),
      );
      return;
    }

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
                        profileBloc!,
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
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: AppColors.junkshopPrimary,
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
                    await _pickImageFromGallery(profileBloc!, messengerContext);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          size: 32,
                          color: AppColors.junkshopPrimary,
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
    final hasAncestorBloc =
        context.findAncestorWidgetOfExactType<BlocProvider<ProfileBloc>>() !=
        null;

    Widget buildContent() {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'My Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
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
      );
    }

    if (hasAncestorBloc) {
      return buildContent();
    }

    return BlocProvider<ProfileBloc>(
      create: (_) => getIt<ProfileBloc>()..add(const LoadProfileEvent()),
      child: buildContent(),
    );
  }

  String _capitalizeText(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildProfileContent(Map<String, dynamic> profileData) {
    // Extract business info from profile data
    final junkshopProfile =
        profileData[UserFields.junkshopProfile] as Map<String, dynamic>?;
    final businessInfo = junkshopProfile?['business'] as Map<String, dynamic>?;
    final locationInfo = junkshopProfile?['location'] as Map<String, dynamic>?;

    final resolvedAddress =
        locationInfo?['business_address'] ??
        locationInfo?[UserFields.address] ??
        businessInfo?[UserFields.address] ??
        profileData[UserFields.address] ??
        'No address';
    final resolvedPhone =
        profileData[UserFields.phone] ??
        businessInfo?[UserFields.phone] ??
        'No phone';
    final serviceRadius =
        locationInfo?['service_radius'] ??
        businessInfo?['service_radius'] ??
        businessInfo?['operation_radius'] ??
        '';

    final businessInfoMap = {
      'name': _capitalizeText(businessInfo?['business_name'] ?? 'Junk Shop'),
      'owner': _capitalizeText(profileData[UserFields.fullName] ?? 'Owner'),
      'email': profileData[UserFields.email] ?? 'No email',
      'phone': resolvedPhone,
      'address': resolvedAddress,
      'businessType': _capitalizeText(
        businessInfo?['business_type'] ?? 'Junk Shop',
      ),
      'serviceRadius': serviceRadius,
      'description': businessInfo?['description'] ?? '',
      'photoUrl': profileData[UserFields.profileImageUrl],
      // Pass the entire location object with lat/lng
      'location': locationInfo,
      // Legacy fields for backwards compatibility
      'latitude':
          locationInfo?[UserFields.latitude] ?? locationInfo?[UserFields.lat],
      'longitude':
          locationInfo?[UserFields.longitude] ?? locationInfo?[UserFields.lng],
      // Business hours from junkshop_profile.business
      'from_day': businessInfo?['from_day'] ?? 'Monday',
      'to_day': businessInfo?['to_day'] ?? 'Sunday',
      'open_time': businessInfo?['open_time'] ?? '08:00',
      'close_time': businessInfo?['close_time'] ?? '18:00',
      'rating': 4.7,
      'totalCollectors': 4,
      'monthlyRevenue': 125000.0,
    };
    return ScrollConfiguration(
      behavior: _NoGlowScrollBehavior(),
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (overscroll) {
          overscroll.disallowIndicator();
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile Header
                  _buildProfileHeader(businessInfoMap),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Budget Alert Banner (shows at 80% and 100% thresholds)
                  const BudgetAlertBanner(),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Business Management Section (Business Information moved to Account)
                  _buildBusinessManagementSection(businessInfoMap),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Settings Section
                  _buildSettingsSection(businessInfoMap),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Logout button
                  _buildLogoutButton(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> businessInfo) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        children: [
          // Business Avatar
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: businessInfo['photoUrl'] != null
                      ? Image.network(
                          businessInfo['photoUrl'],
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.store_mall_directory,
                                color: AppColors.junkshopPrimary,
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
                            Icons.store_mall_directory,
                            color: AppColors.junkshopPrimary,
                            size: 40,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.junkshopPrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Business Name
          Text(
            businessInfo['name'],
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),

          // Location
          Text(
            businessInfo['address'],
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessManagementSection(Map<String, dynamic> businessInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Management',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _buildSettingsList([
          {
            'iconData': Icons.tune,
            'title': 'Business Controls',
            'subtitle': 'Budget limits & posting requirements',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessControlsScreen(),
                ),
              );
            },
          },
          {
            'iconData': Icons.group,
            'title': 'Manage Collectors',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CollectorsScreen(),
                ),
              );
            },
          },
          {
            'iconData': Icons.inventory_2,
            'title': 'View Inventory',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InventoryScreen(),
                ),
              );
            },
          },
          {
            'iconData': Icons.attach_money,
            'title': 'Manage Material Prices',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PricesScreen()),
              );
            },
          },
          {
            'iconData': Icons.receipt_long,
            'title': 'Transaction History',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          },
          {
            'iconData': Icons.badge,
            'title': 'Worker Applications',
            'badge': _pendingApplicationCount,
            'onTap': () {
              Navigator.pushNamed(context, '/junkshop/worker-applications');
            },
          },
          {
            'iconData': Icons.history,
            'title': 'Activity Logs',
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          },
        ]),
      ],
    );
  }

  Widget _buildSettingsSection(Map<String, dynamic> businessInfo) {
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
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProfileBloc>(),
                    child: AccountScreen(businessInfo: businessInfo),
                  ),
                ),
              );
            },
          },
        ]),
      ],
    );
  }

  // Account sheet removed; replaced by dedicated AccountScreen

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
          final hasSubtitle = item.containsKey('subtitle');

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
                    color: AppColors.junkshopPrimary,
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
                        if (hasSubtitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'] as String,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.containsKey('badge') && (item['badge'] as int) > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item['badge']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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
              color: AppColors.junkshopPrimary,
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
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
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
}
