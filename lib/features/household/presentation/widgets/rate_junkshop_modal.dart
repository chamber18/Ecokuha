import 'package:flutter/material.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class RateJunkshopModal extends StatefulWidget {
  final String junkshopName;
  final int? initialRating;
  final Function(int rating, String reviewText, List<String> selectedReasons)
  onSubmit;

  const RateJunkshopModal({
    super.key,
    required this.junkshopName,
    this.initialRating,
    required this.onSubmit,
  });

  @override
  State<RateJunkshopModal> createState() => _RateJunkshopModalState();
}

class _RateJunkshopModalState extends State<RateJunkshopModal> {
  late int _rating;
  final Set<String> _selectedReasons = {};
  final _reviewController = TextEditingController();
  final _sheetController = DraggableScrollableController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 0;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a star rating'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    await widget.onSubmit(
      _rating,
      _reviewController.text.trim(),
      _selectedReasons.toList(),
    );
  }

  Widget _buildStarRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'How would you rate your collection experience?',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() => _rating = starValue);
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(
                    0.75,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star_rounded,
                  size: 48,
                  color: starValue <= _rating
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.shade300,
                ),
              ),
            );
          }),
        ),
        if (_rating > 0) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _getRatingText(_rating),
              style: AppTextStyles.bodyMedium.copyWith(
                color: _getRatingColor(_rating),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating <= 2) return Colors.red.shade600;
    if (rating == 3) return Colors.orange.shade600;
    return AppColors.primaryGreen;
  }

  Widget _buildFeedbackReasons() {
    if (kDebugMode) print('🎯 Building feedback reasons for rating: $_rating');
    final bool isNegative = _rating <= 2;
    final String title = isNegative
        ? 'What dissatisfied you the most?'
        : 'What satisfied you the most?';
    final List<String> reasons = isNegative
        ? [
            'Unfair pricing',
            'Poor communication',
            'Delayed response',
            'Unprofessional staff',
            'Payment issues',
          ]
        : [
            'Fair pricing',
            'Responsive communication',
            'Professional service',
            'Quick payment',
            'Helpful staff',
          ];
    final Color activeColor = isNegative ? Colors.red : AppColors.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...reasons.map((reason) => _buildReasonCheckbox(reason, activeColor)),
        ],
      ),
    );
  }

  Widget _buildReasonCheckbox(String reason, Color activeColor) {
    final bool isSelected = _selectedReasons.contains(reason);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedReasons.remove(reason);
            } else {
              _selectedReasons.add(reason);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedReasons.add(reason);
                      } else {
                        _selectedReasons.remove(reason);
                      }
                    });
                  },
                  activeColor: activeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected ? activeColor : Colors.grey[700],
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.4,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.store_rounded,
                              size: 32,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rate Junkshop',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.junkshopName,
                                  style: AppTextStyles.h4.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Star rating
                      _buildStarRating(),

                      const SizedBox(height: 24),

                      // Contextual feedback reasons
                      if (_rating > 0 && _rating != 3) _buildFeedbackReasons(),
                      if (_rating > 0 && _rating != 3)
                        const SizedBox(height: 24),

                      // Review text
                      if (_rating > 0) ...[
                        Text(
                          'Additional Comments (Optional)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reviewController,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText:
                                'Share more details about your experience...',
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                            counterStyle: AppTextStyles.caption.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRating,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: AppColors.primaryGreen
                                  .withValues(alpha: 0.6),
                              disabledForegroundColor: Colors.white.withValues(alpha: 
                                0.8,
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Submit Rating',
                                    style: AppTextStyles.buttonMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
