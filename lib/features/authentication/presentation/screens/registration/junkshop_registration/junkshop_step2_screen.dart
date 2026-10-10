import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class JunkshopStep2Screen extends StatefulWidget {
  const JunkshopStep2Screen({super.key});

  @override
  State<JunkshopStep2Screen> createState() => _JunkshopStep2ScreenState();
}

class _JunkshopStep2ScreenState extends State<JunkshopStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _serviceRadiusController = TextEditingController();

  final bool _isLoading = false;
  bool _hasPickupService = true;
  String? _selectedServiceRadius;

  final List<String> _serviceRadiusOptions = [
    '1-3 km radius',
    '3-5 km radius',
    '5-10 km radius',
    '10+ km radius',
    'City-wide service',
    'Multiple cities',
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _landmarkController.dispose();
    _serviceRadiusController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      final previousData =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ??
          {};

      final junkshopData = {
        ...previousData,
        'address': _addressController.text,
        'city': _cityController.text,
        'zipCode': _zipCodeController.text,
        'landmark': _landmarkController.text,
        'serviceRadius': _selectedServiceRadius,
        'hasPickupService': _hasPickupService,
        'step': 2,
      };

      Navigator.pushNamed(
        context,
        '/junkshop-register-3',
        arguments: junkshopData,
      );
    }
  }

  void _previousStep() {
    Navigator.pop(context);
  }

  void _useCurrentLocation() {
    // Simulate getting current location
    _addressController.text = "123 Sample Street, Barangay Sample";
    _cityController.text = "Quezon City";
    _zipCodeController.text = "1100";
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location updated!'),
        backgroundColor: AppColors.successColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

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
          Text(
            'Location Information',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: AppDimensions.paddingSm),
          Text(
            'Please provide your business location details.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: AppDimensions.paddingXl),

          // Address Field with Current Location Button
          Stack(
            children: [
              CustomTextField(
                controller: _addressController,
                label: 'Business Address',
                hint: 'Enter complete business address',
                maxLines: 2,
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondary,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your business address';
                  }
                  if (value.length < 10) {
                    return 'Please enter a complete address';
                  }
                  return null;
                },
              ),
              Positioned(
                right: 8,
                top: 35,
                child: TextButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use Current'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.junkshopPrimary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // City and Zip Code Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: _cityController,
                  label: 'City/Municipality',
                  hint: 'Enter city',
                  prefixIcon: const Icon(
                    Icons.location_city,
                    color: AppColors.textSecondary,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter city';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                flex: 1,
                child: CustomTextField(
                  controller: _zipCodeController,
                  label: 'Zip Code',
                  hint: '1100',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(
                    Icons.markunread_mailbox,
                    color: AppColors.textSecondary,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (value.length < 4) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Landmark Field
          CustomTextField(
            controller: _landmarkController,
            label: 'Nearby Landmark (Optional)',
            hint: 'e.g., Near SM Mall, Beside Gas Station',
            prefixIcon: const Icon(
              Icons.place_outlined,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Pickup Service Toggle
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Service',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Do you offer pickup service for customers?',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _hasPickupService,
                  onChanged: (value) {
                    setState(() {
                      _hasPickupService = value;
                    });
                  },
                  activeColor: AppColors.junkshopPrimary,
                ),
              ],
            ),
          ),

          // Service Radius (shown only if pickup service is enabled)
          if (_hasPickupService) ...[
            const SizedBox(height: AppDimensions.spacing20),

            DropdownButtonFormField<String>(
              value: _selectedServiceRadius,
              decoration: InputDecoration(
                labelText: 'Service Radius',
                hintText: 'How far can you pickup?',
                prefixIcon: const Icon(
                  Icons.map_outlined,
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
                    color: AppColors.junkshopPrimary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                  vertical: AppDimensions.spacing16,
                ),
              ),
              items: _serviceRadiusOptions.map((String radius) {
                return DropdownMenuItem<String>(
                  value: radius,
                  child: Text(radius),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedServiceRadius = newValue;
                });
              },
              validator: (value) {
                if (_hasPickupService && (value == null || value.isEmpty)) {
                  return 'Please select service radius';
                }
                return null;
              },
            ),
          ],

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
                  backgroundColor: AppColors.junkshopPrimary,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Progress info
          Text(
            'Next step: Profile',
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
