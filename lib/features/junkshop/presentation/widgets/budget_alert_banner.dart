import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/theme/app_text_styles.dart';

class BudgetAlertBanner extends StatefulWidget {
  const BudgetAlertBanner({super.key});

  @override
  State<BudgetAlertBanner> createState() => _BudgetAlertBannerState();
}

class _BudgetAlertBannerState extends State<BudgetAlertBanner> {
  bool _isDismissed = false;
  double _currentMonthSpending = 0;
  double _monthlyBudget = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDismissalStatus();
    _loadBudgetData();
  }

  Future<void> _checkDismissalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dismissedDate = prefs.getString('budget_banner_dismissed_date');

    if (dismissedDate != null) {
      final dismissed = DateTime.parse(dismissedDate);
      if (dismissed.year == today.year &&
          dismissed.month == today.month &&
          dismissed.day == today.day) {
        if (mounted) {
          setState(() => _isDismissed = true);
        }
      }
    }
  }

  Future<void> _loadBudgetData() async {
    try {
      final userId = currentUid;
      if (userId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final data = await supabase
          .from('junkshops')
          .select('settings')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        final settings = data['settings'] as Map<String, dynamic>?;

        setState(() {
          _currentMonthSpending =
              ((settings?['currentMonthSpending'] ?? 0) as num).toDouble();
          _monthlyBudget = ((settings?['monthlyBudget'] ?? 0) as num)
              .toDouble();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'budget_banner_dismissed_date',
      DateTime.now().toIso8601String(),
    );
    if (mounted) {
      setState(() => _isDismissed = true);
    }
  }

  double get _budgetPercentage {
    if (_monthlyBudget == 0) return 0;
    return (_currentMonthSpending / _monthlyBudget) * 100;
  }

  bool get _shouldShowBanner {
    return !_isDismissed &&
        !_isLoading &&
        _monthlyBudget > 0 &&
        _budgetPercentage >= 80;
  }

  Color get _bannerColor {
    if (_budgetPercentage >= 100) return Colors.red;
    if (_budgetPercentage >= 80) return Colors.orange;
    return Colors.transparent;
  }

  IconData get _bannerIcon {
    if (_budgetPercentage >= 100) return Icons.error;
    return Icons.warning;
  }

  String get _bannerMessage {
    if (_budgetPercentage >= 100) {
      return 'Budget limit reached! Collections are being rejected.';
    }
    return 'Approaching budget limit (${_budgetPercentage.toStringAsFixed(0)}%). Review your controls.';
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowBanner) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _bannerColor.withValues(alpha: 0.1),
        border: Border.all(color: _bannerColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(_bannerIcon, color: _bannerColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Alert',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _bannerColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bannerMessage,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/junkshop/business-controls',
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _bannerColor,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View Controls',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey[600],
                onPressed: _dismissBanner,
                tooltip: 'Dismiss until tomorrow',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
