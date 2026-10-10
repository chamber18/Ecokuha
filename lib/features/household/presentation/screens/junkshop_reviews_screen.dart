import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/constants/firestore_fields/rating_fields.dart';

class JunkshopReviewsScreen extends StatelessWidget {
  final String junkshopId;
  final String junkshopName;
  final double? averageRating;
  final int? totalReviews;

  const JunkshopReviewsScreen({
    super.key,
    required this.junkshopId,
    required this.junkshopName,
    this.averageRating,
    this.totalReviews,
  });

  /// Live stream of this junkshop's ratings (newest first), legacy doc-shaped.
  Stream<List<Map<String, dynamic>>> _ratingsStream() {
    return Supabase.instance.client
        .from('ratings')
        .stream(primaryKey: ['id'])
        .eq('target_id', junkshopId)
        .map((rows) {
          final docs = rowsToDocs(
            'ratings',
            rows.where((r) => r['target_type'] == 'junkshop').toList(),
          );
          docs.sort((a, b) {
            final at = toDateTime(a['createdAt']);
            final bt = toDateTime(b['createdAt']);
            if (at == null || bt == null) return 0;
            return bt.compareTo(at);
          });
          return docs;
        });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingXl,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reviews',
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            junkshopName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Average rating summary
              if (averageRating != null && averageRating! > 0)
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Average rating and stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            averageRating!.toStringAsFixed(1),
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (index) {
                                  if (index < averageRating!.floor()) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                    );
                                  } else if (index < averageRating!) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: Icon(
                                        Icons.star_half_rounded,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                    );
                                  } else {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: Icon(
                                        Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                    );
                                  }
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Rating distribution
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _ratingsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final reviews = snapshot.data!;
                          final ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

                          for (var review in reviews) {
                            final data = review;

                            // Junkshop rating documents store the main value
                            // under 'rating', with fallbacks for legacy fields.
                            final rating =
                                (data['rating'] as num?)?.toInt() ??
                                (data[RatingFields.overallRating] as num?)
                                    ?.toInt() ??
                                (data[RatingFields.junkshopRating] as num?)
                                    ?.toInt() ??
                                0;

                            if (rating >= 1 && rating <= 5) {
                              ratingCounts[rating] =
                                  (ratingCounts[rating] ?? 0) + 1;
                            }
                          }

                          return Column(
                            children: [5, 4, 3, 2, 1].map((star) {
                              final count = ratingCounts[star] ?? 0;
                              final percentage = reviews.isEmpty
                                  ? 0.0
                                  : (count / reviews.length);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        '$star Star',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          // Background bar (gray)
                                          Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E0E0),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          // Filled bar (green)
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              return Container(
                                                height: 6,
                                                width:
                                                    constraints.maxWidth *
                                                    percentage,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF00BFA5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Comments section title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _ratingsStream(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Text(
                          '($count)',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Reviews list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _ratingsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppColors.errorColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading reviews',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final reviews = snapshot.data ?? [];

                    if (reviews.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to leave a review!',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildReviewCard(review),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewText = review[RatingFields.reviewText] as String? ?? '';
    final ratedBy = review[RatingFields.ratedBy] as String? ?? 'Anonymous';
    final selectedReasons =
        (review['selectedReasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Household name
          FutureBuilder<String>(
            future: _getHouseholdName(ratedBy),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Anonymous',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              );
            },
          ),
          // Selected reasons
          if (selectedReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedReasons.map((reason) {
                final bool isNegative = _isNegativeReason(reason);
                final Color tagColor = isNegative
                    ? AppColors.errorColor
                    : AppColors.primaryGreen;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reason,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: tagColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Review text
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reviewText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isNegativeReason(String reason) {
    final negativeReasons = [
      'Unfair pricing',
      'Poor communication',
      'Delayed response',
      'Unprofessional staff',
      'Payment issues',
    ];
    return negativeReasons.contains(reason);
  }

  Future<String> _getHouseholdName(String householdId) async {
    try {
      final row = await Supabase.instance.client
          .from('households')
          .select('full_name')
          .eq('id', householdId)
          .maybeSingle();

      return row?['full_name'] as String? ?? 'Anonymous';
    } catch (e) {
      return 'Anonymous';
    }
  }
}
