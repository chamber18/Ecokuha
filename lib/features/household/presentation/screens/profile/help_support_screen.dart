import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;
  int _selectedCategory = 0;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'icon': Icons.apps_rounded},
    {'label': 'Getting Started', 'icon': Icons.rocket_launch_outlined},
    {'label': 'Collections', 'icon': Icons.local_shipping_outlined},
    {'label': 'Payments', 'icon': Icons.payments_outlined},
    {'label': 'Account', 'icon': Icons.manage_accounts_outlined},
    {'label': 'Eco Impact', 'icon': Icons.eco_outlined},
  ];

  final List<Map<String, dynamic>> _faqs = [
    {
      'category': 'Getting Started',
      'question': 'How do I post items for recycling?',
      'answer':
          'Tap the "Post Items" button on your dashboard. Select the materials you want to recycle, add photos using the AI scanner or manually, specify quantities, choose your preferred junkshop, and submit. A junkshop will review and assign a collector to you.',
    },
    {
      'category': 'Getting Started',
      'question': 'What materials can I recycle?',
      'answer':
          'We accept a wide variety of materials including:\n Paper & Cardboard\n Plastic bottles (PET/HDPE)\n Glass bottles & jars\n Aluminum & tin cans\n Copper, brass & steel scrap\n Car & motorcycle batteries\n Electronics (TVs, motherboards, CPUs)\n Appliances (AC units, refrigerators, washing machines)',
    },
    {
      'category': 'Getting Started',
      'question': 'How does the AI scanner work?',
      'answer':
          'Tap "Scan Items" on the post screen, then take a photo or pick one from your gallery. The AI will automatically detect and identify the material, suggest a category, and provide estimated pricing. You can adjust the result if needed before adding it to your posting.',
    },
    {
      'category': 'Collections',
      'question': 'How long until a junkshop responds to my posting?',
      'answer':
          'Typically within 24 hours. You will receive a push notification when a junkshop accepts your posting and assigns a collector. You can also check the status on your dashboard under active postings.',
    },
    {
      'category': 'Collections',
      'question': 'How do I track my collection in real-time?',
      'answer':
          'Once a collector is assigned you can tap your active posting to see their live location on the map. You will receive notifications at each stage: Assigned  On the Way  Arrived  Completed.',
    },
    {
      'category': 'Collections',
      'question': 'Can I cancel a collection request?',
      'answer':
          'Yes  but only before a collector is assigned. Open the active posting, tap the menu (), and select "Cancel Request". Once a collector is assigned, please coordinate cancellations directly through the in-app chat.',
    },
    {
      'category': 'Collections',
      'question': 'Can I schedule a pickup for a specific date and time?',
      'answer':
          'When creating a posting you can indicate your preferred collection schedule. The assigned collector will confirm availability through the chat, so you can coordinate the exact time that works for both parties.',
    },
    {
      'category': 'Collections',
      'question': 'What if the collector does not arrive?',
      'answer':
          'First check the chat for updates  delays can happen. If the collector is significantly late with no communication, use the chat to follow up or report the issue. Our support team can also assist if the problem persists.',
    },
    {
      'category': 'Payments',
      'question': 'When will I receive payment for my recyclables?',
      'answer':
          'Payment is processed after the collector verifies and weighs your items on-site. The junkshop reviews the verified items and confirms the final amount. You will see the total in your posting details and transaction history.',
    },
    {
      'category': 'Payments',
      'question': 'How are prices determined?',
      'answer':
          'Prices depend on material type, quality, and current market rates. You will see estimated prices when posting, but the final price is confirmed after the collector verifies the actual weight and condition. Each junkshop may offer slightly different rates.',
    },
    {
      'category': 'Payments',
      'question': 'What happens if my items are rejected?',
      'answer':
          'Items may be rejected if they do not match the description, are contaminated, or are heavily damaged. The collector will note this during on-site verification. Only accepted items are included in your final payment. Rejected items remain yours to keep or relist.',
    },
    {
      'category': 'Payments',
      'question': 'How accurate are the weight estimates?',
      'answer':
          'Your estimated weights are a guide only. The collector will weigh items on-site using calibrated scales, and that verified weight determines your final payment. Try to be as accurate as possible when estimating to avoid surprises.',
    },
    {
      'category': 'Account',
      'question': 'How do I update my pickup address?',
      'answer':
          'Go to Profile  Account  Saved Addresses. You can add, edit, or remove addresses. When creating a new posting you can select which saved address to use for pickup.',
    },
    {
      'category': 'Account',
      'question': 'Can I edit a posting after I submit it?',
      'answer':
          'Postings cannot be edited after submission. If you need to make changes before a junkshop accepts it, cancel the posting and create a new one with the correct information.',
    },
    {
      'category': 'Account',
      'question': 'How do I view my collection history?',
      'answer':
          'Tap "Total Collections" or "Total Earned" on your dashboard to see all past transactions, including dates, materials collected, verified weights, and earnings per posting.',
    },
    {
      'category': 'Eco Impact',
      'question': 'What is the carbon savings feature?',
      'answer':
          'Every time you recycle, we calculate the CO\u2082 emissions prevented compared to producing new materials. Tap "Carbon Saved" on your dashboard to see your total environmental impact, visualised as equivalents like trees planted or car kilometres avoided.',
    },
    {
      'category': 'Eco Impact',
      'question': 'How is my carbon savings calculated?',
      'answer':
          'We use material-specific CO\u2082 factors (e.g. Aluminum: 8.5 kg CO\u2082/kg, Glass: 0.3 kg CO\u2082/kg) multiplied by your verified recycled weight. The result reflects the emissions avoided by recycling instead of manufacturing from raw materials.',
    },
  ];

  List<Map<String, dynamic>> get _filteredFaqs {
    final categoryLabel = _categories[_selectedCategory]['label'] as String;
    return _faqs.where((faq) {
      final matchesCategory =
          categoryLabel == 'All' || faq['category'] == categoryLabel;
      final matchesSearch =
          _searchQuery.isEmpty ||
          (faq['question'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (faq['answer'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFaqs;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {
                  _searchQuery = v;
                  _expandedIndex = null;
                }),
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search questions...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Category chips
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: List.generate(_categories.length, (i) {
                      final cat = _categories[i];
                      final selected = _selectedCategory == i;
                      return Padding(
                        padding: EdgeInsets.only(
                          right: i < _categories.length - 1 ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedCategory = i;
                            _expandedIndex = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryGreen
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 14,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // FAQ count label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${filtered.length} question${filtered.length == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          // FAQ list
          filtered.isEmpty
              ? SliverToBoxAdapter(
                  key: ValueKey('empty-$_selectedCategory-$_searchQuery'),
                  child: _buildEmptyState(),
                )
              : SliverPadding(
                  key: ValueKey('list-$_selectedCategory-$_searchQuery'),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildFaqItem(filtered[i], i),
                      childCount: filtered.length,
                    ),
                  ),
                ),

          // Contact section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: _buildContactSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, dynamic> faq, int index) {
    final isExpanded = _expandedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedIndex = isExpanded ? null : index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExpanded
                  ? AppColors.primaryGreen.withValues(alpha: 0.35)
                  : Colors.grey.shade200,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        faq['question'] as String,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded
                            ? AppColors.primaryGreen
                            : Colors.grey.shade400,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade100,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Text(
                        faq['answer'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different keyword or browse all categories.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Still need help?',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildContactTile(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF2196F3),
                title: 'Chat with Support',
                subtitle: 'Usually replies within a few minutes',
                isFirst: true,
                onTap: () => _showComingSoon('Live chat'),
              ),
              _buildDivider(),
              _buildContactTile(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFF9C27B0),
                title: 'Send an Email',
                subtitle: 'support@EcoKuha.com',
                isLast: true,
                onTap: () => _showComingSoon('Email support'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 56);

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature  coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }
}
