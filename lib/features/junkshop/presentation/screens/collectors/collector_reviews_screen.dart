import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class CollectorReviewsScreen extends StatelessWidget {
  final String collectorId;
  final String collectorName;
  final double averageRating;
  final int totalReviews;

  const CollectorReviewsScreen({
    super.key,
    required this.collectorId,
    required this.collectorName,
    required this.averageRating,
    required this.totalReviews,
  });

  /// Live list of this collector's ratings (newest first).
  Stream<List<Map<String, dynamic>>> _ratingsStream() {
    return supabase
        .from('ratings')
        .stream(primaryKey: ['id'])
        .eq('target_id', collectorId)
        .map((rows) {
          final docs = rowsToDocs(
            'ratings',
            rows.where((r) => r['target_type'] == 'collector').toList(),
          );
          docs.sort((a, b) {
            final ta = toDateTime(a['createdAt']) ?? DateTime(1970);
            final tb = toDateTime(b['createdAt']) ?? DateTime(1970);
            return tb.compareTo(ta);
          });
          return docs;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              collectorName,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Average rating summary
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
                      averageRating.toStringAsFixed(1),
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
                            if (index < averageRating.floor()) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 1),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              );
                            } else if (index < averageRating) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 1),
                                child: Icon(
                                  Icons.star_half_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              );
                            } else {
                              return const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 1),
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
                      final rating = (review['rating'] as num?)?.toInt() ?? 0;
                      if (rating >= 1 && rating <= 5) {
                        ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: AppColors.borderLight,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00BFA5),
                                        ),
                                    minHeight: 6,
                                  ),
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
                          FluentIcons.error_circle_24_regular,
                          size: 64,
                          color: AppColors.errorColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading reviews',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.errorColor,
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
                          FluentIcons.star_24_regular,
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
                      ],
                    ),
                  );
                }

                return ListView.builder(
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
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewText = review['reviewText'] as String? ?? '';
    final ratedBy = review['ratedBy'] as String? ?? 'Anonymous';
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
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reason,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.errorColor,
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

  Future<String> _getHouseholdName(String householdId) async {
    try {
      final data = await supabase
          .from('households')
          .select('full_name')
          .eq('id', householdId)
          .maybeSingle();

      return data?['full_name'] as String? ?? 'Anonymous';
    } catch (e) {
      return 'Anonymous';
    }
  }
}
