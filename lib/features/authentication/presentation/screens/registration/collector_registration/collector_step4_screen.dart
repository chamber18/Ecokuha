import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class CollectorStep4Screen extends StatefulWidget {
  const CollectorStep4Screen({super.key});

  @override
  State<CollectorStep4Screen> createState() => _CollectorStep4ScreenState();
}

class _CollectorStep4ScreenState extends State<CollectorStep4Screen> {
  bool _isLoading = false;
  final Map<String, bool> _uploadedDocuments = {
    'validId': false,
    'driversLicense': false,
    'orCr': false,
    'vehiclePhoto': false,
    'selfieWithVehicle': false,
  };

  final List<Map<String, dynamic>> _requiredDocuments = [
    {
      'key': 'validId',
      'title': 'Valid Government ID',
      'description':
          'Driver\'s License, Passport, UMID, SSS ID, or other valid government-issued ID',
      'icon': '🪪',
      'required': true,
    },
    {
      'key': 'driversLicense',
      'title': 'Driver\'s License',
      'description':
          'Professional or Non-Professional Driver\'s License (if driving motorized vehicle)',
      'icon': '🚗',
      'required': false,
    },
    {
      'key': 'orCr',
      'title': 'Vehicle OR/CR',
      'description':
          'Official Receipt and Certificate of Registration of collection vehicle',
      'icon': '📋',
      'required': true,
    },
    {
      'key': 'vehiclePhoto',
      'title': 'Vehicle Photo',
      'description':
          'Clear photo of your collection vehicle with visible plate number',
      'icon': '📸',
      'required': true,
    },
    {
      'key': 'selfieWithVehicle',
      'title': 'Selfie with Vehicle',
      'description': 'Photo of yourself with your collection vehicle',
      'icon': '🤳',
      'required': true,
    },
  ];

  void _nextStep() {
    // Check if all required documents are uploaded
    final requiredDocuments = _requiredDocuments.where(
      (doc) => doc['required'] == true,
    );
    final missingRequired = requiredDocuments
        .where((doc) => !_uploadedDocuments[doc['key']]!)
        .toList();

    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload all required documents (${missingRequired.length} missing)',
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Merge args and navigate to next step
    final previous =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final documents = {
      for (final entry in _uploadedDocuments.entries) entry.key: entry.value,
    };
    // Preserve documentFiles from previous step
    final merged = {...previous, 'documents': documents, 'step': 4};
    Navigator.pushNamed(context, '/collector-register-5', arguments: merged);
  }

  void _previousStep() {
    Navigator.pop(context);
  }

  Future<void> _uploadDocument(String documentKey, String documentTitle) async {
    // Simulate document upload
    setState(() {
      _isLoading = true;
    });

    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
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
  }

  void _removeDocument(String documentKey, String documentTitle) {
    setState(() {
      _uploadedDocuments[documentKey] = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$documentTitle removed'),
        backgroundColor: AppColors.warningColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _viewDocument(String documentTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(documentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Document Preview',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This is a preview of your uploaded $documentTitle',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Progress Indicator
          _buildProgressIndicator(),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing24,
              ),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.radiusXl),
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLg),
          child: Row(
            children: [
              IconButton(
                onPressed: _previousStep,
                icon: Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              SizedBox(width: AppDimensions.paddingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Collector Registration',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: AppDimensions.paddingXs),
                    Text(
                      'Step 4 of 5 - Document Upload',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
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

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLg,
        vertical: AppDimensions.paddingMd,
      ),
      child: Column(
        children: [
          // Progress bars
          Row(
            children: [
              // Step 1 - Completed
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.paddingXs),
              // Step 2 - Completed
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.paddingXs),
              // Step 3 - Completed
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.paddingXs),
              // Step 4 - Current (in progress)
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.paddingXs),
              // Step 5 - Not started
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.paddingSm),
          // Step labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Account',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: Text(
                  'Contact',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: Text(
                  'Vehicle',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: Text(
                  'Docs',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: Text(
                  'Review',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final uploadedCount = _uploadedDocuments.values
        .where((uploaded) => uploaded)
        .length;
    final requiredCount = _requiredDocuments
        .where((doc) => doc['required'] == true)
        .length;
    final requiredUploaded = _requiredDocuments
        .where(
          (doc) => doc['required'] == true && _uploadedDocuments[doc['key']]!,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spacing32),

        // Progress Summary
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.collectorPrimary.withValues(alpha: 0.1),
                AppColors.collectorSecondary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: AppColors.collectorPrimary.withValues(alpha: 0.2),
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
                      color: AppColors.collectorPrimary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.upload_file,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Progress',
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.collectorPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Required: $requiredUploaded/$requiredCount | Total: $uploadedCount/${_requiredDocuments.length}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${((requiredUploaded / requiredCount) * 100).round()}%',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.collectorPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),
              LinearProgressIndicator(
                value: requiredUploaded / requiredCount,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.collectorPrimary,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacing32),

        // Instructions
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: AppColors.infoColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.infoColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.infoColor, size: 24),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Guidelines',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.infoColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Files should be clear and readable\n• Accepted formats: JPG, PNG, PDF\n• Maximum file size: 5MB per file\n• Documents marked with * are required',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacing24),

        // Documents List
        Text(
          'Required Documents',
          style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: AppDimensions.spacing16),

        ..._requiredDocuments.map((document) => _buildDocumentCard(document)),

        const SizedBox(height: AppDimensions.spacing40),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: CustomButton(
                onPressed: _previousStep,
                text: 'Back',
                backgroundColor: AppColors.backgroundDark,
                textColor: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing16),
            Expanded(
              child: CustomButton(
                onPressed: _isLoading ? null : _nextStep,
                text: _isLoading ? 'Processing...' : 'Continue',
                backgroundColor: AppColors.collectorPrimary,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.spacing24),

        // Progress info
        Text(
          'Next: Junk Shop Selection',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppDimensions.spacing24),
      ],
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final isUploaded = _uploadedDocuments[document['key']] ?? false;
    final isRequired = document['required'] ?? false;

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
          // Header with icon, title, and required label
          Row(
            children: [
              // Document Icon
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
                      : Text(
                          document['icon'],
                          style: const TextStyle(fontSize: 20),
                        ),
                ),
              ),

              const SizedBox(width: AppDimensions.spacing16),

              // Title
              Expanded(
                child: Text(
                  document['title'],
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isUploaded
                        ? AppColors.successColor
                        : AppColors.textPrimary,
                  ),
                ),
              ),

              // Required label in upper right
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
            document['description'],
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Upload button below description
          if (isUploaded)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _viewDocument(document['title']),
                  icon: const Icon(
                    Icons.visibility,
                    color: AppColors.collectorPrimary,
                  ),
                  tooltip: 'View Document',
                ),
                IconButton(
                  onPressed: () =>
                      _removeDocument(document['key'], document['title']),
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
                onPressed: () =>
                    _uploadDocument(document['key'], document['title']),
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Upload'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.collectorPrimary,
                  backgroundColor: AppColors.collectorPrimary.withValues(alpha: 0.1),
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
}
