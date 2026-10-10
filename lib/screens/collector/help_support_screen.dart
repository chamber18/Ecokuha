import 'package:flutter/material.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'General';
  String _problemType = 'Technical Issue';

  final List<FAQItem> _faqs = [
    FAQItem(
      question: 'How do I accept collection tasks?',
      answer:
          'Go to your dashboard and toggle your availability to "Available". New tasks will appear in your task list. Tap on any task to view details and accept it.',
      category: 'Tasks',
    ),
    FAQItem(
      question: 'When do I get paid?',
      answer:
          'Payments are processed weekly every Friday. Your earnings from completed collections will be transferred to your registered bank account within 2-3 business days.',
      category: 'Payments',
    ),
    FAQItem(
      question: 'How to optimize my routes?',
      answer:
          'Use the Route Optimization feature in the Routes screen. The app will automatically arrange your stops for maximum efficiency and minimum travel time.',
      category: 'Routes',
    ),
    FAQItem(
      question: 'What should I do if a customer is not home?',
      answer:
          'Try calling the customer first. If they don\'t respond, you can reschedule the pickup or leave a message through the app. Mark the task as "Customer Not Available".',
      category: 'Tasks',
    ),
    FAQItem(
      question: 'How to handle waste rejection?',
      answer:
          'If waste doesn\'t meet our standards, take photos and explain to the customer. You can partially reject items or suggest proper preparation for future collections.',
      category: 'Collections',
    ),
    FAQItem(
      question: 'Can I work outside my assigned area?',
      answer:
          'You can update your service areas in Settings. However, working outside registered areas may affect your task assignments and route optimization.',
      category: 'General',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFAQTab(),
                _buildContactTab(),
                _buildTutorialsTab(),
                _buildFeedbackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.green[700],
        labelColor: Colors.green[700],
        unselectedLabelColor: Colors.grey[600],
        isScrollable: true,
        tabs: const [
          Tab(text: 'FAQ'),
          Tab(text: 'Contact'),
          Tab(text: 'Tutorials'),
          Tab(text: 'Feedback'),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildCategoriesFilter(),
          const SizedBox(height: 16),
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._getFilteredFAQs().map((faq) => _buildFAQItem(faq)),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactOptions(),
          const SizedBox(height: 24),
          _buildContactForm(),
          const SizedBox(height: 24),
          _buildSupportHours(),
        ],
      ),
    );
  }

  Widget _buildTutorialsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Video Tutorials',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTutorialCard(
            'Getting Started as a Collector',
            'Learn the basics of using the collector app',
            '5:32',
            Icons.play_circle,
            Colors.blue,
          ),
          _buildTutorialCard(
            'Accepting and Managing Tasks',
            'How to efficiently handle collection tasks',
            '7:45',
            Icons.play_circle,
            Colors.green,
          ),
          _buildTutorialCard(
            'Route Optimization Tips',
            'Maximize your efficiency with smart routing',
            '4:18',
            Icons.play_circle,
            Colors.orange,
          ),
          _buildTutorialCard(
            'Customer Communication',
            'Best practices for customer interactions',
            '6:12',
            Icons.play_circle,
            Colors.purple,
          ),
          const SizedBox(height: 24),
          const Text(
            'Step-by-Step Guides',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            'Setting Up Your Profile',
            'Complete your collector profile for better opportunities',
            Icons.person,
          ),
          _buildGuideCard(
            'Understanding Waste Categories',
            'Learn about different waste types and their values',
            Icons.recycling,
          ),
          _buildGuideCard(
            'Payment and Earnings',
            'How to track and withdraw your earnings',
            Icons.monetization_on,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeedbackOptions(),
          const SizedBox(height: 24),
          _buildReportProblemForm(),
          const SizedBox(height: 24),
          _buildAppRating(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search FAQs...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (value) {
          setState(() {}); // Trigger rebuild for search
        },
      ),
    );
  }

  Widget _buildCategoriesFilter() {
    final categories = [
      'All',
      'General',
      'Tasks',
      'Payments',
      'Routes',
      'Collections',
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected =
              _selectedCategory == category ||
              (_selectedCategory == 'General' && category == 'All');

          return Padding(
            padding: EdgeInsets.only(
              right: index < categories.length - 1 ? 8 : 0,
            ),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category == 'All' ? 'General' : category;
                });
              },
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[700],
            ),
          );
        },
      ),
    );
  }

  List<FAQItem> _getFilteredFAQs() {
    var filteredFAQs = _faqs;

    // Filter by category
    if (_selectedCategory != 'General') {
      filteredFAQs = filteredFAQs
          .where((faq) => faq.category == _selectedCategory)
          .toList();
    }

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filteredFAQs = filteredFAQs
          .where(
            (faq) =>
                faq.question.toLowerCase().contains(query) ||
                faq.answer.toLowerCase().contains(query),
          )
          .toList();
    }

    return filteredFAQs;
  }

  Widget _buildFAQItem(FAQItem faq) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              faq.answer,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Get in Touch',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildContactMethod(
                'Call Us',
                '+63 2 8123 4567',
                Icons.phone,
                Colors.green,
                () => _makePhoneCall(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildContactMethod(
                'Email Us',
                'support@EcoKuha.com',
                Icons.email,
                Colors.blue,
                () => _sendEmail(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildContactMethod(
                'Live Chat',
                'Available 24/7',
                Icons.chat,
                Colors.orange,
                () => _startLiveChat(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildContactMethod(
                'WhatsApp',
                '+63 917 123 4567',
                Icons.message,
                Colors.green[600]!,
                () => _openWhatsApp(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactMethod(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send us a Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: ['General', 'Tasks', 'Payments', 'Technical', 'Account']
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Describe your question or issue...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Send Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportHours() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Support Hours',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSupportHourItem(
              'Phone Support',
              '8:00 AM - 6:00 PM (Mon-Fri)',
            ),
            _buildSupportHourItem('Live Chat', '24/7 Available'),
            _buildSupportHourItem('Email Response', 'Within 24 hours'),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportHourItem(String service, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(service, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(hours, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(
    String title,
    String description,
    String duration,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.play_arrow),
        onTap: () {
          // Play tutorial video
        },
      ),
    );
  }

  Widget _buildGuideCard(String title, String description, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[700]),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Open guide
        },
      ),
    );
  }

  Widget _buildFeedbackOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'We Value Your Feedback',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeedbackOption(
                'Suggest Feature',
                'Share your ideas',
                Icons.lightbulb,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeedbackOption(
                'Report Bug',
                'Help us improve',
                Icons.bug_report,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Handle feedback option
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportProblemForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report a Problem',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _problemType,
              decoration: const InputDecoration(
                labelText: 'Problem Type',
                border: OutlineInputBorder(),
              ),
              items:
                  [
                        'Technical Issue',
                        'Payment Problem',
                        'Task Assignment',
                        'App Performance',
                        'Other',
                      ]
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() => _problemType = value!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Describe the Problem',
                hintText: 'Please provide details about the issue...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.attach_file, color: Colors.grey[600]),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // Attach screenshot or file
                  },
                  child: const Text('Attach Screenshot'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Submit problem report
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Problem report submitted successfully!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppRating() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate Our App',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help us improve by rating your experience',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => IconButton(
                  onPressed: () {
                    // Handle rating
                  },
                  icon: const Icon(Icons.star_border, size: 32),
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Open app store
                },
                child: const Text('Rate on App Store'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  void _makePhoneCall() {
    // Handle phone call
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening phone dialer...')));
  }

  void _sendEmail() {
    // Handle email
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening email client...')));
  }

  void _startLiveChat() {
    // Handle live chat
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Starting live chat...')));
  }

  void _openWhatsApp() {
    // Handle WhatsApp
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening WhatsApp...')));
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message sent successfully!')));
    _messageController.clear();
  }
}

class FAQItem {
  final String question;
  final String answer;
  final String category;

  FAQItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}
