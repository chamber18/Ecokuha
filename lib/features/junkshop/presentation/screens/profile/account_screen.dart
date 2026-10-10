import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/utils/phone_number_formatter.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../shared/utils/address_formatter.dart';
import '../../../../authentication/presentation/widgets/address_map_card.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.businessInfo});

  final Map<String, dynamic> businessInfo;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // Editing flags
  bool _editPersonal = false;
  bool _editBusiness = false;
  bool _editBusinessHours = false;
  bool _editAccount = false;
  bool _isGoogleUser = false;

  // Original values for cancel functionality
  late String _originalOwner;
  late String _originalEmail;
  late String _originalPhone;
  late String _originalBusinessName;
  late String _originalBusinessType;
  late String _originalAddress;
  late String _originalServiceRadius;
  late String _originalDescription;

  // Controllers
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _serviceRadiusCtrl;
  late final TextEditingController _descriptionCtrl;

  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  // Location coordinates
  double? _latitude;
  double? _longitude;
  String? _geoAddress;

  // Business hours state
  String _fromDay = 'Monday';
  String _toDay = 'Sunday';
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 18, minute: 0);

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _businessTypes = [
    'Small Junk Shop',
    'Medium Junk Shop',
    'Large Junk Shop',
    'Recycling Center',
    'Scrap Metal Dealer',
    'Paper & Cardboard Specialist',
    'Plastic Recycling Center',
    'Electronics Recycling',
  ];

  @override
  void initState() {
    super.initState();

    // Check if user signed in with Google
    _isGoogleUser = widget.businessInfo['signInProvider'] == 'google.com';
    debugPrint(
      '🔐 Junkshop Account Settings: signInProvider=${widget.businessInfo['signInProvider']}, _isGoogleUser=$_isGoogleUser',
    );

    // Initialize controllers
    _ownerCtrl = TextEditingController(
      text: widget.businessInfo['owner'] ?? '',
    );
    _emailCtrl = TextEditingController(
      text: widget.businessInfo['email'] ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: formatPhoneNumber(widget.businessInfo['phone']),
    );
    _nameCtrl = TextEditingController(text: widget.businessInfo['name'] ?? '');
    _typeCtrl = TextEditingController(
      text: widget.businessInfo['businessType'] ?? '',
    );

    // Initialize location coordinates from nested location object
    final location = widget.businessInfo['location'] as Map<String, dynamic>?;
    _latitude = location?['lat'] as double?;
    _longitude = location?['lng'] as double?;

    // Debug: Print loaded coordinates
    debugPrint('🟢 AccountScreen initState loaded coordinates:');
    debugPrint('  Location object: $location');
    debugPrint('  Latitude: $_latitude');
    debugPrint('  Longitude: $_longitude');
    debugPrint('  BusinessInfo keys: ${widget.businessInfo.keys}');

    _addressCtrl = TextEditingController(
      text: location?['address'] ?? widget.businessInfo['address'] ?? '',
    );
    debugPrint('  Address: ${_addressCtrl.text}');

    _serviceRadiusCtrl = TextEditingController(
      text:
          (location?['service_radius'] ??
                  widget.businessInfo['serviceRadius'] ??
                  widget.businessInfo['operationRadius'] ??
                  '')
              .toString(),
    );
    _descriptionCtrl = TextEditingController(
      text: widget.businessInfo['description'] ?? '',
    );

    // Initialize business hours from junkshop_profile.business
    _fromDay = widget.businessInfo['from_day'] ?? 'Monday';
    _toDay = widget.businessInfo['to_day'] ?? 'Sunday';

    // Parse open_time (format: "08:00")
    final openTimeStr = widget.businessInfo['open_time'] ?? '08:00';
    final openParts = openTimeStr.split(':');
    _openTime = TimeOfDay(
      hour: int.tryParse(openParts[0]) ?? 8,
      minute: int.tryParse(openParts[1]) ?? 0,
    );

    // Parse close_time (format: "18:00")
    final closeTimeStr = widget.businessInfo['close_time'] ?? '18:00';
    final closeParts = closeTimeStr.split(':');
    _closeTime = TimeOfDay(
      hour: int.tryParse(closeParts[0]) ?? 18,
      minute: int.tryParse(closeParts[1]) ?? 0,
    );

    // Store original values for cancel functionality
    _originalOwner = _ownerCtrl.text;
    _originalEmail = _emailCtrl.text;
    _originalPhone = _phoneCtrl.text;
    _originalBusinessName = _nameCtrl.text;
    _originalBusinessType = _typeCtrl.text;
    _originalAddress = _addressCtrl.text;
    _originalServiceRadius = _serviceRadiusCtrl.text;
    _originalDescription = _descriptionCtrl.text;
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _addressCtrl.dispose();
    _serviceRadiusCtrl.dispose();
    _descriptionCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _chooseLocationOnMap() async {
    // Save original values in case user cancels
    final originalLat = _latitude;
    final originalLng = _longitude;
    final originalAddress = _addressCtrl.text;

    debugPrint('🟢 Opening map dialog with original values:');
    debugPrint('  Lat: $originalLat, Lng: $originalLng');
    debugPrint('  Address: $originalAddress');

    final initialLat = _latitude ?? 14.5995;
    final initialLng = _longitude ?? 120.9842;

    final LatLng? selectedLocation = await showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
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

      // Get address from geocoding
      await _getAddressFromLatLng(selectedLocation);

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
      _latitude = originalLat;
      _longitude = originalLng;
      _addressCtrl.text = originalAddress;
      debugPrint('  Restored address to: ${_addressCtrl.text}');

      setState(() {});
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    debugPrint(
      '🔵 _getAddressFromLatLng called with: ${position.latitude}, ${position.longitude}',
    );
    // First attempt: Google Geocoding API for richer components (same strategy as collector)
    final success = await _reverseGeocodeWithGoogle(
      position.latitude,
      position.longitude,
    );
    if (success) {
      debugPrint('✅ Google geocoding succeeded');
      return; // Already formatted & assigned
    }

    debugPrint('⚠️ Google geocoding failed, falling back to placemark');
    // Fallback to device placemark API if Google fails
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        void add(String? s) {
          if (s != null && s.trim().isNotEmpty) parts.add(s.trim());
        }

        add(p.subThoroughfare);
        add(p.thoroughfare ?? p.street);
        add(p.subLocality);
        add(p.subAdministrativeArea);
        add(p.locality);
        add(p.administrativeArea);
        add(p.postalCode);
        add(p.country ?? 'Philippines');
        _geoAddress = parts.join(', ');
        if (_geoAddress != null && _geoAddress!.isNotEmpty) {
          _addressCtrl.text = _geoAddress!;
          debugPrint('✅ Fallback placemark address: $_geoAddress');
        }
      } else {
        _showFallbackMessage();
      }
    } catch (e) {
      debugPrint('⚠️ Fallback geocoding error: $e');
      _showFallbackMessage();
    }
  }

  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  Future<bool> _reverseGeocodeWithGoogle(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en',
    );
    try {
      debugPrint('=== JUNKSHOP GEOCODING REQUEST ===');
      debugPrint('Latitude: $lat, Longitude: $lng');
      final response = await http.get(url, headers: _googleAuthHeaders());
      debugPrint('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('API Status: ${data['status']}');
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final results = (data['results'] as List)
              .cast<Map<String, dynamic>>();
          debugPrint('=== RAW GOOGLE RESULTS ===');
          debugPrint('Number of results: ${results.length}');
          if (results.isNotEmpty) {
            debugPrint(
              'First result formatted_address: ${results.first['formatted_address']}',
            );
            final components = results.first['address_components'] as List;
            debugPrint('Components count: ${components.length}');
            for (var comp in components) {
              debugPrint('  ${comp['types']}: ${comp['long_name']}');
            }
          }
          final fullAddress = formatFullAddressFromGoogleResults(results);
          debugPrint('=== FORMATTED ADDRESS ===');
          debugPrint('Full Address: $fullAddress');
          debugPrint('========================');
          _geoAddress = fullAddress;
          _addressCtrl.text = fullAddress;
          return true;
        } else {
          final msg = (data['error_message'] ?? '').toString();
          debugPrint(
            'Geocoding API Error: ${data['status']} ${msg.isNotEmpty ? '- $msg' : ''}',
          );
          return false;
        }
      } else {
        debugPrint('HTTP Error from Geocoding API: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Geocoding error (Google): $e');
      return false;
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
    } catch (_) {
      // Non-mobile platforms (web/desktop) ignore
    }
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        debugPrint('🔔 ProfileBloc state changed: ${state.runtimeType}');
        if (state is ProfileError) {
          debugPrint('❌ Profile error: ${state.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        } else if (state is ProfileLoaded) {
          debugPrint('✅ Profile loaded successfully after update');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                'Personal Information',
                _editPersonal,
                onEdit: () {
                  setState(() => _editPersonal = !_editPersonal);
                  if (!_editPersonal) _savePersonal();
                },
                onCancel: _editPersonal ? _cancelPersonal : null,
              ),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editPersonal) ...[
                      _textFieldRow(Icons.badge, 'Owner', _ownerCtrl),
                      if (_isGoogleUser) ...[
                        _infoRow(
                          Icons.email,
                          'Email',
                          _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 40, top: 4),
                          child: Text(
                            'Email managed by Google account',
                            style: AppTextStyles.caption.copyWith(
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
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
                      _infoRow(
                        Icons.badge,
                        'Owner',
                        _ownerCtrl.text.isEmpty ? '—' : _ownerCtrl.text,
                      ),
                      _infoRow(
                        Icons.email,
                        'Email',
                        _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text,
                      ),
                      _infoRow(
                        Icons.phone,
                        'Phone',
                        _phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spacing16),

              _sectionHeader(
                'Business Information',
                _editBusiness,
                onEdit: () {
                  setState(() => _editBusiness = !_editBusiness);
                  if (!_editBusiness) _saveBusiness();
                },
                onCancel: _editBusiness ? _cancelBusiness : null,
              ),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editBusiness) ...[
                      _textFieldRow(Icons.store, 'Business Name', _nameCtrl),
                      _businessTypeDropdown(),
                      const SizedBox(height: AppDimensions.spacing12),
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
                      const SizedBox(height: AppDimensions.spacing12),
                      _radiusPickerRow(),
                    ] else ...[
                      _infoRow(
                        Icons.store,
                        'Business Name',
                        _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text,
                      ),
                      _infoRow(
                        Icons.business,
                        'Business Type',
                        _typeCtrl.text.isEmpty ? '—' : _typeCtrl.text,
                      ),
                      _infoRow(
                        Icons.location_on,
                        'Address',
                        _addressCtrl.text.isEmpty ? '—' : _addressCtrl.text,
                      ),
                      _infoRow(
                        Icons.my_location,
                        'Service Radius',
                        _serviceRadiusCtrl.text.isEmpty
                            ? '—'
                            : '${_serviceRadiusCtrl.text} km',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spacing20),

              // Business Hours Section
              _sectionHeader(
                'Business Hours',
                _editBusinessHours,
                onEdit: () {
                  setState(() => _editBusinessHours = !_editBusinessHours);
                  if (!_editBusinessHours) _saveBusinessHours();
                },
                onCancel: _editBusinessHours ? _cancelBusinessHours : null,
              ),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: _editBusinessHours
                    ? _buildBusinessHoursEditor()
                    : _buildBusinessHoursDisplay(),
              ),

              const SizedBox(height: AppDimensions.spacing20),

              // Hide password change for Google users
              if (!_isGoogleUser) ...[
                _sectionHeader(
                  'Account Settings',
                  _editAccount,
                  onEdit: () {
                    setState(() => _editAccount = !_editAccount);
                    if (!_editAccount) _saveAccountSettings();
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
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: AppColors.junkshopPrimary,
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
        ),
      ),
    );
  }

  // Section title handled by _sectionHeader with edit icons

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
                        color: AppColors.junkshopPrimary,
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
                            color: AppColors.junkshopPrimary,
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
              color: AppColors.junkshopPrimary,
              size: 20,
            ),
            tooltip: isEditing ? 'Save' : 'Edit',
          ),
        ],
      ),
    );
  }

  void _savePersonal() {
    debugPrint('💾 Saving personal information...');
    debugPrint('  Owner: ${_ownerCtrl.text}');
    debugPrint('  Email: ${_emailCtrl.text}');
    debugPrint('  Phone: ${getPlainPhoneNumber(_phoneCtrl.text)}');

    final profileData = {
      'full_name': _ownerCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': getPlainPhoneNumber(_phoneCtrl.text),
    };

    context.read<ProfileBloc>().add(UpdateProfileEvent(profileData));

    // Update original values after save
    _originalOwner = _ownerCtrl.text;
    _originalEmail = _emailCtrl.text;
    _originalPhone = _phoneCtrl.text;

    debugPrint('✅ Personal information save triggered');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Personal information saved'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  void _cancelPersonal() {
    setState(() {
      _ownerCtrl.text = _originalOwner;
      _emailCtrl.text = _originalEmail;
      _phoneCtrl.text = _originalPhone;
      _editPersonal = false;
    });
  }

  void _saveBusiness() {
    debugPrint('💾 Saving business information...');
    debugPrint('  Business Name: ${_nameCtrl.text}');
    debugPrint('  Business Type: ${_typeCtrl.text}');
    debugPrint('  Address: ${_addressCtrl.text}');
    debugPrint('  Service Radius: ${_serviceRadiusCtrl.text}');
    debugPrint('  Location: $_latitude, $_longitude');

    final parsedRadius = double.tryParse(_serviceRadiusCtrl.text) ?? 0.0;
    debugPrint('  ⚠️ PARSED RADIUS VALUE: $parsedRadius');

    final businessData = {
      'junkshop_profile': {
        'business': {
          'business_name': _nameCtrl.text.trim(),
          'business_type': _typeCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim(),
        },
        'location': {
          'address': _addressCtrl.text.trim(),
          'service_radius': parsedRadius,
          if (_latitude != null) 'lat': _latitude,
          if (_longitude != null) 'lng': _longitude,
        },
      },
    };

    debugPrint('📤 Sending update with ${businessData.length} fields');
    debugPrint('📤 FULL businessData map: $businessData');
    context.read<ProfileBloc>().add(UpdateProfileEvent(businessData));

    // Update original values after save
    _originalBusinessName = _nameCtrl.text;
    _originalBusinessType = _typeCtrl.text;
    _originalAddress = _addressCtrl.text;
    _originalServiceRadius = _serviceRadiusCtrl.text;
    _originalDescription = _descriptionCtrl.text;

    debugPrint('✅ Business information save triggered');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business information saved'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  void _cancelBusiness() {
    setState(() {
      _nameCtrl.text = _originalBusinessName;
      _typeCtrl.text = _originalBusinessType;
      _addressCtrl.text = _originalAddress;
      _serviceRadiusCtrl.text = _originalServiceRadius;
      _descriptionCtrl.text = _originalDescription;
      _editBusiness = false;
    });
  }

  void _saveBusinessHours() {
    final openTimeStr =
        '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}';
    final closeTimeStr =
        '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}';

    final hoursData = {
      'junkshop_profile': {
        'business': {
          'from_day': _fromDay,
          'to_day': _toDay,
          'open_time': openTimeStr,
          'close_time': closeTimeStr,
        },
      },
    };

    debugPrint('💾 Saving business hours...');
    debugPrint('  Hours: $_fromDay-$_toDay, $openTimeStr-$closeTimeStr');

    context.read<ProfileBloc>().add(UpdateProfileEvent(hoursData));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business hours saved'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  void _cancelBusinessHours() {
    // Reload from widget.businessInfo
    final openTimeStr = widget.businessInfo['open_time'] ?? '08:00';
    final openParts = openTimeStr.split(':');
    final closeTimeStr = widget.businessInfo['close_time'] ?? '18:00';
    final closeParts = closeTimeStr.split(':');

    setState(() {
      _fromDay = widget.businessInfo['from_day'] ?? 'Monday';
      _toDay = widget.businessInfo['to_day'] ?? 'Sunday';
      _openTime = TimeOfDay(
        hour: int.tryParse(openParts[0]) ?? 8,
        minute: int.tryParse(openParts[1]) ?? 0,
      );
      _closeTime = TimeOfDay(
        hour: int.tryParse(closeParts[0]) ?? 18,
        minute: int.tryParse(closeParts[1]) ?? 0,
      );
      _editBusinessHours = false;
    });
  }

  Widget _businessTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        children: [
          const Icon(Icons.business, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Type',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _typeCtrl.text.isEmpty ? null : _typeCtrl.text,
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
                        color: AppColors.junkshopPrimary,
                        width: 2,
                      ),
                    ),
                  ),
                  items: _businessTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _typeCtrl.text = value ?? '';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radiusPickerRow() {
    final double current = double.tryParse(_serviceRadiusCtrl.text) ?? 3.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        children: [
          const Icon(
            Icons.my_location,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Radius',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _openServiceRadiusPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      border: Border.all(
                        color: AppColors.junkshopPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radio_button_checked,
                          color: AppColors.junkshopPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${current.toStringAsFixed(1)} km radius',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.junkshopPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.edit,
                          color: AppColors.junkshopPrimary,
                          size: 18,
                        ),
                      ],
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

  void _openServiceRadiusPicker() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your location first'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final double current = double.tryParse(_serviceRadiusCtrl.text) ?? 3.0;

    final double? result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ServiceRadiusPickerDialog(
        latitude: _latitude!,
        longitude: _longitude!,
        initialRadiusKm: current,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _serviceRadiusCtrl.text = result.toStringAsFixed(1);
      });
    }
  }

  void _saveAccountSettings() {
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
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account settings saved')));
  }

  Widget _buildBusinessHoursEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Text(
              'Business Hours',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.junkshopPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.junkshopPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // Days selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From Day', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _fromDay,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: _daysOfWeek.map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text(day),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _fromDay = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To Day', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _toDay,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: _daysOfWeek.map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text(day),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _toDay = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Time selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Open Time', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _selectTime(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text(_openTime.format(context)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Close Time', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _selectTime(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text(_closeTime.format(context)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessHoursDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Hours',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$_fromDay - $_toDay: ${_openTime.format(context)} - ${_closeTime.format(context)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectTime(BuildContext context, bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
    );

    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }
}

