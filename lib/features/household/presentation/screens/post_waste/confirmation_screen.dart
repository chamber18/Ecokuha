import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _contentController;
  late Animation<double> _iconAnimation;
  late Animation<double> _contentAnimation;

  Map<String, dynamic>? _confirmationData;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadConfirmationData();
  }

  void _initAnimations() {
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeInOut),
    );

    // Start animations
    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentController.forward();
    });
  }

  void _loadConfirmationData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _confirmationData = args;
        });
      }
    });
  }

  String _getOrderId() {
    // Generate a mock order ID
    return 'BWP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  String _getEstimatedPickupTime() {
    final now = DateTime.now();
    final estimatedTime = now.add(const Duration(minutes: 30));
    return '${estimatedTime.hour.toString().padLeft(2, '0')}:${estimatedTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _iconController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight, // Light blue background
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            _buildHeader(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing24),
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimensions.spacing32),

                      // Success Icon
                      _buildSuccessIcon(),

                      const SizedBox(height: AppDimensions.spacing32),

                      // Title and Message
                      _buildTitleSection(),

                      const SizedBox(height: AppDimensions.spacing32),

                      // Order Details Card
                      _buildOrderDetailsCard(),

                      const SizedBox(height: AppDimensions.spacing24),

                      // Collector Information
                      _buildCollectorInfoCard(),

                      const SizedBox(height: AppDimensions.spacing24),

                      // Next Steps Card
                      _buildNextStepsCard(),

                      const SizedBox(height: AppDimensions.spacing32),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/household-home',
              (route) => false,
            ),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Order Confirmation',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _iconAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _iconAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleSection() {
    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _contentAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _contentAnimation.value)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SUCCESS',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
                Text(
                  'Waste Posted Successfully!',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  'Your waste collection request has been submitted and a collector will be assigned shortly.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetailsCard() {
    if (_confirmationData == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _contentAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _contentAnimation.value)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Details',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),

                  // Order ID
                  _buildDetailRow(
                    icon: Icons.receipt_long,
                    label: 'Order ID',
                    value: _getOrderId(),
                  ),

                  // Items Count
                  _buildDetailRow(
                    icon: Icons.inventory_2,
                    label: 'Items',
                    value:
                        '${_confirmationData!['wasteItems']?.length ?? 0} items',
                  ),

                  // Total Value
                  _buildDetailRow(
                    icon: Icons.attach_money,
                    label: 'Total Value',
                    value:
                        '₱${(_confirmationData!['totalValue'] ?? 0.0).toStringAsFixed(2)}',
                    isTotal: true,
                  ),

                  // Pickup Address
                  _buildDetailRow(
                    icon: Icons.location_on,
                    label: 'Pickup Address',
                    value: _confirmationData!['address'] ?? '',
                  ),

                  // Estimated Pickup Time
                  _buildDetailRow(
                    icon: Icons.schedule,
                    label: 'Est. Pickup Time',
                    value: _getEstimatedPickupTime(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollectorInfoCard() {
    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _contentAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - _contentAnimation.value)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Junk Shop',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),

                  Row(
                    children: [
                      // Shop Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: AppDimensions.spacing16),

                      // Shop Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _confirmationData?['junkShop']?['name'] ??
                                  'Green Recycling Hub',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: AppColors.warningColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_confirmationData?['junkShop']?['rating'] ?? 4.8}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _confirmationData?['junkShop']?['distance'] ??
                                      '0.5 km away',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Contact Button
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contact feature coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.phone,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextStepsCard() {
    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _contentAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - _contentAnimation.value)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.1),
                    AppColors.primaryGreen.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Text(
                        'What\'s Next?',
                        style: AppTextStyles.h6.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing16),

                  _buildNextStep(
                    '1',
                    'A collector will be assigned to your request',
                  ),
                  _buildNextStep(
                    '2',
                    'You\'ll receive a notification with collector details',
                  ),
                  _buildNextStep('3', 'Track your pickup in real-time'),
                  _buildNextStep('4', 'Get paid after successful collection'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                    color: isTotal
                        ? AppColors.primaryGreen
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStep(String stepNumber, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              onPressed: () {
                Navigator.pushNamed(context, '/household/track');
              },
              text: 'Track Order',
              backgroundColor: AppColors.backgroundDark,
              textColor: AppColors.textPrimary,
              icon: const Icon(
                Icons.track_changes,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: CustomButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/household-home',
                  (route) => false,
                );
              },
              text: 'Go Home',
              backgroundColor: AppColors.primaryBlue,
              icon: const Icon(Icons.home, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
