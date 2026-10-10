import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../core/utils/phone_number_formatter.dart';
import '../../../../../../core/utils/text_utils.dart';
import '../../../../../../shared/utils/address_formatter.dart';
import '../../../widgets/address_map_card.dart';

class JunkshopStep1Screen extends StatefulWidget {
  const JunkshopStep1Screen({super.key});

  @override
  State<JunkshopStep1Screen> createState() => _JunkshopStep1ScreenState();
}

class _JunkshopStep1ScreenState extends State<JunkshopStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Location fields
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _serviceRadiusController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  double _serviceRadiusKm = 3.0; // Default 3km radius

  String? _selectedBusinessType;
  final bool _isLoading = false;
  bool _hasPickupService = true;

  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

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
    // Automatically fetch current location when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentLocation();
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _businessTypeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _serviceRadiusController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      final junkshopData = {
        'businessName': TextUtils.capitalizeWords(_businessNameController.text),
        'ownerFullName': TextUtils.capitalizeWords(
          _ownerNameController.text.trim(),
        ),
        'phone': _phoneController.text,
        'businessType': _selectedBusinessType,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'note': _noteController.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'serviceRadiusKm': _serviceRadiusKm,
        'hasPickupService': _hasPickupService,
        'step': 1,
      };

      Navigator.pushNamed(
        context,
        '/junkshop-register-5',
        arguments: junkshopData,
      );
    }
  }

  void _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Try Google Geocoding API first for richer address
      final googleSuccess = await _reverseGeocodeWithGoogle(
        position.latitude,
        position.longitude,
      );

      if (!googleSuccess) {
        // Fallback to device geocoding
        List<Placemark> placemarks = await placemarkFromCoordinates(
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
            _latitude = position.latitude;
            _longitude = position.longitude;
            _addressController.text = parts.join(', ');
          });
        }
      } else {
        // Google succeeded, just update coordinates
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get your location. Please try again.'),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<bool> _reverseGeocodeWithGoogle(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en',
    );
    try {
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
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final results = (data['results'] as List)
              .cast<Map<String, dynamic>>();
          final fullAddress = formatFullAddressFromGoogleResults(results);
          setState(() {
            _addressController.text = fullAddress;
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Google geocoding error: $e');
      return false;
    }
  }

  void _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _MapPickerDialog(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _addressController.text = result['address'] ?? '';
      });
    }
  }

  void _openServiceRadiusPicker() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your business location first'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ServiceRadiusPickerDialog(
          latitude: _latitude!,
          longitude: _longitude!,
          initialRadiusKm: _serviceRadiusKm,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _serviceRadiusKm = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.paddingLg),
          child: Column(
            children: [
              _buildForm(),

              const SizedBox(height: AppDimensions.spacing24),

              // Bottom action section
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Next Step',
                  onPressed: _nextStep,
                  isLoading: _isLoading,
                  backgroundColor: AppColors.junkshopPrimary,
                ),
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Progress info
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Next step: Review & Submit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacing24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Information',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: AppDimensions.paddingSm),
          Text(
            'Please provide your business details for verification.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: AppDimensions.paddingXl),

          // Business Name
          CustomTextField(
            controller: _businessNameController,
            label: 'Business Name *',
            hint: 'Enter your junk shop name',
            prefixIcon: const Icon(Icons.storefront_outlined),
            focusedBorderColor: AppColors.junkshopPrimary,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Business name is required';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: AppDimensions.paddingLg),

          // Owner/Manager Full Name (single field like household)
          CustomTextField(
            controller: _ownerNameController,
            label: 'Owner/Manager Full Name *',
            hint: 'Enter full name',
            prefixIcon: const Icon(Icons.person_outline),
            focusedBorderColor: AppColors.junkshopPrimary,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              if (value.trim().length < 2) {
                return 'Please enter a valid name';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: AppDimensions.paddingLg),

          // Phone Number (use collector-style placeholder and stroke)
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: '09 000 000 000',
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneNumberFormatter()],
            prefixIcon: const Icon(Icons.phone),
            focusedBorderColor: AppColors.junkshopPrimary,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
              if (digitsOnly.length < 11) {
                return 'Enter a valid 11-digit phone number';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: AppDimensions.paddingLg),

          // Business Type Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Type *',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppDimensions.paddingSm),
              DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                decoration: InputDecoration(
                  hintText: 'Select business type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.inputRadius,
                    ),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.inputRadius,
                    ),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.inputRadius,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.junkshopPrimary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingLg,
                    vertical: AppDimensions.paddingMd,
                  ),
                ),
                items: _businessTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedBusinessType = value),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please select a business type'
                    : null,
              ),
            ],
          ),

          SizedBox(height: AppDimensions.paddingLg),

          // Description
          CustomTextField(
            controller: _descriptionController,
            label: 'Business Description (Optional)',
            hint: 'Describe your services, specialization, etc.',
            maxLines: 4,
            prefixIcon: const Icon(Icons.description_outlined),
            focusedBorderColor: AppColors.junkshopPrimary,
          ),

          SizedBox(height: AppDimensions.paddingLg),

          // Location Section Header
          Text(
            'Location',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: AppDimensions.paddingSm),
          Text(
            'Provide your business location details.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: AppDimensions.paddingLg),

          // Address Map Card
          AddressMapCard(
            latitude: _latitude,
            longitude: _longitude,
            controller: _addressController,
            onChangeLocation: _openMapPicker,
            onUseCurrentLocation: _useCurrentLocation,
            isLoading: _isLoadingLocation,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your business address';
              }
              if (value.length < 10) {
                return 'Please enter a complete address';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacing20),

          // Note Field (previously Landmark)
          CustomTextField(
            controller: _noteController,
            label: 'Note (Optional)',
            hint: 'e.g., Near SM Mall, Beside Gas Station',
            prefixIcon: const Icon(
              Icons.note_outlined,
              color: AppColors.textSecondary,
            ),
            focusedBorderColor: AppColors.junkshopPrimary,
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Pickup Service Toggle
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Service',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        'Offer waste collection service',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hasPickupService,
                  onChanged: (value) {
                    setState(() => _hasPickupService = value);
                  },
                  activeColor: AppColors.junkshopPrimary,
                ),
              ],
            ),
          ),

          if (_hasPickupService) ...[
            const SizedBox(height: AppDimensions.spacing20),
            Text(
              'Service Radius *',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'Select how far you can provide pickup service',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            InkWell(
              onTap: _openServiceRadiusPicker,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.location_searching,
                        color: AppColors.junkshopPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_serviceRadiusKm.toStringAsFixed(1)} km radius',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to adjust on map',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Map Picker Dialog
class _MapPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const _MapPickerDialog({this.initialLatitude, this.initialLongitude});

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
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _getAddressFromLatLng(_selectedPosition!);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoadingAddress = true);

    // Try Google first
    final googleSuccess = await _reverseGeocodeWithGoogle(
      position.latitude,
      position.longitude,
    );

    if (googleSuccess) {
      setState(() => _isLoadingAddress = false);
      return;
    }

    // Fallback to placemark
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
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
      debugPrint('Error getting address: $e');
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<bool> _reverseGeocodeWithGoogle(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en',
      );

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
      if (response.statusCode != 200) return false;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return false;

      final results = (data['results'] as List).cast<Map<String, dynamic>>();
      if (results.isEmpty) return false;

      final formatted = formatFullAddressFromGoogleResults(results);
      setState(() {
        _selectedAddress = formatted;
      });
      return true;
    } catch (e) {
      debugPrint('Google geocoding error: $e');
      return false;
    }
  }

  void _confirmLocation() {
    if (_selectedPosition != null) {
      Navigator.of(context).pop({
        'latitude': _selectedPosition!.latitude,
        'longitude': _selectedPosition!.longitude,
        'address': _selectedAddress,
      });
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
        _selectedPosition ?? const LatLng(14.5995, 120.9842); // Default: Manila

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

/// Dialog for visually selecting service radius with interactive map and circle
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
    _currentRadiusKm = widget.initialRadiusKm;
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
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('service_radius'),
                center: LatLng(widget.latitude, widget.longitude),
                radius: _currentRadiusKm * 1000, // Convert km to meters
                fillColor: Colors.blue.withValues(alpha: 0.15),
                strokeColor: Colors.blue,
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
