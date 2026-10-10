import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/user_collection_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String role; // 'household', 'collector', or 'junkshop'

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.role,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  Timer? _verificationCheckTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.emailConfirmedAt == null) {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: widget.email,
        );
        if (kDebugMode) print('✅ Verification email sent to ${widget.email}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sending verification email: $e');
    }
  }

  void _startVerificationCheck() {
    _verificationCheckTimer = Timer.periodic(
      const Duration(
        seconds: 10,
      ), // Changed from 3 to 10 seconds to avoid rate limiting
      (timer) async {
        await _checkEmailVerification();
      },
    );
  }

  Future<void> _checkEmailVerification() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentUser != null) {
        try {
          await auth.refreshSession();
        } catch (_) {
          // Keep using the cached session if refresh fails
        }
        final refreshedUser = auth.currentUser;

        if (refreshedUser != null && refreshedUser.emailConfirmedAt != null) {
          await _updateVerificationFlag(refreshedUser.id);

          _verificationCheckTimer?.cancel();
          _navigateToNextStep();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error checking verification: $e');
    }
  }

  Future<void> _updateVerificationFlag(String userId) async {
    try {
      final ref = UserCollectionHelper.getUserDocument(userId, widget.role);
      await ref.update({'is_email_verified': true});
      if (kDebugMode) print('? Updated email verification for user: $userId');
    } catch (e) {
      if (kDebugMode) print('? Error updating verification flag: $e');
      // Don't block navigation if the update fails
    }
  }

  void _navigateToNextStep() {
    // Navigate to role-specific registration steps
    if (!mounted) return;

    String route;
    switch (widget.role) {
      case 'household':
        route = '/household-register';
        break;
      case 'collector':
        route = '/collector-register-1';
        break;
      case 'junkshop':
        route = '/junkshop-register-1';
        break;
      default:
        route = '/role-selection';
    }

    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending || _resendCooldown > 0) return;

    setState(() => _isResending = true);

    try {
      await _sendVerificationEmail();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification email sent!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Start 60-second cooldown
      setState(() => _resendCooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown > 0) {
          setState(() => _resendCooldown--);
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend email: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _openEmailApp() async {
    try {
      // Create mailto URI to open email app
      final Uri emailUri = Uri.parse('mailto:');

      // Try to launch the email app directly
      final bool launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your email app manually'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // If launch fails, just show a gentle message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open your email app to verify'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _skipVerification() {
    // Cancel the verification check timer
    _verificationCheckTimer?.cancel();
    _cooldownTimer?.cancel();

    // Show a message that they can verify later from profile
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'You can verify your email later from profile settings',
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Navigate to role-specific registration screen
    switch (widget.role) {
      case 'household':
        Navigator.pushReplacementNamed(context, '/household-register');
        break;
      case 'collector':
        Navigator.pushReplacementNamed(context, '/collector-register-1');
        break;
      case 'junkshop':
        Navigator.pushReplacementNamed(context, '/junkshop-register-1');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryGreen.withValues(alpha: 0.85),
              AppColors.primaryGreen.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative paper planes
              Positioned(
                top: 80,
                right: 30,
                child: Transform.rotate(
                  angle: -0.3,
                  child: Icon(
                    Icons.send_rounded,
                    size: 60,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Positioned(
                top: 160,
                left: 40,
                child: Transform.rotate(
                  angle: 0.4,
                  child: Icon(
                    Icons.send_rounded,
                    size: 45,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: 200,
                left: 20,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    Icons.send_rounded,
                    size: 35,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: 150,
                right: 50,
                child: Transform.rotate(
                  angle: 0.5,
                  child: Icon(
                    Icons.send_rounded,
                    size: 50,
                    color: Colors.white.withValues(alpha: 0.13),
                  ),
                ),
              ),

              // Main content
              Column(
                children: [
                  const SizedBox(height: 180),

                  // Large paper plane icon at top for balance
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Icon(
                            Icons.send_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        // Main title
                        Text(
                          'Confirm your email',
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        // Subtitle with email
                        Text(
                          'We just sent you an email to',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.email,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 50),

                        // Open email app button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _openEmailApp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Open email app',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // I didn't receive my email link
                        TextButton(
                          onPressed: (_isResending || _resendCooldown > 0)
                              ? null
                              : _resendVerificationEmail,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: _isResending
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _resendCooldown > 0
                                      ? 'Resend in ${_resendCooldown}s'
                                      : 'I didn\'t receive my email',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Skip button
                        TextButton(
                          onPressed: _skipVerification,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Skip for now',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
