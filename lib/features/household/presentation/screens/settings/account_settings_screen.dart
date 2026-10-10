import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _biometricEnabled = true;
  bool _twoFactorEnabled = false;
  bool _autoBackup = true;
  bool _analyticsEnabled = false;
  String _selectedTheme = 'System';
  String _dataRetention = '1 Year';

  final List<String> _themeOptions = ['System', 'Light', 'Dark'];

  final List<String> _retentionOptions = [
    '6 Months',
    '1 Year',
    '2 Years',
    'Forever',
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
                  _buildSecuritySection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildPrivacySection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildAppearanceSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildDataSection(),
                  const SizedBox(height: AppDimensions.spacing20),
                  _buildAdvancedSection(),
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
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryBlue.withValues(alpha: 0.8),
          ],
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
                    'Account Settings',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your account security and preferences',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _buildSection(
      title: 'Security',
      icon: Icons.security,
      iconColor: AppColors.primaryBlue,
      children: [
        _buildSettingsTile(
          title: 'Change Password',
          subtitle: 'Update your account password',
          leading: Icons.lock_outline,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showChangePasswordDialog,
        ),

        _buildSwitchTile(
          title: 'Biometric Authentication',
          subtitle: 'Use fingerprint or face recognition',
          leading: Icons.fingerprint,
          value: _biometricEnabled,
          onChanged: (value) {
            setState(() {
              _biometricEnabled = value;
            });
            _showBiometricSetup();
          },
        ),

        _buildSwitchTile(
          title: 'Two-Factor Authentication',
          subtitle: 'Extra security for your account',
          leading: Icons.security,
          value: _twoFactorEnabled,
          onChanged: (value) {
            setState(() {
              _twoFactorEnabled = value;
            });
            if (value) {
              _showTwoFactorSetup();
            }
          },
        ),

        _buildSettingsTile(
          title: 'Login Activity',
          subtitle: 'View recent login attempts',
          leading: Icons.history,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showLoginActivity,
        ),

        _buildSettingsTile(
          title: 'Active Sessions',
          subtitle: 'Manage device sessions',
          leading: Icons.devices,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '2 active',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: _showActiveSessions,
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _buildSection(
      title: 'Privacy',
      icon: Icons.privacy_tip,
      iconColor: AppColors.primaryGreen,
      children: [
        _buildSwitchTile(
          title: 'Analytics & Diagnostics',
          subtitle: 'Help improve the app with usage data',
          leading: Icons.analytics,
          value: _analyticsEnabled,
          onChanged: (value) {
            setState(() {
              _analyticsEnabled = value;
            });
          },
        ),

        _buildSettingsTile(
          title: 'Data Download',
          subtitle: 'Download a copy of your data',
          leading: Icons.download,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showDataDownloadDialog,
        ),

        _buildSettingsTile(
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          leading: Icons.policy,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _openPrivacyPolicy,
        ),

        _buildSettingsTile(
          title: 'Terms of Service',
          subtitle: 'Read our terms of service',
          leading: Icons.description,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _openTermsOfService,
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _buildSection(
      title: 'Appearance',
      icon: Icons.palette,
      iconColor: Colors.purple,
      children: [
        _buildDropdownTile(
          title: 'Theme',
          subtitle: 'Choose your preferred theme',
          leading: Icons.brightness_6,
          value: _selectedTheme,
          items: _themeOptions,
          onChanged: (value) {
            setState(() {
              _selectedTheme = value!;
            });
            _applyTheme(value!);
          },
        ),

        _buildSettingsTile(
          title: 'Font Size',
          subtitle: 'Adjust text size for readability',
          leading: Icons.text_fields,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Default',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: _showFontSizeSettings,
        ),

        _buildSettingsTile(
          title: 'Language & Region',
          subtitle: 'Change your preferred language',
          leading: Icons.language,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'English',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: _showLanguageSettings,
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return _buildSection(
      title: 'Data Management',
      icon: Icons.storage,
      iconColor: Colors.orange,
      children: [
        _buildSwitchTile(
          title: 'Automatic Backup',
          subtitle: 'Backup data to cloud storage',
          leading: Icons.cloud_upload,
          value: _autoBackup,
          onChanged: (value) {
            setState(() {
              _autoBackup = value;
            });
            if (value) {
              _showBackupDialog();
            }
          },
        ),

        _buildDropdownTile(
          title: 'Data Retention',
          subtitle: 'How long to keep your data',
          leading: Icons.schedule,
          value: _dataRetention,
          items: _retentionOptions,
          onChanged: (value) {
            setState(() {
              _dataRetention = value!;
            });
          },
        ),

        _buildSettingsTile(
          title: 'Clear Cache',
          subtitle: 'Free up storage space',
          leading: Icons.delete_sweep,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '24.5 MB',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: _showClearCacheDialog,
        ),

        _buildSettingsTile(
          title: 'Storage Usage',
          subtitle: 'View detailed storage information',
          leading: Icons.folder,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showStorageUsage,
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return _buildSection(
      title: 'Advanced',
      icon: Icons.settings_applications,
      iconColor: Colors.red,
      children: [
        _buildSettingsTile(
          title: 'Developer Options',
          subtitle: 'Advanced debugging features',
          leading: Icons.code,
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showDeveloperOptions,
        ),

        _buildSettingsTile(
          title: 'App Version',
          subtitle: 'Check for updates',
          leading: Icons.info_outline,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'v1.0.0',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: _checkForUpdates,
        ),

        const SizedBox(height: AppDimensions.spacing20),

        // Danger Zone
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: AppColors.errorColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: AppColors.errorColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: AppColors.errorColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Danger Zone',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing12),

              _buildDangerTile(
                title: 'Delete All Data',
                subtitle: 'Permanently delete all your data',
                onTap: _showDeleteDataDialog,
              ),

              const SizedBox(height: AppDimensions.spacing8),

              _buildDangerTile(
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: _showDeleteAccountDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData leading,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(leading, color: AppColors.textSecondary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData leading,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(leading, color: AppColors.textSecondary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required IconData leading,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return ListTile(
      leading: Icon(leading, color: AppColors.textSecondary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            underline: const SizedBox(),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                      color: AppColors.errorColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.errorColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.errorColor,
            ),
          ],
        ),
      ),
    );
  }

  // Dialog Methods
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _changePassword,
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete All Data',
          style: TextStyle(color: AppColors.errorColor),
        ),
        content: const Text(
          'This will permanently delete all your data including transaction history, preferences, and profile information. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllData();
            },
            child: Text(
              'Delete All Data',
              style: TextStyle(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: AppColors.errorColor),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. You will not be able to recover your account or data after deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: Text(
              'Delete Account',
              style: TextStyle(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear temporary files and cached data to free up storage space. Your personal data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  // Action Methods
  void _changePassword() {
    // Implement password change logic
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password changed successfully'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _showBiometricSetup() {
    if (_biometricEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication enabled'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  void _showTwoFactorSetup() {
    // Navigate to two-factor setup screen or show dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Two-factor authentication setup coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showLoginActivity() {
    // Show login activity screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login activity feature coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showActiveSessions() {
    // Show active sessions screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Active sessions management coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showDataDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Data'),
        content: const Text(
          'We\'ll prepare a copy of your data and send it to your registered email address. This may take a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateDataDownload();
            },
            child: const Text('Request Download'),
          ),
        ],
      ),
    );
  }

  void _initiateDataDownload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data download request submitted. Check your email.'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _openPrivacyPolicy() {
    // Open privacy policy URL or screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening privacy policy...'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _openTermsOfService() {
    // Open terms of service URL or screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening terms of service...'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _applyTheme(String theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Theme changed to $theme'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _showFontSizeSettings() {
    // Show font size adjustment screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Font size settings coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showLanguageSettings() {
    // Show language selection screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Language settings coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showBackupDialog() {
    if (_autoBackup) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Backup'),
          content: const Text(
            'Your data will be automatically backed up to secure cloud storage. You can restore your data if you switch devices.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _autoBackup = false;
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Automatic backup enabled'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      );
    }
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared successfully'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _showStorageUsage() {
    // Show detailed storage usage screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Storage usage details coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showDeveloperOptions() {
    // Show developer options screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Developer options coming soon'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _checkForUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are using the latest version'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _deleteAllData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All data has been deleted'),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }

  void _deleteAccount() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Account deletion initiated'),
        backgroundColor: AppColors.errorColor,
      ),
    );
    // Navigate back to login
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
