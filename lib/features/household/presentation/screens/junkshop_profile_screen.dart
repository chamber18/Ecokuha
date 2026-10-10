import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/phone_launcher.dart';
import '../utils/direct_chat_helper.dart';
import 'junkshop_reviews_screen.dart';

class JunkshopProfileScreen extends StatelessWidget {
  final Map<String, dynamic> shop;

  const JunkshopProfileScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.successColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                shop['name'] ?? 'Junkshop Profile',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (shop['image'] != null &&
                          (shop['image'] as String).isNotEmpty &&
                          ((shop['image'] as String).startsWith('http://') ||
                              (shop['image'] as String).startsWith(
                                'https://',
                              ))) {
                        _showFullScreenImage(context, shop['image'] as String);
                      }
                    },
                    child:
                        (shop['image'] != null &&
                            (shop['image'] as String).isNotEmpty &&
                            ((shop['image'] as String).startsWith('http://') ||
                                (shop['image'] as String).startsWith(
                                  'https://',
                                )))
                        ? Image.network(
                            shop['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.successColor,
                                      AppColors.successColor.withValues(alpha: 0.8),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.store_rounded,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.successColor,
                                  AppColors.successColor.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.store_rounded,
                                color: Colors.white,
                                size: 80,
                              ),
                            ),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (shop['isOpen'] ?? false)
                            ? AppColors.successColor
                            : AppColors.errorColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (shop['isOpen'] ?? false) ? 'Open Now' : 'Closed',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Average Rating and Reviews (clickable)
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => JunkshopReviewsScreen(
                        junkshopId: shop['id'] as String,
                        junkshopName: shop['name'] as String,
                        averageRating: shop['rating'] as double?,
                        totalReviews: shop['reviews'] as int?,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      if ((shop['reviews'] as int? ?? 0) > 0) ...[
                        const Icon(Icons.star, size: 20, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${(shop['rating'] as double? ?? 0.0).toStringAsFixed(1)} (${shop['reviews']} ${(shop['reviews'] as int? ?? 0) == 1 ? 'review' : 'reviews'})',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.primaryBlue,
                        ),
                      ] else ...[
                        const Icon(
                          Icons.star_border,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'No reviews yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Distance – only shown when the value is available
                if ((shop['distance'] as num?) != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${((shop['distance'] as num).toDouble()).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppDimensions.spacing16),
                // Contact info
                _buildDetailRow(
                  Icons.location_on,
                  'Address',
                  shop['address'] ?? 'No address available',
                ),
                if (shop['locationNote'] != null &&
                    (shop['locationNote'] as String).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 32, bottom: 12),
                    child: Text(
                      shop['locationNote'] as String,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryBlue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                _buildDetailRow(
                  Icons.phone,
                  'Phone',
                  shop['phone'] ?? 'No phone available',
                ),
                _buildDetailRow(
                  Icons.access_time,
                  'Hours',
                  shop['hours'] ?? 'Not specified',
                ),
                if (shop['openDays'] != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      shop['openDays'],
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.spacing16),
                // Rates (if available)
                if (shop['rates'] != null) ...[
                  const Text('Current Rates', style: AppTextStyles.cardTitle),
                  const SizedBox(height: AppDimensions.spacing12),
                  ...(shop['rates'] as Map<String, dynamic>).entries.map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacingS,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                ],
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final phoneNumber = shop['phone'] as String?;
                          if (phoneNumber != null && phoneNumber.isNotEmpty) {
                            try {
                              await PhoneLauncher.makePhoneCall(phoneNumber);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to make phone call: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone number not available'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.phone,
                          color: AppColors.primaryBlue,
                        ),
                        label: const Text(
                          'Call Now',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryBlue),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.paddingSm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusM,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openOrCreateConversation(context),
                        icon: const Icon(
                          Icons.message,
                          color: AppColors.textWhite,
                        ),
                        label: const Text(
                          'Message',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.paddingSm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusM,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                // Materials and Prices Section
                const Text(
                  'Materials & Prices',
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: AppDimensions.spacing12),
                _buildMaterialsSection(shop['id']),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                return const Center(
                  child: Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 80,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openOrCreateConversation(BuildContext context) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to send messages'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final junkshopId = shop['id'] as String?;
      final junkshopName = shop['name'] as String? ?? 'Unknown Junkshop';
      final junkshopProfileImage = shop['image'] as String?;

      if (junkshopId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open chat: Junkshop ID not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final conversation = await DirectChatHelper.getOrCreate(
        currentUserId: currentUserId,
        junkshopId: junkshopId,
        junkshopName: junkshopName,
        junkshopProfileImage: junkshopProfileImage,
      );

      if (conversation != null && context.mounted) {
        Navigator.pushNamed(
          context,
          '/household/conversation',
          arguments: {'conversation': conversation},
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Widget _buildMaterialsSection(String? junkshopId) {
    if (junkshopId == null) {
      return const Text('No materials available');
    }

    return _PaginatedMaterialsList(junkshopId: junkshopId);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginatedMaterialsList extends StatefulWidget {
  final String junkshopId;

  const _PaginatedMaterialsList({required this.junkshopId});

  @override
  State<_PaginatedMaterialsList> createState() =>
      _PaginatedMaterialsListState();
}

class _PaginatedMaterialsListState extends State<_PaginatedMaterialsList> {
  List<Map<String, dynamic>> _allMaterials = [];
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int get _totalPages => _filteredMaterials.isEmpty
      ? 1
      : (_filteredMaterials.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _filteredMaterials {
    if (_searchQuery.isEmpty) {
      return _allMaterials;
    }
    return _allMaterials.where((material) {
      final name = (material['name'] as String).toLowerCase();
      final category = (material['category'] as String).toLowerCase();
      return name.contains(_searchQuery) || category.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _paginatedMaterials {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      _filteredMaterials.length,
    );
    return _filteredMaterials.sublist(startIndex, endIndex);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 0;
      });
    });
    _loadMaterials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);

    try {
      final docs = rowsToDocs(
        'junkshop_materials',
        await Supabase.instance.client
            .from('junkshop_materials')
            .select()
            .eq('junkshop_id', widget.junkshopId),
      );

      final materials = <Map<String, dynamic>>[];
      for (final data in docs) {
        final category = data['category'] as String? ?? 'others';
        final name = data['name'] as String;
        final isActive = data['isActive'] as bool? ?? false;

        materials.add({
          'name': name,
          'category': category,
          'priceMin': data['householdPriceMin'] ?? data['priceMin'],
          'priceMax': data['householdPriceMax'] ?? data['priceMax'],
          'unit': data['unit'],
          'isActive': isActive,
        });
      }

      materials.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      setState(() {
        _allMaterials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_allMaterials.isEmpty) {
      return const Text(
        'No materials available',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search materials...',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF6B7280),
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paginatedMaterials.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[300]),
            itemBuilder: (context, index) {
              final material = _paginatedMaterials[index];
              final name = material['name'] as String;
              final category = material['category'] as String;
              final priceMin = material['priceMin'];
              final priceMax = material['priceMax'];
              final unit = material['unit'] as String? ?? 'kg';

              String priceText = 'Price not set';
              if (priceMin != null && priceMax != null) {
                priceText = '₱$priceMin-₱$priceMax/$unit';
              } else if (priceMin != null) {
                priceText = '₱$priceMin/$unit';
              }

              return Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? _previousPage : null,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.primaryGreen,
                disabledColor: Colors.grey[400],
              ),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
                icon: const Icon(Icons.chevron_right),
                color: AppColors.primaryGreen,
                disabledColor: Colors.grey[400],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MaterialCategoryCard extends StatefulWidget {
  final String category;
  final String icon;
  final List<Map<String, dynamic>> materials;

  const _MaterialCategoryCard({
    required this.category,
    required this.icon,
    required this.materials,
  });

  @override
  State<_MaterialCategoryCard> createState() => _MaterialCategoryCardState();
}

class _MaterialCategoryCardState extends State<_MaterialCategoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayMaterials = _isExpanded
        ? widget.materials
        : widget.materials.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                widget.category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...displayMaterials.map((material) {
            final priceMin = material['priceMin'] as num?;
            final priceMax = material['priceMax'] as num?;
            final unit = material['unit'] as String? ?? 'piece';

            String priceText;
            if (priceMin != null && priceMax != null) {
              if (priceMin == priceMax) {
                priceText = '₱$priceMin/$unit';
              } else {
                priceText = '₱$priceMin-$priceMax/$unit';
              }
            } else {
              priceText = 'Price not set';
            }

            final isActive = material['isActive'] as bool? ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    material['name'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    priceText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.successColor
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (widget.materials.length > 3)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded ? 'Show less' : 'Show more',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
