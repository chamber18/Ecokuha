import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/common/common_widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/di/service_locator.dart';
import '../bloc/register/register_bloc.dart';
import '../bloc/register/register_event.dart';
import '../bloc/register/register_state.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? role; // 'household' | 'collector' | 'junkshop'
  const RegisterScreen({super.key, this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
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
                child: BlocProvider(
                  create: (_) => getIt<RegisterBloc>(),
                  child: BlocConsumer<RegisterBloc, RegisterState>(
                    listener: (context, state) {
                      if (state.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.error!),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else if (state.success) {
                        // Navigate to email verification screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailVerificationScreen(
                              email: _emailController.text.trim(),
                              role: role ?? 'household',
                            ),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo and header section
                          _buildHeader(role),

                          const SizedBox(height: 48),

                          // Registration form
                          _buildRegistrationForm(context, state, role),

                          const SizedBox(height: 32),

                          // Divider
                          _buildDivider(),

                          const SizedBox(height: 32),

                          // Social login buttons
                          _buildSocialButtons(context, state, role),

                          const SizedBox(height: 40),

                          // Existing user section
                          _buildSignInSection(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(String? role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome text
        Text(
          role == null
              ? 'Create Account'
              : 'Create ${_formatRole(role)} Account',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 34,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Join B.B.P. Tracker and start making a difference',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String _formatRole(String role) {
    if (role == 'household') return 'Household';
    if (role == 'collector') return 'Collector';
    if (role == 'junkshop') return 'Junk Shop';
    return role;
  }

  Widget _buildRegistrationForm(
    BuildContext context,
    RegisterState state,
    String? role,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
          CustomTextField(
            label: 'Email Address',
            hint: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
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

          // Password
          CustomTextField(
            label: 'Password',
            hint: 'Create a password',
            controller: _passwordController,
            obscureText: _obscurePassword,
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
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
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
          const SizedBox(height: 20),

          // Confirm Password
          CustomTextField(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Create Account Button
          CustomButton(
            text: state.isLoading ? 'Creating account...' : 'Create Account',
            onPressed: state.isLoading
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      context.read<RegisterBloc>().add(
                        SubmitRegister(
                          email: _emailController.text.trim(),
                          password: _passwordController.text,
                          confirmPassword: _confirmPasswordController.text,
                          role: role,
                        ),
                      );
                    }
                  },
            backgroundColor: AppColors.primaryGreen,
            isLoading: state.isLoading,
            height: 56,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons(
    BuildContext context,
    RegisterState state,
    String? role,
  ) {
    return CustomButton(
      text: 'Google',
      onPressed: state.isLoading
          ? null
          : () => context.read<RegisterBloc>().add(
              SocialRegisterPressed(provider: 'google', role: role),
            ),
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

  Widget _buildSignInSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Sign In',
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
