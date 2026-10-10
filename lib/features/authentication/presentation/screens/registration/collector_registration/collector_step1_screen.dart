import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../core/utils/phone_number_formatter.dart';
import '../../../../../../core/utils/text_utils.dart';
import 'collector_step2_screen.dart';

class CollectorStep1Screen extends StatefulWidget {
  const CollectorStep1Screen({super.key});

  @override
  State<CollectorStep1Screen> createState() => _CollectorStep1ScreenState();
}

class _CollectorStep1ScreenState extends State<CollectorStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: eighteenYearsAgo,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dobController.text = DateFormat('MMMM d, yyyy').format(picked);
    }
  }

  void _handleNext() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    // Get incoming arguments to preserve application_attempts counter
    final incomingArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Create data with step 1 fields
    final collectorData = <String, dynamic>{
      'fullName': TextUtils.capitalizeWords(_fullNameController.text.trim()),
      'dateOfBirth': _dobController.text.trim(),
      'phone': _phoneController.text.trim().replaceAll(' ', ''),
      'step': 1,
    };

    // Preserve application_attempts counter if it exists
    if (incomingArgs != null &&
        incomingArgs.containsKey('application_attempts')) {
      collectorData['application_attempts'] =
          incomingArgs['application_attempts'];
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CollectorStep2Screen(),
        settings: RouteSettings(arguments: collectorData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppDimensions.paddingLg),
              child: _buildForm(),
            ),
          ),
          _buildBottomButton(),
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
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLg),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
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
                      'Step 1 of 5 - Personal',
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
              // Step 1 - Current
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
              // Step 2 - Not started
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.paddingXs),
              // Step 3 - Not started
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.paddingXs),
              // Step 4 - Not started
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
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
            children: const [
              Flexible(
                child: Text(
                  'Personal',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Flexible(
                child: Text(
                  'Contact',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Flexible(
                child: Text(
                  'Vehicle',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Flexible(
                child: Text(
                  'Docs',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Flexible(
                child: Text(
                  'Review',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ],
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
            'Personal Information',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: AppDimensions.paddingSm),
          Text(
            'Please provide your personal details for verification.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppDimensions.paddingXl),
          CustomTextField(
            controller: _fullNameController,
            label: 'Full Name *',
            hint: 'Enter your full name',
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(
              Icons.person_outline,
              color: AppColors.outline,
            ),
            focusedBorderColor: AppColors.primary,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              if (value.trim().length < 2) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          SizedBox(height: AppDimensions.paddingLg),
          CustomTextField(
            controller: _dobController,
            label: 'Date of Birth *',
            hint: 'Select your date of birth',
            readOnly: true,
            onTap: _pickDateOfBirth,
            suffixIcon: const Icon(
              Icons.calendar_today,
              color: AppColors.outline,
            ),
            textInputAction: TextInputAction.next,
            focusedBorderColor: AppColors.primary,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Date of birth is required';
              }
              return null;
            },
          ),
          SizedBox(height: AppDimensions.paddingLg),
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: '09 000 000 000',
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneNumberFormatter()],
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.phone),
            focusedBorderColor: AppColors.primary,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
              if (digitsOnly.length < 11) {
                return 'Enter a valid 11-digit phone number';
              }
              return null;
            },
          ),
          SizedBox(height: AppDimensions.paddingLg),
          // Email/password removed: auth is handled before profile steps
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDimensions.paddingLg),
      child: CustomButton(
        text: 'Next Step',
        onPressed: _handleNext,
        backgroundColor: AppColors.primary,
        textColor: Colors.white,
      ),
    );
  }
}