// Map Picker Dialog - Matches Junkshop Registration Design
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
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String _selectedAddress = '';
  bool _isLoadingAddress = false;

  // Google Maps API key - loaded from environment
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _selectedPosition = LatLng(widget.initialLatitude, widget.initialLongitude);
    _getAddressFromLatLng(_selectedPosition!);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    debugPrint(
      '🔵 MAP DIALOG _getAddressFromLatLng called: ${position.latitude}, ${position.longitude}',
    );
    setState(() => _isLoadingAddress = true);
    // Attempt Google rich geocoding first
    final googleSuccess = await _reverseGeocodeWithGoogle(
      position.latitude,
      position.longitude,
    );
    if (googleSuccess) {
      debugPrint('✅ Google succeeded for map dialog');
      setState(() => _isLoadingAddress = false);
      return;
    }
    debugPrint('⚠️ Google failed, using placemark fallback');
    // Fallback to placemark
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        void add(String? s) {
          if (s != null && s.trim().isNotEmpty) parts.add(s.trim());
        }

        add(p.subThoroughfare);
        add(p.thoroughfare ?? p.street);
        add(p.subLocality);
        add(p.subAdministrativeArea);
        add(p.locality);
        add(p.administrativeArea);
        add(p.postalCode);
        add(p.country ?? 'Philippines');
        setState(() {
          _selectedAddress = parts.join(', ');
        });
      }
    } catch (e) {
      debugPrint('Error getting fallback address: $e');
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<bool> _reverseGeocodeWithGoogle(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en',
      );
      debugPrint('=== MAP PICKER GEOCODING ===');
      debugPrint('Lat: $lat, Lng: $lng');

      // Add auth headers just like the main method
      final headers = <String, String>{};
      try {
        if (Platform.isAndroid) {
          headers['X-Android-Package'] = 'com.example.ecokuha';
          headers['X-Android-Cert'] =
              '6D37720CF6A19565D469A64F746A08728517438C';
        } else if (Platform.isIOS) {
          headers['X-Ios-Bundle-Identifier'] = 'com.example.EcoKuha';
        }
      } catch (_) {}

      final response = await http.get(url, headers: headers);
      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('HTTP error: ${response.statusCode}');
        return false;
      }
      final data = json.decode(response.body);
      debugPrint('API Status: ${data['status']}');

      if (data['status'] != 'OK') {
        final msg = (data['error_message'] ?? '').toString();
        debugPrint(
          'API error: ${data['status']} ${msg.isNotEmpty ? '- $msg' : ''}',
        );
        return false;
      }
      final results = (data['results'] as List).cast<Map<String, dynamic>>();
      if (results.isEmpty) return false;
      debugPrint('Google returned ${results.length} results');
      final formatted = formatFullAddressFromGoogleResults(results);
      debugPrint('Formatted: $formatted');
      setState(() {
        _selectedAddress = formatted;
      });
      return true;
    } catch (e) {
      debugPrint('Google reverse geocode failed: $e');
      return false;
    }
  }

  void _confirmLocation() {
    if (_selectedPosition != null) {
      Navigator.of(context).pop(_selectedPosition);
    }
  }

  Future<void> _centerToCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      // Animate camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLocation, zoom: 16),
        ),
      );

      // Update selected position
      setState(() {
        _selectedPosition = currentLocation;
      });

      // Get address for the new position
      _getAddressFromLatLng(currentLocation);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition =
        _selectedPosition ?? const LatLng(14.5995, 120.9842);

    return Scaffold(
      body: Stack(
        children: [
          // Google Map (Full Screen)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
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
            onCameraIdle: () {
              if (_selectedPosition != null) {
                _getAddressFromLatLng(_selectedPosition!);
              }
            },
            markers: _selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedPosition!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
          ),

          // Top bar with gradient
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
                          onPressed: () => Navigator.of(context).pop(null),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Select Location',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: Colors.white,
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

          // Center to current location button
          Positioned(
            right: 16,
            bottom: 220, // Position above the bottom sheet
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.my_location,
                  color: AppColors.junkshopPrimary,
                  size: 24,
                ),
                onPressed: _centerToCurrentLocation,
                tooltip: 'Go to current location',
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
                            color: AppColors.junkshopPrimary,
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
                        onPressed: _selectedPosition != null
                            ? _confirmLocation
                            : null,
                        backgroundColor: AppColors.junkshopPrimary,
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

// Service Radius Picker Dialog with Map and Circle
class _ServiceRadiusPickerDialog extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double initialRadiusKm;

  const _ServiceRadiusPickerDialog({
    required this.latitude,
    required this.longitude,
    required this.initialRadiusKm,
  });

  @override
  State<_ServiceRadiusPickerDialog> createState() =>
      _ServiceRadiusPickerDialogState();
}

class _ServiceRadiusPickerDialogState
    extends State<_ServiceRadiusPickerDialog> {
  late double _currentRadiusKm;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // Clamp the initial radius between 1.0 and 50.0 km
    _currentRadiusKm = widget.initialRadiusKm.clamp(1.0, 50.0);
  }

  void _confirmRadius() {
    Navigator.pop(context, _currentRadiusKm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Google Map with circle overlay
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: _getZoomLevel(_currentRadiusKm),
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('business_location'),
                position: LatLng(widget.latitude, widget.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('service_radius'),
                center: LatLng(widget.latitude, widget.longitude),
                radius: _currentRadiusKm * 1000, // Convert km to meters
                fillColor: AppColors.junkshopPrimary.withValues(alpha: 0.15),
                strokeColor: AppColors.junkshopPrimary,
                strokeWidth: 2,
              ),
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Select Service Radius',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet with slider
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLg),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Radius display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Service Radius',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.junkshopPrimary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                            ),
                            child: Text(
                              '${_currentRadiusKm.toStringAsFixed(1)} km',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.junkshopPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacing16),

                      // Slider
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.junkshopPrimary,
                          inactiveTrackColor: AppColors.junkshopPrimary
                              .withValues(alpha: 0.2),
                          thumbColor: AppColors.junkshopPrimary,
                          overlayColor: AppColors.junkshopPrimary.withValues(
                            alpha: 0.2,
                          ),
                          valueIndicatorColor: AppColors.junkshopPrimary,
                          valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Slider(
                          value: _currentRadiusKm,
                          min: 1.0,
                          max: 50.0,
                          divisions: 49,
                          label: '${_currentRadiusKm.toStringAsFixed(1)} km',
                          onChanged: (value) {
                            setState(() {
                              _currentRadiusKm = value;
                            });
                            // Adjust zoom based on radius
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(widget.latitude, widget.longitude),
                                _getZoomLevel(value),
                              ),
                            );
                          },
                        ),
                      ),

                      // Range indicators
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '1 km',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '50 km',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spacing20),

                      // Confirm button
                      CustomButton(
                        text: 'Confirm Radius',
                        onPressed: _confirmRadius,
                        backgroundColor: AppColors.junkshopPrimary,
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

  // Calculate appropriate zoom level based on radius
  double _getZoomLevel(double radiusKm) {
    if (radiusKm <= 2) return 14.0;
    if (radiusKm <= 5) return 13.0;
    if (radiusKm <= 10) return 12.0;
    if (radiusKm <= 20) return 11.0;
    if (radiusKm <= 30) return 10.0;
    return 9.0;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
