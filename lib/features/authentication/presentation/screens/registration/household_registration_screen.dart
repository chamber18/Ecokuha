import '../../widgets/address_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../core/utils/user_collection_helper.dart';
import '../../../../../core/utils/phone_number_formatter.dart';
import '../../../../../core/utils/text_utils.dart';
import '../../../../../shared/utils/address_formatter.dart';

class HouseholdRegistrationScreen extends StatefulWidget {
  const HouseholdRegistrationScreen({super.key});

  @override
  State<HouseholdRegistrationScreen> createState() =>
      _HouseholdRegistrationScreenState();
}

class _HouseholdRegistrationScreenState
    extends State<HouseholdRegistrationScreen> {
  // Google Geocoding API Key - loaded from environment
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _blockLotController = TextEditingController();
  // Simplified address entry: only complete address + optional note
  final _noteController = TextEditingController();

  bool _isLoading = false;
  bool _agreeToTerms = false;

  // Captured GPS state
  double? _latitude;
  double? _longitude;
  String? _geoAddress; // reverse-geocoded single-line address

  // Map controller for interactive map
  // ignore: unused_field
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // Automatically get current location when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentLocation();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _blockLotController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.householdPrimary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dobController.text = DateFormat('MMMM d, yyyy').format(picked);
      setState(() {});
    }
  }

  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() {
        _isLoading = true;
      });

      // Build normalized address string and persist to Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are not logged in'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      // Use the complete address field directly
      _addressController.text = _addressController.text.trim();

      try {
        await UserCollectionHelper.getUserDocument(
          user.id,
          'household',
        ).set({
          'full_name': TextUtils.capitalizeWords(_nameController.text.trim()),
          'phone': _phoneController.text.trim().replaceAll(' ', ''),
          'date_of_birth': _dobController.text.trim(),
          if (_latitude != null && _longitude != null)
            'location': {
              'lat': _latitude,
              'lng': _longitude,
              'address': _addressController.text.trim().isNotEmpty
                  ? _addressController.text.trim()
                  : _geoAddress,
              if (_noteController.text.trim().isNotEmpty)
                'note': _noteController.text.trim(),
            },
          'is_profile_complete': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, merge: true);

        setState(() {
          _isLoading = false;
        });

        _navigateToHouseholdHome();
      } on PostgrestException {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile. Please try again.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  void _navigateToHouseholdHome() {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile complete! You can customize more in your profile settings.',
        ),
        backgroundColor: AppColors.successColor,
        duration: Duration(seconds: 3),
      ),
    );

    // Clear the stack and go straight to the main Household dashboard
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/household-home',
      (route) => false,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check and request permission
      bool serviceEnabled;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } on MissingPluginException {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location plugin not registered yet. Please fully restart the app.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
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
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Enable it in Settings.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      // Get current position
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );
      } on MissingPluginException {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location plugin not available on this platform or app not restarted.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      _latitude = position.latitude;
      _longitude = position.longitude;

      debugPrint('=== LOCATION CAPTURED ===');
      debugPrint('Latitude: $_latitude');
      debugPrint('Longitude: $_longitude');
      debugPrint('=========================');

      // Use Google Geocoding API for better barangay data
      await _reverseGeocodeWithGoogle(position.latitude, position.longitude);

      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address captured! You can add an optional note.'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error using current location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  Future<void> _reverseGeocodeWithGoogle(double lat, double lng) async {
    try {
      // Google Geocoding API endpoint
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

          // Fill the single complete address field
          _geoAddress = fullAddress;
          _addressController.text = _geoAddress ?? '';
        } else {
          final msg = (data['error_message'] ?? '').toString();
          debugPrint(
            'Google Geocoding API Error: ${data['status']} ${msg.isNotEmpty ? '- $msg' : ''}',
          );
          _showFallbackMessage();
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        _showFallbackMessage();
      }
    } catch (e) {
      debugPrint('Error calling Google Geocoding API: $e');
      _showFallbackMessage();
    }
  }

  Future<void> _chooseLocationOnMap() async {
    debugPrint('🗺️ CHOOSE LOCATION ON MAP BUTTON CLICKED');

    // Start with current location or default to Philippines center
    final initialLat = _latitude ?? 12.8797;
    final initialLng = _longitude ?? 121.7740;

    debugPrint('📍 Initial position: $initialLat, $initialLng');
    debugPrint('🔄 Opening map dialog...');

    final LatLng? selectedLocation = await showDialog<LatLng>(
      context: context,
      builder: (context) {
        debugPrint('🏗️ Building _MapPickerDialog widget');
        return _MapPickerDialog(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          apiKey: _googleApiKey,
          headers: _googleAuthHeaders(),
        );
      },
    );

    if (selectedLocation != null) {
      _latitude = selectedLocation.latitude;
      _longitude = selectedLocation.longitude;

      debugPrint('=== LOCATION SELECTED FROM MAP ===');
      debugPrint('Latitude: $_latitude');
      debugPrint('Longitude: $_longitude');
      debugPrint('==================================');

      // Reverse geocode the selected location
      await _reverseGeocodeWithGoogle(
        selectedLocation.latitude,
        selectedLocation.longitude,
      );

      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated from map!'),
          backgroundColor: AppColors.successColor,
        ),
      );
    }
  }

  // Provide Google verification headers when key is restricted to Android/iOS apps.
  Map<String, String> _googleAuthHeaders() {
    final headers = <String, String>{};
    try {
      if (Platform.isAndroid) {
        headers['X-Android-Package'] = 'com.example.ecokuha';
        // SHA-1 without colons
        headers['X-Android-Cert'] = '6D37720CF6A19565D469A64F746A08728517438C';
      } else if (Platform.isIOS) {
        headers['X-Ios-Bundle-Identifier'] = 'com.example.EcoKuha';
      }
    } catch (_) {
      // Non-mobile platforms or tests
    }
    return headers;
  }

  void _showFallbackMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not auto-fill address. Please enter manually.'),
        backgroundColor: AppColors.warningColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: 375,
          height: 812,
          child: Column(
            children: [
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppDimensions.paddingLg),
                  child: _buildRegistrationForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: AppDimensions.paddingSm),
          Text(
            'Please provide your details to create your household account.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: AppDimensions.paddingXl),

          // Full Name Field
          CustomTextField(
            controller: _nameController,
            label: 'Full Name *',
            hint: 'Enter your full name',
            prefixIcon: const Icon(
              Icons.person_outline,
              color: AppColors.textSecondary,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              if (value.length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Date of Birth
          CustomTextField(
            controller: _dobController,
            label: 'Date of Birth *',
            hint: 'Select your date of birth',
            readOnly: true,
            onTap: _pickDateOfBirth,
            suffixIcon: const Icon(
              Icons.calendar_today,
              color: AppColors.textSecondary,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please select your date of birth';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Phone Field
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: '09 000 000 000',
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneNumberFormatter()],
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: AppColors.textSecondary,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
              if (digitsOnly.length < 11) {
                return 'Please enter a valid 11-digit phone number';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Address
          Text(
            'Address',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),

          // Address Card (Map + Editable Address) — loading only overlays the map preview
          AddressMapCard(
            latitude: _latitude,
            longitude: _longitude,
            controller: _addressController,
            isLoading: _isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
            onChangeLocation: _chooseLocationOnMap,
            onUseCurrentLocation: _useCurrentLocation,
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Removed standalone address field (now inside the map card)
          const SizedBox(height: AppDimensions.spacing4),

          // Location Note (optional)
          CustomTextField(
            controller: _noteController,
            label: 'Location Note (optional)',
            hint: 'Gate code, special instructions, nearby landmark',
            prefixIcon: const Icon(
              Icons.sticky_note_2_outlined,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Removed duplicate action row (actions are inside the card)
          const SizedBox(height: AppDimensions.spacing16),

          // Email/password removed: handled during account creation
          const SizedBox(height: AppDimensions.spacing8),

          // Terms and Conditions Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                activeColor: AppColors.householdPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _agreeToTerms = !_agreeToTerms;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.householdPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.householdPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing32),

          // Register Button
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              onPressed: _isLoading ? null : _handleRegistration,
              text: _isLoading ? 'Completing Profile...' : 'Go to Dashboard',
              backgroundColor: AppColors.householdPrimary,
              isLoading: _isLoading,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing24),
        ],
      ),
    );
  }
}

// Map Picker Dialog for choosing location
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
                          onPressed: () => Navigator.of(context).pop(),
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
                  color: AppColors.householdPrimary,
                ),
                onPressed: () async {
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
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
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
                            color: AppColors.householdPrimary,
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
                          Navigator.of(context).pop(_selectedPosition);
                        },
                        backgroundColor: AppColors.householdPrimary,
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
