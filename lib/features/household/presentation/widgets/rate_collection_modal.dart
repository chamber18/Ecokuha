import 'package:flutter/material.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';
import 'package:ecokuha/core/theme/app_dimensions.dart';

class RateCollectionModal extends StatefulWidget {
  final String collectorName;
  final String junkshopName;
  final Function(
    double collectorRating,
    double junkshopRating,
    String reviewText,
    int timelinessScore,
    int professionalismScore,
  )
  onSubmit;

  const RateCollectionModal({
    super.key,
    required this.collectorName,
    required this.junkshopName,
    required this.onSubmit,
  });

  @override
  State<RateCollectionModal> createState() => _RateCollectionModalState();
}

class _RateCollectionModalState extends State<RateCollectionModal> {
  double _collectorRating = 0;
  double _junkshopRating = 0;
  int _timelinessScore = 0;
  int _professionalismScore = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Widget _buildStarRating({
    required String label,
    required double currentRating,
    required Function(double) onRatingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppDimensions.paddingSm),
        Row(
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => onRatingChanged((index + 1).toDouble()),
              child: Icon(
                index < currentRating ? Icons.star : Icons.star_border,
                color: AppColors.primaryGreen,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildScoreSelector({
    required String label,
    required int currentScore,
    required Function(int) onScoreChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppDimensions.paddingSm),
        Row(
          children: List.generate(5, (index) {
            final score = index + 1;
            final isSelected = score == currentScore;
            return GestureDetector(
              onTap: () => onScoreChanged(score),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryGreen : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_collectorRating == 0 || _junkshopRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate both collector and junkshop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_timelinessScore == 0 || _professionalismScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide timeliness and professionalism scores'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    widget.onSubmit(
      _collectorRating,
      _junkshopRating,
      _reviewController.text.trim(),
      _timelinessScore,
      _professionalismScore,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate Your Collection', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.paddingMd),

              // Collector Rating
              _buildStarRating(
                label: 'Rate Collector: ${widget.collectorName}',
                currentRating: _collectorRating,
                onRatingChanged: (rating) {
                  setState(() => _collectorRating = rating);
                },
              ),
              const SizedBox(height: AppDimensions.paddingLg),

              // Junkshop Rating
              _buildStarRating(
                label: 'Rate Junkshop: ${widget.junkshopName}',
                currentRating: _junkshopRating,
                onRatingChanged: (rating) {
                  setState(() => _junkshopRating = rating);
                },
              ),
              const SizedBox(height: AppDimensions.paddingLg),

              // Timeliness Score
              _buildScoreSelector(
                label: 'Timeliness (1-5)',
                currentScore: _timelinessScore,
                onScoreChanged: (score) {
                  setState(() => _timelinessScore = score);
                },
              ),
              const SizedBox(height: AppDimensions.paddingLg),

              // Professionalism Score
              _buildScoreSelector(
                label: 'Professionalism (1-5)',
                currentScore: _professionalismScore,
                onScoreChanged: (score) {
                  setState(() => _professionalismScore = score);
                },
              ),
              const SizedBox(height: AppDimensions.paddingLg),

              // Review Text
              Text('Review (Optional)', style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppDimensions.paddingSm),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingLg),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingMd),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingLg,
                        vertical: AppDimensions.paddingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Submit Rating',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
