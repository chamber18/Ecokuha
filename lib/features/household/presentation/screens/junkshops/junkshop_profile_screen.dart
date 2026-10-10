import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/supabase/supabase_helpers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/phone_launcher.dart';
import '../../utils/direct_chat_helper.dart';

// Custom painter for dotted lines
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;

    const dashWidth = 3;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class JunkshopProfileScreen extends StatefulWidget {
  final Map<String, dynamic> junkshop;

  const JunkshopProfileScreen({super.key, required this.junkshop});

  @override
  State<JunkshopProfileScreen> createState() => _JunkshopProfileScreenState();
}

class _JunkshopProfileScreenState extends State<JunkshopProfileScreen> {
  List<Map<String, dynamic>> _allMaterials = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int get _totalPages => (_filteredMaterials.length / _itemsPerPage).ceil();

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
    try {
      final junkshopId = widget.junkshop['id'] as String?;
      debugPrint(
        '[JunkshopProfile] Loading materials for junkshop ID: $junkshopId',
      );
      debugPrint('[JunkshopProfile] Junkshop data: ${widget.junkshop}');

      if (junkshopId == null) {
        debugPrint('[JunkshopProfile] No junkshop ID found');
        setState(() => _isLoading = false);
        return;
      }

      final docs = rowsToDocs(
        'junkshop_materials',
        await Supabase.instance.client
            .from('junkshop_materials')
            .select()
            .eq('junkshop_id', junkshopId)
            .eq('is_active', true),
      );

      debugPrint('[JunkshopProfile] Fetched ${docs.length} materials');

      final materials = <String, List<Map<String, dynamic>>>{};

      for (final data in docs) {
        final category = data['category'] as String? ?? 'others';
        debugPrint(
          '[JunkshopProfile] Material: ${data['name']}, Category: $category, Price: ${data['priceMin']}-${data['priceMax']}',
        );

        final material = {
          'name': data['name'],
          'priceMin': data['priceMin'],
          'priceMax': data['priceMax'],
          'unit': data['unit'],
        };

        if (!materials.containsKey(category)) {
          materials[category] = [];
        }
        materials[category]!.add(material);
      }

      // Sort materials within each category by name
      for (final list in materials.values) {
        list.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
      }

      // Flatten materials into a single list for pagination
      final allMaterials = <Map<String, dynamic>>[];
      for (final entry in materials.entries) {
        for (final material in entry.value) {
          allMaterials.add({...material, 'category': entry.key});
        }
      }

      // Sort all materials alphabetically by name
      allMaterials.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      debugPrint(
        '[JunkshopProfile] Grouped materials: ${materials.keys.toList()}',
      );
      debugPrint('[JunkshopProfile] Total materials: ${allMaterials.length}');

      setState(() {
        _allMaterials = allMaterials;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading materials: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.successColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.junkshop['name'] ?? 'Junkshop Details',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          'assets/images/placeholders/junkshop-bg.jpg',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Stats Section (simplified, not in cards)
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  color: AppColors.backgroundLight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('4.8', 'Rating', Icons.star),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          '250+',
                          'Collections',
                          Icons.recycling,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          '2.5km',
                          'Distance',
                          Icons.location_on,
                        ),
                      ),
                    ],
                  ),
                ),

                // Basic Info Section
                Container(
                  margin: const EdgeInsets.all(AppDimensions.paddingL),
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Operating Hours', '8:00 AM - 6:00 PM'),
                      const Divider(),
                      _buildInfoRow('Contact', '+63 912 345 6789'),
                      const Divider(),
                      _buildInfoRow(
                        'Status',
                        'Open Now',
                        valueColor: AppColors.successColor,
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingM,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final phoneNumber =
                                widget.junkshop['phone'] as String?;
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
                            side: const BorderSide(
                              color: AppColors.primaryBlue,
                            ),
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
                ),

                // Waste Prices Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingL,
                        ),
                        child: Text(
                          'Waste Prices',
                          style: AppTextStyles.headerMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildWastePricesSection(),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrCreateConversation(BuildContext context) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please login first')));
        }
        return;
      }

      final junkshopId = widget.junkshop['id'] as String?;
      if (junkshopId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Junkshop ID not available')),
          );
        }
        return;
      }

      final conversation = await DirectChatHelper.getOrCreate(
        currentUserId: currentUser.id,
        junkshopId: junkshopId,
        junkshopName: (widget.junkshop['name'] as String?) ?? 'Junkshop',
      );

      if (context.mounted && conversation != null) {
        Navigator.pushNamed(
          context,
          '/conversation',
          arguments: {
            'conversationId': conversation.id,
            'otherUserId': junkshopId,
            'otherUserName': widget.junkshop['name'] ?? 'Junkshop',
          },
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create conversation')),
        );
      }    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.successColor, size: 24),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          value,
          style: AppTextStyles.headerSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWastePricesSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_allMaterials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No materials available',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
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
        // Materials List
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: Column(
            children: _paginatedMaterials.asMap().entries.map((entry) {
              final index = entry.key;
              final material = entry.value;
              final isLast = index == _paginatedMaterials.length - 1;

              // Format price
              final priceMin = material['priceMin'] as num?;
              final priceMax = material['priceMax'] as num?;
              final unit = material['unit'] as String? ?? 'piece';
              final category = material['category'] as String? ?? 'others';

              String priceText;
              if (priceMin != null && priceMax != null) {
                if (priceMin == priceMax) {
                  priceText = '₱${priceMin.toStringAsFixed(0)}/$unit';
                } else {
                  priceText =
                      '₱${priceMin.toStringAsFixed(0)}-${priceMax.toStringAsFixed(0)}/$unit';
                }
              } else {
                priceText = 'Price not set';
              }

              return Container(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  border: !isLast
                      ? Border(
                          bottom: BorderSide(
                            color: AppColors.borderColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Material name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material['name'] as String,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            category.toUpperCase(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price
                    Text(
                      priceText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Pagination controls
        if (_totalPages > 1) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button
                TextButton.icon(
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                ),
                // Page indicator
                Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                // Next button
                TextButton.icon(
                  onPressed: _currentPage < _totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                  iconAlignment: IconAlignment.end,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppDimensions.spacingL),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
