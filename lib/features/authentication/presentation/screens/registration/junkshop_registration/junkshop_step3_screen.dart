import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class JunkshopStep3Screen extends StatefulWidget {
  const JunkshopStep3Screen({super.key});

  @override
  State<JunkshopStep3Screen> createState() => _JunkshopStep3ScreenState();
}

class _JunkshopStep3ScreenState extends State<JunkshopStep3Screen> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final Map<String, bool> _uploadedDocuments = {
    'business_permit': false,
    'owner_valid_id': false,
  };

  final Map<String, File?> _documentImages = {
    'business_permit': null,
    'owner_valid_id': null,
  };

  final List<Map<String, dynamic>> _requiredDocuments = [
    {
      'key': 'business_permit',
      'title': 'Business Permit',
      'description': 'Valid business permit issued by your LGU',
      'icon': Icons.business_center,
      'required': true,
    },
    {
      'key': 'owner_valid_id',
      'title': "Owner's Valid ID",
      'description':
          'Government-issued ID of the owner/manager (e.g., Driver\'s License, Passport, UMID)',
      'icon': Icons.badge_outlined,
      'required': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: _buildDocumentsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Documents',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: AppDimensions.paddingSm),
        Text(
          'Upload required business documents for verification.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: AppDimensions.paddingXl),

        // Upload Progress
        _buildUploadSummary(),

        SizedBox(height: AppDimensions.paddingLg),

        // Document Cards
        ..._requiredDocuments.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> document = entry.value;
          return _buildDocumentCard(document, index);
        }),

        SizedBox(height: AppDimensions.paddingXl),

        // Navigation Buttons
        const SizedBox(height: AppDimensions.spacing24),
        Row(
          children: [
            Expanded(
              flex: 7,
              child: CustomButton(
                onPressed: () => Navigator.pop(context),
                text: 'Back',
                backgroundColor: AppColors.backgroundDark,
                textColor: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing16),
            Expanded(
              flex: 10,
              child: CustomButton(
                onPressed: _canProceed() ? _nextStep : null,
                text: 'Next Step',
                backgroundColor: AppColors.junkshopPrimary,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.spacing16),

        // Progress info
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Next step: Review & Submit',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacing24),
      ],
    );
  }

  Widget _buildUploadSummary() {
    final int requiredCount = _requiredDocuments
        .where((doc) => doc['required'])
        .length;
    final int requiredUploaded = _requiredDocuments
        .where(
          (doc) => doc['required'] && _uploadedDocuments[doc['key']] == true,
        )
        .length;
    final int uploadedCount = _requiredDocuments
        .where((doc) => _uploadedDocuments[doc['key']] == true)
        .length;

    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppColors.junkshopPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.junkshopPrimary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(Icons.upload_file, color: Colors.white),
                ),
              ),
              SizedBox(width: AppDimensions.paddingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Progress',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.junkshopPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Required: $requiredUploaded/$requiredCount | Total: $uploadedCount/${_requiredDocuments.length}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${((requiredUploaded / requiredCount) * 100).round()}%',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.junkshopPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, int index) {
    final bool isUploaded = _uploadedDocuments[doc['key']] ?? false;
    final bool isRequired = doc['required'] ?? false;
    final File? imageFile = _documentImages[doc['key']];

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isUploaded
              ? AppColors.successColor.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: isUploaded ? 2 : 1,
        ),
        boxShadow: isUploaded
            ? [
                BoxShadow(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon, title, and required label (collector-style)
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? AppColors.successColor.withValues(alpha: 0.1)
                      : AppColors.backgroundLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isUploaded
                        ? AppColors.successColor.withValues(alpha: 0.3)
                        : AppColors.borderLight,
                  ),
                ),
                child: Center(
                  child: isUploaded
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.successColor,
                          size: 24,
                        )
                      : Icon(
                          doc['icon'],
                          color: AppColors.junkshopPrimary,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Text(
                  doc['title'],
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isUploaded
                        ? AppColors.successColor
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.errorColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing12),

          // Description
          Text(
            doc['description'],
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Image preview
          if (imageFile != null)
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(
                  color: AppColors.successColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSm - 2,
                    ),
                    child: Image.file(
                      imageFile,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.successColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.junkshopPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(
                  color: AppColors.junkshopPrimary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      doc['icon'],
                      size: 40,
                      color: AppColors.junkshopPrimary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No document uploaded',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: AppDimensions.spacing16),

          // Actions at bottom-right (upload/view/remove)
          if (isUploaded)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _viewDocument(doc['key'], doc['title']),
                  icon: const Icon(
                    Icons.visibility,
                    color: AppColors.junkshopPrimary,
                  ),
                  tooltip: 'View Document',
                ),
                IconButton(
                  onPressed: () => _removeDocument(doc['key'], doc['title']),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.errorColor,
                  ),
                  tooltip: 'Remove Document',
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _uploadDocument(doc['key'], doc['title']),
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Upload'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.junkshopPrimary,
                  backgroundColor: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument(String documentKey, String documentTitle) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, ImageSource.camera),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.junkshopPrimary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: AppColors.junkshopPrimary,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Camera',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.junkshopPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            Navigator.pop(context, ImageSource.gallery),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.junkshopPrimary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.photo_library,
                                color: AppColors.junkshopPrimary,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Gallery',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.junkshopPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _documentImages[documentKey] = File(image.path);
          _uploadedDocuments[documentKey] = true;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$documentTitle uploaded successfully!'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _viewDocument(String documentKey, String documentTitle) {
    final imageFile = _documentImages[documentKey];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              documentTitle,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: imageFile != null
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  )
                : const Icon(Icons.image, size: 100, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  void _removeDocument(String documentKey, String documentTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Document'),
          content: Text('Are you sure you want to remove $documentTitle?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _uploadedDocuments[documentKey] = false;
                  _documentImages[documentKey] = null;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$documentTitle removed'),
                    backgroundColor: AppColors.warningColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  bool _canProceed() {
    return _requiredDocuments
        .where((doc) => doc['required'])
        .every((doc) => _uploadedDocuments[doc['key']] == true);
  }

  void _nextStep() async {
    final requiredDocs = _requiredDocuments
        .where((doc) => doc['required'] == true)
        .toList();

    final missingDocs = requiredDocs
        .where((doc) => _uploadedDocuments[doc['key']] != true)
        .toList();

    if (missingDocs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload the following required documents: ${missingDocs.map((doc) => doc['title']).join(', ')}',
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      final previousData =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ??
          {};

      // Convert File objects to paths for serialization
      final documentPaths = <String, String>{};
      _documentImages.forEach((key, file) {
        if (file != null) {
          documentPaths[key] = file.path;
        }
      });

      final junkshopData = {
        ...previousData,
        'documents': Map<String, bool>.from(_uploadedDocuments),
        'documentPaths': documentPaths,
        'step': 3,
      };

      Navigator.pushNamed(
        context,
        '/junkshop-register-5',
        arguments: junkshopData,
      );
    }
  }
}
