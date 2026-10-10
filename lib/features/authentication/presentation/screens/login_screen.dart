import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/common/common_widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../bloc/login/login_bloc.dart';
import '../../domain/entities/auth_user_entity.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      // Trigger login via BLoC
      context.read<LoginBloc>().add(
        LoginSubmitted(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  void _navigateBasedOnRole(
    UserRole role, {
    bool isProfileComplete = false,
    String? applicationStatus,
    bool hadPriorApproval = false,
  }) {
    if (!isProfileComplete) {
      // Send to role-specific onboarding forms if profile is incomplete.
      switch (role) {
        case UserRole.household:
          Navigator.pushReplacementNamed(context, '/household-register');
          return;
        case UserRole.collector:
          Navigator.pushReplacementNamed(context, '/collector-register-1');
          return;
        case UserRole.junkshop:
          Navigator.pushReplacementNamed(context, '/junkshop-register-1');
          return;
      }
    }

    // Special case: Collector with pending or rejected application status
    // If rejected AND they were previously approved (rejecting a reapplication),
    // send them to the dashboard — it shows a rejection banner with a reapply option.
    // If rejected with no prior approval (first-time rejection), send to pending screen.
    if (role == UserRole.collector &&
        (applicationStatus == 'pending' ||
            (applicationStatus == 'rejected' && !hadPriorApproval))) {
      Navigator.pushReplacementNamed(context, '/auth/collector-pending');
      return;
    }
    // Reapplying and rejected-after-reapply collectors go to the dashboard

    // Special case: Junkshop with pending or rejected application status
    if (role == UserRole.junkshop &&
        (applicationStatus == 'pending' || applicationStatus == 'rejected')) {
      Navigator.pushReplacementNamed(context, '/junkshop-pending');
      return;
    }

    // Profile complete — go to dashboards
    switch (role) {
      case UserRole.household:
        Navigator.pushReplacementNamed(context, '/household-home');
        break;
      case UserRole.collector:
        Navigator.pushReplacementNamed(context, '/collector-home');
        break;
      case UserRole.junkshop:
        Navigator.pushReplacementNamed(context, '/junkshop-dashboard');
        break;
    }
  }

  // Removed direct navigation button to role selection from login per design

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (kDebugMode) {
          print('🔵 LoginBloc state changed: ${state.runtimeType}');
        }
        if (state is LoginSuccess) {
          if (kDebugMode) {
            print('🟢 Login successful! Navigating based on role...');
            if (kDebugMode) print('🟢 Role: ${state.user.role}');
            if (kDebugMode) {
              print('🟢 Profile complete: ${state.user.isProfileComplete}');
            }
            if (kDebugMode) {
              print('🟢 Application status: ${state.user.applicationStatus}');
            }
          }
          // Clear any errors
          setState(() {
            _emailError = null;
            _passwordError = null;
            _generalError = null;
          });
          // Navigate based on user role and profile completion
          _navigateBasedOnRole(
            state.user.role,
            isProfileComplete: state.user.isProfileComplete,
            applicationStatus: state.user.applicationStatus,
            hadPriorApproval: state.user.hadPriorApproval,
          );
        } else if (state is LoginFailure) {
          if (kDebugMode) print('🔴 Login failed: ${state.message}');
          setState(() {
            // Categorize error based on message
            final message = state.message.toLowerCase();
            if (message.contains('email or password is incorrect')) {
              // Generic auth error - show below password field
              _passwordError = state.message;
              _emailError = null;
              _generalError = null;
            } else if (message.contains('invalid email')) {
              _emailError = state.message;
              _passwordError = null;
              _generalError = null;
            } else {
              // Network, too many attempts, etc.
              _generalError = state.message;
              _emailError = null;
              _passwordError = null;
            }
          });
        } else if (state is LoginLoading) {
          // Clear errors when attempting login
          setState(() {
            _emailError = null;
            _passwordError = null;
            _generalError = null;
          });
        }
      },
      child: BlocBuilder<LoginBloc, LoginState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 48.0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 96,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo and header section
                          _buildHeader(),

                          const SizedBox(height: 48),

                          // Login form
                          _buildLoginForm(isLoading: state is LoginLoading),

                          const SizedBox(height: 32),

                          // Divider
                          _buildDivider(),

                          const SizedBox(height: 32),

                          // Social login buttons
                          _buildSocialButtons(),

                          const SizedBox(height: 40),

                          // New user section
                          _buildNewUserSection(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App logo
        Image.asset(
          'assets/images/logos/bbp logo-200px.png',
          width: 84,
          height: 84,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        // Welcome text
        Text(
          'Welcome Back',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue to B.B.P. Tracker',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm({bool isLoading = false}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Field
          CustomTextField(
            label: 'Email Address',
            hint: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onChanged: (value) {
              // Clear errors when user starts typing
              if (_emailError != null || _generalError != null) {
                setState(() {
                  _emailError = null;
                  _generalError = null;
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Password Field
          CustomTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            errorText: _passwordError,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: _togglePasswordVisibility,
            ),
            onChanged: (value) {
              // Clear errors when user starts typing
              if (_passwordError != null || _generalError != null) {
                setState(() {
                  _passwordError = null;
                  _generalError = null;
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // General error message
          if (_generalError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _generalError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Login Button
          CustomButton(
            text: isLoading ? 'Logging in...' : 'Sign In',
            onPressed: isLoading ? null : _login,
            backgroundColor: AppColors.primaryGreen,
            isLoading: isLoading,
            height: 56,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return CustomButton(
      text: 'Google',
      onPressed: () {
        context.read<LoginBloc>().add(GoogleSignInRequested());
      },
      backgroundColor: Colors.white,
      isOutlined: true,
      borderColor: AppColors.borderLight,
      borderWidth: 1.5,
      textColor: AppColors.textPrimary,
      height: 54,
      icon: const FaIcon(
        FontAwesomeIcons.google,
        size: 20,
        color: Color(0xFFDB4437),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderLight)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderLight)),
      ],
    );
  }

  Widget _buildNewUserSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/role-selection'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Sign Up',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
