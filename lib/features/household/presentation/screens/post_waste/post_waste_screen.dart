import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class PostWasteScreen extends StatefulWidget {
  const PostWasteScreen({super.key});

  @override
  State<PostWasteScreen> createState() => _PostWasteScreenState();
}

class _PostWasteScreenState extends State<PostWasteScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _wasteItems = [];
  String? _selectedJunkShop;
  DateTime? _preferredPickupDate;
  TimeOfDay? _preferredPickupTime;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _showScanningMode = false;

  // Animation controllers
  late AnimationController _scanAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  // Mock junk shops data
  final List<Map<String, dynamic>> _junkShops = [
    {
      'id': '1',
      'name': 'Green Recycling Hub',
      'distance': '0.5 km',
      'rating': 4.8,
      'estimatedTime': '15-30 mins',
      'acceptedMaterials': ['Plastic', 'Metal', 'Paper', 'Glass'],
    },
    {
      'id': '2',
      'name': 'EcoWaste Solutions',
      'distance': '1.2 km',
      'rating': 4.6,
      'estimatedTime': '20-35 mins',
      'acceptedMaterials': ['Plastic', 'Metal', 'Paper'],
    },
    {
      'id': '3',
      'name': 'Metro Scrap Dealers',
      'distance': '2.1 km',
      'rating': 4.3,
      'estimatedTime': '25-40 mins',
      'acceptedMaterials': ['Metal', 'E-waste', 'Paper'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDetectedItems();
    _setDefaultAddress();
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

  void _loadDetectedItems() {
    // Get detected items from AI scanner if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['detectedItems'] != null) {
        setState(() {
          _wasteItems = List<Map<String, dynamic>>.from(args['detectedItems']);
        });
      } else {
        // If no detected items, show manual entry option
        _showManualItemEntry();
      }
    });
  }

  void _setDefaultAddress() {
    // Set default address (in real app, this would come from user profile)
    _addressController.text = '123 Sampaguita Street, Barangay San Antonio';
    _landmarkController.text = 'Near Jollibee';
  }

  void _showManualItemEntry() {
    // If no AI detected items, show button to add items manually
    setState(() {
      _wasteItems = [];
    });
  }

  void _startAiScanning() async {
    setState(() {
      _isScanning = true;
      _showScanningMode = true;
    });

    _scanAnimationController.repeat();
    _pulseController.repeat(reverse: true);

    // Simulate AI scanning and detection
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _scanAnimationController.stop();
      _pulseController.stop();

      // Mock detected items using real material data from Firebase
      final detectedItems = await _getMockDetectionData();

      setState(() {
        _isScanning = false;
        _wasteItems = detectedItems;
        _showScanningMode = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getMockDetectionData() async {
    try {
      // Get materials from first available junkshop (in real app, this would be selected junkshop)
      final db = Supabase.instance.client;
      final junkshopRows = await db.from('junkshops').select('id').limit(1);

      if (junkshopRows.isEmpty) {
        return _getFallbackMockData();
      }

      final junkshopId = junkshopRows.first['id'] as String;
      final materialRows = await db
          .from('junkshop_materials')
          .select()
          .eq('junkshop_id', junkshopId)
          .eq('is_active', true)
          .limit(5);

      if (materialRows.isEmpty) {
        return _getFallbackMockData();
      }

      // Create mock detected items from real materials
      final detectedItems = <Map<String, dynamic>>[];
      int itemId = 1;

      for (final data in materialRows) {
        final category = data['category'] as String? ?? 'others';
        final name = data['name'] as String? ?? 'Unknown Item';
        final unit = data['unit'] as String? ?? 'kg';
        final priceMax =
            (data['household_price_max'] as num?)?.toDouble() ??
            (data['price_max'] as num?)?.toDouble() ??
            0.0;
        final commission = (data['commission'] as num?)?.toDouble() ?? 0.0;

        // Calculate household price (price - commission)
        final householdPrice = priceMax - commission;

        detectedItems.add({
          'id': itemId++,
          'name': name,
          'category': _formatCategoryName(category),
          'confidence': 85 + (itemId * 3), // Mock confidence between 85-100%
          'quantity': itemId, // Mock quantity 1-5
          'unit': unit,
          'estimatedPrice': householdPrice * itemId, // Total price
          'recyclable': true,
          'icon': _getCategoryIcon(category),
          'weight': itemId * 0.5,
          'materialId': data['id'],
        });

        if (detectedItems.length >= 3) break; // Limit to 3 items for demo
      }

      return detectedItems;
    } catch (e) {
      debugPrint('[AI Scan] Error loading materials: $e');
      return _getFallbackMockData();
    }
  }

  List<Map<String, dynamic>> _getFallbackMockData() {
    return [
      {
        'id': 1,
        'name': 'Plastic Water Bottles',
        'category': 'Plastic',
        'confidence': 95,
        'quantity': 3,
        'unit': 'piece',
        'estimatedPrice': 12.50,
        'recyclable': true,
        'icon': '♻️',
        'weight': 0.5,
      },
      {
        'id': 2,
        'name': 'Aluminum Cans',
        'category': 'Metal',
        'confidence': 88,
        'quantity': 2,
        'unit': 'piece',
        'estimatedPrice': 8.75,
        'recyclable': true,
        'icon': '🥤',
        'weight': 0.3,
      },
    ];
  }

  String _formatCategoryName(String category) {
    // Convert category to display name
    final categoryMap = {
      'plastic': 'Plastic',
      'metal': 'Metal',
      'paper': 'Paper',
      'glass': 'Glass',
      'e-waste': 'E-Waste',
      'battery': 'Battery',
      'iron': 'Iron',
      'others': 'Others',
    };
    return categoryMap[category.toLowerCase()] ?? category;
  }

  String _getCategoryIcon(String category) {
    // Return emoji icon based on category
    final iconMap = {
      'plastic': '♻️',
      'metal': '🔩',
      'paper': '📄',
      'glass': '🍾',
      'e-waste': '🔌',
      'battery': '🔋',
      'iron': '⚙️',
      'others': '📦',
    };
    return iconMap[category.toLowerCase()] ?? '📦';
  }

  void _addManualItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddItemModal(),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _wasteItems.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, int newQuantity) {
    setState(() {
      _wasteItems[index]['quantity'] = newQuantity;
      // Recalculate estimated price
      final pricePerUnit =
          _wasteItems[index]['estimatedPrice'] / _wasteItems[index]['quantity'];
      _wasteItems[index]['estimatedPrice'] = pricePerUnit * newQuantity;
    });
  }

  void _selectJunkShop(String junkShopId) {
    setState(() {
      _selectedJunkShop = junkShopId;
    });
  }

  void _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaryGreen,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _preferredPickupDate = date;
          _preferredPickupTime = time;
        });
      }
    }
  }

  void _postWaste() async {
    if (!_formKey.currentState!.validate()) return;

    if (_wasteItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one waste item'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    if (_selectedJunkShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a junk shop'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate posting delay
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      // Navigate to confirmation screen
      Navigator.pushReplacementNamed(
        context,
        '/household/post-confirmation',
        arguments: {
          'wasteItems': _wasteItems,
          'junkShop': _junkShops.firstWhere(
            (shop) => shop['id'] == _selectedJunkShop,
          ),
          'address': _addressController.text,
          'pickupDate': _preferredPickupDate,
          'pickupTime': _preferredPickupTime,
          'totalValue': _totalEstimatedValue,
        },
      );
    }
  }

  double get _totalEstimatedValue {
    return _wasteItems.fold(
      0.0,
      (acc, item) => acc + (item['estimatedPrice'] ?? 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Section
                  _buildAddressSection(),

                  // Waste Items Section
                  _buildWasteItemsSection(),

                  // Junk Shop Selection
                  _buildJunkShopSection(),

                  // Schedule Section
                  _buildScheduleSection(),

                  // Additional Notes
                  _buildNotesSection(),

                  // Total Value
                  if (_wasteItems.isNotEmpty) _buildTotalSection(),

                  const SizedBox(height: AppDimensions.spacing24),
                ],
              ),
            ),
          ),

          // Bottom Action
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textWhite,
                      iconSize: 24,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Post Waste Items',
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI POWERED',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
              const SizedBox(height: 16),
              // Progress indicator
              Row(
                children: [
                  _buildProgressStep(1, 'Add Items', isActive: true),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  _buildProgressStep(2, 'Select Shop', isActive: false),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  _buildProgressStep(3, 'Schedule', isActive: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, {required bool isActive}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive
                    ? AppColors.primaryGreen
                    : Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pickup Address',
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimensions.spacing16),

            // Address Field
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Complete Address',
                hintText: 'Enter your complete address',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  onPressed: () {
                    // Use current location functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Using current location...'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.my_location,
                    color: AppColors.primaryBlue,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your address';
                }
                return null;
              },
              maxLines: 2,
            ),

            const SizedBox(height: AppDimensions.spacing16),

            // Landmark Field
            TextFormField(
              controller: _landmarkController,
              decoration: InputDecoration(
                labelText: 'Landmark (Optional)',
                hintText: 'e.g., Near Jollibee, Across SM Mall',
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteItemsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waste Items',
                style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  if (_wasteItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _wasteItems = [];
                          _showScanningMode = true;
                        });
                        _startAiScanning();
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Scan Again'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _addManualItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing16),

          if (_wasteItems.isEmpty)
            _buildEmptyItemsState()
          else
            ...List.generate(
              _wasteItems.length,
              (index) => _buildWasteItemCard(_wasteItems[index], index),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    if (_showScanningMode) {
      return _buildAiScanningInterface();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.backgroundDark.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withValues(alpha: 0.15),
                  AppColors.primaryGreen.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.recycling_rounded,
              size: 40,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing20),
          Text(
            'No items added yet',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Use AI Scanner to detect items automatically\nor add them manually',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing24),

          // AI Scanner Button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startAiScanning,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Start AI Scanner',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Manual Add Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _addManualItem,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Add Items Manually',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
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
    );
  }

  Widget _buildAiScanningInterface() {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: _isScanning
              ? AppColors.primaryGreen.withValues(alpha: 0.5)
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
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isScanning
                                ? [
                                    AppColors.primaryGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                    AppColors.primaryGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                  ]
                                : [
                                    AppColors.primaryGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                    AppColors.primaryGreen.withValues(
                                      alpha: 0.05,
                                    ),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(
                              alpha: _isScanning ? 0.8 : 0.3,
                            ),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: _isScanning
                              ? AppColors.primaryGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.spacing16),
                Text(
                  _isScanning
                      ? 'AI is analyzing your waste...'
                      : 'Point camera at your recyclable items',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isScanning
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isScanning) ...[
                  const SizedBox(height: AppDimensions.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Processing...',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppDimensions.spacing8),
                  Text(
                    'AI will automatically detect and categorize items',
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
                  top: _scanAnimation.value * 280,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.8),
                          AppColors.primaryGreen,
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Corner brackets
          if (!_isScanning) ...[
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                    left: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                    right: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                    left: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                    right: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWasteItemCard(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Row(
              children: [
                // Item Icon with gradient background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen.withValues(alpha: 0.15),
                        AppColors.primaryGreen.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item['icon'] ?? '♻️',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),

                const SizedBox(width: AppDimensions.spacing16),

                // Item Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['category'] ?? 'Recyclable',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (item['recyclable'] == true) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.successColor,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacing12),

                      // Quantity and Price Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Quantity Controls
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (item['quantity'] > 1) {
                                        _updateItemQuantity(
                                          index,
                                          item['quantity'] - 1,
                                        );
                                      }
                                    },
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.remove_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '${item['quantity']} ${item['unit'] ?? 'pcs'}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _updateItemQuantity(
                                        index,
                                        item['quantity'] + 1,
                                      );
                                    },
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price with currency icon
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGreen.withValues(
                                    alpha: 0.15,
                                  ),
                                  AppColors.primaryGreen.withValues(
                                    alpha: 0.08,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '₱${(item['estimatedPrice'] ?? 0.0).toStringAsFixed(2)}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
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
              ],
            ),
          ),

          // Remove Button - modern design
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _removeItem(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.errorColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.errorColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJunkShopSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Junk Shop',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          ...List.generate(_junkShops.length, (index) {
            final shop = _junkShops[index];
            final isSelected = _selectedJunkShop == shop['id'];

            return Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.borderLight,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: InkWell(
                onTap: () => _selectJunkShop(shop['id']),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  child: Row(
                    children: [
                      // Shop Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: AppDimensions.spacing12),

                      // Shop Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop['name'],
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.textPrimary,
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
                                  '${shop['rating']}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${shop['distance']}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  shop['estimatedTime'],
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Selection Indicator
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primaryBlue,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Pickup Time',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: InkWell(
              onTap: _selectDateTime,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppColors.primaryBlue),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _preferredPickupDate != null &&
                                    _preferredPickupTime != null
                                ? 'Scheduled for ${_preferredPickupDate!.day}/${_preferredPickupDate!.month}/${_preferredPickupDate!.year} at ${_preferredPickupTime!.format(context)}'
                                : 'Select preferred date and time',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: _preferredPickupDate != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (_preferredPickupDate == null)
                            Text(
                              'Tap to choose when you\'re available',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Notes (Optional)',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Any special instructions for the collector?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Estimated Value',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_wasteItems.length} ${_wasteItems.length == 1 ? 'item' : 'items'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${_totalEstimatedValue.toStringAsFixed(2)}',
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PHP',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final canPost = _wasteItems.isNotEmpty && _selectedJunkShop != null;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canPost)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _wasteItems.isEmpty
                            ? 'Add at least one item to continue'
                            : 'Select a junk shop to continue',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: canPost && !_isLoading
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !canPost || _isLoading
                    ? AppColors.textSecondary.withValues(alpha: 0.3)
                    : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: canPost && !_isLoading
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canPost && !_isLoading ? _postWaste : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: canPost
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Post Waste Items',
                                style: AppTextStyles.buttonLarge.copyWith(
                                  color: canPost
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
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
      ),
    );
  }

  Widget _buildAddItemModal() {
    // This would be a comprehensive modal for adding items manually
    // For now, just show a simple placeholder
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.radiusXl),
          topRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: AppDimensions.spacing24),

            Text(
              'Add Item Manually',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: AppDimensions.spacing32),

            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.construction,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  Text(
                    'Manual Item Entry',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  Text(
                    'This feature will allow manual item entry with categories, quantities, and estimated prices.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacing32),
                  CustomButton(
                    onPressed: () => Navigator.pop(context),
                    text: 'Close',
                    backgroundColor: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    _scanAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
