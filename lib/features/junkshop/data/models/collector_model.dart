import 'dart:math';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class Collector {
  final String id;
  final String name;
  final String? email;
  final String? profileImageUrl;
  final double rating;
  final int activeJobs;
  final String status; // 'online', 'offline'
  final double? latitude;
  final double? longitude;
  final DateTime? lastActive;
  final String? phoneNumber;
  final String? vehicleType;
  final String? address; // resolved human-readable address if provided
  final String? city;
  final String? barangay;
  final DateTime? approvedAt;
  // Debug fields to know where data came from (only used in debug builds)
  final String? debugPhoneSource;
  final String? debugAddressSource;

  const Collector({
    required this.id,
    required this.name,
    this.email,
    this.profileImageUrl,
    required this.rating,
    required this.activeJobs,
    required this.status,
    this.latitude,
    this.longitude,
    this.lastActive,
    this.phoneNumber,
    this.vehicleType,
    this.address,
    this.city,
    this.barangay,
    this.approvedAt,
    this.debugPhoneSource,
    this.debugAddressSource,
  });

  /// Builds a [Collector] from a raw collectors table row.
  factory Collector.fromRow(Map<String, dynamic> row) {
    final data = rowToDoc('collectors', row);
    final docId = row['id'].toString();

    // Check if data is nested under collector_profile
    final collectorProfile =
        data[UserFields.collectorProfile] as Map<String, dynamic>?;
    final profileData = collectorProfile ?? data;

    final locationMap =
        profileData[UserFields.location] as Map<String, dynamic>?;
    final personal = profileData['personal'] as Map<String, dynamic>?;
    final contact = profileData['contact'] as Map<String, dynamic>?;

    // Debug: Print the entire document structure
    if (kDebugMode) print('[DEBUG] Collector $docId full data: $data');
    if (kDebugMode) print('[DEBUG] collectorProfile: $collectorProfile');
    if (kDebugMode) print('[DEBUG] personal: $personal');
    if (kDebugMode) print('[DEBUG] contact: $contact');
    if (kDebugMode) print('[DEBUG] location: $locationMap');

    // Resolve phone from personal.phone specifically
    String? phoneSource;
    dynamic phoneRaw;
    if ((phoneRaw = personal?['phone']) != null) {
      phoneSource = 'personal.phone';
    } else if ((phoneRaw = personal?['phoneNumber']) != null) {
      phoneSource = 'personal.phoneNumber';
    } else if ((phoneRaw = personal?['phone_number']) != null) {
      phoneSource = 'personal.phone_number';
    } else if ((phoneRaw = personal?['mobile']) != null) {
      phoneSource = 'personal.mobile';
    } else if ((phoneRaw = data['phone_number']) != null) {
      phoneSource = 'phone_number';
    } else if ((phoneRaw = data['phoneNumber']) != null) {
      phoneSource = 'phoneNumber';
    } else if ((phoneRaw = data['phone']) != null) {
      phoneSource = 'phone';
    }
    final String? phoneResolved = phoneRaw?.toString();

    // Build full address from contact fields or use existing address
    String? addressSource;
    String? addressResolved;

    // Try to build a full address from contact components
    if (contact != null) {
      final parts = <String>[];
      if (contact['block_lot'] != null) {
        parts.add(contact['block_lot'].toString());
      }
      if (contact['address'] != null) parts.add(contact['address'].toString());
      if (contact['barangay'] != null) {
        parts.add(contact['barangay'].toString());
      }
      if (contact['city'] != null) parts.add(contact['city'].toString());

      if (parts.isNotEmpty) {
        addressResolved = parts.join(', ');
        addressSource = 'contact.composite';
      }
    }

    // Fallback to simple address fields if composite failed
    if (addressResolved == null || addressResolved.isEmpty) {
      dynamic addressRaw;
      if ((addressRaw = contact?['address']) != null) {
        addressSource = 'contact.address';
      } else if ((addressRaw = contact?['full_address']) != null) {
        addressSource = 'contact.full_address';
      } else if ((addressRaw = contact?['fullAddress']) != null) {
        addressSource = 'contact.fullAddress';
      } else if ((addressRaw = contact?['street_address']) != null) {
        addressSource = 'contact.street_address';
      } else if ((addressRaw = contact?['home_address']) != null) {
        addressSource = 'contact.home_address';
      } else if ((addressRaw = contact?['business_address']) != null) {
        addressSource = 'contact.business_address';
      } else if ((addressRaw = contact?['location']) != null) {
        addressSource = 'contact.location';
      } else if ((addressRaw = locationMap?['address']) != null) {
        addressSource = 'location.address';
      } else if ((addressRaw = locationMap?['business_address']) != null) {
        addressSource = 'location.business_address';
      } else if ((addressRaw = data['address']) != null) {
        addressSource = 'address';
      }
      addressResolved = addressRaw?.toString();
    }

    if (kDebugMode) {
      print('[DEBUG] Phone resolved: "$phoneResolved" from $phoneSource');
    }
    if (kDebugMode) {
      print('[DEBUG] Address resolved: "$addressResolved" from $addressSource');
    }

    // Extract city and barangay
    final city = contact?['city']?.toString();
    final barangay = contact?['barangay']?.toString();

    // Parse approval date with better error handling
    DateTime? approvedAtDate;
    if (data['approved_at'] != null) {
      if (data['approved_at'] is Timestamp) {
        approvedAtDate = (data['approved_at'] as Timestamp).toDate();
      } else {
        final dateStr = data['approved_at'].toString();
        approvedAtDate = DateTime.tryParse(dateStr);
        if (approvedAtDate == null) {
          if (kDebugMode) {
            print('[DEBUG] Failed to parse approved_at: "$dateStr"');
          }
        }
      }
    } else if (data['application_status_updated_at'] != null) {
      if (data['application_status_updated_at'] is Timestamp) {
        approvedAtDate = (data['application_status_updated_at'] as Timestamp)
            .toDate();
      } else {
        final dateStr = data['application_status_updated_at'].toString();
        approvedAtDate = DateTime.tryParse(dateStr);
      }
    }

    return Collector(
      id: docId,
      name:
          personal?[UserFields.fullName] ??
          personal?['fullName'] ??
          personal?[UserFields.name] ??
          data[UserFields.fullName] ??
          data['fullName'] ??
          data[UserFields.name] ??
          'Unknown Collector',
      email: data[UserFields.email],
      // Support both snake_case and camelCase keys - check both root and profile
      profileImageUrl:
          data[UserFields.profileImageUrl] ?? data['profileImageUrl'],
      rating: (data[UserFields.rating] as num?)?.toDouble() ?? 0.0,
      activeJobs: (data['active_jobs'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'offline',
      latitude: locationMap?[UserFields.latitude] as double?,
      longitude: locationMap?[UserFields.longitude] as double?,
      lastActive: data['last_active'] != null
          ? toDateTime(data['last_active'])
          : null,
      // Support multiple phone key variants, including nested under personal
      phoneNumber: phoneResolved,
      vehicleType: data[UserFields.vehicleType],
      // Address can be flat, inside location, or nested under contact
      address: addressResolved,
      city: city,
      barangay: barangay,
      approvedAt: approvedAtDate,
      debugPhoneSource: phoneSource,
      debugAddressSource: addressSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      UserFields.fullName: name,
      UserFields.profileImageUrl: profileImageUrl,
      UserFields.rating: rating,
      'active_jobs': activeJobs,
      'status': status,
      UserFields.location: latitude != null && longitude != null
          ? {UserFields.latitude: latitude, UserFields.longitude: longitude}
          : null,
      'last_active': lastActive != null
          ? Timestamp.fromDate(lastActive!)
          : null,
      'phone_number': phoneNumber,
      'vehicle_type': vehicleType,
      if (address != null) UserFields.address: address,
    };
  }

  // Helper method to calculate distance from a point
  double? distanceFrom(double lat, double lng) {
    if (latitude == null || longitude == null) return null;

    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(lat - latitude!);
    final double dLng = _degreesToRadians(lng - longitude!);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(latitude!)) *
            cos(_degreesToRadians(lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(1 - a), sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180);

  // Helper method to get status color
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'available':
        return '#10B981'; // green
      case 'busy':
        return '#F59E0B'; // yellow
      case 'offline':
        return '#6B7280'; // gray
      default:
        return '#6B7280';
    }
  }

  // Helper method to get display status
  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      default:
        return status;
    }
  }
}
