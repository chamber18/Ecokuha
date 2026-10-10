import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import 'application_detail_screen.dart';
import '../collectors/collector_profile_screen.dart';

class WorkerApplicationsScreen extends StatefulWidget {
  const WorkerApplicationsScreen({super.key});

  @override
  State<WorkerApplicationsScreen> createState() =>
      _WorkerApplicationsScreenState();
}

class _WorkerApplicationsScreenState extends State<WorkerApplicationsScreen> {
  double? _junkshopLat;
  double? _junkshopLng;
  final Set<String> _processingApplications = {};

  @override
  void initState() {
    super.initState();
    _loadJunkshopLocation();
  }

  Future<void> _loadJunkshopLocation() async {
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

        if (mounted) {
          setState(() {
            _junkshopLat = (location?['lat'] as num?)?.toDouble();
            _junkshopLng = (location?['lng'] as num?)?.toDouble();
          });
          debugPrint(
            '📍 Junkshop location loaded: $_junkshopLat, $_junkshopLng',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading junkshop location: $e');
    }
  }

  String? _calculateDistance(Map<String, dynamic> data) {
    if (_junkshopLat == null || _junkshopLng == null) {
      debugPrint(
        '⚠️ Junkshop location not available: $_junkshopLat, $_junkshopLng',
      );
      return null;
    }

    final collectorProfile = data['collector_profile'] as Map<String, dynamic>?;
    final contact = collectorProfile?['contact'] as Map<String, dynamic>?;

    final collectorLat = (contact?['lat'] as num?)?.toDouble();
    final collectorLng = (contact?['lng'] as num?)?.toDouble();

    debugPrint('🔍 Collector coordinates: $collectorLat, $collectorLng');

    if (collectorLat == null || collectorLng == null) {
      debugPrint('⚠️ Collector location not available');
      return null;
    }

    try {
      final distanceInMeters = Geolocator.distanceBetween(
        collectorLat,
        collectorLng,
        _junkshopLat!,
        _junkshopLng!,
      );
      final distanceInKm = distanceInMeters / 1000;

      String result;
      if (distanceInKm < 1) {
        result = '${distanceInMeters.toStringAsFixed(0)} m away';
      } else {
        result = '${distanceInKm.toStringAsFixed(1)} km away';
      }

      debugPrint('✅ Distance calculated: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Worker Applications',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildApplicationsList(currentUser.id, 'pending'),
    );
  }

  Widget _buildApplicationsList(String currentUserId, String statusFilter) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('collectors')
          .stream(primaryKey: ['id'])
          .eq('preferred_junkshop_id', currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Worker Applications Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data ?? [];
        debugPrint('═══════════════════════════════════════════════════');

        // Filter in-memory by application status
        final applications = allDocs.where((data) {
          // Get application status
          final applicationStatus =
              data['application_status'] as String? ?? 'pending';

          // Show both 'pending' and 'reapplying' in the pending tab
          final matchesStatus = statusFilter == 'pending'
              ? (applicationStatus == 'pending' ||
                    applicationStatus == 'reapplying')
              : applicationStatus == statusFilter;

          return matchesStatus;
        }).toList();

        if (applications.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final data = applications[index];
            return _buildApplicationCard(
              context,
              data['id'].toString(),
              data,
            );
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    String applicationId,
    Map<String, dynamic> data,
  ) {
    final collectorProfile = data['collector_profile'] as Map<String, dynamic>?;
    final personal = collectorProfile?['personal'] as Map<String, dynamic>?;
    final vehicle = collectorProfile?['vehicle'] as Map<String, dynamic>?;
    final applicationStatus =
        data['application_status'] as String? ?? 'pending';
    final fullName = _resolveFullName(personal, data);
    final phone = personal?['phone'] ?? 'No phone';
    final vehicleType = vehicle?['type']?.toString() ?? 'No vehicle';
    final submittedAt = data['created_at'] as String?;
    final distance = _calculateDistance(data);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ApplicationDetailScreen(
                  applicationId: applicationId,
                  applicationData: data,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.collectorPrimary.withValues(
                        alpha: 0.1,
                      ),
                      child: Icon(
                        FluentIcons.person_24_filled,
                        color: AppColors.collectorPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name and Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    _buildStatusBadge(applicationStatus),
                  ],
                ),

                const SizedBox(height: 12),

                // Divider
                Container(height: 1, color: AppColors.borderLight),

                const SizedBox(height: 12),

                // Info Row
                Row(
                  children: [
                    // Vehicle Info
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            FluentIcons.vehicle_truck_24_regular,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vehicleType,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Submitted Date
                    if (submittedAt != null)
                      Row(
                        children: [
                          Icon(
                            FluentIcons.calendar_24_regular,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(submittedAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Distance Row (if available)
                if (distance != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        FluentIcons.location_24_regular,
                        size: 18,
                        color: AppColors.junkshopPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        distance,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.junkshopPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                if (applicationStatus == 'pending') ...[
                  const SizedBox(height: 12),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _processingApplications.contains(applicationId)
                              ? null
                              : () => _rejectApplication(applicationId),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: AppColors.errorColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _processingApplications.contains(applicationId)
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.errorColor,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Reject',
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: AppColors.errorColor,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _processingApplications.contains(applicationId)
                              ? null
                              : () => _approveApplication(applicationId),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            backgroundColor: AppColors.junkshopPrimary,
                            disabledBackgroundColor: AppColors.junkshopPrimary
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _processingApplications.contains(applicationId)
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Approve',
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveFullName(
    Map<String, dynamic>? personal,
    Map<String, dynamic> root,
  ) {
    // Order of precedence: nested personal variants -> root variants -> fallback
    final candidates = [
      personal?['full_name'],
      personal?['fullName'],
      personal?['name'],
      root['full_name'],
      root['fullName'],
      root['name'],
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);

    final resolved = candidates.isNotEmpty ? candidates.first : 'Unknown';
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

  Widget _buildStatusBadge(String status) {
    final Color color;
    final String label;
    final IconData icon;

    if (status == 'reapplying') {
      color = Colors.blue;
      label = 'Reapplying';
      icon = FluentIcons.arrow_sync_24_filled;
    } else {
      color = Colors.orange;
      label = 'Pending';
      icon = FluentIcons.clock_24_filled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String statusFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.mail_inbox_24_regular,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending applications',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _approveApplication(String applicationId) async {
    // Get collector data first for confirmation dialog
    final collectorData = await supabase
        .from('collectors')
        .select()
        .eq('id', applicationId)
        .maybeSingle();
    final collectorName =
        (collectorData?['collector_profile']?['personal']?['full_name']
                    as String?)
                ?.trim()
                .isNotEmpty ==
            true
        ? collectorData!['collector_profile']['personal']['full_name'] as String
        : (collectorData?['full_name'] as String?) ?? 'Unknown Collector';

    if (!mounted) return;
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

    setState(() {
      _processingApplications.add(applicationId);
    });

    try {
      // The DB trigger adds the collector to the junkshop group chat on approval.
      await supabase
          .from('collectors')
          .update({
            'application_status': 'approved',
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', applicationId);

      // Log activity
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('activity_logs').insert({
          'junkshop_id': user.id,
          'type': 'collector_approved',
          'title': 'Approved collector: $collectorName',
          'details': {
            'collectorId': applicationId,
            'collectorName': collectorName,
          },
        });
      }

      if (mounted) {
        setState(() {
          _processingApplications.remove(applicationId);
        });

        // Show success dialog
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
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
                    FluentIcons.checkmark_circle_24_filled,
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
                  '$collectorName has been approved and can now receive collection tasks.',
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
                      Navigator.pop(ctx);
                      // Extract collector details for the profile screen
                      final collectorProfile =
                          collectorData?['collector_profile']
                              as Map<String, dynamic>?;
                      final personal =
                          collectorProfile?['personal']
                              as Map<String, dynamic>?;
                      final contact =
                          collectorProfile?['contact'] as Map<String, dynamic>?;
                      final vehicle =
                          collectorProfile?['vehicle'] as Map<String, dynamic>?;
                      final phone =
                          personal?['phone'] as String? ??
                          collectorData?['phone'] as String? ??
                          '';
                      final email =
                          personal?['email'] as String? ??
                          collectorData?['email'] as String? ??
                          '';
                      final address =
                          contact?['address'] as String? ??
                          collectorData?['address'] as String? ??
                          '';
                      final avatarUrl =
                          collectorData?['profile_image_url'] as String? ??
                          collectorData?['profileImageUrl'] as String?;
                      final rating =
                          (collectorData?['averageRating'] as num?)
                              ?.toDouble() ??
                          (collectorData?['rating'] as num?)?.toDouble() ??
                          0.0;
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CollectorProfileScreen(
                              collectorId: applicationId,
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
                      }
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
      if (mounted) {
        setState(() {
          _processingApplications.remove(applicationId);
        });

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
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _rejectApplication(String applicationId) async {
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
      if (mounted && reason != null && reason.isEmpty) {
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
    } // Proceed with rejection

    setState(() {
      _processingApplications.add(applicationId);
    });

    try {
      // Get collector data first
      final collectorData = await supabase
          .from('collectors')
          .select()
          .eq('id', applicationId)
          .maybeSingle();
      final collectorName =
          (collectorData?['collector_profile']?['personal']?['full_name']
                      as String?)
                  ?.trim()
                  .isNotEmpty ==
              true
          ? collectorData!['collector_profile']['personal']['full_name']
                as String
          : (collectorData?['full_name'] as String?) ?? 'Unknown Collector';
      final isReapplying = collectorData?['application_status'] == 'reapplying';

      await supabase
          .from('collectors')
          .update({
            'application_status': 'rejected',
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
            'rejection_reason': reason,
          })
          .eq('id', applicationId);

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
            'collectorId': applicationId,
            'collectorName': collectorName,
            'reason': reason,
            'isReapplication': isReapplying,
          },
        });
      }

      if (mounted) {
        setState(() {
          _processingApplications.remove(applicationId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Application rejected successfully')),
              ],
            ),
            backgroundColor: AppColors.errorColor,
            duration: Duration(seconds: 3),
          ),
        );

        // If we're in a detail screen, pop it
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingApplications.remove(applicationId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to reject: $e')),
              ],
            ),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
