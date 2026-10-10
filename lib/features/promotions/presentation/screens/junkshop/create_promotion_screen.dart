import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/promotion.dart';
import '../../../domain/entities/promotion_type.dart';
import '../../bloc/junkshop_promotions/junkshop_promotions_bloc.dart';
import '../../bloc/junkshop_promotions/junkshop_promotions_event.dart';
import '../../bloc/junkshop_promotions/junkshop_promotions_state.dart';
import '../../../../junkshop/presentation/widgets/material_category_dropdown.dart';

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
    return const ClampingScrollPhysics();
  }
}

class CreatePromotionScreen extends StatefulWidget {
  final Promotion? existingPromotion;

  const CreatePromotionScreen({super.key, this.existingPromotion});

  @override
  State<CreatePromotionScreen> createState() => _CreatePromotionScreenState();
}

class _CreatePromotionScreenState extends State<CreatePromotionScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Basic Info
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedImage;
  final _imagePicker = ImagePicker();

  // Step 2: Materials & Price Boost
  List<String> _selectedMaterials = [];
  final _priceBoostController = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _materialsGroupedByCategory = {};
  bool _isLoadingMaterials = false;

  bool _isLoading = false;
  final _db = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    if (widget.existingPromotion != null) {
      _loadExistingPromotion();
    }
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoadingMaterials = true);

    try {
      final user = _db.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final rows = await _db
          .from('junkshop_materials')
          .select()
          .eq('junkshop_id', user.id)
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('name', ascending: true);

      final Map<String, List<Map<String, dynamic>>> groupedMaterials = {};

      for (final data in rows) {
        final category = (data['category'] ?? 'others')
            .toString()
            .toLowerCase();

        final material = {
          'id': data['id'].toString(),
          'name': data['name'] ?? '',
          'category': category,
          'stock': (data['stock'] as num?)?.toDouble() ?? 0.0,
          'unit': data['unit'] ?? 'kg',
          'price': (data['price_max'] as num?)?.toDouble() ?? 0.0,
        };

        if (!groupedMaterials.containsKey(category)) {
          groupedMaterials[category] = [];
        }
        groupedMaterials[category]!.add(material);
      }

      setState(() {
        _materialsGroupedByCategory = groupedMaterials;
        _isLoadingMaterials = false;
      });
    } catch (e) {
      debugPrint('Error loading materials: $e');
      setState(() => _isLoadingMaterials = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load materials. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadExistingPromotion() {
    final promo = widget.existingPromotion!;
    _titleController.text = promo.title;
    _descriptionController.text = promo.description;
    _startDate = promo.startDate;
    _endDate = promo.endDate;
    _selectedMaterials = List.from(promo.materials);
    _priceBoostController.text = promo.priceBoostDetails.boostPercentage
        .toStringAsFixed(0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceBoostController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 1) {
      if (!_validateStep2()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateStep1() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a promotion title');
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please enter a description');
      return false;
    }
    if (_startDate == null || _endDate == null) {
      _showError('Please select start and end dates');
      return false;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showError('End date must be after start date');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_selectedMaterials.isEmpty) {
      _showError('Please select at least one material');
      return false;
    }
    final boostValue = int.tryParse(_priceBoostController.text);
    if (boostValue == null || boostValue < 1 || boostValue > 100) {
      _showError('Please enter a valid boost percentage (1-100)');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submitPromotion() async {
    if (!_validateStep1() || !_validateStep2()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Fetch junkshop name from Firestore
      String junkshopName = widget.existingPromotion?.junkshopName ?? '';
      if (junkshopName.isEmpty) {
        final junkshopRow = await Supabase.instance.client
            .from('junkshops')
            .select('business_name, junkshop_profile')
            .eq('id', user.id)
            .maybeSingle();

        if (junkshopRow != null) {
          final profile = junkshopRow['junkshop_profile'];
          final business = profile is Map ? profile['business'] : null;
          junkshopName =
              (junkshopRow['business_name'] as String?) ??
              (business is Map ? business['business_name'] as String? : null) ??
              '';
        }
        if (junkshopName.isEmpty) junkshopName = 'Unknown Junkshop';
      }

      final promotion = Promotion(
        id:
            widget.existingPromotion?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        junkshopId: user.id,
        junkshopName: junkshopName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: PromotionType.priceBoost,
        materials: _selectedMaterials,
        status: PromotionStatus.active,
        startDate: _startDate!,
        endDate: _endDate!,
        createdAt: widget.existingPromotion?.createdAt ?? DateTime.now(),
        updatedAt: widget.existingPromotion != null ? DateTime.now() : null,
        priceBoostDetails: PriceBoostDetails(
          boostPercentage: double.parse(_priceBoostController.text),
        ),
        imageUrl: null, // Will be set by repository after upload
      );

      if (!mounted) return;
      if (widget.existingPromotion != null) {
        context.read<JunkshopPromotionsBloc>().add(
          UpdatePromotion(promotion, _selectedImage),
        );
      } else {
        context.read<JunkshopPromotionsBloc>().add(
          CreatePromotion(promotion, _selectedImage),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to submit promotion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<JunkshopPromotionsBloc, JunkshopPromotionsState>(
      listener: (context, state) {
        if (state is JunkshopPromotionsOperationSuccess) {
          Navigator.pop(context, true); // Return true to trigger reload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.existingPromotion == null
                    ? 'Promotion created successfully'
                    : 'Promotion updated successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is JunkshopPromotionsError) {
          setState(() => _isLoading = false);
          _showError(state.message);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        appBar: AppBar(
          backgroundColor: AppColors.junkshopPrimary,
          foregroundColor: Colors.white,
          title: Text(
            widget.existingPromotion == null
                ? 'Create Promotion'
                : 'Edit Promotion',
            style: AppTextStyles.h5.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          elevation: 0,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                  children: [
                    _buildStep1BasicInfo(),
                    _buildStep2MaterialsAndPrice(),
                    _buildStep3Preview(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDec(String hint, {IconData? icon}) => InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight),
    prefixIcon: icon != null
        ? Icon(icon, color: AppColors.junkshopPrimary, size: 20)
        : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.junkshopPrimary, width: 2),
    ),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );

  Widget _buildStep1BasicInfo() {
    return ScrollConfiguration(
      behavior: _NoGlowScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step heading
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.junkshopPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set up your promotion details',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Card: Title + Description
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Promotion Title'),
                  TextFormField(
                    controller: _titleController,
                    decoration: _fieldDec(
                      'e.g., Weekend Price Boost',
                      icon: Icons.campaign_outlined,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Description'),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _fieldDec(
                      'Tell households about this promotion...',
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card: Dates
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        color: AppColors.junkshopPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      _sectionLabel('Promotion Period'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Start Date',
                          date: _startDate,
                          onTap: () => _selectDate(isStartDate: true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: _buildDateField(
                          label: 'End Date',
                          date: _endDate,
                          onTap: () => _selectDate(isStartDate: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card: Image (optional)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Promo Banner'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Optional',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.junkshopPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedImage != null
                              ? AppColors.junkshopPrimary
                              : AppColors.borderLight,
                          width: 2,
                          style: _selectedImage != null
                              ? BorderStyle.solid
                              : BorderStyle.solid,
                        ),
                        color: AppColors.junkshopPrimary.withValues(
                          alpha: 0.03,
                        ),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Material(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _selectedImage = null,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 32,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap to upload banner image',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PNG or JPG · max 5 MB',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasDate
              ? AppColors.junkshopPrimary.withValues(alpha: 0.07)
              : const Color(0xFFF6F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate
                ? AppColors.junkshopPrimary.withValues(alpha: 0.5)
                : AppColors.borderLight,
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: hasDate
                    ? AppColors.junkshopPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  hasDate
                      ? Icons.event_available_rounded
                      : Icons.calendar_month_outlined,
                  size: 16,
                  color: hasDate
                      ? AppColors.junkshopPrimary
                      : AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasDate
                        ? DateFormat('MMM d, yyyy').format(date)
                        : 'Pick date',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: hasDate
                          ? AppColors.textPrimary
                          : AppColors.textLight,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ??
                (_startDate?.add(const Duration(days: 7))) ??
                DateTime.now().add(const Duration(days: 7))),
      firstDate: isStartDate ? DateTime.now() : (_startDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.junkshopPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
              surfaceContainerHighest: Color(0xFFF1F5F9),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              headerBackgroundColor: AppColors.junkshopPrimary,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              headerHelpStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
              dayStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              weekdayStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              todayBackgroundColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              todayForegroundColor: const WidgetStatePropertyAll(
                AppColors.junkshopPrimary,
              ),
              todayBorder: const BorderSide(
                color: AppColors.junkshopPrimary,
                width: 1.5,
              ),
              elevation: 12,
              shadowColor: Colors.black26,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.junkshopPrimary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // auto-clear end date if it's before the new start
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildStep2MaterialsAndPrice() {
    final presets = [5, 10, 15, 20, 25, 30];
    final currentBoost = int.tryParse(_priceBoostController.text);

    return ScrollConfiguration(
      behavior: _NoGlowScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step heading
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.junkshopPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Materials & Boost',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select materials and set the price boost',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Materials Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionLabel('Applicable Materials'),
                      const Spacer(),
                      if (_selectedMaterials.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.junkshopPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedMaterials.length} selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'Pick which materials receive the price boost',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  MaterialCategoryDropdown(
                    materialsGroupedByCategory: _materialsGroupedByCategory,
                    selectedMaterialIds: _selectedMaterials,
                    onSelectionChanged: (materialIds) {
                      setState(() => _selectedMaterials = materialIds);
                    },
                    isLoading: _isLoadingMaterials,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Boost Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Price Boost'),
                  Text(
                    'Quick presets',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((pct) {
                      final isSelected = currentBoost == pct;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _priceBoostController.text = '$pct'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.junkshopPrimary
                                : AppColors.junkshopPrimary.withValues(
                                    alpha: 0.08,
                                  ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.junkshopPrimary
                                  : AppColors.junkshopPrimary.withValues(
                                      alpha: 0.25,
                                    ),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '+$pct%',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Or enter a custom percentage',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _priceBoostController,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        _fieldDec(
                          'e.g., 18',
                          icon: Icons.trending_up_rounded,
                        ).copyWith(
                          suffixText: '%',
                          suffixStyle: AppTextStyles.h5.copyWith(
                            color: AppColors.junkshopPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (currentBoost != null && currentBoost > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.junkshopPrimary.withValues(alpha: 0.08),
                            AppColors.junkshopPrimary.withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_graph_rounded,
                            color: AppColors.junkshopPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Households will receive $currentBoost% more for the selected materials during the promotion period.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.junkshopPrimary,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.junkshopPrimary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.junkshopPrimary, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Preview() {
    final boostPercentage = int.tryParse(_priceBoostController.text) ?? 0;
    final hasStart = _startDate != null;
    final hasEnd = _endDate != null;
    final durationDays = hasStart && hasEnd
        ? _endDate!.difference(_startDate!).inDays + 1
        : 0;
    final periodText = hasStart && hasEnd
        ? '${DateFormat('MMM d').format(_startDate!)} – ${DateFormat('MMM d, yyyy').format(_endDate!)}'
        : 'Not set';

    return ScrollConfiguration(
      behavior: _NoGlowScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ready banner ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Everything looks good! Review and publish when ready.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Hero card ─────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // background image or gradient
                  if (_selectedImage != null)
                    SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.junkshopPrimary,
                            AppColors.junkshopPrimary.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  // overlay scrim
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // content
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // boost badge
                          if (boostPercentage > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '+$boostPercentage% Price Boost',
                                style: TextStyle(
                                  color: AppColors.junkshopPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          Text(
                            _titleController.text.isNotEmpty
                                ? _titleController.text
                                : 'Untitled Promotion',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          if (_descriptionController.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _descriptionController.text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2×2 stat grid ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    Icons.date_range_rounded,
                    'PERIOD',
                    periodText,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statTile(
                    Icons.hourglass_bottom_rounded,
                    'DURATION',
                    durationDays > 0
                        ? '$durationDays ${durationDays == 1 ? 'day' : 'days'}'
                        : 'Not set',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    Icons.trending_up_rounded,
                    'PRICE BOOST',
                    boostPercentage > 0 ? '+$boostPercentage%' : 'Not set',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statTile(
                    Icons.inventory_2_outlined,
                    'MATERIALS',
                    _selectedMaterials.isEmpty
                        ? 'None'
                        : '${_selectedMaterials.length} selected',
                  ),
                ),
              ],
            ),

            // ── Materials chips ───────────────────────────────
            if (_selectedMaterials.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sell_outlined,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'BOOSTED MATERIALS',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _selectedMaterials.map((materialId) {
                        final material = _materialsGroupedByCategory.values
                            .expand((l) => l)
                            .firstWhere(
                              (m) => m['id'] == materialId,
                              orElse: () => {'name': materialId},
                            );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.junkshopPrimary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.junkshopPrimary.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Text(
                            material['name'].toString(),
                            style: TextStyle(
                              color: AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final primaryLabel = _currentStep < 2 ? 'Continue' : 'Publish Promotion';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : _currentStep < 2
              ? _nextStep
              : _submitPromotion,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.junkshopPrimary,
            disabledBackgroundColor: AppColors.junkshopPrimary.withValues(
              alpha: 0.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            shadowColor: AppColors.junkshopPrimary.withValues(alpha: 0.3),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      primaryLabel,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_currentStep < 2) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
        ),
        if (_currentStep > 0) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _previousStep,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.textSecondary,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Back',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
