import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../../../shared/utils/address_formatter.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../core/utils/phone_number_formatter.dart';
import '../../../widgets/address_map_card.dart';
import 'collector_step3_screen.dart';

class CollectorStep2Screen extends StatefulWidget {
  const CollectorStep2Screen({super.key});

  @override
  State<CollectorStep2Screen> createState() => _CollectorStep2ScreenState();
}

class _CollectorStep2ScreenState extends State<CollectorStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Personal Information controllers
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();

  // Contact/Address controllers
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  // Location
  double? _latitude;
  double? _longitude;

  bool _isLoading = false;
  bool _hasDriversLicense = true;
  String? _selectedLicenseType;
  String? _selectedExperience;

  final List<String> _licenseTypes = [
    'Professional Driver\'s License (PDL)',
    'Non-Professional Driver\'s License (NPDL)',
    'Student Permit',
    'Motorcycle License',
    'Expired License (for renewal)',
  ];

  final List<String> _experienceOptions = [
    'Less than 1 year',
    '1-2 years',
    '3-5 years',
    '5+ years',
    'No driving experience',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-fetch location when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentLocation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load personal info from step 1 only (not reapply data)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      // Load from step 1's flat structure
      if (args.containsKey('fullName') && _fullNameController.text.isEmpty) {
        _fullNameController.text = args['fullName']?.toString() ?? '';
      }
      if (args.containsKey('dateOfBirth') && _dobController.text.isEmpty) {
        _dobController.text = args['dateOfBirth']?.toString() ?? '';
      }
      if (args.containsKey('phone') && _phoneController.text.isEmpty) {
        _phoneController.text = args['phone']?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  // Get current location
  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: AppColors.errorColor,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
        return;
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint('=== COLLECTOR USE CURRENT LOCATION ===');
      debugPrint(
        'Position obtained: ${position.latitude}, ${position.longitude}',
      );

      // Set coordinates first (like household)
      _latitude = position.latitude;
      _longitude = position.longitude;
      debugPrint('Coordinates set: $_latitude, $_longitude');

      // Reverse geocode to get address (updates _addressController internally)
      await _reverseGeocodeWithGoogle(position.latitude, position.longitude);
      debugPrint(
        'After geocoding, controller text: ${_addressController.text}',
      );

      // Trigger rebuild after geocoding completes
      setState(() {
        _isLoading = false;
        debugPrint('setState called - triggering rebuild');
      });
      debugPrint('After setState, controller text: ${_addressController.text}');
      debugPrint('========================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated!'),
            backgroundColor: AppColors.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  // Reverse geocode using Google Maps Geocoding API (same as household registration)
  Future<void> _reverseGeocodeWithGoogle(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en',
    );

    try {
      debugPrint('=== COLLECTOR GEOCODING REQUEST ===');
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
          final fullAddress = formatFullAddressFromGoogleResults(results);

          debugPrint('=== EXTRACTED VALUES ===');
          // Component-level debug logging is centralized by the formatter logic now
          debugPrint('Full Address: $fullAddress');
          debugPrint('========================');

          _addressController.text = fullAddress;
        } else {
          final msg = (data['error_message'] ?? '').toString();
          debugPrint(
            'Geocoding API Error: ${data['status']} ${msg.isNotEmpty ? '- $msg' : ''}',
          );
          await _reverseGeocodeFallback(lat, lng);
        }
      } else {
        debugPrint('HTTP Error from Geocoding API: ${response.statusCode}');
        await _reverseGeocodeFallback(lat, lng);
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      await _reverseGeocodeFallback(lat, lng);
    }
  }

  // Fallback using the device geocoding package - only use if Google API completely fails
  // This is less detailed but better than nothing
  Future<void> _reverseGeocodeFallback(double lat, double lng) async {
    debugPrint('➡️ Using fallback geocoder (placemarkFromCoordinates)');
    debugPrint(
      '⚠️ WARNING: Fallback geocoder cannot extract barangay properly',
    );
    debugPrint(
      '⚠️ To fix: Enable Google Geocoding API with correct Android restrictions',
    );

    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // Build best-effort address from placemark
        final parts = <String>[];
        void add(String? s) {
          if (s != null && s.trim().isNotEmpty) parts.add(s.trim());
        }

        // Try to get as much detail as possible
        add(p.subThoroughfare); // house number
        add(p.thoroughfare ?? p.street); // street name
        add(p.subLocality); // might be subdivision or district
        add(p.subAdministrativeArea); // might have barangay
        add(p.locality); // city
        add(p.administrativeArea); // province
        add(p.postalCode);
        add(p.country ?? 'Philippines');

        final formatted = parts.join(', ');
        _addressController.text = formatted;

        debugPrint('Fallback address (incomplete): $formatted');
        debugPrint('⚠️ Note: This address may be missing barangay details');
      } else {
        debugPrint('Fallback geocoder returned no placemarks');
        _addressController.text =
            'Lat: $lat, Lng: $lng (Unable to get address)';
      }
    } catch (e) {
      debugPrint('Fallback geocoder error: $e');
      _addressController.text = 'Lat: $lat, Lng: $lng (Geocoding failed)';
    }
  }

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

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      // Validate location
      if (_latitude == null || _longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please set your location using current location or map',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      // Personal information (previously from step 1)
      final personal = {
        'full_name': _fullNameController.text.trim(),
        'date_of_birth': _dobController.text.trim(),
        'phone': _phoneController.text.trim().replaceAll(' ', ''),
      };

      // Contact information
      final contact = {
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'has_drivers_license': _hasDriversLicense,
        'license_type': _selectedLicenseType,
        'license_number': _licenseNumberController.text.trim(),
        'experience': _selectedExperience,
      };

      // Get incoming arguments to preserve application_attempts
      final incomingArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      final merged = <String, dynamic>{
        'personal': personal,
        'contact': contact,
        'step': 2,
      };

      // Preserve application_attempts counter if it exists
      if (incomingArgs != null &&
          incomingArgs.containsKey('application_attempts')) {
        merged['application_attempts'] = incomingArgs['application_attempts'];
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const CollectorStep3Screen(),
          settings: RouteSettings(arguments: merged),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing24,
                ),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: eighteenYearsAgo,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.collectorPrimary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dobController.text = DateFormat('MMMM d, yyyy').format(picked);
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacing32),

          // Personal Information Section
          Text(
            'Personal Information',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing8),

          Text(
            'Please complete the following fields to finish your collector profile.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Full Name
          CustomTextField(
            controller: _fullNameController,
            label: 'Full Name *',
            hint: 'Enter your complete name',
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

          const SizedBox(height: AppDimensions.spacing32),

          // Address Section with Map
          Text(
            'Home Address',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Address Map Card
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
            onUseCurrentLocation: _useCurrentLocation,
            onChangeLocation: () async {
              // Open full-screen map picker
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: EdgeInsets.zero,
                  child: _buildMapPicker(),
                ),
              );

              if (result != null) {
                setState(() {
                  _latitude = result['lat'];
                  _longitude = result['lng'];
                  _addressController.text = result['address'];
                });
              }
            },
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Note Field
          CustomTextField(
            controller: _noteController,
            label: 'Note (Optional)',
            hint: 'e.g., Near SM Mall, Beside Gas Station',
            prefixIcon: const Icon(
              Icons.note_outlined,
              color: AppColors.textSecondary,
            ),
            focusedBorderColor: AppColors.collectorPrimary,
          ),

          const SizedBox(height: AppDimensions.spacing32),

          // Driving Information Section
          Text(
            'Driving Information',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Driver's License Toggle
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver\'s License',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Do you have a valid driver\'s license?',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _hasDriversLicense,
                  onChanged: (value) {
                    setState(() {
                      _hasDriversLicense = value;
                      if (!value) {
                        _selectedLicenseType = null;
                        _licenseNumberController.clear();
                      }
                    });
                  },
                  activeColor: AppColors.collectorPrimary,
                ),
              ],
            ),
          ),

          // License Details (shown only if has license)
          if (_hasDriversLicense) ...[
            const SizedBox(height: AppDimensions.spacing20),

            // License Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedLicenseType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'License Type',
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.textSecondary,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.collectorPrimary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing12,
                  vertical: AppDimensions.spacing12,
                ),
              ),
              items: _licenseTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLicenseType = newValue;
                });
              },
              validator: (value) {
                if (_hasDriversLicense && (value == null || value.isEmpty)) {
                  return 'Please select license type';
                }
                return null;
              },
            ),

            const SizedBox(height: AppDimensions.spacing20),

            // License Number
            CustomTextField(
              controller: _licenseNumberController,
              label: 'License Number',
              hint: 'Enter license number',
              prefixIcon: const Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.textSecondary,
              ),
              validator: (value) {
                if (_hasDriversLicense && (value == null || value.isEmpty)) {
                  return 'Please enter license number';
                }
                if (_hasDriversLicense && value!.length < 8) {
                  return 'Please enter valid license number';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: AppDimensions.spacing20),

          // Driving Experience Dropdown
          DropdownButtonFormField<String>(
            value: _selectedExperience,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Driving Experience',
              prefixIcon: const Icon(
                Icons.speed_outlined,
                color: AppColors.textSecondary,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.collectorPrimary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.backgroundLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing12,
                vertical: AppDimensions.spacing12,
              ),
            ),
            items: _experienceOptions.map((String experience) {
              return DropdownMenuItem<String>(
                value: experience,
                child: Text(
                  experience,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedExperience = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select driving experience';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing40),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _isLoading ? null : _nextStep,
                  text: _isLoading ? 'Processing...' : 'Next Step',
                  backgroundColor: AppColors.collectorPrimary,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Progress info
          Text(
            'Next: Vehicle Information',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.spacing24),
        ],
      ),
    );
  }

  // Full-screen map picker matching junkshop design
  Widget _buildMapPicker() {
    LatLng initialPosition = _latitude != null && _longitude != null
        ? LatLng(_latitude!, _longitude!)
        : const LatLng(14.5995, 120.9842); // Default: Manila

    LatLng selectedPosition = initialPosition;
    String selectedAddress = _addressController.text;
    bool isLoadingAddress = false;
    GoogleMapController? mapController;

    return StatefulBuilder(
      builder: (context, setState) {
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
                  mapController = controller;
                },
                onCameraMove: (position) {
                  setState(() {
                    selectedPosition = position.target;
                  });
                },
                onCameraIdle: () async {
                  // Reverse geocode when camera stops moving
                  setState(() {
                    isLoadingAddress = true;
                  });
                  await _reverseGeocodeWithGoogle(
                    selectedPosition.latitude,
                    selectedPosition.longitude,
                  );
                  setState(() {
                    selectedAddress = _addressController.text;
                    isLoadingAddress = false;
                  });
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: selectedPosition,
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
                      color: AppColors.collectorPrimary,
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
                        mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(currentLatLng, 16),
                        );

                        // Update selected position
                        setState(() {
                          selectedPosition = currentLatLng;
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
                                color: AppColors.collectorPrimary,
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
                                    isLoadingAddress
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            selectedAddress.isEmpty
                                                ? 'Move map to select location'
                                                : selectedAddress,
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
                              Navigator.of(context).pop({
                                'lat': selectedPosition.latitude,
                                'lng': selectedPosition.longitude,
                                'address': selectedAddress,
                              });
                            },
                            backgroundColor: AppColors.collectorPrimary,
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
      },
    );
  }
}
