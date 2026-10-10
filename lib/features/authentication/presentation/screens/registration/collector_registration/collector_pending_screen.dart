import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as sb;

import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/utils/user_collection_helper.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';
import 'package:ecokuha/core/theme/app_dimensions.dart';
import 'package:ecokuha/core/utils/phone_number_formatter.dart';
import 'package:ecokuha/shared/widgets/common/common_widgets.dart';

class CollectorPendingScreen extends StatefulWidget {
  const CollectorPendingScreen({super.key});

  @override
  State<CollectorPendingScreen> createState() => _CollectorPendingScreenState();
}

class _CollectorPendingScreenState extends State<CollectorPendingScreen> {
  bool _isReapplying = false;

  Stream<Map<String, dynamic>?> _collectorStream(String uid) {
    return sb.supabase
        .from('collectors')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map(
          (rows) => rows.isEmpty ? null : sb.rowToDoc('collectors', rows.first),
        );
  }

  void _goBackToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _handleReapply() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isReapplying = true);

    try {
      // Fetch current collector data
      final userData = await sb.supabase
          .from('collectors')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User data not found');
      }

      final applicationAttempts =
          (userData['application_attempts'] ?? 0) as int;

      // Prepare registration data with only application_attempts
      // User will fill all fields fresh
      Map<String, dynamic> registrationData = {
        'email': currentUser.email,
        'password': '',
        'isReapplying': true,
        'application_attempts': applicationAttempts,
      };

      setState(() => _isReapplying = false);

      // Navigate to step 1 immediately
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/collector-register-1',
          arguments: registrationData,
        );

        // Only delete rejection data, don't change status yet
        // Status will be updated to 'pending' when they submit in step 5
        await sb.supabase
            .from('collectors')
            .update({
              'rejected_at': null,
              'rejection_reason': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', currentUser.id);
      }
    } catch (e) {
      setState(() => _isReapplying = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start reapplication. Please try again.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Application Status',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: AppColors.warningColor),
              const SizedBox(height: 12),
              Text('You are not signed in.', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  onPressed: _goBackToLogin,
                  text: 'Back to Login',
                  isOutlined: true,
                  backgroundColor: Colors.white,
                  textColor: AppColors.collectorPrimary,
                  borderColor: AppColors.collectorPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _collectorStream(currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              child: Text(
                'Failed to load application data',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.errorColor,
                ),
              ),
            ),
          );
        }

        // Render UI even if document is missing; show placeholders
        final userData = snapshot.data ?? <String, dynamic>{};
        final collectorProfile =
            (userData[UserFields.collectorProfile] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            <String, dynamic>{};
        final personal =
            (collectorProfile['personal'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            <String, dynamic>{};
        final String fullName = (personal[UserFields.fullName] ?? '')
            .toString();
        final String phone = formatPhoneNumber(
          (personal[UserFields.phone] ?? '').toString(),
        );
        final String status =
            (userData[UserFields.applicationStatus] ?? 'pending').toString();
        final String? createdAt = (userData[UserFields.createdAt] as String?);
        final String? rejectedAt = (userData[UserFields.rejectedAt] as String?);
        final String? rejectionReason =
            (userData[UserFields.rejectionReason] as String?);
        final String applicationId = currentUser.id;
        final String? preferredJunkshopId =
            (collectorProfile['preferred_junkshop_id'] as String?);

        return FutureBuilder<Map<String, dynamic>?>(
          future: preferredJunkshopId == null
              ? null
              : UserCollectionHelper.getUserDocument(
                  preferredJunkshopId,
                  'junkshop',
                ).get(),
          builder: (context, jsSnapshot) {
            final junkshopData = jsSnapshot.data;

            // Try to get junkshop name and phone from multiple possible fields
            String partnerName = 'No Junkshop Selected';
            String junkshopPhone = 'N/A';

            if (junkshopData != null) {
              // Get junkshop profile
              final junkshopProfile =
                  junkshopData[UserFields.junkshopProfile] as Map?;

              if (junkshopProfile != null) {
                // Get business info from junkshop_profile.business
                final business = junkshopProfile['business'] as Map?;

                if (business != null) {
                  // Get business name
                  partnerName =
                      (business[UserFields.businessName] ??
                              business[UserFields.name] ??
                              partnerName)
                          .toString();

                  // Get phone number from business.phone
                  if (business[UserFields.phone] != null) {
                    junkshopPhone = formatPhoneNumber(
                      business[UserFields.phone].toString(),
                    );
                  }
                }
              }

              // Fallback to full_name if business name not found
              if (partnerName == 'No Junkshop Selected' &&
                  junkshopData[UserFields.fullName] != null) {
                partnerName = junkshopData[UserFields.fullName].toString();
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCompactHero(status: status),
                  const SizedBox(height: AppDimensions.spacing24),
                  _buildSummaryCardFrom(
                    fullName: fullName.isEmpty ? 'Not Provided' : fullName,
                    phone: phone.isEmpty ? 'Not Provided' : phone,
                    partnerName: partnerName,
                    junkshopPhone: junkshopPhone,
                    applicationId: applicationId,
                    status: status,
                    createdAt: createdAt,
                    rejectedAt: rejectedAt,
                    rejectionReason: rejectionReason,
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  _buildLoginOnlyAction(),
                  const SizedBox(height: AppDimensions.spacing16),
                  _buildFooterNote(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactHero({String status = 'pending'}) {
    final bool isRejected = status == 'rejected';
    final bool isApproved = status == 'approved';
    final bool isReapplying = status == 'reapplying';

    Color brandColor = isApproved
        ? AppColors.successColor
        : isRejected
        ? AppColors.errorColor
        : isReapplying
        ? AppColors.warningColor
        : AppColors.collectorPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Static icon (no animation) with enhanced styling for rejection
        Center(
          child: Container(
            width: isRejected ? 96 : 84,
            height: isRejected ? 96 : 84,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(isRejected ? 48 : 42),
              border: Border.all(
                color: brandColor.withValues(alpha: isRejected ? 0.3 : 0.25),
                width: isRejected ? 2 : 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                isApproved
                    ? Icons.check_circle_rounded
                    : isRejected
                    ? Icons.error_outline_rounded
                    : isReapplying
                    ? Icons.update_rounded
                    : Icons.hourglass_top_rounded,
                size: isRejected ? 52 : 44,
                color: brandColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        Text(
          isApproved
              ? 'Application Approved'
              : isRejected
              ? 'Application Not Approved'
              : isReapplying
              ? 'Reapplication Submitted'
              : 'Application Submitted',
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w700,
            color: brandColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing32,
          ),
          child: Text(
            isApproved
                ? 'Congratulations! You can now login and start collecting waste.'
                : isRejected
                ? 'Unfortunately, your application was not approved at this time. Please review the details below.'
                : isReapplying
                ? 'Your reapplication is under review. You\'ll be notified once the junkshop approves your request.'
                : 'Your collector registration is under review. We\'ll notify you once it\'s processed.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCardFrom({
    required String fullName,
    required String phone,
    required String partnerName,
    required String junkshopPhone,
    required String applicationId,
    required String status,
    required String? createdAt,
    required String? rejectedAt,
    required String? rejectionReason,
  }) {
    final bool isApproved = status == 'approved';
    final bool isRejected = status == 'rejected';
    final bool isReapplying = status == 'reapplying';

    Color statusColor = isApproved
        ? AppColors.successColor
        : isRejected
        ? AppColors.errorColor
        : isReapplying
        ? AppColors.warningColor
        : AppColors.warningColor;
    Color statusBg = statusColor.withValues(alpha: 0.1);
    String statusLabel = isApproved
        ? 'Approved'
        : isRejected
        ? 'Rejected'
        : isReapplying
        ? 'Reapplying'
        : 'Under Review';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved
                    ? Icons.check_circle
                    : isRejected
                    ? Icons.cancel
                    : isReapplying
                    ? Icons.update
                    : Icons.info,
                color: statusColor,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                isApproved
                    ? 'You are approved!'
                    : isRejected
                    ? 'Application not approved'
                    : isReapplying
                    ? 'Reapplication submitted!'
                    : 'Thanks for applying!',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            isApproved
                ? 'You can now sign in and start using the app.'
                : isRejected
                ? 'You may reach out to your selected junkshop for more details.'
                : isReapplying
                ? 'Your reapplication is awaiting review. You\'ll be notified once the junkshop approves your request.'
                : 'We’ll review your application shortly. You’ll be notified upon any update.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          _buildDetailRow('Applicant', fullName),
          _buildDetailRow('Phone', phone),
          _buildDetailRow('Partner Shop', partnerName),
          _buildDetailRow('Shop Phone', junkshopPhone),
          if (createdAt != null)
            _buildDetailRow('Submitted', _formatDate(createdAt)),
          _buildDetailRow('Application ID', applicationId),
          _buildDetailRow(
            'Status',
            statusLabel,
            isStatus: true,
            statusBg: statusBg,
            statusColor: statusColor,
          ),

          // Show rejection details if rejected
          if (isRejected) ...[
            const SizedBox(height: AppDimensions.spacing20),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.errorColor.withValues(alpha: 0.25),
                  width: 1.5,
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
                          color: AppColors.errorColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rejection Details',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.errorColor,
                        ),
                      ),
                    ],
                  ),
                  if (rejectedAt != null) ...[
                    const SizedBox(height: AppDimensions.spacing12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rejected on: ${_formatDate(rejectedAt)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (rejectionReason != null &&
                      rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacing12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reason for Rejection:',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rejectionReason,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppDimensions.spacing12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: Text(
                        'No specific reason was provided. Please contact the junkshop for more information.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacing12),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing12),
                    decoration: BoxDecoration(
                      color: AppColors.infoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: AppColors.infoColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contact your selected junkshop ($partnerName) for clarification or to reapply.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
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

  Widget _buildLoginOnlyAction() {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: currentUser == null ? null : _collectorStream(currentUser.id),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? <String, dynamic>{};
        final String status =
            (userData[UserFields.applicationStatus] ?? 'pending').toString();
        final bool isRejected = status == 'rejected';
        final bool isReapplying = status == 'reapplying';

        if (isRejected && !isReapplying) {
          // Show different actions for rejected applications
          return Column(
            children: [
              // Buttons in a row
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: _goBackToLogin,
                      text: 'Sign Out',
                      isOutlined: true,
                      backgroundColor: Colors.white,
                      textColor: AppColors.textSecondary,
                      borderColor: AppColors.borderLight,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: CustomButton(
                      onPressed: _isReapplying ? null : _handleReapply,
                      text: _isReapplying ? 'Processing...' : 'Reapply Now',
                      backgroundColor: AppColors.collectorPrimary,
                      isLoading: _isReapplying,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // Default action for pending/approved
        return Row(
          children: [
            Expanded(
              child: CustomButton(
                onPressed: _goBackToLogin,
                text: 'Back to Login',
                isOutlined: true,
                backgroundColor: Colors.white,
                textColor: AppColors.collectorPrimary,
                borderColor: AppColors.collectorPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooterNote() {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: currentUser == null ? null : _collectorStream(currentUser.id),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? <String, dynamic>{};
        final String status =
            (userData[UserFields.applicationStatus] ?? 'pending').toString();
        final bool isRejected = status == 'rejected';
        final bool isApproved = status == 'approved';
        final bool isReapplying = status == 'reapplying';

        IconData icon;
        String message;
        Color bgColor;

        if (isApproved) {
          icon = Icons.check_circle_outline;
          message =
              'Your application is approved! You can now sign in and start using EcoKuha.';
          bgColor = AppColors.successColor;
        } else if (isRejected) {
          icon = Icons.help_outline;
          message =
              'For questions about your rejection, please reach out to the junkshop you applied to or contact EcoKuha support.';
          bgColor = AppColors.errorColor;
        } else if (isReapplying) {
          icon = Icons.update;
          message =
              'Your reapplication is pending review. You\'ll be notified when the junkshop approves your request.';
          bgColor = AppColors.warningColor;
        } else {
          icon = Icons.access_time;
          message =
              'We\'ll notify you when your application status changes. Keep your contact details updated.';
          bgColor = AppColors.infoColor;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: bgColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: bgColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isStatus = false,
    Color? statusBg,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (statusBg ?? AppColors.warningColor.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: (statusColor ?? AppColors.warningColor),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Text(
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

  String _formatDate(String dateString) {
    try {
      final dt = DateTime.parse(dateString);
      return "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return dateString;
    }
  }
}
