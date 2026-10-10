import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/household_posting_repository.dart';
import '../../widgets/rate_collector_modal.dart';
import '../../widgets/rate_junkshop_modal.dart';
import '../../../../../core/di/service_locator.dart';

class CollectionDetailsScreen extends StatefulWidget {
  final CompletedCollection collection;
  final double calculatedTotal;
  final List<Map<String, dynamic>> parsedItems;
  final Function() onRefresh;

  const CollectionDetailsScreen({
    super.key,
    required this.collection,
    required this.calculatedTotal,
    required this.parsedItems,
    required this.onRefresh,
  });

  @override
  State<CollectionDetailsScreen> createState() =>
      _CollectionDetailsScreenState();
}

class _CollectionDetailsScreenState extends State<CollectionDetailsScreen> {
  final _repository = getIt<IHouseholdPostingRepository>();
  bool _isRefreshing = false;
  bool _hasRatedCollector = false;
  bool _hasRatedJunkshop = false;

  @override
  Widget build(BuildContext context) {
    final isDeclined =
        widget.collection.status?.toLowerCase() == 'declined' ||
        widget.collection.status?.toLowerCase() == 'cancelled';
    final statusColor = _getStatusColor(widget.collection.status);
    final displayDate = isDeclined
        ? (widget.collection.declinedAt ??
              widget.collection.reviewedAt ??
              widget.collection.createdAt)
        : (widget.collection.reviewedAt ??
              widget.collection.collectedAt ??
              widget.collection.createdAt);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Transaction Details',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFF0F0F0)),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero header ──────────────────────────────────
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.collection.junkshopName ??
                                  'Unknown Junkshop',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatStatus(widget.collection.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isDeclined) ...[
                        const SizedBox(height: 10),
                        Text(
                          '\u20b1${NumberFormat('#,##0.00').format(widget.calculatedTotal)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGreen,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                      if (displayDate != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          DateFormat(
                            'MMMM d, yyyy \u2022 h:mm a',
                          ).format(displayDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Details card ─────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Details'),
                      if (widget.collection.junkshopName != null)
                        _buildInfoRow(
                          'Junkshop',
                          widget.collection.junkshopName!,
                          trailing: widget.collection.junkshopRating != null
                              ? _buildStarPill(
                                  widget.collection.junkshopRating!,
                                )
                              : null,
                        ),
                      if (widget.collection.collectorName != null)
                        _buildInfoRow(
                          'Collector',
                          widget.collection.collectorName!,
                          trailing: widget.collection.collectorRating != null
                              ? _buildStarPill(
                                  widget.collection.collectorRating!,
                                )
                              : null,
                        ),
                      if (displayDate != null)
                        _buildInfoRow(
                          isDeclined ? 'Declined On' : 'Collected',
                          DateFormat(
                            'MMM d, yyyy \u2022 h:mm a',
                          ).format(displayDate),
                        ),
                      if (widget.collection.addressShort != null)
                        _buildInfoRow(
                          'Pickup Location',
                          widget.collection.addressShort!,
                        ),
                      _buildInfoRow(
                        'Reference',
                        '#${widget.collection.id.length >= 8 ? widget.collection.id.substring(0, 8).toUpperCase() : widget.collection.id.toUpperCase()}',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Ratings card ─────────────────────────────────
                if (widget.collection.canRateJunkshop ||
                    widget.collection.isJunkshopRated == true ||
                    widget.collection.canRateCollector ||
                    widget.collection.isCollectorRated == true)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Ratings'),
                        if (widget.collection.canRateJunkshop ||
                            widget.collection.isJunkshopRated == true)
                          _buildRatingStarsRow(
                            label: widget.collection.isJunkshopRated == true
                                ? 'Junkshop'
                                : 'Rate Junkshop',
                            starsWidget: _JunkshopStarRating(
                              collection: widget.collection,
                              hasRatedLocally: _hasRatedJunkshop,
                              onStarTap: (v) => _showJunkshopRatingModal(
                                widget.collection,
                                v,
                              ),
                            ),
                            isLast:
                                !(widget.collection.canRateCollector ||
                                    widget.collection.isCollectorRated == true),
                          ),
                        if (widget.collection.canRateCollector ||
                            widget.collection.isCollectorRated == true)
                          _buildRatingStarsRow(
                            label: widget.collection.isCollectorRated == true
                                ? 'Collector'
                                : 'Rate Collector',
                            starsWidget: _CollectorStarRating(
                              collection: widget.collection,
                              hasRatedLocally: _hasRatedCollector,
                              onStarTap: (v) => _showCollectorRatingModal(
                                widget.collection,
                                v,
                              ),
                            ),
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                if (widget.collection.canRateJunkshop ||
                    widget.collection.isJunkshopRated == true ||
                    widget.collection.canRateCollector ||
                    widget.collection.isCollectorRated == true)
                  const SizedBox(height: 8),

                // ── Items card ───────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildDetailedItemsList(widget.collection),
                ),
                const SizedBox(height: 8),

                // ── Timeline card ────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Timeline'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: _buildHistoryTimeline(widget.collection),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                _buildUnifiedPhotoCarousel(widget.collection),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        if (_isRefreshing)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Updating rating...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── lean UI helpers ─────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFADB5BD),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Widget? trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF3F4F6),
            indent: 20,
          ),
      ],
    );
  }

