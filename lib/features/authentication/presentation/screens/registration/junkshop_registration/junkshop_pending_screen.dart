import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as sb;

import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';
import 'package:ecokuha/core/theme/app_dimensions.dart';
import 'package:ecokuha/core/utils/phone_number_formatter.dart';
import 'package:ecokuha/shared/widgets/common/common_widgets.dart';

class JunkshopPendingScreen extends StatefulWidget {
  const JunkshopPendingScreen({super.key});

  @override
  State<JunkshopPendingScreen> createState() => _JunkshopPendingScreenState();
}

class _JunkshopPendingScreenState extends State<JunkshopPendingScreen> {
  /// The junkshops table is not in the realtime publication, so poll.
  Stream<Map<String, dynamic>?> _junkshopStream(String uid) async* {
    while (true) {
      try {
        final row = await sb.supabase
            .from('junkshops')
            .select()
            .eq('id', uid)
            .maybeSingle();
        yield row == null ? null : sb.rowToDoc('junkshops', row);
      } catch (e) {
        yield* Stream<Map<String, dynamic>?>.error(e);
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }

  void _goBackToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
                  textColor: AppColors.junkshopPrimary,
                  borderColor: AppColors.junkshopPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _junkshopStream(currentUser.id),
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

        final userData = snapshot.data ?? <String, dynamic>{};
        final junkshopProfile =
            (userData[UserFields.junkshopProfile] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            <String, dynamic>{};
        final business =
            (junkshopProfile['business'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            <String, dynamic>{};
        final location =
            (junkshopProfile['location'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            <String, dynamic>{};

        final String businessName = (business[UserFields.businessName] ?? '')
            .toString();
        final String ownerName = (business['owner_full_name'] ?? '').toString();
        final String phone = formatPhoneNumber(
          (business[UserFields.phone] ?? '').toString(),
        );
        final String email = (business['email'] ?? '').toString();
        final String address = (location['address'] ?? '').toString();
        final String status = (userData['application_status'] ?? 'pending')
            .toString();
        final String? createdAt = (userData['created_at'] as String?);
        final String? rejectedAt = (userData['rejected_at'] as String?);
        final String? rejectionReason =
            (userData['rejection_reason'] as String?);
        final String applicationId = currentUser.id;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompactHero(status: status),
              const SizedBox(height: AppDimensions.spacing24),
              _buildSummaryCard(
                businessName: businessName.isEmpty
                    ? 'Not Provided'
                    : businessName,
                ownerName: ownerName.isEmpty ? 'Not Provided' : ownerName,
                phone: phone.isEmpty ? 'Not Provided' : phone,
                email: email.isEmpty ? 'Not Provided' : email,
                address: address.isEmpty ? 'Not Provided' : address,
                applicationId: applicationId,
                status: status,
                createdAt: createdAt,
                rejectedAt: rejectedAt,
                rejectionReason: rejectionReason,
              ),
              const SizedBox(height: AppDimensions.spacing24),
              _buildActionButton(status: status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactHero({required String status}) {
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPending
              ? [
                  AppColors.junkshopPrimary,
                  AppColors.junkshopPrimary.withValues(alpha: 0.8),
                ]
              : isRejected
              ? [AppColors.errorColor, AppColors.errorColor.withValues(alpha: 0.8)]
              : [
                  AppColors.successColor,
                  AppColors.successColor.withValues(alpha: 0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color:
                (isPending
                        ? AppColors.junkshopPrimary
                        : isRejected
                        ? AppColors.errorColor
                        : AppColors.successColor)
                    .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isPending
                ? Icons.hourglass_empty
                : isRejected
                ? Icons.cancel_outlined
                : Icons.check_circle_outline,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            isPending
                ? 'Application Under Review'
                : isRejected
                ? 'Application Rejected'
                : 'Application Approved',
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            isPending
                ? 'Your junkshop application is being reviewed by our team. We\'ll notify you once it\'s been approved.'
                : isRejected
                ? 'Unfortunately, your application was not approved. Please see the reason below.'
                : 'Congratulations! Your junkshop has been approved. You can now access the full platform.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String businessName,
    required String ownerName,
    required String phone,
    required String email,
    required String address,
    required String applicationId,
    required String status,
    String? createdAt,
    String? rejectedAt,
    String? rejectionReason,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Summary',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.junkshopPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          _buildInfoRow(Icons.business, 'Business Name', businessName),
          _buildInfoRow(Icons.person, 'Owner Name', ownerName),
          _buildInfoRow(Icons.phone, 'Phone', phone),
          _buildInfoRow(Icons.email, 'Email', email),
          _buildInfoRow(Icons.location_on, 'Address', address),
          const Divider(height: AppDimensions.spacing24),
          _buildInfoRow(
            Icons.confirmation_number,
            'Application ID',
            applicationId,
          ),
          _buildInfoRow(
            Icons.info_outline,
            'Status',
            status.toUpperCase(),
            valueColor: status == 'pending'
                ? AppColors.junkshopPrimary
                : status == 'rejected'
                ? AppColors.errorColor
                : AppColors.successColor,
          ),
          if (createdAt != null)
            _buildInfoRow(
              Icons.calendar_today,
              'Submitted',
              _formatDate(createdAt),
            ),
          if (rejectedAt != null)
            _buildInfoRow(
              Icons.event,
              'Rejected',
              _formatDate(rejectedAt),
              valueColor: AppColors.errorColor,
            ),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const Divider(height: AppDimensions.spacing24),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(
                  color: AppColors.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rejection Reason',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.errorColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejectionReason,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
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

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String status}) {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        onPressed: _goBackToLogin,
        text: 'Back to Login',
        backgroundColor: AppColors.junkshopPrimary,
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return isoString;
    }
  }
}
