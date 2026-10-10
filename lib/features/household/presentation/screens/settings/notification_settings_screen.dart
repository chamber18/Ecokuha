import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Push Notifications
  bool _pushNotificationsEnabled = true;

  // Collection Notifications
  bool _collectionUpdates = true;
  bool _collectorArrival = true;
  bool _collectionComplete = true;
  bool _paymentConfirmation = true;

  // Marketing & Promotions
  bool _promotionalOffers = false;
  bool _recyclingTips = true;
  bool _newFeatures = true;
  bool _monthlyNewsletter = false;

  // System Notifications
  bool _securityAlerts = true;
  bool _accountUpdates = true;
  bool _systemMaintenance = false;

  // Notification Timing
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';
  bool _quietHoursEnabled = false;

  // Notification Channels
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _inAppNotifications = true;

  // Sound & Vibration
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _selectedSound = 'Default';

  final List<String> _soundOptions = [
    'Default',
    'Chime',
    'Bell',
    'Ding',
    'Silent',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                children: [
                  _buildMasterToggleSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildCollectionNotificationsSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildMarketingSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildSystemNotificationsSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildChannelsSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildTimingSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildSoundVibratonSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildQuickActionsSection(),
                  const SizedBox(height: AppDimensions.spacing32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.purple.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios),
              color: AppColors.textWhite,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Notification Settings',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage how you receive notifications',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.restore),
              color: AppColors.textWhite,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterToggleSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _pushNotificationsEnabled
              ? AppColors.primaryGreen.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _pushNotificationsEnabled
                      ? AppColors.primaryGreen.withValues(alpha: 0.1)
                      : AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications,
                  color: _pushNotificationsEnabled
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notifications',
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pushNotificationsEnabled
                          ? 'You\'ll receive notifications about collections and updates'
                          : 'You won\'t receive any push notifications',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pushNotificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _pushNotificationsEnabled = value;
                    if (!value) {
                      _disableAllNotifications();
                    }
                  });
                },
                activeColor: AppColors.primaryGreen,
              ),
            ],
          ),

          if (!_pushNotificationsEnabled) ...[
            const SizedBox(height: AppDimensions.spacing16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You may miss important collection updates',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionNotificationsSection() {
    return _buildSection(
      title: 'Collection Updates',
      icon: Icons.local_shipping,
      iconColor: AppColors.primaryGreen,
      enabled: _pushNotificationsEnabled,
      children: [
        _buildNotificationTile(
          title: 'Collection Updates',
          subtitle: 'Status changes for your waste collections',
          value: _collectionUpdates,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _collectionUpdates = value;
                  });
                }
              : null,
        ),

        _buildNotificationTile(
          title: 'Collector Arrival',
          subtitle: 'When collector is nearby or has arrived',
          value: _collectorArrival,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _collectorArrival = value;
                  });
                }
              : null,
        ),

        _buildNotificationTile(
          title: 'Collection Complete',
          subtitle: 'When your waste has been collected',
          value: _collectionComplete,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _collectionComplete = value;
                  });
                }
              : null,
        ),

        _buildNotificationTile(
          title: 'Payment Confirmation',
          subtitle: 'When payment has been processed',
          value: _paymentConfirmation,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _paymentConfirmation = value;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildMarketingSection() {
    return _buildSection(
      title: 'Marketing & Tips',
      icon: Icons.campaign,
      iconColor: AppColors.primaryBlue,
      enabled: _pushNotificationsEnabled,
      children: [
        _buildNotificationTile(
          title: 'Promotional Offers',
          subtitle: 'Special deals and bonuses',
          value: _promotionalOffers,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _promotionalOffers = value;
                  });
                }
              : null,
        ),

        _buildNotificationTile(
          title: 'Recycling Tips',
          subtitle: 'Learn better recycling practices',
          value: _recyclingTips,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _recyclingTips = value;
                  });
                }
              : null,
        ),

        _buildNotificationTile(
          title: 'New Features',
          subtitle: 'Updates about new app features',
          value: _newFeatures,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _newFeatures = value;
                  });
                }
              : null,
        ),

        _buildNotificationTile(
          title: 'Monthly Newsletter',
          subtitle: 'Monthly recycling statistics and news',
          value: _monthlyNewsletter,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _monthlyNewsletter = value;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildSystemNotificationsSection() {
    return _buildSection(
      title: 'System & Security',
      icon: Icons.security,
      iconColor: Colors.orange,
      enabled: true, // System notifications are always available
      children: [
        _buildNotificationTile(
          title: 'Security Alerts',
          subtitle: 'Important security notifications',
          value: _securityAlerts,
          onChanged: (value) {
            setState(() {
              _securityAlerts = value;
            });
          },
        ),

        _buildNotificationTile(
          title: 'Account Updates',
          subtitle: 'Changes to your account information',
          value: _accountUpdates,
          onChanged: (value) {
            setState(() {
              _accountUpdates = value;
            });
          },
        ),

        _buildNotificationTile(
          title: 'System Maintenance',
          subtitle: 'Scheduled maintenance notifications',
          value: _systemMaintenance,
          onChanged: (value) {
            setState(() {
              _systemMaintenance = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildChannelsSection() {
    return _buildSection(
      title: 'Notification Channels',
      icon: Icons.send,
      iconColor: Colors.purple,
      enabled: true,
      children: [
        _buildNotificationTile(
          title: 'Push Notifications',
          subtitle: 'Notifications in the app',
          value: _inAppNotifications,
          onChanged: (value) {
            setState(() {
              _inAppNotifications = value;
            });
          },
        ),

        _buildNotificationTile(
          title: 'Email Notifications',
          subtitle: 'Receive notifications via email',
          value: _emailNotifications,
          onChanged: (value) {
            setState(() {
              _emailNotifications = value;
            });
          },
        ),

        _buildNotificationTile(
          title: 'SMS Notifications',
          subtitle: 'Important updates via text message',
          value: _smsNotifications,
          onChanged: (value) {
            setState(() {
              _smsNotifications = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTimingSection() {
    return _buildSection(
      title: 'Timing & Schedule',
      icon: Icons.access_time,
      iconColor: Colors.indigo,
      enabled: _pushNotificationsEnabled,
      children: [
        _buildNotificationTile(
          title: 'Quiet Hours',
          subtitle: _quietHoursEnabled
              ? 'No notifications from $_quietHoursStart to $_quietHoursEnd'
              : 'Receive notifications at any time',
          value: _quietHoursEnabled,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _quietHoursEnabled = value;
                  });
                  if (value) {
                    _showQuietHoursDialog();
                  }
                }
              : null,
        ),

        if (_quietHoursEnabled) ...[
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    InkWell(
                      onTap: () => _selectQuietTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _quietHoursStart,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End Time',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    InkWell(
                      onTap: () => _selectQuietTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _quietHoursEnd,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSoundVibratonSection() {
    return _buildSection(
      title: 'Sound & Vibration',
      icon: Icons.volume_up,
      iconColor: Colors.teal,
      enabled: _pushNotificationsEnabled,
      children: [
        _buildNotificationTile(
          title: 'Sound',
          subtitle: 'Play sound for notifications',
          value: _soundEnabled,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _soundEnabled = value;
                  });
                }
              : null,
        ),

        if (_soundEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 16),
            child: Row(
              children: [
                Text(
                  'Notification Sound: ',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedSound,
                  onChanged: (value) {
                    setState(() {
                      _selectedSound = value!;
                    });
                  },
                  underline: const SizedBox(),
                  items: _soundOptions
                      .map(
                        (sound) => DropdownMenuItem(
                          value: sound,
                          child: Text(
                            sound,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _playTestSound,
                  icon: const Icon(Icons.play_arrow),
                  color: AppColors.primaryGreen,
                  iconSize: 20,
                ),
              ],
            ),
          ),

        _buildNotificationTile(
          title: 'Vibration',
          subtitle: 'Vibrate for notifications',
          value: _vibrationEnabled,
          onChanged: _pushNotificationsEnabled
              ? (value) {
                  setState(() {
                    _vibrationEnabled = value;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Enable All',
                  Icons.notifications_active,
                  AppColors.primaryGreen,
                  _enableAllNotifications,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Disable All',
                  Icons.notifications_off,
                  Colors.orange,
                  _disableAllNotifications,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing12),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Reset Defaults',
                  Icons.restore,
                  AppColors.primaryBlue,
                  _resetToDefaults,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Test Notification',
                  Icons.send,
                  Colors.purple,
                  _sendTestNotification,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool enabled,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: enabled
                  ? iconColor.withValues(alpha: 0.05)
                  : AppColors.backgroundDark.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusMd),
                topRight: Radius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: enabled
                        ? iconColor.withValues(alpha: 0.1)
                        : AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? iconColor : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.h6.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          ...children.map(
            (child) => Column(
              children: [
                child,
                if (child != children.last)
                  Divider(
                    height: 1,
                    color: AppColors.borderLight,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    final enabled = onChanged != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacing12,
          horizontal: AppDimensions.spacing8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _disableAllNotifications() {
    setState(() {
      _collectionUpdates = false;
      _collectorArrival = false;
      _collectionComplete = false;
      _paymentConfirmation = false;
      _promotionalOffers = false;
      _recyclingTips = false;
      _newFeatures = false;
      _monthlyNewsletter = false;
    });
  }

  void _enableAllNotifications() {
    setState(() {
      _pushNotificationsEnabled = true;
      _collectionUpdates = true;
      _collectorArrival = true;
      _collectionComplete = true;
      _paymentConfirmation = true;
      _recyclingTips = true;
      _newFeatures = true;
      _securityAlerts = true;
      _accountUpdates = true;
      _inAppNotifications = true;
      _emailNotifications = true;
      _soundEnabled = true;
      _vibrationEnabled = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications enabled'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _pushNotificationsEnabled = true;
      _collectionUpdates = true;
      _collectorArrival = true;
      _collectionComplete = true;
      _paymentConfirmation = true;
      _promotionalOffers = false;
      _recyclingTips = true;
      _newFeatures = true;
      _monthlyNewsletter = false;
      _securityAlerts = true;
      _accountUpdates = true;
      _systemMaintenance = false;
      _quietHoursEnabled = false;
      _emailNotifications = true;
      _smsNotifications = false;
      _inAppNotifications = true;
      _soundEnabled = true;
      _vibrationEnabled = true;
      _selectedSound = 'Default';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to defaults'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showQuietHoursDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quiet Hours'),
        content: Text(
          'During quiet hours ($_quietHoursStart - $_quietHoursEnd), you won\'t receive most notifications except for urgent security alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _quietHoursEnabled = false;
              });
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectQuietTime(bool isStartTime) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isStartTime ? 22 : 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.purple),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        final timeString =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        if (isStartTime) {
          _quietHoursStart = timeString;
        } else {
          _quietHoursEnd = timeString;
        }
      });
    }
  }

  void _playTestSound() {
    // Implement sound test
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing $_selectedSound sound...'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _sendTestNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 Test notification sent successfully!'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
