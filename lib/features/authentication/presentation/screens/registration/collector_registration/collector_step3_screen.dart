import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class CollectorStep3Screen extends StatefulWidget {
  const CollectorStep3Screen({super.key});

  @override
  State<CollectorStep3Screen> createState() => _CollectorStep3ScreenState();
}

class _CollectorStep3ScreenState extends State<CollectorStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _plateNumberController = TextEditingController();

  bool _isLoading = false;
  String? _selectedVehicleType;
  String? _selectedCapacity;

  // Document upload state
  final Map<String, bool> _uploadedDocuments = {
    'validId': false,
    'driversLicense': false,
    'vehiclePhoto': false,
  };

  final Map<String, File?> _documentImages = {
    'validId': null,
    'driversLicense': null,
    'vehiclePhoto': null,
  };

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _requiredDocuments = [
    {
      'key': 'validId',
      'title': 'Valid Government ID',
      'description':
          'Upload a clear photo of your valid government-issued ID (e.g., National ID, Passport, Driver\'s License)',
      'icon': '🪪',
      'required': true,
    },
    {
      'key': 'driversLicense',
      'title': 'Driver\'s License',
      'description':
          'Upload a clear photo of your driver\'s license (if applicable)',
      'icon': '🚗',
      'required': false,
    },
    {
      'key': 'vehiclePhoto',
      'title': 'Vehicle Photo',
      'description':
          'Upload a clear photo showing your entire collection vehicle',
      'icon': '📸',
      'required': true,
    },
  ];

  final List<String> _vehicleTypes = [
    'Motorcycle',
    'Tricycle',
    'Jeepney',
    'Mini Truck',
    'Pickup Truck',
    'Van',
    'Bicycle with Cart',
    'E-Bike with Cart',
    'Push Cart',
    'Other',
  ];

  final List<String> _capacityOptions = [
    'Less than 100kg',
    '100-300kg',
    '300-500kg',
    '500-1000kg',
    '1000-2000kg',
    'More than 2000kg',
  ];

  @override
  void dispose() {
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument(String documentKey, String documentTitle) async {
    // Show bottom sheet to choose camera or gallery
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
                            color: AppColors.collectorPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.collectorPrimary.withValues(alpha: 
                                0.3,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: AppColors.collectorPrimary,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Camera',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.collectorPrimary,
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
                            color: AppColors.collectorPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.collectorPrimary.withValues(alpha: 
                                0.3,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.photo_library,
                                color: AppColors.collectorPrimary,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Gallery',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.collectorPrimary,
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

  void _removeDocument(String documentKey, String documentTitle) {
    setState(() {
      _uploadedDocuments[documentKey] = false;
      _documentImages[documentKey] = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$documentTitle removed'),
        backgroundColor: AppColors.warningColor,
        duration: const Duration(seconds: 2),
      ),
    );
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

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      // Validate required documents
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

      final previous =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};
      final vehicle = {
        'type': _selectedVehicleType,
        'capacity': _selectedCapacity,
        'plate_number': _plateNumberController.text.trim(),
      };
      final documents = Map<String, bool>.from(_uploadedDocuments);
      final documentFiles = Map<String, File?>.from(_documentImages);
      final merged = {
        ...previous,
        'vehicle': vehicle,
        'documents': documents,
        'documentFiles': documentFiles,
        'step': 3,
      };
      Navigator.pushNamed(context, '/collector-register-3', arguments: merged);
    }
  }

  void _previousStep() {
    Navigator.pop(context);
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final isUploaded = _uploadedDocuments[document['key']] ?? false;
    final isRequired = document['required'] ?? false;
    final imageFile = _documentImages[document['key']];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document['title'],
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document['description'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Required',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.errorColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Image preview or upload area
          if (imageFile != null)
            Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
                      decoration: BoxDecoration(
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
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.collectorPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.collectorPrimary.withValues(alpha: 0.2),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      document['icon'],
                      style: const TextStyle(fontSize: 40),
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

          const SizedBox(height: 16),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (isUploaded) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _viewDocument(document['key'], document['title']),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.collectorPrimary,
                        side: BorderSide(
                          color: AppColors.collectorPrimary.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _removeDocument(document['key'], document['title']),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorColor,
                        side: BorderSide(
                          color: AppColors.errorColor.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _uploadDocument(document['key'], document['title']),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                      label: const Text('Upload Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.collectorPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing24,
                ),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacing16),

          // Vehicle Basic Information
          Text(
            'Vehicle Details',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing8),

          Text(
            'Provide information about your collection vehicle.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Vehicle Type
          DropdownButtonFormField<String>(
            value: _selectedVehicleType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              hintText: 'Select vehicle type',
              isDense: true,
              prefixIcon: const Icon(
                Icons.directions_car_outlined,
                color: AppColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.collectorPrimary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.backgroundLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
            ),
            items: _vehicleTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type, overflow: TextOverflow.ellipsis, maxLines: 1),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedVehicleType = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select vehicle type';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Plate Number
          CustomTextField(
            controller: _plateNumberController,
            label: 'Plate Number',
            hint: 'ABC 1234',
            prefixIcon: const Icon(
              Icons.credit_card,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Capacity
          DropdownButtonFormField<String>(
            value: _selectedCapacity,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Capacity',
              hintText: 'Load capacity',
              isDense: true,
              prefixIcon: const Icon(
                Icons.scale,
                color: AppColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.collectorPrimary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.backgroundLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
            ),
            items: _capacityOptions.map((String capacity) {
              return DropdownMenuItem<String>(
                value: capacity,
                child: Text(
                  capacity,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCapacity = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select capacity';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing40),

          // Document Upload Section
          const Divider(height: 1, color: AppColors.borderLight),

          const SizedBox(height: AppDimensions.spacing32),

          Text(
            'Required Documents',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing8),

          Text(
            'Upload the following documents to verify your identity and vehicle.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Document cards
          ..._requiredDocuments.map((document) => _buildDocumentCard(document)),

          const SizedBox(height: AppDimensions.spacing24),

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
                  text: _isLoading ? 'Processing...' : 'Next Step',
                  backgroundColor: AppColors.collectorPrimary,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Progress info
          Text(
            'Next: Review & Submit',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.spacing24),
        ],
      ),
    );
  }
}
