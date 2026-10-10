import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import '../../../../../../shared/utils/address_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as sb;
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';
import 'package:ecokuha/core/theme/app_dimensions.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:ecokuha/core/utils/phone_number_formatter.dart';
import 'package:ecokuha/core/utils/user_collection_helper.dart';
import 'package:ecokuha/shared/widgets/common/common_widgets.dart';
import 'package:ecokuha/features/authentication/presentation/widgets/address_map_card.dart';
import '../../bloc/profile/collector_profile_bloc.dart';
import '../../bloc/profile/collector_profile_event.dart';
import '../../bloc/profile/collector_profile_state.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Edit toggles
  bool _editPersonal = false;
  bool _editVehicle = false;
  bool _editAddress = false;
  bool _editAccount = false;
  bool _editJunkshop = false;
  bool _isGoogleUser = false;

  // Controllers - Personal
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  // Location
  double? _latitude;
  double? _longitude;
  String? _geoAddress;

  // Controllers - Vehicle
  late final TextEditingController _vehicleTypeCtrl;
  late final TextEditingController _plateCtrl;
  final TextEditingController _capacityCtrl = TextEditingController();

  // Dropdown selections
  String? _selectedVehicleType;
  String? _selectedCapacity;

  // Options
  final List<String> _vehicleTypes = const [
    'Motorcycle',
    'Tricycle',
    'Jeepney',
    'Mini Truck',
    'Pickup Truck',
    'Van',
    'Bicycle with Cart',
    'E-Bike with Cart',
    'Push Cart',
    'Other',
  ];

  final List<String> _capacityOptions = const [
    'Less than 100kg',
    '100-300kg',
    '300-500kg',
    '500-1000kg',
    '1000-2000kg',
    'More than 2000kg',
  ];

  // Controllers - Account
  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  // Partner junkshop future (refreshable)
  Future<Map<String, dynamic>?> _junkshopPartnerFuture = Future.value(null);

  // Current collector application status (used to display 'Reapplying...' in the partner section)
  String _collectorAppStatus = '';

  // One-time init guard

  bool _hasInitialized = false; // prevent repeated loads and rebuild loops

  @override
  void initState() {
    super.initState();
    // Initialize with empty values - will be loaded from Firebase
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _vehicleTypeCtrl = TextEditingController();
    _plateCtrl = TextEditingController();
    _junkshopPartnerFuture = _loadJunkshopPartner();
    _loadCollectorApplicationStatus();
  }

  Future<void> _loadCollectorApplicationStatus() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final snap = await UserCollectionHelper.getUserDocument(
        uid,
        'collector',
      ).get();
      if (snap != null && mounted) {
        setState(() {
          _collectorAppStatus = (snap['application_status'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  void _loadProfileData(Map<String, dynamic> profileData) {
    // Extract nested profile data
    final collectorProfile =
        profileData[UserFields.collectorProfile] as Map<String, dynamic>?;
    final personalInfo = collectorProfile?['personal'] as Map<String, dynamic>?;
    final contactInfo = collectorProfile?['contact'] as Map<String, dynamic>?;

    // Check if user signed in with Google
    _isGoogleUser = profileData['signInProvider'] == 'google.com';
    debugPrint(
      '🔐 Collector Account Settings: signInProvider=${profileData['signInProvider']}, _isGoogleUser=$_isGoogleUser',
    );

    // Load personal info - check both top-level and nested fields for name
    if (_nameCtrl.text.isEmpty) {
      final topLevelName =
          profileData[UserFields.fullName]?.toString().trim() ?? '';
      final nestedName = personalInfo?['full_name']?.toString().trim() ?? '';
      _nameCtrl.text = topLevelName.isNotEmpty ? topLevelName : nestedName;
    }
    if (_emailCtrl.text.isEmpty) {
      _emailCtrl.text = profileData[UserFields.email] ?? '';
    }

    // Extract phone from nested or top-level
    _phoneCtrl.text = formatPhoneNumber(
      (personalInfo?[UserFields.phone] ??
              personalInfo?['contact_number'] ??
              contactInfo?[UserFields.phone] ??
              profileData[UserFields.phone] ??
              profileData['contact_number'] ??
              '')
          .toString(),
    );

    // Extract address and parse location - check contact first, then personal
    final address = _extractAddress(profileData);
    final parsedLat = _tryParseDouble(
      contactInfo?[UserFields.lat] ??
          contactInfo?[UserFields.latitude] ??
          personalInfo?['lat'] ??
          personalInfo?['latitude'],
    );
    final parsedLng = _tryParseDouble(
      contactInfo?['lng'] ??
          contactInfo?['longitude'] ??
          personalInfo?['lng'] ??
          personalInfo?['longitude'],
    );

    // Only overwrite fields if not currently editing, or if uninitialized
    if (!_editAddress) {
      _addressCtrl.text = address;
      _geoAddress = address;
      _latitude = parsedLat;
      _longitude = parsedLng;
    } else {
      // While editing, don't clobber in-progress user edits; only fill blanks
      if ((_latitude == null || _longitude == null) &&
          parsedLat != null &&
          parsedLng != null) {
        _latitude = parsedLat;
        _longitude = parsedLng;
      }
      if (_addressCtrl.text.trim().isEmpty && address.trim().isNotEmpty) {
        _addressCtrl.text = address;
        _geoAddress = address;
      }
    }

    // Load vehicle info
    final vehicleInfo = collectorProfile?['vehicle'] as Map<String, dynamic>?;
    if (vehicleInfo != null) {
      final vType = vehicleInfo['type']?.toString() ?? '';
      _vehicleTypeCtrl.text = vType;
      _selectedVehicleType = _vehicleTypes.contains(vType)
          ? vType
          : _vehicleTypes.first;

      _plateCtrl.text =
          (vehicleInfo['plate_number'] ?? vehicleInfo['plateNumber'] ?? '')
              .toString();

      final cap = vehicleInfo['capacity']?.toString() ?? '';
      _capacityCtrl.text = cap;
      _selectedCapacity = _capacityOptions.contains(cap)
          ? cap
          : _capacityOptions[1];
    } else {
      _selectedVehicleType = _vehicleTypes.first;
      _selectedCapacity = _capacityOptions[1];
    }
  }

  double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _extractAddress(Map<String, dynamic> profileData) {
    try {
      final collectorProfile =
          profileData['collector_profile'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;
      final contact = collectorProfile?['contact'] as Map<String, dynamic>?;

      // First check contact.address (from registration step 2)
      final contactAddress = contact?['address'];
      if (contactAddress is String && contactAddress.trim().isNotEmpty) {
        return contactAddress.trim();
      }

      // Then check personal.address (from profile edit)
      final personalAddress =
          (personal?['address'] ?? personal?['full_address']);
      if (personalAddress is String && personalAddress.trim().isNotEmpty) {
        return personalAddress.trim();
      }

      // Try composing from parts (contact or personal)
      final parts = <String>[];
      for (final key in [
        'street',
        'barangay',
        'city',
        'municipality',
        'province',
      ]) {
        final v = contact?[key] ?? personal?[key];
        if (v is String && v.trim().isNotEmpty) parts.add(v.trim());
      }
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }

      // Fallback to top-level
      return (profileData[UserFields.address] ??
              profileData[UserFields.location] ??
              '')
          .toString()
          .trim();
    } catch (e) {
      return (profileData[UserFields.address] ??
              profileData[UserFields.location] ??
              '')
          .toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    _plateCtrl.dispose();
    _capacityCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectorProfileBloc, CollectorProfileState>(
      builder: (context, state) {
        if (state is CollectorProfileLoaded && !_hasInitialized) {
          // Load once on first successful load to avoid rebuild loops
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _loadProfileData(state.profileData);
              _hasInitialized = true;
            });
          });
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            title: const Text(
              'Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.collectorPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          body: _buildContent(context, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, CollectorProfileState state) {
    if (state is CollectorProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is CollectorProfileError) {
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
          ],
        ),
      );
    }

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
                ? () => setState(() => _editPersonal = false)
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
                ? () => setState(() => _editAddress = false)
                : null,
          ),
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editAddress) ...[
                  AddressMapCard(
                    latitude: _latitude,
                    longitude: _longitude,
                    controller: _addressCtrl,
                    onChangeLocation: _chooseLocationOnMap,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  _infoRow(Icons.location_on, 'Address', _addressCtrl.text),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          _sectionHeader(
            'Vehicle Information',
            _editVehicle,
            onEdit: () {
              setState(() => _editVehicle = !_editVehicle);
              if (!_editVehicle) _saveVehicle(context);
            },
            onCancel: _editVehicle
                ? () => setState(() => _editVehicle = false)
                : null,
          ),
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editVehicle) ...[
                  // Vehicle Type dropdown
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacing12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.two_wheeler,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vehicle Type',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedVehicleType,
                                isExpanded: true,
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
                                      color: AppColors.collectorPrimary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: _vehicleTypes
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(
                                          t,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _selectedVehicleType = v;
                                  if (v != null) _vehicleTypeCtrl.text = v;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _textFieldRow(
                    Icons.confirmation_number,
                    'Plate Number',
                    _plateCtrl,
                  ),
                  // Capacity dropdown
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacing12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.scale,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capacity',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedCapacity,
                                isExpanded: true,
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
                                      color: AppColors.collectorPrimary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: _capacityOptions
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _selectedCapacity = v;
                                  if (v != null) _capacityCtrl.text = v;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _infoRow(
                    Icons.two_wheeler,
                    'Vehicle Type',
                    _vehicleTypeCtrl.text,
                  ),
                  _infoRow(
                    Icons.confirmation_number,
                    'Plate Number',
                    _plateCtrl.text,
                  ),
                  _infoRow(Icons.scale, 'Capacity', _capacityCtrl.text),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          _sectionHeader(
            'Partner Junkshop',
            _editJunkshop,
            onEdit: () => setState(() => _editJunkshop = !_editJunkshop),
            onCancel: _editJunkshop
                ? () => setState(() => _editJunkshop = false)
                : null,
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _junkshopPartnerFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              String shopName;
              bool junkshopDisabled = false;
              if (_collectorAppStatus == 'reapplying') {
                shopName = 'Reapplying...';
              } else if (_collectorAppStatus == 'rejected') {
                shopName = 'Rejected';
              } else if (_collectorAppStatus == 'fired') {
                shopName = 'Dismissed';
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                shopName = '...';
              } else if (data == null || data['_idEmpty'] == true) {
                shopName = 'None';
              } else if (data['_idNotFound'] == true) {
                shopName = 'Unknown';
              } else {
                final jp = data['junkshop_profile'] as Map<String, dynamic>?;
                final name =
                    (jp?['business_name'] ??
                            jp?['shop_name'] ??
                            data['full_name'] ??
                            '')
                        .toString()
                        .trim();
                shopName = name.isNotEmpty ? name : 'Unknown';
                junkshopDisabled = data['isActive'] == false;
              }
              return CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spacing12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Junkshop',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        shopName.isEmpty ? '—' : shopName,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    if (junkshopDisabled) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          'Disabled',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_editJunkshop)
                      ...([
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.collectorPrimary.withValues(
                                  alpha: 0.08,
                                ),
                                AppColors.collectorPrimary.withValues(
                                  alpha: 0.03,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.collectorPrimary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.collectorPrimary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                      color: AppColors.collectorPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Switch Partner Junkshop',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.collectorPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'A new application will be sent to the junkshop you choose. Assignments are paused until they approve you.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _confirmAndPickJunkshop(context),
                                  icon: const Icon(
                                    Icons.store_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Re-apply to a Junkshop'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.collectorPrimary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: AppTextStyles.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                  ],
                ),
              );
            },
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
                      color: AppColors.collectorPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: AppColors.collectorPrimary,
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

  /// Recursively searches any nested map for a key, returns the value string.
  String? _findNestedField(Map<dynamic, dynamic> map, String key) {
    if (map.containsKey(key)) return map[key]?.toString();
    for (final value in map.values) {
      if (value is Map) {
        final result = _findNestedField(value, key);
        if (result != null && result.isNotEmpty) return result;
      }
    }
    return null;
  }

  /// Shows a confirmation dialog before opening the junkshop picker.
  Future<void> _confirmAndPickJunkshop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.collectorPrimary.withValues(alpha: 0.15),
                      AppColors.collectorPrimary.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.collectorPrimary.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.collectorPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Switch Partner Junkshop?',
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    _dialogInfoRow(
                      Icons.send_rounded,
                      'A new application will be sent to your chosen junkshop.',
                    ),
                    const SizedBox(height: 12),
                    _dialogInfoRow(
                      Icons.pause_circle_outline_rounded,
                      'Assignments are paused until the junkshop approves you.',
                    ),
                    const SizedBox(height: 12),
                    _dialogInfoRow(
                      Icons.check_circle_outline_rounded,
                      'They can approve or reject your application anytime.',
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.collectorPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      _showDocumentUpdateSheet();
    }
  }

  Widget _dialogInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.collectorPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Shows a sheet to let the collector optionally update their documents before applying.
  void _showDocumentUpdateSheet() {
    // Document definitions
    const docDefs = [
      {'key': 'validId', 'title': 'Valid Government ID', 'required': true},
      {'key': 'driversLicense', 'title': "Driver's License", 'required': false},
      {'key': 'orCr', 'title': 'Vehicle OR/CR', 'required': false},
      {'key': 'vehiclePhoto', 'title': 'Vehicle Photo', 'required': true},
      {
        'key': 'selfieWithVehicle',
        'title': 'Selfie with Vehicle',
        'required': false,
      },
    ];

    // Local state for the sheet
    Map<String, String?> existingUrls = {}; // key → current stored URL
    Map<String, XFile?> newFiles =
        {}; // key → newly picked file (null = no change)
    bool loadingDocs = true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Load existing document URLs once
          if (loadingDocs && existingUrls.isEmpty) {
            Future.microtask(() async {
              final uid = Supabase.instance.client.auth.currentUser?.id;
              if (uid == null) {
                setSheet(() => loadingDocs = false);
                return;
              }
              try {
                final snap = await UserCollectionHelper.getUserDocument(
                  uid,
                  'collector',
                ).get();
                final docs =
                    (snap?['collector_profile']
                            as Map<String, dynamic>?)?['documents']
                        as Map<String, dynamic>?;
                final urls = <String, String?>{};
                for (final d in docDefs) {
                  final key = d['key'] as String;
                  final val = docs?[key];
                  if (val is String && val.startsWith('http')) {
                    urls[key] = val;
                  } else if (val is String && val.isNotEmpty) {
                    // Private documents bucket: stored value is an object path
                    try {
                      urls[key] = await sb.signedDocumentUrl(val);
                    } catch (_) {
                      urls[key] = null;
                    }
                  } else {
                    urls[key] = null;
                  }
                }
                setSheet(() {
                  existingUrls = urls;
                  for (final d in docDefs) {
                    newFiles[d['key'] as String] = null;
                  }
                  loadingDocs = false;
                });
              } catch (_) {
                setSheet(() => loadingDocs = false);
              }
            });
          }

          Future<void> pickDoc(String key) async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 80,
            );
            if (picked != null) setSheet(() => newFiles[key] = picked);
          }

          Future<void> saveAndContinue() async {
            setSheet(() => saving = true);
            final navigator = Navigator.of(ctx);
            final messenger = ScaffoldMessenger.of(context);
            try {
              final uid = Supabase.instance.client.auth.currentUser?.id;
              if (uid != null) {
                final updates = <String, dynamic>{};
                for (final entry in newFiles.entries) {
                  final file = entry.value;
                  if (file == null) continue;
                  // Private documents bucket: store the object PATH
                  final path = await sb.uploadPrivateDocument(
                    path:
                        '$uid/collector/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                    bytes: await file.readAsBytes(),
                  );
                  updates['collector_profile.documents.${entry.key}'] = path;
                }
                if (updates.isNotEmpty) {
                  await UserCollectionHelper.getUserDocument(
                    uid,
                    'collector',
                  ).update(updates);
                }
              }
              if (mounted) {
                navigator.pop();
                _showJunkshopPickerSheet();
              }
            } catch (e) {
              setSheet(() => saving = false);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Failed to upload documents: $e'),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            }
          }

          final hasChanges = newFiles.values.any((f) => f != null);

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Documents',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can update your documents before applying. '
                          'Tap any document to replace it, or skip to keep your current ones.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: loadingDocs
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              for (final d in docDefs) ...[
                                _buildDocRow(
                                  key: d['key'] as String,
                                  title: d['title'] as String,
                                  isRequired: d['required'] as bool,
                                  existingUrl: existingUrls[d['key']],
                                  pickedFile: newFiles[d['key'] as String],
                                  onTap: () => pickDoc(d['key'] as String),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                  ),
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (saving || !hasChanges)
                                ? null
                                : saveAndContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.collectorPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors
                                  .collectorPrimary
                                  .withValues(alpha: 0.35),
                              disabledForegroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Changes & Continue'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    _showJunkshopPickerSheet();
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                color: AppColors.borderLight,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Continue Without Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocRow({
    required String key,
    required String title,
    required bool isRequired,
    required String? existingUrl,
    required XFile? pickedFile,
    required VoidCallback onTap,
  }) {
    final hasNew = pickedFile != null;
    final hasExisting = existingUrl != null;
    final statusColor = hasNew
        ? AppColors.collectorPrimary
        : hasExisting
        ? AppColors.successColor
        : isRequired
        ? AppColors.errorColor
        : AppColors.warningColor;
    final statusIcon = hasNew
        ? Icons.check_circle
        : hasExisting
        ? Icons.check_circle_outline
        : Icons.upload_file_outlined;
    final statusLabel = hasNew
        ? 'New file selected'
        : hasExisting
        ? 'Uploaded'
        : isRequired
        ? 'Required — not uploaded'
        : 'Optional — not uploaded';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasNew ? AppColors.collectorPrimary : AppColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(10),
          color: hasNew
              ? AppColors.collectorPrimary.withValues(alpha: 0.04)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 4),
                        Text(
                          '*',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.errorColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    statusLabel,
                    style: AppTextStyles.bodySmall.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Opens a bottom sheet so the collector can pick / re-apply to a junkshop.
  void _showJunkshopPickerSheet() {
    final TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> allShops = [];
    List<Map<String, dynamic>> filteredShops = [];
    bool isLoading = true;
    String? pendingId;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Load junkshops once
            if (isLoading && allShops.isEmpty) {
              Future.microtask(() async {
                try {
                  final snap = await UserCollectionHelper.queryUsersByRole(
                    'junkshop',
                  );
                  final shops = <Map<String, dynamic>>[];
                  for (final d in snap) {
                    // Skip junkshops disabled by admin
                    if (d['isActive'] == false) continue;

                    final jp = d['junkshop_profile'] as Map<String, dynamic>?;
                    final biz = jp?['business'] as Map<String, dynamic>?;
                    final name =
                        (biz?['business_name'] ??
                                jp?['business_name'] ??
                                d['full_name'] ??
                                'Unknown Junkshop')
                            .toString()
                            .trim();
                    final loc = jp?['location'] as Map<String, dynamic>?;
                    final addr = (loc?['address'] ?? d['address'] ?? '')
                        .toString()
                        .trim();
                    final shopLat = _tryParseDouble(
                      loc?['lat'] ?? loc?['latitude'] ?? jp?['lat'] ?? d['lat'],
                    );
                    final shopLng = _tryParseDouble(
                      loc?['lng'] ??
                          loc?['longitude'] ??
                          jp?['lng'] ??
                          d['lng'],
                    );
                    shops.add({
                      'id': d['id'],
                      'name': name,
                      'address': addr,
                      'lat': shopLat,
                      'lng': shopLng,
                    });
                  }
                  setSheetState(() {
                    allShops = shops;
                    filteredShops = List.from(shops);
                    isLoading = false;
                  });
                } catch (_) {
                  setSheetState(() => isLoading = false);
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (_, scrollCtrl) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.borderLight.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.collectorPrimary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.store_rounded,
                                color: AppColors.collectorPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Partner Junkshop',
                                  style: AppTextStyles.h5.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Choose the junkshop to apply to',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Search
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search junkshops...',
                            hintStyle: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.collectorPrimary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (q) {
                            setSheetState(() {
                              filteredShops = allShops
                                  .where(
                                    (s) =>
                                        s['name']
                                            .toString()
                                            .toLowerCase()
                                            .contains(q.toLowerCase()) ||
                                        s['address']
                                            .toString()
                                            .toLowerCase()
                                            .contains(q.toLowerCase()),
                                  )
                                  .toList();
                            });
                          },
                        ),
                      ),
                      // List
                      Expanded(
                        child: isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.collectorPrimary,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : filteredShops.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.store_outlined,
                                      size: 48,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No junkshops found',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                itemCount: filteredShops.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final shop = filteredShops[i];
                                  final selected = pendingId == shop['id'];
                                  // Compute distance if coordinates are available
                                  String? distLabel;
                                  final shopLat = shop['lat'] as double?;
                                  final shopLng = shop['lng'] as double?;
                                  if (_latitude != null &&
                                      _longitude != null &&
                                      shopLat != null &&
                                      shopLng != null) {
                                    final dLat =
                                        (shopLat - _latitude!) * math.pi / 180;
                                    final dLng =
                                        (shopLng - _longitude!) * math.pi / 180;
                                    final a =
                                        math.sin(dLat / 2) *
                                            math.sin(dLat / 2) +
                                        math.cos(_latitude! * math.pi / 180) *
                                            math.cos(shopLat * math.pi / 180) *
                                            math.sin(dLng / 2) *
                                            math.sin(dLng / 2);
                                    final distKm =
                                        6371 *
                                        2 *
                                        math.atan2(
                                          math.sqrt(a),
                                          math.sqrt(1 - a),
                                        );
                                    distLabel = distKm < 1
                                        ? '${(distKm * 1000).round()} m away'
                                        : '${distKm.toStringAsFixed(1)} km away';
                                  }
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.collectorPrimary
                                                .withValues(alpha: 0.08)
                                          : AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.collectorPrimary
                                                  .withValues(alpha: 0.4)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => setSheetState(
                                        () => pendingId = shop['id'],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          shop['name'],
                                                          style: AppTextStyles
                                                              .bodyMedium
                                                              .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: selected
                                                                    ? AppColors
                                                                          .collectorPrimary
                                                                    : AppColors
                                                                          .textPrimary,
                                                              ),
                                                        ),
                                                      ),
                                                      if (distLabel !=
                                                          null) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 3,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .collectorPrimary
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            distLabel,
                                                            style: AppTextStyles
                                                                .bodySmall
                                                                .copyWith(
                                                                  color: AppColors
                                                                      .collectorPrimary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 11,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if ((shop['address']
                                                          as String)
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      shop['address'],
                                                      style: AppTextStyles
                                                          .bodySmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .textSecondary,
                                                            height: 1.4,
                                                          ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (selected)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .collectorPrimary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Confirm button
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          border: Border(
                            top: BorderSide(
                              color: AppColors.borderLight.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (pendingId == null || isSaving)
                                ? null
                                : () async {
                                    final navigator = Navigator.of(ctx);
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    setSheetState(() => isSaving = true);
                                    try {
                                      final uid = Supabase
                                          .instance
                                          .client
                                          .auth
                                          .currentUser
                                          ?.id;
                                      if (uid != null) {
                                        // Capture old junkshop ID and status before overwriting
                                        String? oldJunkshopId;
                                        String? oldStatus;
                                        try {
                                          final oldSnap =
                                              await UserCollectionHelper.getUserDocument(
                                                uid,
                                                'collector',
                                              ).get();
                                          if (oldSnap != null) {
                                            oldJunkshopId = _findNestedField(
                                              oldSnap,
                                              'preferred_junkshop_id',
                                            );
                                            oldStatus = oldSnap['application_status']
                                                ?.toString();
                                          }
                                        } catch (_) {}

                                        await UserCollectionHelper.getUserDocument(
                                          uid,
                                          'collector',
                                        ).set({
                                          'collector_profile': {
                                            'preferred_junkshop_id': pendingId,
                                          },
                                          'preferred_junkshop_id': pendingId,
                                          'application_status': 'reapplying',
                                          'updated_at': DateTime.now()
                                              .toUtc()
                                              .toIso8601String(),
                                        }, merge: true);

                                        // Kick from group chat and clear all conversations on reapply
                                        if (oldJunkshopId != null &&
                                            oldJunkshopId.isNotEmpty) {
                                          await _kickFromGroupChat(
                                            uid,
                                            oldJunkshopId,
                                            postMessage: oldStatus != 'fired',
                                          );
                                        }
                                        await _removeFromAllConversations(uid);
                                      }
                                      if (mounted) {
                                        setState(() {
                                          _junkshopPartnerFuture =
                                              _loadJunkshopPartner();
                                          _editJunkshop = false;
                                        });
                                        navigator.pop();
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Application submitted — awaiting approval',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setSheetState(() => isSaving = false);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to apply: $e'),
                                          backgroundColor: AppColors.errorColor,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.collectorPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors
                                  .collectorPrimary
                                  .withValues(alpha: 0.35),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Apply to Selected Junkshop'),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Fetches the partner junkshop document, searching all nesting levels.
  Future<Map<String, dynamic>?> _loadJunkshopPartner() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;

    String? junkshopId;

    try {
      final snap = await UserCollectionHelper.getUserDocument(
        uid,
        'collector',
      ).get();
      if (snap != null) {
        junkshopId =
            snap['preferred_junkshop_id']?.toString() ??
            _findNestedField(snap, 'preferred_junkshop_id');
      }
    } catch (_) {}

    if (junkshopId == null || junkshopId.isEmpty) {
      return {'_idEmpty': true};
    }

    try {
      final snap = await UserCollectionHelper.getUserDocument(
        junkshopId,
        'junkshop',
      ).get();
      if (snap != null) return snap;
    } catch (_) {}
    return {'_idNotFound': true};
  }

  /// Removes the collector from their old junkshop's group chat and optionally
  /// posts a EcoKuha Assistant departure message.
  Future<void> _kickFromGroupChat(
    String collectorUid,
    String oldJunkshopId, {
    bool postMessage = true,
  }) async {
    try {
      // Resolve collector's display name for the message
      String collectorName = 'Collector';
      try {
        final data = await UserCollectionHelper.getUserDocument(
          collectorUid,
          'collector',
        ).get();
        if (data != null) {
          // Use safe dynamic access to avoid cast failures on jsonb maps
          final dynamic cp = data['collector_profile'];
          final dynamic personal = (cp is Map) ? cp['personal'] : null;
          final String? fullName = (personal is Map)
              ? (personal['full_name']?.toString() ??
                    personal['name']?.toString())
              : null;
          collectorName = (fullName != null && fullName.isNotEmpty)
              ? fullName
              : (_findNestedField(data, 'full_name') ??
                    _findNestedField(data, 'name') ??
                    'Collector');
        }
      } catch (_) {}

      // Find the group chat for the old junkshop
      final client = Supabase.instance.client;
      final groupChats = await client
          .from('conversations')
          .select()
          .eq('is_group_chat', true)
          .eq('junkshop_id', oldJunkshopId)
          .limit(1);

      if (groupChats.isEmpty) return;

      final groupChat = groupChats.first;
      final chatId = groupChat['id'] as String;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Only post the departure message if not already sent at dismissal time.
      // Post it first: messages RLS requires the sender to still be a participant.
      if (postMessage) {
        await client.from('messages').insert({
          'conversation_id': chatId,
          'sender_id': 'ecokuha_assistant',
          'sender_name': 'EcoKuha Assistant',
          'sender_role': 'system',
          'text': '$collectorName has left the team!',
          'type': 'system',
        });
      }

      // Remove the collector from participants and participant_details
      final participants = List<String>.from(
        (groupChat['participants'] as List? ?? const []).map(
          (e) => e.toString(),
        ),
      )..remove(collectorUid);
      final details = Map<String, dynamic>.from(
        (groupChat['participant_details'] as Map?) ?? const {},
      )..remove(collectorUid);

      await client
          .from('conversations')
          .update({
            'participants': participants,
            'participant_details': details,
            if (postMessage) ...{
              'last_message': '$collectorName has left the team!',
              'last_message_sender_id': 'ecokuha_assistant',
              'last_message_sender_name': 'EcoKuha Assistant',
              'last_message_timestamp': nowIso,
            },
            'updated_at': nowIso,
          })
          .eq('id', chatId);
    } catch (e) {
      debugPrint('Error kicking collector from group chat: $e');
    }
  }

  /// Removes the collector from all individual (non-group) conversations so
  /// their inbox is empty while they are in 'reapplying' status.
  Future<void> _removeFromAllConversations(String collectorUid) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('conversations')
          .select()
          .contains('participants', [collectorUid]);

      for (final data in rows) {
        // Group chat departure is handled by _kickFromGroupChat; skip here.
        if (data['is_group_chat'] == true) continue;
        final participants = List<String>.from(
          (data['participants'] as List? ?? const []).map((e) => e.toString()),
        )..remove(collectorUid);
        final details = Map<String, dynamic>.from(
          (data['participant_details'] as Map?) ?? const {},
        )..remove(collectorUid);
        await client
            .from('conversations')
            .update({
              'participants': participants,
              'participant_details': details,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', data['id'] as String);
      }
    } catch (e) {
      debugPrint('Error removing collector from conversations: $e');
    }
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
                  value.isEmpty ? '—' : value,
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
                        color: AppColors.collectorPrimary,
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
                            color: AppColors.collectorPrimary,
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
              color: AppColors.collectorPrimary,
              size: 20,
            ),
            tooltip: isEditing ? 'Save' : 'Edit',
          ),
        ],
      ),
    );
  }

  void _savePersonal(BuildContext context) {
    final updates = <String, dynamic>{
      // Save to both top-level and nested fields for compatibility
      UserFields.fullName: _nameCtrl.text.trim(),
      'collector_profile.personal.full_name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'collector_profile.personal.phone': getPlainPhoneNumber(_phoneCtrl.text),
      'collector_profile.personal.contact_number': getPlainPhoneNumber(
        _phoneCtrl.text,
      ),
    };

    context.read<CollectorProfileBloc>().add(
      UpdateCollectorProfileEvent(updates),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Personal information saved')));
  }

  void _saveAddress(BuildContext context) {
    final updates = <String, dynamic>{
      'collector_profile.personal.address': _addressCtrl.text.trim(),
      'collector_profile.personal.full_address': _addressCtrl.text.trim(),
    };

    if (_latitude != null && _longitude != null) {
      // Save to personal (for backward compatibility)
      updates['collector_profile.personal.latitude'] = _latitude;
      updates['collector_profile.personal.longitude'] = _longitude;
      // Also save to contact (where registration stores it)
      updates['collector_profile.contact.lat'] = _latitude;
      updates['collector_profile.contact.lng'] = _longitude;
      updates['collector_profile.contact.address'] = _addressCtrl.text.trim();
    }

    context.read<CollectorProfileBloc>().add(
      UpdateCollectorProfileEvent(updates),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address saved')));
  }

  void _saveVehicle(BuildContext context) {
    final updates = <String, dynamic>{
      'collector_profile.vehicle.type': _vehicleTypeCtrl.text.trim(),
      'collector_profile.vehicle.plate_number': _plateCtrl.text.trim(),
      'collector_profile.vehicle.capacity': _capacityCtrl.text.trim(),
    };

    context.read<CollectorProfileBloc>().add(
      UpdateCollectorProfileEvent(updates),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vehicle information saved')));
  }

  Future<void> _saveAccountSettings(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_newPassCtrl.text.isNotEmpty || _confirmPassCtrl.text.isNotEmpty) {
      if (_newPassCtrl.text != _confirmPassCtrl.text) {
        messenger.showSnackBar(
          const SnackBar(content: Text('New passwords do not match')),
        );
        return;
      }
      if (_currentPassCtrl.text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter current password to change')),
        );
        return;
      }

      // Update password via Supabase Auth
      try {
        final auth = Supabase.instance.client.auth;
        final user = auth.currentUser;
        if (user == null || user.email == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
          return;
        }

        // Re-authenticate
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

        messenger.showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      } catch (e) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to update password. Please try again.'),
          ),
        );
      }
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Account settings saved')),
      );
    }
  }

  Future<void> _reverseGeocodeWithGoogle(double lat, double lng) async {
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
          final results = (data['results'] as List)
              .cast<Map<String, dynamic>>();
          final fullAddress = formatFullAddressFromGoogleResults(results);
          _geoAddress = fullAddress;
          _addressCtrl.text = _geoAddress ?? '';
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

  Future<void> _chooseLocationOnMap() async {
    // Save original values in case user cancels
    final originalLat = _latitude;
    final originalLng = _longitude;
    final originalAddress = _addressCtrl.text;
    final originalGeoAddress = _geoAddress;

    debugPrint('🔵 Opening map dialog with original values:');
    debugPrint('  Lat: $originalLat, Lng: $originalLng');
    debugPrint('  Address: $originalAddress');

    final initialLat = _latitude ?? 12.8797;
    final initialLng = _longitude ?? 121.7740;

    final LatLng? selectedLocation = await showDialog<LatLng>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return _MapPickerDialog(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
        );
      },
    );

    debugPrint('🟡 Dialog returned: $selectedLocation');

    if (selectedLocation != null) {
      debugPrint(
        '✅ User confirmed location: ${selectedLocation.latitude}, ${selectedLocation.longitude}',
      );
      _latitude = selectedLocation.latitude;
      _longitude = selectedLocation.longitude;

      await _reverseGeocodeWithGoogle(
        selectedLocation.latitude,
        selectedLocation.longitude,
      );

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated from map!'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } else {
      debugPrint('❌ User cancelled - restoring original values');
      // User clicked X - restore original values
      _latitude = originalLat;
      _longitude = originalLng;
      _geoAddress = originalGeoAddress;

      // Force update the text controller
      _addressCtrl.text = originalAddress;
      debugPrint('  Restored address to: ${_addressCtrl.text}');

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

// Map Picker Dialog
class _MapPickerDialog extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;

  const _MapPickerDialog({
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _selectedPosition;
  GoogleMapController? _mapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = LatLng(widget.initialLatitude, widget.initialLongitude);
    if (kDebugMode) {
      print(
        '📍 Map Picker initialized with: ${_selectedPosition.latitude}, ${_selectedPosition.longitude}',
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapTap(LatLng position) async {
    if (!_isMapReady) return;

    setState(() {
      _selectedPosition = position;
    });

    if (kDebugMode) {
      print('📍 Map tapped at: ${position.latitude}, ${position.longitude}');
    }

    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(position, 16),
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Camera animation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero, // Full screen
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.collectorPrimary,
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.map, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'Choose Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        debugPrint('🔴 X button clicked - returning null');
                        Navigator.pop(context, null);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedPosition,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) async {
                      if (kDebugMode) print('🗺️ Google Map created!');
                      _mapController = controller;

                      try {
                        // Wait for map to fully initialize
                        await Future.delayed(const Duration(milliseconds: 800));

                        // Animate to initial position
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_selectedPosition, 16),
                        );

                        setState(() {
                          _isMapReady = true;
                        });

                        if (kDebugMode) print('✅ Map ready and positioned');
                      } catch (e) {
                        if (kDebugMode) {
                          print('⚠️ Map initialization error: $e');
                        }
                        setState(() {
                          _isMapReady =
                              true; // Allow interaction even if animation fails
                        });
                      }
                    },
                    onTap: _onMapTap,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    onCameraMove: (position) {
                      if (_isMapReady) {
                        setState(() {
                          _selectedPosition = position.target;
                        });
                      }
                    },
                    onCameraIdle: () {
                      if (kDebugMode) {
                        print(
                          '📍 Camera idle at: ${_selectedPosition.latitude}, ${_selectedPosition.longitude}',
                        );
                      }
                    },
                    mapType: MapType.normal,
                    buildingsEnabled: true,
                    trafficEnabled: false,
                    indoorViewEnabled: true,
                    minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
                    // Add markers to show the selected position more clearly
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedPosition,
                        draggable: true,
                        onDragEnd: (newPosition) {
                          setState(() {
                            _selectedPosition = newPosition;
                          });
                          if (kDebugMode) {
                            print(
                              '📍 Marker dragged to: ${newPosition.latitude}, ${newPosition.longitude}',
                            );
                          }
                        },
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed, // Classic red marker
                        ),
                      ),
                    },
                  ),
                  // Loading indicator while map initializes
                  if (!_isMapReady)
                    Container(
                      color: Colors.white.withValues(alpha: 0.9),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.collectorPrimary,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading map...',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.collectorPrimary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.touch_app,
                            size: 18,
                            color: AppColors.collectorPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Drag the red marker or tap anywhere on the map to select your location',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.collectorPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        onPressed: () {
                          debugPrint(
                            '🟢 Confirm button clicked - returning $_selectedPosition',
                          );
                          Navigator.pop(context, _selectedPosition);
                        },
                        text: 'Confirm Location',
                        backgroundColor: AppColors.collectorPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