  Widget _buildRatingStarsRow({
    required String label,
    required Widget starsWidget,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              starsWidget,
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF3F4F6),
            indent: 20,
          ),
      ],
    );
  }

  Widget _buildStarPill(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTimeline(CompletedCollection collection) {
    final events = <Map<String, dynamic>>[];
    final isDeclined =
        collection.status?.toLowerCase() == 'declined' ||
        collection.status?.toLowerCase() == 'cancelled';

    if (collection.createdAt != null) {
      events.add({
        'event': 'Collection Created',
        'timestamp': collection.createdAt,
        'icon': Icons.add_circle_outline,
        'color': AppColors.primaryGreen,
      });
    }

    if (collection.scheduledDate != null) {
      events.add({
        'event': 'Pickup Scheduled',
        'timestamp': collection.scheduledDate,
        'icon': Icons.calendar_today_outlined,
        'color': const Color(0xFF3B82F6),
      });
    }

    if (collection.collectorName != null) {
      events.add({
        'event': 'Collector Assigned',
        'timestamp': collection.scheduledDate ?? collection.createdAt,
        'icon': Icons.person_add_outlined,
        'color': AppColors.primaryGreen,
        'detail': collection.collectorName,
      });
    }

    if (isDeclined) {
      // Show decline event
      events.add({
        'event': collection.status?.toLowerCase() == 'cancelled'
            ? 'Collection Cancelled'
            : 'Collection Declined',
        'timestamp':
            collection.declinedAt ??
            collection.reviewedAt ??
            collection.createdAt,
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
      });
    } else {
      // Show completion events
      if (collection.collectedAt != null) {
        events.add({
          'event': 'Items Verified',
          'timestamp': collection.collectedAt,
          'icon': Icons.check_circle_outline,
          'color': AppColors.primaryGreen,
        });
      }

      if (collection.collectedAt != null) {
        events.add({
          'event': 'Collection Completed',
          'timestamp': collection.collectedAt,
          'icon': Icons.check_circle,
          'color': AppColors.primaryGreen,
        });
      }
    }

    return Column(
      children: events.asMap().entries.map((entry) {
        final index = entry.key;
        final event = entry.value;
        final isLast = index == events.length - 1;

        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline line
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: event['color'].withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: event['color'], width: 2),
                        ),
                        child: Icon(
                          event['icon'],
                          size: 12,
                          color: event['color'],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppColors.borderLight,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Event details
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['event'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'MMM dd, yyyy • h:mm a',
                          ).format(event['timestamp']),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (event['detail'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            event['detail'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUnifiedPhotoCarousel(CompletedCollection collection) {
    // Collect all photos with their metadata
    final List<Map<String, dynamic>> allPhotos = [];

    // Add arrival photos
    if (collection.proofPhotos['arrival']?.isNotEmpty ?? false) {
      for (final url in collection.proofPhotos['arrival']!) {
        allPhotos.add({
          'url': url,
          'type': 'Arrival',
          'icon': Icons.location_on,
          'color': const Color(0xFFF59E0B),
        });
      }
    }

    // Add collection photos
    if (collection.proofPhotos['collection']?.isNotEmpty ?? false) {
      for (final url in collection.proofPhotos['collection']!) {
        allPhotos.add({
          'url': url,
          'type': 'Collection',
          'icon': Icons.inventory_2,
          'color': const Color(0xFF3B82F6),
        });
      }
    }

    // Add before/after photos
    if (collection.proofPhotos['before_after']?.isNotEmpty ?? false) {
      for (final url in collection.proofPhotos['before_after']!) {
        allPhotos.add({
          'url': url,
          'type': 'Before/After',
          'icon': Icons.compare_arrows,
          'color': const Color(0xFF8B5CF6),
        });
      }
    }

    // Add payment photos
    if (collection.paymentProofUrls.isNotEmpty) {
      for (final url in collection.paymentProofUrls) {
        allPhotos.add({
          'url': url,
          'type': 'Payment',
          'icon': Icons.receipt_long,
          'color': AppColors.primaryGreen,
        });
      }
    }

    if (allPhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library,
                  size: 20,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Photos',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${allPhotos.length} photo${allPhotos.length != 1 ? 's' : ''}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Unified carousel (full width, edge to edge)
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: allPhotos.length,
            itemBuilder: (context, index) {
              final photo = allPhotos[index];
              return Container(
                margin: EdgeInsets.only(
                  right: index == allPhotos.length - 1 ? 0 : 12,
                ),
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: photo['url'],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: Center(
                            child: Icon(
                              photo['icon'],
                              color: photo['color'].withValues(alpha: 0.3),
                              size: 28,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),

                    // Type badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: photo['color'],
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(photo['icon'], size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              photo['type'],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tap overlay
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () =>
                            _showFullScreenPhotoViewer(allPhotos, index),
                        child: Container(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedItemsList(CompletedCollection collection) {
    final isDeclined =
        collection.status?.toLowerCase() == 'declined' ||
        collection.status?.toLowerCase() == 'cancelled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Text(
                isDeclined ? 'ITEMS' : 'ITEMS COLLECTED',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFADB5BD),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.parsedItems.length} item${widget.parsedItems.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFADB5BD),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 4),
        ...widget.parsedItems.map((item) {
          // Get actual price from item data
          double itemValue = 0.0;
          if (item['junkshopTotalPrice'] != null) {
            itemValue = (item['junkshopTotalPrice'] as num).toDouble();
          } else if (item['totalPrice'] != null) {
            itemValue = (item['totalPrice'] as num).toDouble();
          } else if (item['pricePerUnit'] != null && item['quantity'] != null) {
            final pricePerUnit = (item['pricePerUnit'] as num).toDouble();
            final quantity = (item['quantity'] as num).toDouble();
            itemValue = pricePerUnit * quantity;
          } else if (item['junkshopPricePerUnit'] != null &&
              item['quantity'] != null) {
            final pricePerUnit = (item['junkshopPricePerUnit'] as num)
                .toDouble();
            final quantity = (item['quantity'] as num).toDouble();
            itemValue = pricePerUnit * quantity;
          }

          final name =
              item['name']?.toString() ??
              item['type']?.toString() ??
              'Unknown Item';
          final quantity = item['quantity']?.toString() ?? '0';
          final unit = item['unit']?.toString() ?? 'pcs';

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Promotion Boost Badge
                          if (item['promotionBoostPercentage'] != null &&
                              item['promotionBoostPercentage'] > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.successColor,
                                    AppColors.successColor.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.successColor.withValues(alpha: 
                                      0.3,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.trending_up,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '+${(item['promotionBoostPercentage'] as num).toStringAsFixed(0)}%',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$quantity $unit',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${NumberFormat('#,##0.00').format(itemValue)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.successColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₱${NumberFormat('#,##0.00').format(widget.calculatedTotal)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  void _showCollectorRatingModal(
    CompletedCollection collection, [
    int? initialRating,
  ]) async {
    if (collection.collectorName == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RateCollectorModal(
        collectorName: collection.collectorName!,
        collectorPhoto: collection.collectorPhoto,
        initialRating: initialRating,
        onSubmit: (rating, reviewText, selectedReasons) async {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          try {
            await _repository.submitCollectorRating(
              postingId: collection.id,
              rating: rating.toDouble(),
              reviewText: reviewText,
              selectedReasons: selectedReasons,
            );

            if (!mounted) return;

            navigator.pop();

            setState(() {
              _hasRatedCollector = true;
              _isRefreshing = true;
            });

            await widget.onRefresh();

            if (!mounted) return;

            setState(() {
              _isRefreshing = false;
            });

            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: const Text('Collector rating submitted successfully!'),
                backgroundColor: AppColors.primaryGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;

            navigator.pop();

            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Error: ${e.toString().replaceAll('Exception: ', '')}',
                ),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showJunkshopRatingModal(
    CompletedCollection collection, [
    int? initialRating,
  ]) async {
    if (collection.junkshopName == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RateJunkshopModal(
        junkshopName: collection.junkshopName!,
        initialRating: initialRating,
        onSubmit: (rating, reviewText, selectedReasons) async {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          try {
            await _repository.submitJunkshopRating(
              postingId: collection.id,
              rating: rating.toDouble(),
              reviewText: reviewText,
              selectedReasons: selectedReasons,
            );

            if (!mounted) return;

            navigator.pop();

            setState(() {
              _hasRatedJunkshop = true;
              _isRefreshing = true;
            });

            await widget.onRefresh();

            if (!mounted) return;

            setState(() {
              _isRefreshing = false;
            });

            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: const Text('Junkshop rating submitted successfully!'),
                backgroundColor: AppColors.primaryGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;

            navigator.pop();

            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Error: ${e.toString().replaceAll('Exception: ', '')}',
                ),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showFullScreenPhotoViewer(
    List<Map<String, dynamic>> photos,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FullScreenPhotoViewer(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    final statusLower = status.toLowerCase();

    switch (statusLower) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'scheduled':
        return 'Scheduled';
      case 'rescheduled':
      case 'reschedule':
        return 'Rescheduled';
      case 'in_progress':
        return 'In Progress';
      case 'en_route':
        return 'En Route';
      case 'arrived':
        return 'Arrived';
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'declined':
        return 'Declined';
      default:
        return statusLower
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return const Color(0xFF6B7280);
    final statusLower = status.toLowerCase();

    switch (statusLower) {
      case 'completed':
        return const Color(0xFF10B981); // Green
      case 'assigned':
      case 'scheduled':
        return const Color(0xFF3B82F6); // Blue
      case 'rescheduled':
      case 'reschedule':
        return const Color(0xFFF59E0B); // Orange
      case 'in_progress':
      case 'en_route':
      case 'arrived':
      case 'collecting':
        return const Color(0xFF8B5CF6); // Purple
      case 'pending':
        return const Color(0xFF6B7280); // Gray
      case 'cancelled':
      case 'declined':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

class FullScreenPhotoViewer extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;

  const FullScreenPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.photos[_currentIndex]['color'],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.photos[_currentIndex]['icon'],
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.photos[_currentIndex]['type'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: widget.photos[index]['url'],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JunkshopStarRating extends StatefulWidget {
  final CompletedCollection collection;
  final Function(int) onStarTap;
  final bool hasRatedLocally;

  const _JunkshopStarRating({
    required this.collection,
    required this.onStarTap,
    this.hasRatedLocally = false,
  });

  @override
  State<_JunkshopStarRating> createState() => _JunkshopStarRatingState();
}

class _JunkshopStarRatingState extends State<_JunkshopStarRating> {
  int _hoveredStar = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => setState(() => _hoveredStar = 0),
      child: Row(
        children: List.generate(5, (index) {
          final starValue = index + 1;
          final isRated = widget.collection.isJunkshopRated == true;
          final ratingValue = widget.collection.junkshopRating ?? 0;
          final isSelected = isRated
              ? starValue <= ratingValue
              : _hoveredStar > 0
              ? starValue <= _hoveredStar
              : false;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredStar = starValue),
            child: GestureDetector(
              onTap:
                  (widget.collection.canRateJunkshop && !widget.hasRatedLocally)
                  ? () {
                      setState(() => _hoveredStar = starValue);
                      widget.onStarTap(starValue);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star_rounded,
                  size: 28,
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CollectorStarRating extends StatefulWidget {
  final CompletedCollection collection;
  final Function(int) onStarTap;
  final bool hasRatedLocally;

  const _CollectorStarRating({
    required this.collection,
    required this.onStarTap,
    this.hasRatedLocally = false,
  });

  @override
  State<_CollectorStarRating> createState() => _CollectorStarRatingState();
}

class _CollectorStarRatingState extends State<_CollectorStarRating> {
  int _hoveredStar = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => setState(() => _hoveredStar = 0),
      child: Row(
        children: List.generate(5, (index) {
          final starValue = index + 1;
          final isRated = widget.collection.isCollectorRated == true;
          final ratingValue = widget.collection.collectorRating ?? 0;
          final isSelected = isRated
              ? starValue <= ratingValue
              : _hoveredStar > 0
              ? starValue <= _hoveredStar
              : false;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredStar = starValue),
            child: GestureDetector(
              onTap:
                  (widget.collection.canRateCollector &&
                      !widget.hasRatedLocally)
                  ? () {
                      setState(() => _hoveredStar = starValue);
                      widget.onStarTap(starValue);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star_rounded,
                  size: 28,
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
