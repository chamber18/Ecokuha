import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';

class AiScannerScreen extends StatefulWidget {
  const AiScannerScreen({super.key});

  @override
  State<AiScannerScreen> createState() => _AiScannerScreenState();
}

class _AiScannerScreenState extends State<AiScannerScreen>
    with TickerProviderStateMixin {
  bool _isScanning = false;
  bool _hasScannedImage = false;
  bool _isAnalyzing = false;

  late AnimationController _scanAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  // Mock detected items data
  final List<Map<String, dynamic>> _detectedItems = [
    {
      'id': 1,
      'name': 'Plastic Water Bottles',
      'category': 'PET Plastic',
      'confidence': 95,
      'quantity': 5,
      'unit': 'pcs',
      'estimatedPrice': 15.50,
      'recyclable': true,
      'icon': '🧴',
      'weight': 0.5,
    },
    {
      'id': 2,
      'name': 'Aluminum Cans',
      'category': 'Aluminum',
      'confidence': 88,
      'quantity': 3,
      'unit': 'pcs',
      'estimatedPrice': 12.75,
      'recyclable': true,
      'icon': '🥤',
      'weight': 0.3,
    },
    {
      'id': 3,
      'name': 'Cardboard Box',
      'category': 'Cardboard',
      'confidence': 92,
      'quantity': 1,
      'unit': 'pcs',
      'estimatedPrice': 8.25,
      'recyclable': true,
      'icon': '📦',
      'weight': 0.8,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startScanning() async {
    setState(() {
      _isScanning = true;
      _isAnalyzing = false;
    });

    _scanAnimationController.repeat();
    _pulseController.repeat(reverse: true);

    // Simulate camera capture after 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _scanAnimationController.stop();
      _pulseController.stop();

      setState(() {
        _isScanning = false;
        _hasScannedImage = true;
        _isAnalyzing = true;
      });

      // Simulate AI analysis
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _scanAgain() {
    setState(() {
      _hasScannedImage = false;
      _isScanning = false;
      _isAnalyzing = false;
    });
  }

  void _proceedToPost() {
    // Navigate to post waste screen with detected items
    Navigator.pushNamed(
      context,
      '/household/post-waste',
      arguments: {'detectedItems': _detectedItems},
    );
  }

  void _removeItem(int itemId) {
    setState(() {
      _detectedItems.removeWhere((item) => item['id'] == itemId);
    });
  }

  void _updateQuantity(int itemId, int newQuantity) {
    setState(() {
      final itemIndex = _detectedItems.indexWhere(
        (item) => item['id'] == itemId,
      );
      if (itemIndex != -1) {
        _detectedItems[itemIndex]['quantity'] = newQuantity;
        // Recalculate price based on quantity
        final pricePerUnit =
            _detectedItems[itemIndex]['estimatedPrice'] /
            _detectedItems[itemIndex]['quantity'];
        _detectedItems[itemIndex]['estimatedPrice'] =
            pricePerUnit * newQuantity;
      }
    });
  }

  double get _totalEstimatedValue {
    return _detectedItems.fold(
      0.0,
      (sum, item) => sum + item['estimatedPrice'],
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

          // Main Content
          Expanded(
            child: _hasScannedImage ? _buildResultsView() : _buildScannerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios),
              color: AppColors.textWhite,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'AI Waste Scanner',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI POWERED',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40), // Balance the back button
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        // Camera Preview Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.spacing24),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: _isScanning
                    ? AppColors.primaryBlue.withValues(alpha: 0.5)
                    : AppColors.borderLight,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Camera placeholder
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isScanning ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: _isScanning
                                    ? AppColors.primaryBlue.withValues(alpha: 0.2)
                                    : AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 48,
                                color: _isScanning
                                    ? AppColors.primaryBlue
                                    : AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppDimensions.spacing24),
                      Text(
                        _isScanning
                            ? 'Scanning your waste...'
                            : 'Point camera at your waste items',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isScanning
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!_isScanning) ...[
                        const SizedBox(height: AppDimensions.spacing8),
                        Text(
                          'AI will automatically detect and categorize recyclable items',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                // Scanning overlay
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top:
                            _scanAnimation.value *
                            (MediaQuery.of(context).size.height * 0.4),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primaryBlue,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // Action Button
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: CustomButton(
            onPressed: _isScanning ? null : _startScanning,
            text: _isScanning ? 'Scanning...' : 'Start AI Scan',
            backgroundColor: AppColors.primaryBlue,
            isLoading: _isScanning,
            width: double.infinity,
            icon: _isScanning ? null : const Icon(Icons.camera_alt),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_isAnalyzing) {
      return _buildAnalyzingView();
    }

    return Column(
      children: [
        // Results Header
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection Complete',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_detectedItems.length} items found',
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

        // Detected Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing24,
            ),
            itemCount: _detectedItems.length,
            itemBuilder: (context, index) {
              return _buildItemCard(_detectedItems[index]);
            },
          ),
        ),

        // Total Value Section
        if (_detectedItems.isNotEmpty) _buildTotalSection(),

        // Action Buttons
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildAnalyzingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            strokeWidth: 3,
          ),
          const SizedBox(height: AppDimensions.spacing24),
          Text(
            'Analyzing your waste...',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'AI is detecting and categorizing items',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              children: [
                // Item Header
                Row(
                  children: [
                    // Item Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          item['icon'],
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppDimensions.spacing12),

                    // Item Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['category'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${item['confidence']}% confidence',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing12),

                // Item Details Grid
                Container(
                  padding: const EdgeInsets.only(top: AppDimensions.spacing12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Quantity
                      Expanded(
                        child: _buildInfoChip(
                          'Quantity',
                          '${item['quantity']} ${item['unit']}',
                          isEditable: true,
                          onQuantityChanged: (newQty) =>
                              _updateQuantity(item['id'], newQty),
                        ),
                      ),

                      const SizedBox(width: AppDimensions.spacing12),

                      // Price
                      Expanded(
                        child: _buildInfoChip(
                          'Est. Value',
                          '₱${item['estimatedPrice'].toStringAsFixed(2)}',
                          valueColor: AppColors.primaryGreen,
                        ),
                      ),

                      const SizedBox(width: AppDimensions.spacing12),

                      // Recyclable Status
                      Expanded(
                        child: _buildInfoChip(
                          'Status',
                          item['recyclable'] ? 'Recyclable' : 'Not Recyclable',
                          valueColor: item['recyclable']
                              ? AppColors.successColor
                              : AppColors.errorColor,
                          icon: item['recyclable']
                              ? Icons.recycling
                              : Icons.block,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Remove Button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeItem(item['id']),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    String label,
    String value, {
    Color? valueColor,
    IconData? icon,
    bool isEditable = false,
    Function(int)? onQuantityChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing8),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: valueColor ?? AppColors.textPrimary,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing24),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Estimated Value',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '₱${_totalEstimatedValue.toStringAsFixed(2)}',
            style: AppTextStyles.h5.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _scanAgain,
                  text: 'Scan Again',
                  backgroundColor: AppColors.backgroundDark,
                  textColor: AppColors.textPrimary,
                  icon: const Icon(Icons.camera_alt),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: CustomButton(
                  onPressed: () {
                    // Add more images functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add more images feature coming soon!'),
                      ),
                    );
                  },
                  text: 'Add Image',
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  textColor: AppColors.primaryBlue,
                  icon: const Icon(Icons.add_photo_alternate),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing12),

          // Main action button
          CustomButton(
            onPressed: _detectedItems.isNotEmpty ? _proceedToPost : null,
            text: 'Continue to Post Waste',
            backgroundColor: AppColors.primaryBlue,
            width: double.infinity,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}
