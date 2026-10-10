import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/supabase/supabase_helpers.dart' as sb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../core/utils/user_collection_helper.dart';

class JunkshopStep5Screen extends StatefulWidget {
  const JunkshopStep5Screen({super.key});

  @override
  State<JunkshopStep5Screen> createState() => _JunkshopStep5ScreenState();
}

class _JunkshopStep5ScreenState extends State<JunkshopStep5Screen> {
  Map<String, dynamic>? _registrationData;
  bool _isSubmitting = false;
  bool _agreeToTerms = false;

  @override
  void initState() {
    super.initState();
    // Get data passed from previous steps
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _registrationData = args;
        });
      }
    });
  }

  Future<String?> _uploadDocumentImage(
    File imageFile,
    String userId,
    String documentType,
  ) async {
    try {
      debugPrint('Starting upload for $documentType...');
      debugPrint('File path: ${imageFile.path}');
      debugPrint('File exists: ${await imageFile.exists()}');

      if (!await imageFile.exists()) {
        debugPrint('ERROR: File does not exist!');
        return null;
      }

      // Get original file size
      final fileSize = await imageFile.length();
      debugPrint('📏 Original file size: $fileSize bytes');

      // Compress image before uploading
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        '${imageFile.path}_compressed.jpg',
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      final fileToUpload = compressedFile != null
          ? File(compressedFile.path)
          : imageFile;

      final compressedSize = await fileToUpload.length();
      debugPrint(
        '📉 Compressed size: $compressedSize bytes (${((1 - compressedSize / fileSize) * 100).toStringAsFixed(1)}% reduction)',
      );

      final fileName =
          '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final objectPath = '$userId/junkshop/$fileName';
      debugPrint('Storage path: documents/$objectPath');

      final storedPath = await sb.uploadPrivateDocument(
        path: objectPath,
        file: fileToUpload,
      );
      debugPrint('Upload complete for $documentType: $storedPath');

      return storedPath;
    } catch (e, stackTrace) {
      debugPrint('ERROR uploading document image $documentType: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  void _submitApplication() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final data = _registrationData ?? <String, dynamic>{};

      // Upload document images to the private documents bucket and store object paths
      debugPrint('=== Starting document upload process ===');

      // Reconstruct File objects from paths
      final documentPaths =
          data['documentPaths'] as Map<String, dynamic>? ?? {};
      debugPrint('Document paths received: $documentPaths');

      final documentUrls = <String, dynamic>{};

      for (final entry in documentPaths.entries) {
        final path = entry.value as String?;
        if (path == null || path.isEmpty) {
          debugPrint('⚠️ ${entry.key} has no path');
          continue;
        }

        debugPrint('Processing ${entry.key}: $path');

        final file = File(path);
        final exists = await file.exists();
        debugPrint('  - File exists: $exists');

        if (!exists) {
          debugPrint('❌ File does not exist: $path');
          continue;
        }

        try {
          debugPrint('Uploading ${entry.key} to Storage...');
          final url = await _uploadDocumentImage(file, user.id, entry.key);

          if (url != null && url.isNotEmpty) {
            documentUrls[entry.key] = url;
            debugPrint('✅ Successfully uploaded ${entry.key}: $url');
          } else {
            debugPrint('❌ Upload returned null/empty for ${entry.key}');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Exception uploading ${entry.key}: $e');
          debugPrint('Stack trace: $stackTrace');
        }
      }

      debugPrint('Final document URLs: $documentUrls');
      debugPrint('=== Document upload process complete ===');

      // Verify that required documents were uploaded
      if (documentUrls.isEmpty) {
        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload documents. Please try again.'),
              backgroundColor: AppColors.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Normalize and group fields to avoid nulls
      final business = {
        'business_name': (data['businessName'] ?? '').toString().trim(),
        'email': user.email ?? '',
        'phone': (data['phone'] ?? '').toString().trim().replaceAll(' ', ''),
        'business_type': data['businessType'],
        'description': (data['description'] ?? '').toString().trim(),
        'owner_full_name': (data['ownerFullName'] ?? '').toString().trim(),
        'from_day': 'Monday',
        'to_day': 'Sunday',
        'open_time': '08:00',
        'close_time': '18:00',
      };
      final location = {
        'address': (data['address'] ?? '').toString().trim(),
        'note': (data['note'] ?? '').toString().trim(),
        'lat': data['latitude'] ?? 0.0,
        'lng': data['longitude'] ?? 0.0,
        'service_radius': data['serviceRadiusKm'] ?? 0.0,
        'has_pickup_service': data['hasPickupService'] ?? true,
      };

      final svcRadius = data['serviceRadiusKm'];
      final payload = <String, dynamic>{
        if ((business['owner_full_name'] as String).isNotEmpty)
          'full_name': business['owner_full_name'],
        'business_name': business['business_name'],
        'phone': business['phone'],
        'junkshop_profile': {
          'business': business,
          'location': location,
          'documents': documentUrls,
        },
        if (data['latitude'] is num) 'latitude': data['latitude'],
        if (data['longitude'] is num) 'longitude': data['longitude'],
        if (svcRadius is num) 'service_radius': svcRadius,
        'application_status': 'pending',
        'is_profile_complete': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await UserCollectionHelper.getUserDocument(
        user.id,
        'junkshop',
      ).set(payload, merge: true);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/junkshop-pending',
        (route) => false,
        arguments: _registrationData,
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.spacing16),

              // Review Section
              _buildReviewSection(),

              const SizedBox(height: AppDimensions.spacing24),

              // Bottom actions
              Padding(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: CustomButton(
                            text: 'Back',
                            onPressed: _isSubmitting ? null : _goBack,
                            backgroundColor: AppColors.backgroundDark,
                            textColor: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacing16),
                        Expanded(
                          flex: 10,
                          child: CustomButton(
                            text: _isSubmitting
                                ? 'Submitting...'
                                : 'Submit Application',
                            onPressed: _isSubmitting
                                ? null
                                : _submitApplication,
                            isLoading: _isSubmitting,
                            backgroundColor: AppColors.junkshopPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    final data = _registrationData ?? {};

    // Extract data
    final businessName = data['businessName'] as String? ?? '';
    final ownerName = data['ownerFullName'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? ''; // Get email from the auth session
    final businessType = data['businessType'] as String? ?? '';
    final description = data['description'] as String? ?? '';

    final address = data['address'] as String? ?? '';
    final note = data['note'] as String? ?? '';
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final serviceRadiusKm = data['serviceRadiusKm'] as double? ?? 0.0;
    final hasPickupService = data['hasPickupService'] as bool? ?? false;

    final documentsMap = data['documents'] as Map<String, dynamic>? ?? {};
    final documentsUploaded = documentsMap.entries
        .where((entry) => entry.value == true)
        .map((entry) {
          final key = entry.key;
          if (key == 'business_permit') {
            return 'Business Permit: ✓ Uploaded';
          } else if (key == 'owner_valid_id') {
            return "Owner's Valid ID: ✓ Uploaded";
          }
          return '$key: ✓ Uploaded';
        })
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in,
                color: AppColors.junkshopPrimary,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Application Review',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.junkshopPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Business Information Card
          if (businessName.isNotEmpty ||
              ownerName.isNotEmpty ||
              phone.isNotEmpty ||
              email.isNotEmpty)
            _buildReviewCard(
              icon: Icons.business,
              title: 'Business Information',
              items: [
                if (businessName.isNotEmpty) 'Business Name: $businessName',
                if (ownerName.isNotEmpty) 'Owner Name: $ownerName',
                if (phone.isNotEmpty) 'Phone: $phone',
                if (email.isNotEmpty) 'Email: $email',
                if (businessType.isNotEmpty) 'Business Type: $businessType',
                if (description.isNotEmpty) 'Description: $description',
              ],
            ),

          if (businessName.isNotEmpty || ownerName.isNotEmpty)
            const SizedBox(height: AppDimensions.spacing12),

          // Location Details Card
          if (address.isNotEmpty || (latitude != null && longitude != null))
            _buildReviewCard(
              icon: Icons.location_on,
              title: 'Location Details',
              items: [
                if (address.isNotEmpty) 'Address: $address',
                if (note.isNotEmpty) 'Note: $note',
                if (latitude != null && longitude != null)
                  'GPS Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              ],
            ),

          if (address.isNotEmpty || (latitude != null && longitude != null))
            const SizedBox(height: AppDimensions.spacing12),

          // Service Information Card
          if (hasPickupService || serviceRadiusKm > 0)
            _buildReviewCard(
              icon: Icons.local_shipping,
              title: 'Service Information',
              items: [
                'Pickup Service: ${hasPickupService ? "Yes" : "No"}',
                if (hasPickupService && serviceRadiusKm > 0)
                  'Service Radius: ${serviceRadiusKm.toStringAsFixed(1)} km',
              ],
            ),

          if (hasPickupService || serviceRadiusKm > 0)
            const SizedBox(height: AppDimensions.spacing12),

          // Documents Card
          if (documentsUploaded.isNotEmpty)
            _buildReviewCard(
              icon: Icons.folder_open,
              title: 'Submitted Documents',
              items: documentsUploaded,
            ),

          if (documentsUploaded.isNotEmpty)
            const SizedBox(height: AppDimensions.spacing16),

          // Agreements Section
          Text(
            'Terms & Agreements',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // General Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                activeColor: AppColors.junkshopPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _agreeToTerms = !_agreeToTerms;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Note about verification
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.infoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.infoColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.infoColor, size: 16),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'All information will be verified before approval. Ensure all details are accurate.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.infoColor,
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

  Widget _buildReviewCard({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Icon(icon, color: AppColors.junkshopPrimary, size: 16),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing8),

          // Card Content
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
