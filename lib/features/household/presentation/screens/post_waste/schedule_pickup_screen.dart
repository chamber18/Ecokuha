import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class SchedulePickupScreen extends StatefulWidget {
  const SchedulePickupScreen({super.key});

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '';
  String _priority = 'normal';
  final _specialInstructionsController = TextEditingController();

  final List<Map<String, dynamic>> _timeSlots = [
    {
      'id': 'morning',
      'label': 'Morning',
      'time': '8:00 AM - 12:00 PM',
      'icon': 'ðŸŒ…',
      'isAvailable': true,
      'description': 'Best for early pickups',
    },
    {
      'id': 'afternoon',
      'label': 'Afternoon',
      'time': '1:00 PM - 5:00 PM',
      'icon': 'â˜€ï¸',
      'isAvailable': true,
      'description': 'Standard pickup time',
    },
    {
      'id': 'evening',
      'label': 'Evening',
      'time': '6:00 PM - 8:00 PM',
      'icon': 'ðŸŒ†',
      'isAvailable': false,
      'description': 'Limited availability',
    },
  ];

  final List<Map<String, dynamic>> _priorityOptions = [
    {
      'id': 'low',
      'label': 'Standard',
      'description': 'Regular collection within 24-48 hours',
      'price': 0,
      'color': AppColors.textSecondary,
    },
    {
      'id': 'normal',
      'label': 'Priority',
      'description': 'Faster collection within 12-24 hours',
      'price': 25,
      'color': AppColors.primaryBlue,
    },
    {
      'id': 'high',
      'label': 'Express',
      'description': 'Urgent collection within 6-12 hours',
      'price': 50,
      'color': AppColors.primaryGreen,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedTimeSlot = 'morning'; // Default selection
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _selectTimeSlot(String timeSlotId) {
    final timeSlot = _timeSlots.firstWhere((slot) => slot['id'] == timeSlotId);
    if (timeSlot['isAvailable']) {
      setState(() {
        _selectedTimeSlot = timeSlotId;
      });
    }
  }

  void _selectPriority(String priorityId) {
    setState(() {
      _priority = priorityId;
    });
  }

  void _confirmSchedule() async {
    if (_selectedTimeSlot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmationDialog(),
    );

    if (confirmed == true && mounted) {
      // Navigate back to post waste screen with schedule data
      Navigator.pop(context, {
        'date': _selectedDate,
        'timeSlot': _selectedTimeSlot,
        'priority': _priority,
        'specialInstructions': _specialInstructionsController.text,
      });
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (selectedDay == today) {
      return 'Today';
    } else if (selectedDay == tomorrow) {
      return 'Tomorrow';
    } else {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

      return '${weekdays[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${months[_selectedDate.month - 1]}';
    }
  }

  double _getAdditionalFee() {
    final priority = _priorityOptions.firstWhere((p) => p['id'] == _priority);
    return priority['price'].toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selection
                    _buildDateSection(),

                    const SizedBox(height: AppDimensions.spacing32),

                    // Time Slot Selection
                    _buildTimeSlotSection(),

                    const SizedBox(height: AppDimensions.spacing32),

                    // Priority Selection
                    _buildPrioritySection(),

                    const SizedBox(height: AppDimensions.spacing32),

                    // Special Instructions
                    _buildInstructionsSection(),

                    const SizedBox(height: AppDimensions.spacing32),

                    // Summary Card
                    _buildSummaryCard(),

                    const SizedBox(height: AppDimensions.spacing24),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios),
              color: AppColors.textWhite,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Schedule Pickup',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your preferred collection time',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40), // Balance the back button
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.spacing16),

        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getFormattedDate(),
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Time Slot',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.spacing16),

        ...List.generate(_timeSlots.length, (index) {
          final slot = _timeSlots[index];
          final isSelected = _selectedTimeSlot == slot['id'];
          final isAvailable = slot['isAvailable'];

          return Container(
            margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: isAvailable
                  ? AppColors.backgroundLight
                  : AppColors.backgroundDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isSelected && isAvailable
                    ? AppColors.primaryGreen
                    : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected && isAvailable
                  ? [
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              onTap: isAvailable ? () => _selectTimeSlot(slot['id']) : null,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  children: [
                    // Time Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? (isSelected
                                  ? AppColors.primaryGreen.withValues(
                                      alpha: 0.1,
                                    )
                                  : AppColors.backgroundDark)
                            : AppColors.backgroundDark.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          slot['icon'],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppDimensions.spacing16),

                    // Time Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                slot['label'],
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable
                                      ? (isSelected
                                            ? AppColors.primaryGreen
                                            : AppColors.textPrimary)
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (!isAvailable) ...[
                                const SizedBox(width: AppDimensions.spacing8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Full',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.errorColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slot['time'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            slot['description'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Selection Indicator
                    if (isSelected && isAvailable)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Priority',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Text(
          'Higher priority means faster collection but includes additional fees',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),

        ...List.generate(_priorityOptions.length, (index) {
          final option = _priorityOptions[index];
          final isSelected = _priority == option['id'];

          return Container(
            margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isSelected ? option['color'] : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: option['color'].withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              onTap: () => _selectPriority(option['id']),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  children: [
                    // Priority Icon
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: option['color'],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    const SizedBox(width: AppDimensions.spacing16),

                    // Priority Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                option['label'],
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? option['color']
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (option['price'] > 0)
                                Text(
                                  '+â‚±${option['price']}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: option['color'],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option['description'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Selection Indicator
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: option['color'],
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Instructions (Optional)',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.spacing16),

        TextFormField(
          controller: _specialInstructionsController,
          decoration: InputDecoration(
            hintText:
                'Any special instructions for the collector?\ne.g., "Please ring the doorbell", "Items are at the back gate"',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final selectedTimeSlot = _timeSlots.firstWhere(
      (slot) => slot['id'] == _selectedTimeSlot,
    );
    final selectedPriority = _priorityOptions.firstWhere(
      (p) => p['id'] == _priority,
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.1),
            AppColors.primaryBlue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Pickup Summary',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildSummaryRow('Date', _getFormattedDate()),
          _buildSummaryRow(
            'Time',
            '${selectedTimeSlot['label']} (${selectedTimeSlot['time']})',
          ),
          _buildSummaryRow('Priority', selectedPriority['label']),
          if (_getAdditionalFee() > 0)
            _buildSummaryRow(
              'Additional Fee',
              'â‚±${_getAdditionalFee().toStringAsFixed(0)}',
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: CustomButton(
        onPressed: _confirmSchedule,
        text: 'Confirm Schedule',
        backgroundColor: AppColors.primaryGreen,
        width: double.infinity,
        icon: const Icon(Icons.schedule, color: Colors.white),
      ),
    );
  }

  Widget _buildConfirmationDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      title: Text(
        'Confirm Schedule',
        style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to schedule the pickup for:',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ðŸ“… ${_getFormattedDate()}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'â° ${_timeSlots.firstWhere((slot) => slot['id'] == _selectedTimeSlot)['label']}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'âš¡ ${_priorityOptions.firstWhere((p) => p['id'] == _priority)['label']}',
                  style: AppTextStyles.bodySmall,
                ),
                if (_getAdditionalFee() > 0)
                  Text(
                    'ðŸ’° Additional fee: â‚±${_getAdditionalFee().toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: Text(
            'Confirm',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _specialInstructionsController.dispose();
    super.dispose();
  }
}
