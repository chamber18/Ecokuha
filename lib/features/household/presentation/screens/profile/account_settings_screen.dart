import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../authentication/presentation/widgets/address_map_card.dart';
import '../../../../../../core/constants/firestore_fields/index.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/utils/phone_number_formatter.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../shared/utils/address_formatter.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  // Google Geocoding API Key - loaded from environment
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Editing flags
  bool _editPersonal = false;
  bool _editAddress = false;
  bool _editAccount = false;
  bool _isGoogleUser = false;

  // Controllers - will be populated from Firebase
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController(); // Address note
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Location state (Primary Address)
  double? _latitude;
  double? _longitude;
  String? _geoAddress;

  // Second Address state
  final _address2Ctrl = TextEditingController();
  final _note2Ctrl = TextEditingController();
  double? _latitude2;
  double? _longitude2;
  String? _geoAddress2;
  bool _hasSecondAddress = false;

  // Original values from Firestore (for cancel/restore)
  String _originalName = '';
  String _originalEmail = '';
  String _originalPhone = '';
  String _originalAddress = '';
  String _originalNote = '';
  double? _originalLatitude;
  double? _originalLongitude;
  String? _originalGeoAddress;

  // Original values for second address
  String _originalAddress2 = '';
  String _originalNote2 = '';
  double? _originalLatitude2;
  double? _originalLongitude2;
  String? _originalGeoAddress2;
  bool _originalHasSecondAddress = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _address2Ctrl.dispose();
    _note2Ctrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ProfileBloc>()..add(const LoadProfileEvent()),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: const Text('Account'),
          backgroundColor: AppColors.householdPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.message}',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                          const RefreshProfileEvent(),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else if (state is ProfileLoaded) {
              // Populate controllers with real data when loaded
              if (_nameCtrl.text.isEmpty) {
                _nameCtrl.text = state.profileData[UserFields.fullName] ?? '';
                _emailCtrl.text = state.profileData[UserFields.email] ?? '';
                _phoneCtrl.text = formatPhoneNumber(
                  state.profileData[UserFields.phone],
                );

                // Check if user signed in with Google
                _isGoogleUser =
                    state.profileData['signInProvider'] == 'google.com';
                debugPrint(
                  '🔐 Household Account Settings: signInProvider=${state.profileData['signInProvider']}, _isGoogleUser=$_isGoogleUser',
                );

                // Save original values for restore on cancel
                _originalName = _nameCtrl.text;
                _originalEmail = _emailCtrl.text;
                _originalPhone = _phoneCtrl.text;

                // Initialize coordinates and address from saved profile.location if available
                final loc = state.profileData[UserFields.location];
                if (loc is Map<String, dynamic>) {
                  final lat = loc[UserFields.lat];
                  final lng = loc[UserFields.lng];
                  if (lat is num && lng is num) {
                    _latitude = lat.toDouble();
                    _longitude = lng.toDouble();
                    _originalLatitude = _latitude;
                    _originalLongitude = _longitude;
                  }
                  if (loc[UserFields.address] is String) {
                    final addr = (loc[UserFields.address] as String).trim();
                    if (addr.isNotEmpty) {
                      _addressCtrl.text = addr;
                      _originalAddress = addr;
                    }
                  }
                  // Load address note from location.note
                  if (loc[UserFields.note] is String) {
                    final note = (loc[UserFields.note] as String).trim();
                    _noteCtrl.text = note;
                    _originalNote = note;
                  }
                }

                // Load second address from location_2
                final loc2 = state.profileData[UserFields.location2];
                if (loc2 is Map<String, dynamic>) {
                  _hasSecondAddress = true;
                  _originalHasSecondAddress = true;

                  final lat2 = loc2['lat'];
                  final lng2 = loc2['lng'];
                  if (lat2 is num && lng2 is num) {
                    _latitude2 = lat2.toDouble();
                    _longitude2 = lng2.toDouble();
                    _originalLatitude2 = _latitude2;
                    _originalLongitude2 = _longitude2;
                  }
                  if (loc2['address'] is String) {
                    final addr2 = (loc2['address'] as String).trim();
                    if (addr2.isNotEmpty) {
                      _address2Ctrl.text = addr2;
                      _originalAddress2 = addr2;
                    }
                  }
                  if (loc2['note'] is String) {
                    final note2 = (loc2['note'] as String).trim();
                    _note2Ctrl.text = note2;
                    _originalNote2 = note2;
                  }
                }
              }
              return _buildContent(context);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Personal Information',
            _editPersonal,
            onEdit: () {
              setState(() => _editPersonal = !_editPersonal);
              if (!_editPersonal) _savePersonal(context);
            },
            onCancel: _editPersonal
                ? () {
                    // Restore original values
                    _nameCtrl.text = _originalName;
                    _emailCtrl.text = _originalEmail;
                    _phoneCtrl.text = _originalPhone;
                    setState(() => _editPersonal = false);
                  }
                : null,
          ),
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editPersonal) ...[
                  _textFieldRow(Icons.person, 'Full Name', _nameCtrl),
                  if (_isGoogleUser) ...[
                    // Show read-only email for Google users
                    _infoRow(Icons.email, 'Email', _emailCtrl.text),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 40,
                        top: 4,
                        bottom: 12,
                      ),
                      child: Text(
                        'Email managed by Google account',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ] else ...[
                    _textFieldRow(
                      Icons.email,
                      'Email',
                      _emailCtrl,
                      keyboard: TextInputType.emailAddress,
                    ),
                  ],
                  _textFieldRow(
                    Icons.phone,
                    'Phone',
                    _phoneCtrl,
                    keyboard: TextInputType.phone,
                    formatters: [PhoneNumberFormatter()],
                  ),
                ] else ...[
                  _infoRow(Icons.person, 'Full Name', _nameCtrl.text),
                  _infoRow(Icons.email, 'Email', _emailCtrl.text),
                  _infoRow(Icons.phone, 'Phone', _phoneCtrl.text),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          _sectionHeader(
            'Address',
            _editAddress,
            onEdit: () {
              setState(() => _editAddress = !_editAddress);
              if (!_editAddress) _saveAddress(context);
            },
            onCancel: _editAddress
                ? () {
                    // Restore original address values
                    _addressCtrl.text = _originalAddress;
                    _noteCtrl.text = _originalNote;
                    _latitude = _originalLatitude;
                    _longitude = _originalLongitude;
                    _geoAddress = _originalGeoAddress;

                    // Restore second address values
                    _address2Ctrl.text = _originalAddress2;
                    _note2Ctrl.text = _originalNote2;
                    _latitude2 = _originalLatitude2;
                    _longitude2 = _originalLongitude2;
                    _geoAddress2 = _originalGeoAddress2;
                    _hasSecondAddress = _originalHasSecondAddress;

                    setState(() => _editAddress = false);
                  }
                : null,
          ),
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editAddress) ...[
                  // Primary Address
                  Text(
                    'Primary Address',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AddressMapCard(
                    latitude: _latitude,
                    longitude: _longitude,
                    controller: _addressCtrl,
                    onChangeLocation: _chooseLocationOnMap,
                    onUseCurrentLocation: _useCurrentLocation,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  // Location Note
                  CustomTextField(
                    controller: _noteCtrl,
                    label: 'Note',
                    hint: 'Gate code, special instructions, nearby landmark',
                    prefixIcon: const Icon(
                      Icons.sticky_note_2_outlined,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                  ),

                  // Second Address Section
                  if (_hasSecondAddress) ...[
                    const SizedBox(height: AppDimensions.spacing20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Second Address',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _hasSecondAddress = false;
                              _address2Ctrl.clear();
                              _note2Ctrl.clear();
                              _latitude2 = null;
                              _longitude2 = null;
                              _geoAddress2 = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: AppColors.errorColor,
                          tooltip: 'Remove second address',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AddressMapCard(
                      latitude: _latitude2,
                      longitude: _longitude2,
                      controller: _address2Ctrl,
                      onChangeLocation: () =>
                          _chooseLocationOnMap(isSecondAddress: true),
                      onUseCurrentLocation: () =>
                          _useCurrentLocation(isSecondAddress: true),
                      validator: null, // Optional address
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    CustomTextField(
                      controller: _note2Ctrl,
                      label: 'Note',
                      hint: 'Gate code, special instructions, nearby landmark',
                      prefixIcon: const Icon(
                        Icons.sticky_note_2_outlined,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                  ] else ...[
                    const SizedBox(height: AppDimensions.spacing16),
                    // Add Address Button (Outlined style)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _hasSecondAddress = true;
                            // Initialize second address with primary location coordinates
                            // so the map tiles display properly
                            if (_latitude != null && _longitude != null) {
                              _latitude2 = _latitude;
                              _longitude2 = _longitude;
                            }
                          });
                        },
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add Address'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(
                            color: AppColors.primaryGreen,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  // View Mode
                  _infoRow(
                    Icons.location_on,
                    'Primary Address',
                    _addressCtrl.text,
                  ),
                  if (_noteCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.sticky_note_2_outlined,
                      'Note',
                      _noteCtrl.text,
                    ),
                  ],

                  if (_hasSecondAddress && _address2Ctrl.text.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacing16),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spacing16),
                    _infoRow(
                      Icons.location_on,
                      'Second Address',
                      _address2Ctrl.text,
                    ),
                    if (_note2Ctrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.sticky_note_2_outlined,
                        'Note',
                        _note2Ctrl.text,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Hide password change for Google users
          if (!_isGoogleUser) ...[
            _sectionHeader(
              'Account Settings',
              _editAccount,
              onEdit: () {
                setState(() => _editAccount = !_editAccount);
                if (!_editAccount) _saveAccountSettings(context);
              },
              onCancel: _editAccount
                  ? () => setState(() => _editAccount = false)
                  : null,
            ),
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editAccount) ...[
                    _passwordRow('Current Password', _currentPassCtrl),
                    _passwordRow('New Password', _newPassCtrl),
                    _passwordRow('Confirm Password', _confirmPassCtrl),
                  ] else ...[
                    _infoRow(Icons.lock, 'Password', '********'),
                  ],
                ],
              ),
            ),
          ] else ...[
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Account',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your account is secured with Google Sign-In. Email and password are managed by Google.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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

  Widget _sectionHeader(
    String title,
    bool isEditing, {
    required VoidCallback onEdit,
    VoidCallback? onCancel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isEditing && onCancel != null)
            IconButton(
              onPressed: onCancel,
              icon: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 20,
              ),
              tooltip: 'Cancel',
            ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              isEditing ? Icons.check : Icons.edit,
              color: AppColors.householdPrimary,
              size: 20,
            ),
            tooltip: isEditing ? 'Save' : 'Edit',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textFieldRow(
    IconData icon,
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: ctrl,
                  keyboardType: keyboard,
                  maxLines: maxLines,
                  inputFormatters: formatters,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.householdPrimary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordRow(String label, TextEditingController ctrl) {
    bool obscure = true;
    return StatefulBuilder(
      builder: (context, setObscure) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: ctrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.householdPrimary,
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setObscure(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _savePersonal(BuildContext context) {
    // Update Firebase with real data (strip formatting from phone)
    context.read<ProfileBloc>().add(
      UpdateProfileEvent(
        updates: {
          'full_name': _nameCtrl.text,
          'email': _emailCtrl.text,
          'phone': getPlainPhoneNumber(_phoneCtrl.text),
        },
      ),
    );

    // Update original values after successful save
    _originalName = _nameCtrl.text;
    _originalEmail = _emailCtrl.text;
    _originalPhone = _phoneCtrl.text;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Personal information saved')));
  }

  void _saveAddress(BuildContext context) {
    // Update Firebase with location data (address stored inside location)
    final updates = <String, dynamic>{};

    // Primary address
    if (_latitude != null && _longitude != null) {
      updates['location'] = {
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : _geoAddress,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };
    }

    // Second address
    if (_hasSecondAddress && _latitude2 != null && _longitude2 != null) {
      updates['location_2'] = {
        'lat': _latitude2,
        'lng': _longitude2,
        'address': _address2Ctrl.text.trim().isNotEmpty
            ? _address2Ctrl.text.trim()
            : _geoAddress2,
        if (_note2Ctrl.text.trim().isNotEmpty) 'note': _note2Ctrl.text.trim(),
      };
    } else if (!_hasSecondAddress) {
      // Remove location_2 from Firebase if user removed the second address
      updates['location_2'] = null;
    }

    context.read<ProfileBloc>().add(UpdateProfileEvent(updates: updates));

    // Update original values after successful save
    _originalAddress = _addressCtrl.text;
    _originalNote = _noteCtrl.text;
    _originalLatitude = _latitude;
    _originalLongitude = _longitude;
    _originalGeoAddress = _geoAddress;

    _originalAddress2 = _address2Ctrl.text;
    _originalNote2 = _note2Ctrl.text;
    _originalLatitude2 = _latitude2;
    _originalLongitude2 = _longitude2;
    _originalGeoAddress2 = _geoAddress2;
    _originalHasSecondAddress = _hasSecondAddress;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address saved')));
  }

  void _saveAccountSettings(BuildContext context) {
    if (_newPassCtrl.text.isNotEmpty || _confirmPassCtrl.text.isNotEmpty) {
      if (_newPassCtrl.text != _confirmPassCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match')),
        );
        return;
      }
      if (_currentPassCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter current password to change')),
        );
        return;
      }

      // Update password via Firebase Auth
      _updatePassword(context);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account settings saved')));
  }

  Future<void> _updatePassword(BuildContext context) async {
    try {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user before changing password
        await auth.signInWithPassword(
          email: user.email!,
          password: _currentPassCtrl.text,
        );

        // Update password
        await auth.updateUser(UserAttributes(password: _newPassCtrl.text));

        // Clear password fields
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update password. Please try again.'),
        ),
      );
    }
  }

  // Reuse registration flow helpers
  Future<void> _useCurrentLocation({bool isSecondAddress = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Location permission denied'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Enable it in Settings.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );
      } on MissingPluginException {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location plugin not available on this platform or app not restarted.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      if (isSecondAddress) {
        _latitude2 = position.latitude;
        _longitude2 = position.longitude;
        await _reverseGeocodeWithGoogle(
          position.latitude,
          position.longitude,
          isSecondAddress: true,
        );
      } else {
        _latitude = position.latitude;
        _longitude = position.longitude;
        await _reverseGeocodeWithGoogle(position.latitude, position.longitude);
      }

      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Address captured! You can edit if needed.'),
          backgroundColor: AppColors.warningColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  Future<void> _reverseGeocodeWithGoogle(
    double lat,
    double lng, {
    bool isSecondAddress = false,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en',
      );

      final response = await http.get(url, headers: _googleAuthHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          // Use the centralized address formatter for consistent extraction
          final results = (data['results'] as List)
              .cast<Map<String, dynamic>>();
          final fullAddress = formatFullAddressFromGoogleResults(results);

          debugPrint('=== FORMATTED ADDRESS ===');
          debugPrint(fullAddress);
          debugPrint('=========================');

          if (isSecondAddress) {
            _geoAddress2 = fullAddress;
            _address2Ctrl.text = _geoAddress2 ?? '';
          } else {
            _geoAddress = fullAddress;
            _addressCtrl.text = _geoAddress ?? '';
          }
        } else {
          _showFallbackMessage();
        }
      } else {
        _showFallbackMessage();
      }
    } catch (e) {
      _showFallbackMessage();
    }
  }

  Future<void> _chooseLocationOnMap({bool isSecondAddress = false}) async {
    // Save original values in case user cancels
    final originalLat = isSecondAddress ? _latitude2 : _latitude;
    final originalLng = isSecondAddress ? _longitude2 : _longitude;
    final originalAddress = isSecondAddress
        ? _address2Ctrl.text
        : _addressCtrl.text;
    final originalGeoAddress = isSecondAddress ? _geoAddress2 : _geoAddress;

    debugPrint('🔵 Opening map dialog with original values:');
    debugPrint('  Lat: $originalLat, Lng: $originalLng');
    debugPrint('  Address: $originalAddress');

    final initialLat = (isSecondAddress ? _latitude2 : _latitude) ?? 12.8797;
    final initialLng = (isSecondAddress ? _longitude2 : _longitude) ?? 121.7740;

    final LatLng? selectedLocation = await showDialog<LatLng>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return _MapPickerDialog(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          apiKey: _googleApiKey,
          headers: _googleAuthHeaders(),
        );
      },
    );

    debugPrint('🟡 Dialog returned: $selectedLocation');

    if (selectedLocation != null) {
      debugPrint(
        '✅ User confirmed location: ${selectedLocation.latitude}, ${selectedLocation.longitude}',
      );

      if (isSecondAddress) {
        _latitude2 = selectedLocation.latitude;
        _longitude2 = selectedLocation.longitude;
        await _reverseGeocodeWithGoogle(
          selectedLocation.latitude,
          selectedLocation.longitude,
          isSecondAddress: true,
        );
      } else {
        _latitude = selectedLocation.latitude;
        _longitude = selectedLocation.longitude;
        await _reverseGeocodeWithGoogle(
          selectedLocation.latitude,
          selectedLocation.longitude,
        );
      }

      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated from map!'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } else {
      debugPrint('❌ User cancelled - restoring original values');
      // User clicked X - restore original values
      if (isSecondAddress) {
        _latitude2 = originalLat;
        _longitude2 = originalLng;
        _geoAddress2 = originalGeoAddress;
        _address2Ctrl.text = originalAddress;
        debugPrint('  Restored second address to: ${_address2Ctrl.text}');
      } else {
        _latitude = originalLat;
        _longitude = originalLng;
        _geoAddress = originalGeoAddress;
        _addressCtrl.text = originalAddress;
        debugPrint('  Restored address to: ${_addressCtrl.text}');
      }

      setState(() {}); // Rebuild to show original values
    }
  }

  Map<String, String> _googleAuthHeaders() {
    final headers = <String, String>{};
    try {
      if (Platform.isAndroid) {
        headers['X-Android-Package'] = 'com.example.ecokuha';
        headers['X-Android-Cert'] = '6D37720CF6A19565D469A64F746A08728517438C';
      } else if (Platform.isIOS) {
        headers['X-Ios-Bundle-Identifier'] = 'com.example.EcoKuha';
      }
    } catch (_) {}
    return headers;
  }

  void _showFallbackMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not auto-fill address. Please enter manually.'),
        backgroundColor: AppColors.warningColor,
      ),
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String apiKey;
  final Map<String, String> headers;

  const _MapPickerDialog({
    required this.initialLatitude,
    required this.initialLongitude,
    required this.apiKey,
    required this.headers,
  });

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _selectedPosition;
  GoogleMapController? _mapController;
  String _selectedAddress = '';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 _MapPickerDialogState.initState() called');
    _selectedPosition = LatLng(widget.initialLatitude, widget.initialLongitude);
    debugPrint(
      '📌 Selected position set to: ${_selectedPosition.latitude}, ${_selectedPosition.longitude}',
    );
    // Load address immediately on init (after first build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoadingAddress = true;
        });
        _reverseGeocode(widget.initialLatitude, widget.initialLongitude);
      }
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${widget.apiKey}&language=en';
      final response = await http.get(Uri.parse(url), headers: widget.headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Use the centralized address formatter for consistent extraction
          final results = (data['results'] as List)
              .cast<Map<String, dynamic>>();
          final fullAddress = formatFullAddressFromGoogleResults(results);
          setState(() {
            _selectedAddress = fullAddress;
            _isLoadingAddress = false;
          });
        } else {
          setState(() {
            _isLoadingAddress = false;
          });
        }
      } else {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ _MapPickerDialogState.build() called');
    return Scaffold(
      body: Stack(
        children: [
          // Google Map (Full Screen)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              setState(() {
                _selectedPosition = position.target;
              });
            },
            onCameraIdle: () async {
              // Reverse geocode when camera stops moving
              setState(() {
                _isLoadingAddress = true;
              });
              await _reverseGeocode(
                _selectedPosition.latitude,
                _selectedPosition.longitude,
              );
              setState(() {
                _isLoadingAddress = false;
              });
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: _selectedPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            debugPrint(
                              '🔴 Back button clicked - returning null',
                            );
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Select Location',
                          style: AppTextStyles.h5.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Center on current location button
          Positioned(
            right: 16,
            bottom: 200, // Position above bottom sheet
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.my_location,
                  color: AppColors.primaryGreen,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    // Get current location
                    final position = await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(
                        accuracy: LocationAccuracy.high,
                      ),
                    );

                    final currentLatLng = LatLng(
                      position.latitude,
                      position.longitude,
                    );

                    // Animate camera to current location
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(currentLatLng, 16),
                    );

                    // Update selected position
                    setState(() {
                      _selectedPosition = currentLatLng;
                    });
                  } catch (e) {
                    debugPrint('Error getting current location: $e');
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Unable to get current location'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          // Bottom sheet with address
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primaryGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Location',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _isLoadingAddress
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _selectedAddress.isEmpty
                                            ? 'Move map to select location'
                                            : _selectedAddress,
                                        style: AppTextStyles.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Confirm Location',
                        onPressed: () {
                          debugPrint(
                            '🟢 Confirm button clicked - returning $_selectedPosition',
                          );
                          Navigator.of(context).pop(_selectedPosition);
                        },
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
