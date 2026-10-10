import 'package:flutter/material.dart';

class CollectorSettingsScreen extends StatefulWidget {
  const CollectorSettingsScreen({super.key});

  @override
  State<CollectorSettingsScreen> createState() =>
      _CollectorSettingsScreenState();
}

class _CollectorSettingsScreenState extends State<CollectorSettingsScreen> {
  // Availability Settings
  bool _isAvailable = true;
  TimeOfDay _workStartTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _workEndTime = const TimeOfDay(hour: 18, minute: 0);
  final List<String> _workDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  // Notification Settings
  bool _newTaskNotifications = true;
  bool _messageNotifications = true;
  bool _paymentNotifications = true;
  bool _routeOptimizationNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // App Preferences
  String _language = 'English';
  String _theme = 'System';
  bool _offlineMode = false;
  bool _autoBackup = true;

  // Privacy Settings
  bool _locationSharing = true;
  bool _profileVisibility = true;
  bool _dataAnalytics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAvailabilitySection(),
          const SizedBox(height: 16),
          _buildNotificationSection(),
          const SizedBox(height: 16),
          _buildAppPreferencesSection(),
          const SizedBox(height: 16),
          _buildPrivacySection(),
          const SizedBox(height: 16),
          _buildAccountSection(),
          const SizedBox(height: 16),
          _buildSupportSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return _buildSettingsCard('Work Availability', Icons.work, [
      _buildSwitchTile(
        'Available for Collections',
        'Toggle your work availability',
        _isAvailable,
        (value) => setState(() => _isAvailable = value),
      ),
      _buildTile(
        'Working Hours',
        '${_workStartTime.format(context)} - ${_workEndTime.format(context)}',
        Icons.schedule,
        onTap: () => _showWorkingHoursPicker(),
      ),
      _buildTile(
        'Work Days',
        '${_workDays.length} days selected',
        Icons.calendar_today,
        onTap: () => _showWorkDaysPicker(),
      ),
      _buildTile(
        'Service Areas',
        'Metro Manila, Quezon City',
        Icons.location_on,
        onTap: () => _showServiceAreasPicker(),
      ),
    ]);
  }

  Widget _buildNotificationSection() {
    return _buildSettingsCard('Notifications', Icons.notifications, [
      _buildSwitchTile(
        'New Task Notifications',
        'Get notified when new collection tasks are available',
        _newTaskNotifications,
        (value) => setState(() => _newTaskNotifications = value),
      ),
      _buildSwitchTile(
        'Message Notifications',
        'Notifications for new messages from customers',
        _messageNotifications,
        (value) => setState(() => _messageNotifications = value),
      ),
      _buildSwitchTile(
        'Payment Notifications',
        'Notifications for payment confirmations and earnings',
        _paymentNotifications,
        (value) => setState(() => _paymentNotifications = value),
      ),
      _buildSwitchTile(
        'Route Optimization',
        'Notifications for route updates and optimizations',
        _routeOptimizationNotifications,
        (value) => setState(() => _routeOptimizationNotifications = value),
      ),
      const Divider(height: 24),
      _buildSwitchTile(
        'Sound',
        'Play notification sounds',
        _soundEnabled,
        (value) => setState(() => _soundEnabled = value),
      ),
      _buildSwitchTile(
        'Vibration',
        'Vibrate for notifications',
        _vibrationEnabled,
        (value) => setState(() => _vibrationEnabled = value),
      ),
      _buildTile(
        'Notification Schedule',
        'Quiet hours: 10:00 PM - 6:00 AM',
        Icons.nightlight_round,
        onTap: () => _showNotificationSchedule(),
      ),
    ]);
  }

  Widget _buildAppPreferencesSection() {
    return _buildSettingsCard('App Preferences', Icons.settings, [
      _buildTile(
        'Language',
        _language,
        Icons.language,
        onTap: () => _showLanguagePicker(),
      ),
      _buildTile(
        'Theme',
        _theme,
        Icons.palette,
        onTap: () => _showThemePicker(),
      ),
      _buildSwitchTile(
        'Offline Mode',
        'Allow app to work when internet is poor',
        _offlineMode,
        (value) => setState(() => _offlineMode = value),
      ),
      _buildSwitchTile(
        'Auto Backup',
        'Automatically backup your data',
        _autoBackup,
        (value) => setState(() => _autoBackup = value),
      ),
      _buildTile(
        'Storage Usage',
        '1.2 GB used',
        Icons.storage,
        onTap: () => _showStorageManager(),
      ),
    ]);
  }

  Widget _buildPrivacySection() {
    return _buildSettingsCard('Privacy & Data', Icons.privacy_tip, [
      _buildSwitchTile(
        'Location Sharing',
        'Share your location for route optimization',
        _locationSharing,
        (value) => setState(() => _locationSharing = value),
      ),
      _buildSwitchTile(
        'Profile Visibility',
        'Allow customers to see your profile and ratings',
        _profileVisibility,
        (value) => setState(() => _profileVisibility = value),
      ),
      _buildSwitchTile(
        'Data Analytics',
        'Help improve the app by sharing usage data',
        _dataAnalytics,
        (value) => setState(() => _dataAnalytics = value),
      ),
      _buildTile(
        'Data Export',
        'Download your personal data',
        Icons.download,
        onTap: () => _exportData(),
      ),
      _buildTile(
        'Privacy Policy',
        'Read our privacy policy',
        Icons.policy,
        onTap: () => _showPrivacyPolicy(),
      ),
    ]);
  }

  Widget _buildAccountSection() {
    return _buildSettingsCard('Account Management', Icons.account_circle, [
      _buildTile(
        'Edit Profile',
        'Update your personal information',
        Icons.edit,
        onTap: () => _editProfile(),
      ),
      _buildTile(
        'Change Password',
        'Update your account password',
        Icons.lock,
        onTap: () => _changePassword(),
      ),
      _buildTile(
        'Two-Factor Authentication',
        'Add extra security to your account',
        Icons.security,
        onTap: () => _setup2FA(),
      ),
      _buildTile(
        'Connected Accounts',
        'Manage linked social media accounts',
        Icons.link,
        onTap: () => _manageConnectedAccounts(),
      ),
      _buildTile(
        'Bank Account',
        'Update payment and banking information',
        Icons.account_balance,
        onTap: () => _manageBankAccount(),
      ),
    ]);
  }

  Widget _buildSupportSection() {
    return Column(
      children: [
        _buildSettingsCard('Help & Support', Icons.help, [
          _buildTile(
            'Help Center',
            'Find answers to common questions',
            Icons.help_center,
            onTap: () => _showHelpCenter(),
          ),
          _buildTile(
            'Contact Support',
            'Get in touch with our support team',
            Icons.support_agent,
            onTap: () => _contactSupport(),
          ),
          _buildTile(
            'Report a Problem',
            'Let us know if you encounter any issues',
            Icons.report_problem,
            onTap: () => _reportProblem(),
          ),
          _buildTile(
            'App Tutorial',
            'Learn how to use the collector app',
            Icons.school,
            onTap: () => _showTutorial(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildDangerZone(),
      ],
    );
  }

  Widget _buildDangerZone() {
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
                Icon(Icons.warning, color: Colors.red[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTile(
              'Deactivate Account',
              'Temporarily disable your collector account',
              Icons.pause_circle,
              onTap: () => _deactivateAccount(),
              textColor: Colors.orange[700],
            ),
            _buildTile(
              'Delete Account',
              'Permanently delete your account and data',
              Icons.delete_forever,
              onTap: () => _deleteAccount(),
              textColor: Colors.red[700],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
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
                Icon(icon, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green[700],
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  // Helper methods for showing dialogs and pickers
  void _showWorkingHoursPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Working Hours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_workStartTime.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _workStartTime,
                );
                if (time != null) {
                  setState(() => _workStartTime = time);
                }
              },
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(_workEndTime.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _workEndTime,
                );
                if (time != null) {
                  setState(() => _workEndTime = time);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showWorkDaysPicker() {
    final allDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Work Days'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: allDays
                .map(
                  (day) => CheckboxListTile(
                    title: Text(day),
                    value: _workDays.contains(day),
                    onChanged: (checked) {
                      setState(() {
                        if (checked!) {
                          _workDays.add(day);
                        } else {
                          _workDays.remove(day);
                        }
                      });
                    },
                    activeColor: Colors.green[700],
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showServiceAreasPicker() {
    // Show service areas selection dialog
  }

  void _showNotificationSchedule() {
    // Show quiet hours picker
  }

  void _showLanguagePicker() {
    final languages = ['English', 'Filipino', 'Español'];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: languages
            .map(
              (lang) => SimpleDialogOption(
                onPressed: () {
                  setState(() => _language = lang);
                  Navigator.pop(context);
                },
                child: Text(lang),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showThemePicker() {
    final themes = ['System', 'Light', 'Dark'];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme'),
        children: themes
            .map(
              (theme) => SimpleDialogOption(
                onPressed: () {
                  setState(() => _theme = theme);
                  Navigator.pop(context);
                },
                child: Text(theme),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showStorageManager() {
    // Show storage usage and cleanup options
  }

  void _exportData() {
    // Handle data export
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Data export started...')));
  }

  void _showPrivacyPolicy() {
    // Show privacy policy
  }

  void _editProfile() {
    // Navigate to profile editing
  }

  void _changePassword() {
    // Show change password dialog
  }

  void _setup2FA() {
    // Setup two-factor authentication
  }

  void _manageConnectedAccounts() {
    // Manage social media connections
  }

  void _manageBankAccount() {
    // Manage banking information
  }

  void _showHelpCenter() {
    // Navigate to help center
  }

  void _contactSupport() {
    // Show support contact options
  }

  void _reportProblem() {
    // Show problem reporting form
  }

  void _showTutorial() {
    // Start app tutorial
  }

  void _deactivateAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Account'),
        content: const Text(
          'Are you sure you want to deactivate your collector account? '
          'You can reactivate it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle account deactivation
            },
            child: Text(
              'Deactivate',
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? '
          'This action cannot be undone and all your data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle account deletion
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }
}
