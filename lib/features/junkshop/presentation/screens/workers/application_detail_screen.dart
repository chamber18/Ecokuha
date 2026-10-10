import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/phone_number_formatter.dart';
import '../collectors/collector_profile_screen.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final String applicationId;
  final Map<String, dynamic> applicationData;

  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.applicationData,
  });

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  double? _junkshopLat;
  double? _junkshopLng;
  String? _distance;

  /// Object path (private `documents` bucket) -> short-lived signed URL.
  final Map<String, String> _signedUrls = {};

  /// Resolves a stored document value (object path or legacy URL) for display.
  String _docUrl(dynamic value) {
    final v = value?.toString() ?? '';
    if (v.startsWith('http')) return v;
    return _signedUrls[v] ?? v;
  }

  Future<void> _loadSignedDocuments() async {
    final profile =
        widget.applicationData['collector_profile'] as Map<String, dynamic>?;
    final documents = profile?['documents'] as Map<String, dynamic>?;
    if (documents == null) return;
    for (final value in documents.values) {
      if (value is String && value.isNotEmpty && !value.startsWith('http')) {
        try {
          final url = await signedDocumentUrl(value);
          if (!mounted) return;
          setState(() => _signedUrls[value] = url);
        } catch (e) {
          debugPrint('❌ Error signing document $value: $e');
        }
      }
    }
  }

  String _resolveFullName(
    Map<String, dynamic>? personal,
    Map<String, dynamic> root,
  ) {
    final candidates = [
      personal?['full_name'],
      personal?['fullName'],
      personal?['name'],
      root['full_name'],
      root['fullName'],
      root['name'],
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    final resolved = candidates.isNotEmpty ? candidates.first : 'N/A';
    return _capitalizeWords(resolved);
  }

  String _capitalizeWords(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.isEmpty
              ? w
              : w[0].toUpperCase() +
                    (w.length > 1 ? w.substring(1).toLowerCase() : ''),
        )
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _loadJunkshopLocationAndCalculateDistance();
    _loadSignedDocuments();
  }

  Future<void> _loadJunkshopLocationAndCalculateDistance() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final data = await supabase
          .from('junkshops')
          .select('junkshop_profile')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (data != null) {
        final junkshopProfile =
            data['junkshop_profile'] as Map<String, dynamic>?;
        final location = junkshopProfile?['location'] as Map<String, dynamic>?;

        _junkshopLat = (location?['lat'] as num?)?.toDouble();
        _junkshopLng = (location?['lng'] as num?)?.toDouble();

        if (_junkshopLat != null && _junkshopLng != null) {
          _calculateDistance();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading junkshop location: $e');
    }
  }

  void _calculateDistance() {
    final collectorProfile =
        widget.applicationData['collector_profile'] as Map<String, dynamic>?;
    final contact = collectorProfile?['contact'] as Map<String, dynamic>?;

    final collectorLat = (contact?['lat'] as num?)?.toDouble();
    final collectorLng = (contact?['lng'] as num?)?.toDouble();

    if (collectorLat == null ||
        collectorLng == null ||
        _junkshopLat == null ||
        _junkshopLng == null) {
      return;
    }

    try {
      final distanceInMeters = Geolocator.distanceBetween(
        collectorLat,
        collectorLng,
        _junkshopLat!,
        _junkshopLng!,
      );
      final distanceInKm = distanceInMeters / 1000;

      setState(() {
        if (distanceInKm < 1) {
          _distance = '${distanceInMeters.toStringAsFixed(0)} m away';
        } else {
          _distance = '${distanceInKm.toStringAsFixed(1)} km away';
        }
      });

      debugPrint('📍 Distance calculated: $_distance');
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectorProfile =
        widget.applicationData['collector_profile'] as Map<String, dynamic>?;
    final personal = collectorProfile?['personal'] as Map<String, dynamic>?;
    final contact = collectorProfile?['contact'] as Map<String, dynamic>?;
    final vehicle = collectorProfile?['vehicle'] as Map<String, dynamic>?;
    final documents = collectorProfile?['documents'] as Map<String, dynamic>?;
    final status = widget.applicationData['application_status'] ?? 'pending';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Application Details',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeaderSection(personal, status),

                  const SizedBox(height: AppDimensions.spacing16),

                  // Personal Information
                  _buildSectionCard(
                    'Personal Information',
                    FluentIcons.person_24_filled,
                    [
                      _buildInfoRow(
                        'Full Name',
                        _resolveFullName(personal, widget.applicationData),
                      ),
                      _buildInfoRow(
                        'Date of Birth',
                        personal?['date_of_birth'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        'Phone Number',
                        formatPhoneNumber(personal?['phone'] ?? ''),
                      ),
                    ],
                  ),

                  // Contact Information
                  _buildSectionCard(
                    'Contact Information',
                    FluentIcons.location_24_filled,
                    [
                      _buildInfoRow('Address', contact?['address'] ?? 'N/A'),
                      if (_distance != null) _buildDistanceRow(_distance!),
                      if (contact != null &&
                          contact['has_drivers_license'] != null)
                        _buildInfoRow(
                          'Driver\'s License',
                          contact['has_drivers_license'] == true ? 'Yes' : 'No',
                        ),
                      if (contact != null && contact['license_type'] != null)
                        _buildInfoRow('License Type', contact['license_type']),
                      if (contact != null && contact['license_number'] != null)
                        _buildInfoRow(
                          'License Number',
                          contact['license_number'],
                        ),
                      if (contact != null && contact['experience'] != null)
                        _buildInfoRow(
                          'Driving Experience',
                          contact['experience'],
                        ),
                    ],
                  ),

                  // Vehicle Information
                  _buildSectionCard(
                    'Vehicle Information',
                    FluentIcons.vehicle_truck_24_filled,
                    [
                      _buildInfoRow(
                        'Vehicle Type',
                        vehicle?['type']?.toString() ?? 'No vehicle specified',
                      ),
                      _buildInfoRow(
                        'Plate Number',
                        vehicle?['plate_number']?.toString() ??
                            'No plate number',
                      ),
                      if (vehicle != null && vehicle['year'] != null)
                        _buildInfoRow('Year', vehicle['year'].toString()),
                      if (vehicle != null && vehicle['capacity'] != null)
                        _buildInfoRow(
                          'Capacity',
                          vehicle['capacity'].toString(),
                        ),
                      if (vehicle != null && vehicle['condition'] != null)
                        _buildInfoRow(
                          'Condition',
                          vehicle['condition'].toString(),
                        ),
                    ],
                  ),

                  // Documents with image previews
                  if (documents != null && documents.isNotEmpty)
                    _buildDocumentsSection(documents),

                  const SizedBox(height: AppDimensions.spacing24),
                ],
              ),
            ),
          ),

          // Action Buttons (only for pending applications)
          if (status == 'pending' || status == 'reapplying')
            _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(Map<String, dynamic>? personal, String status) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = AppColors.successColor;
        statusLabel = 'Approved';
        statusIcon = FluentIcons.checkmark_circle_24_filled;
        break;
      case 'rejected':
        statusColor = AppColors.errorColor;
        statusLabel = 'Rejected';
        statusIcon = FluentIcons.dismiss_circle_24_filled;
        break;
      case 'reapplying':
        statusColor = Colors.blue;
        statusLabel = 'Reapplying';
        statusIcon = FluentIcons.arrow_sync_24_regular;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending Review';
        statusIcon = FluentIcons.clock_24_regular;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        children: [
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (widget.applicationData['created_at'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Submitted: ${_formatDate(widget.applicationData['created_at'])}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing8,
      ),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.junkshopPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Divider
          Container(height: 1, color: AppColors.borderLight),

          const SizedBox(height: 16),

          // Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceRow(String distance) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Distance',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              distance,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(Map<String, dynamic> documents) {
    final List<Map<String, dynamic>> documentList = [];

    if (documents['validId'] != null) {
      documentList.add({
        'url': _docUrl(documents['validId']),
        'label': 'Valid ID',
        'icon': FluentIcons.contact_card_24_regular,
      });
    }

    if (documents['driversLicense'] != null) {
      documentList.add({
        'url': _docUrl(documents['driversLicense']),
        'label': 'Driver\'s License',
        'icon': FluentIcons.vehicle_car_profile_ltr_24_regular,
      });
    }

    if (documents['vehiclePhoto'] != null) {
      documentList.add({
        'url': _docUrl(documents['vehiclePhoto']),
        'label': 'Vehicle Photo',
        'icon': FluentIcons.vehicle_truck_24_regular,
      });
    }

    if (documentList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  FluentIcons.document_24_filled,
                  size: 20,
                  color: AppColors.junkshopPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Submitted Documents',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${documentList.length} document${documentList.length != 1 ? 's' : ''}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Document preview carousel
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: documentList.length,
            itemBuilder: (context, index) {
              final doc = documentList[index];
              return GestureDetector(
                onTap: () {
                  _showFullScreenDocumentViewer(documentList, index);
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: index == documentList.length - 1 ? 0 : 12,
                  ),
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Document image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          doc['url'],
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 140,
                              height: 140,
                              color: AppColors.backgroundDark,
                              child: Icon(
                                doc['icon'],
                                size: 40,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 140,
                              height: 140,
                              color: AppColors.backgroundDark,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: AppColors.junkshopPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Label overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            doc['label'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showFullScreenDocumentViewer(
    List<Map<String, dynamic>> documents,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenDocumentViewer(
          documents: documents,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showRejectDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.errorColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: AppTextStyles.buttonLarge.copyWith(
                    color: AppColors.errorColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showApproveDialog(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.junkshopPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Approve',
                  style: AppTextStyles.buttonLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApproveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text(
          'Are you sure you want to approve this collector application?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _approveApplication(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.junkshopPrimary,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final TextEditingController reasonController = TextEditingController();

    // Show dialog to get rejection reason
    final String? reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reject Application',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This action cannot be undone',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Reason Label
                  Text(
                    'Reason for Rejection',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 4,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., Incomplete documents, not qualified...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: AppTextStyles.bodyMedium,
                      autofocus: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppColors.borderLight,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final text = reasonController.text.trim();
                            if (text.isEmpty) {
                              // Don't show snackbar in dialog context, just return
                              return;
                            }
                            Navigator.of(context).pop(text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Reject',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.white,
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
          ),
        );
      },
    );

    // Wait for the dialog to fully close before disposing
    await Future.delayed(const Duration(milliseconds: 100));
    reasonController.dispose();

    // If user cancelled or reason is empty, return early
    if (reason == null || reason.isEmpty) {
      if (context.mounted && reason != null && reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  FluentIcons.warning_24_filled,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text('Please enter a rejection reason'),
              ],
            ),
            backgroundColor: AppColors.warningColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return;
    }

    // Proceed with rejection
    if (!context.mounted) return;
    await _rejectApplication(context, reason);
  }

  Future<void> _approveApplication(BuildContext context) async {
    // Safe dynamic access — avoids cast failures on Firestore map types
    final dynamic cp = widget.applicationData['collector_profile'];
    final dynamic personal = (cp is Map) ? cp['personal'] : null;
    final String? rawName = (personal is Map)
        ? (personal['full_name']?.toString() ?? personal['name']?.toString())
        : null;
    final collectorName = (rawName != null && rawName.isNotEmpty)
        ? _capitalizeWords(rawName)
        : _resolveFullName(
            personal is Map ? Map<String, dynamic>.from(personal) : null,
            widget.applicationData,
          );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                FluentIcons.checkmark_circle_24_regular,
                color: AppColors.successColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Approve Application')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve $collectorName as a collector?',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'They will be able to accept and complete collection tasks.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final collectorProfile =
          widget.applicationData['collector_profile'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;
      final collectorName = _resolveFullName(personal, widget.applicationData);

      // The DB trigger adds the collector to the junkshop group chat on approval.
      await supabase
          .from('collectors')
          .update({
            'application_status': 'approved',
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.applicationId);

      // Log activity
      final junkshopUid = currentUid;
      if (junkshopUid != null) {
        await supabase.from('activity_logs').insert({
          'junkshop_id': junkshopUid,
          'type': 'collector_approved',
          'title': 'Approved collector: $collectorName',
          'details': {
            'collectorId': widget.applicationId,
            'collectorName': collectorName,
          },
        });
      }

      if (context.mounted) {
        final nav = Navigator.of(context);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.successColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Application Approved!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '$collectorName has been approved as a collector and can now accept collection tasks.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      final cp =
                          widget.applicationData['collector_profile']
                              as Map<String, dynamic>?;
                      final personal = cp?['personal'] as Map<String, dynamic>?;
                      final contact = cp?['contact'] as Map<String, dynamic>?;
                      final vehicle = cp?['vehicle'] as Map<String, dynamic>?;
                      final phone =
                          personal?['phone'] as String? ??
                          widget.applicationData['phone'] as String? ??
                          '';
                      final email =
                          personal?['email'] as String? ??
                          widget.applicationData['email'] as String? ??
                          '';
                      final address =
                          contact?['address'] as String? ??
                          widget.applicationData['address'] as String? ??
                          '';
                      final avatarUrl =
                          widget.applicationData['profile_image_url']
                              as String? ??
                          widget.applicationData['profileImageUrl'] as String?;
                      final rating =
                          (widget.applicationData['averageRating'] as num?)
                              ?.toDouble() ??
                          (widget.applicationData['rating'] as num?)
                              ?.toDouble() ??
                          0.0;
                      nav.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CollectorProfileScreen(
                            collectorId: widget.applicationId,
                            name: collectorName,
                            phone: phone,
                            email: email,
                            address: address,
                            status: 'approved',
                            avatarUrl: avatarUrl,
                            rating: rating,
                            totalCollections: 0,
                            totalSold: 0.0,
                            assignedTasks: 0,
                            approvedAt: DateTime.now(),
                            vehicle: vehicle,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to approve: $e')),
              ],
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _rejectApplication(BuildContext context, String reason) async {
    try {
      final collectorProfile =
          widget.applicationData['collector_profile'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;
      final collectorName = _resolveFullName(personal, widget.applicationData);
      final isReapplying =
          widget.applicationData['application_status'] == 'reapplying';

      await supabase
          .from('collectors')
          .update({
            'application_status': 'rejected',
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
            'rejection_reason': reason,
          })
          .eq('id', widget.applicationId);

      // Log activity
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('activity_logs').insert({
          'junkshop_id': user.id,
          'type': 'collector_rejected',
          'title': isReapplying
              ? 'Rejected reapplication: $collectorName'
              : 'Rejected collector application: $collectorName',
          'details': {
            'collectorId': widget.applicationId,
            'collectorName': collectorName,
            'reason': reason,
            'isReapplication': isReapplying,
          },
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        Navigator.pop(context); // Go back to applications list
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

}

class _FullScreenDocumentViewer extends StatefulWidget {
  final List<Map<String, dynamic>> documents;
  final int initialIndex;

  const _FullScreenDocumentViewer({
    required this.documents,
    required this.initialIndex,
  });

  @override
  State<_FullScreenDocumentViewer> createState() =>
      _FullScreenDocumentViewerState();
}

class _FullScreenDocumentViewerState extends State<_FullScreenDocumentViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.documents.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.junkshopPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.documents[_currentIndex]['icon'],
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.documents[_currentIndex]['label'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.documents.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.documents[index]['url'],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, color: Colors.white, size: 48);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
