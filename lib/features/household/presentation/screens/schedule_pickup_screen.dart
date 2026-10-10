import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SchedulePickupScreen extends StatefulWidget {
  final String? junkshopName;
  final String? location;

  const SchedulePickupScreen({super.key, this.junkshopName, this.location});

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  final TextEditingController _instructionsController = TextEditingController();
  final List<DateTime> _selectedDates = [];
  String _fromTime = '08:00';
  String _toTime = '17:00';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      final existingDates = args?['existingDates'] as List<dynamic>?;
      if (existingDates != null && existingDates.isNotEmpty) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        setState(() {
          _selectedDates.clear();
          for (var date in existingDates) {
            if (date is DateTime) {
              final dateOnly = DateTime(date.year, date.month, date.day);
              if (!dateOnly.isBefore(today)) {
                _selectedDates.add(date);
              }
            }
          }
          if (_selectedDates.isEmpty && existingDates.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Previous unavailable dates have passed. You can add new dates when you\'re not available.',
                    ),
                    backgroundColor: AppColors.warningColor,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            });
          }
        });
      }

      final existingTimeSlot = args?['existingTimeSlot'] as String?;
      if (existingTimeSlot != null && existingTimeSlot.contains(' - ')) {
        final times = existingTimeSlot.split(' - ');
        if (times.length == 2) {
          setState(() {
            _fromTime = times[0].trim();
            _toTime = times[1].trim();
          });
        }
      }

      final existingInstructions = args?['existingInstructions'] as String?;
      if (existingInstructions != null && existingInstructions.isNotEmpty) {
        _instructionsController.text = existingInstructions;
      }
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final junkshopName =
        widget.junkshopName ?? args?['junkshopName'] as String?;
    final location = widget.location ?? args?['location'] as String?;
    final itemCount = args?['itemCount'] as int? ?? 0;
    final totalValue = args?['totalEstimatedValue'] as double? ?? 0.0;
    final totalValueMax =
        args?['totalEstimatedValueMax'] as double? ?? totalValue;
    final isEditMode = args?['isEditMode'] as bool? ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // ”€”€ App bar ”€”€
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditMode ? 'Update Post' : 'Schedule Pickup',
                          style: AppTextStyles.h5.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (junkshopName != null)
                          Text(
                            junkshopName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Item count badge
                  if (itemCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ”€”€ Scrollable content ”€”€
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Unavailable dates section
                    _buildSection(
                      label: 'Unavailable Dates',
                      subtitle: 'Block dates you\'re NOT available',
                      child: _buildDatesContent(),
                    ),
                    const SizedBox(height: 16),
                    // Time window section
                    _buildSection(
                      label: 'Preferred Time Window',
                      subtitle: 'When can the collector arrive?',
                      child: _buildTimeContent(),
                    ),
                    const SizedBox(height: 16),
                    // Instructions section
                    _buildSection(
                      label: 'Special Instructions',
                      subtitle: 'Optional notes for the collector',
                      child: _buildInstructionsContent(),
                    ),
                    const SizedBox(height: 16),
                    // Summary section
                    _buildSummaryCard(
                      junkshopName: junkshopName,
                      location: location,
                      itemCount: itemCount,
                      totalValue: totalValue,
                      totalValueMax: totalValueMax,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // ”€”€ Confirm button ”€”€
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _confirmPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isEditMode ? 'Update Post' : 'Confirm & Post',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String label,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDatesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDates.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedDates.map((date) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_getDayName(date.weekday).substring(0, 3)}, ${date.day} ${_getShortMonthName(date.month)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeDate(date),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Date',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeContent() {
    return Row(
      children: [
        Expanded(
          child: _buildTimeCard(
            label: 'From',
            time: _fromTime,
            onTap: () => _selectTime(context, true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: _buildTimeCard(
            label: 'To',
            time: _toTime,
            onTap: () => _selectTime(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard({
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeTo12Hour(time),
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsContent() {
    return TextField(
      controller: _instructionsController,
      maxLines: 3,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: 'e.g. Place items near the gate...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        DateTime displayMonth = DateTime.now();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final currentMonth = DateTime(
              displayMonth.year,
              displayMonth.month,
              1,
            );
            final daysInMonth = DateTime(
              displayMonth.year,
              displayMonth.month + 1,
              0,
            ).day;
            final firstWeekday = currentMonth.weekday % 7;
            final canGoBack = displayMonth.isAfter(
              DateTime(now.year, now.month, 1),
            );
            final canGoForward = displayMonth.isBefore(
              now.add(const Duration(days: 60)),
            );

            return GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 0 && canGoBack) {
                  setSheetState(() {
                    displayMonth = DateTime(
                      displayMonth.year,
                      displayMonth.month - 1,
                      1,
                    );
                  });
                } else if (details.primaryVelocity! < 0 && canGoForward) {
                  setSheetState(() {
                    displayMonth = DateTime(
                      displayMonth.year,
                      displayMonth.month + 1,
                      1,
                    );
                  });
                }
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ”€”€ Drag handle ”€”€
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ”€”€ Header ”€”€
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Block Unavailable Dates',
                                  style: AppTextStyles.h5.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap dates you cannot receive pickups',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(sheetContext),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ”€”€ Month navigation ”€”€
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: canGoBack
                                ? () => setSheetState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month - 1,
                                      1,
                                    );
                                  })
                                : null,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: canGoBack
                                    ? AppColors.primaryGreen.withValues(
                                        alpha: 0.1,
                                      )
                                    : const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 22,
                                color: canGoBack
                                    ? AppColors.primaryGreen
                                    : AppColors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                          ),
                          Text(
                            '${_getMonthName(displayMonth.month)} ${displayMonth.year}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: canGoForward
                                ? () => setSheetState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month + 1,
                                      1,
                                    );
                                  })
                                : null,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: canGoForward
                                    ? AppColors.primaryGreen.withValues(
                                        alpha: 0.1,
                                      )
                                    : const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 22,
                                color: canGoForward
                                    ? AppColors.primaryGreen
                                    : AppColors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ”€”€ Day-of-week headers ”€”€
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children:
                            ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                .map(
                                  (d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 8),

                      // ”€”€ Calendar grid ”€”€
                      ...List.generate(
                        ((daysInMonth + firstWeekday - 1) ~/ 7) + 1,
                        (weekIndex) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(7, (dayIndex) {
                              final cellIndex = weekIndex * 7 + dayIndex;
                              final dayNumber = cellIndex - firstWeekday + 1;
                              if (cellIndex < firstWeekday ||
                                  dayNumber > daysInMonth) {
                                return const Expanded(child: SizedBox());
                              }
                              final date = DateTime(
                                displayMonth.year,
                                displayMonth.month,
                                dayNumber,
                              );
                              final isPast = date.isBefore(today);
                              final isTooFar = date.isAfter(
                                today.add(const Duration(days: 60)),
                              );
                              final isDisabled = isPast || isTooFar;
                              final isToday = date == today;
                              final isBlocked = _selectedDates.any(
                                (d) =>
                                    d.year == date.year &&
                                    d.month == date.month &&
                                    d.day == date.day,
                              );

                              return Expanded(
                                child: GestureDetector(
                                  onTap: isDisabled
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            setState(() {
                                              if (isBlocked) {
                                                _selectedDates.removeWhere(
                                                  (d) =>
                                                      d.year == date.year &&
                                                      d.month == date.month &&
                                                      d.day == date.day,
                                                );
                                              } else {
                                                _selectedDates.add(date);
                                                _selectedDates.sort();
                                              }
                                            });
                                          });
                                        },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isBlocked
                                          ? Colors.red.shade50
                                          : isToday && !isBlocked
                                          ? AppColors.primaryGreen.withValues(
                                              alpha: 0.08,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isBlocked
                                          ? Border.all(
                                              color: Colors.red.shade300,
                                              width: 1.5,
                                            )
                                          : isToday
                                          ? Border.all(
                                              color: AppColors.primaryGreen,
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        dayNumber.toString(),
                                        style: TextStyle(
                                          color: isDisabled
                                              ? AppColors.textSecondary
                                                    .withValues(alpha: 0.25)
                                              : isBlocked
                                              ? Colors.red.shade700
                                              : isToday
                                              ? AppColors.primaryGreen
                                              : AppColors.textPrimary,
                                          fontWeight: isBlocked || isToday
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ”€”€ Blocked dates chips ”€”€
                      if (_selectedDates.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Blocked (${_selectedDates.length})',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedDates.map((d) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_getDayName(d.weekday).substring(0, 3)}, ${d.day} ${_getShortMonthName(d.month)}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        setState(() {
                                          _selectedDates.removeWhere(
                                            (x) =>
                                                x.year == d.year &&
                                                x.month == d.month &&
                                                x.day == d.day,
                                          );
                                        });
                                      });
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.red.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ”€”€ Done button ”€”€
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _selectedDates.isEmpty
                                ? 'No Blocked Dates'
                                : 'Confirm ${_selectedDates.length} Blocked Date${_selectedDates.length > 1 ? 's' : ''}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.removeWhere(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      );
    });
  }

  Future<void> _selectTime(BuildContext context, bool isFromTime) async {
    final currentTime = isFromTime ? _fromTime : _toTime;
    final parts = currentTime.split(':');
    final initHour24 = int.parse(parts[0]).clamp(8, 17);
    final initMinute = int.parse(parts[1]);

    // Valid hours: 8 AM to 5 PM only
    const validHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
    const hourLabels = [
      '8 AM',
      '9 AM',
      '10 AM',
      '11 AM',
      '12 PM',
      '1 PM',
      '2 PM',
      '3 PM',
      '4 PM',
      '5 PM',
    ];
    final minutes = List.generate(12, (i) => i * 5);
    final initHourIdx = validHours.indexOf(initHour24).clamp(0, 9);
    final nearestMinuteIdx = minutes
        .indexWhere((m) => m >= initMinute)
        .clamp(0, 11);

    final hourCtrl = FixedExtentScrollController(initialItem: initHourIdx);
    final minuteCtrl = FixedExtentScrollController(
      initialItem: nearestMinuteIdx,
    );

    int selectedHourIdx = initHourIdx;
    int selectedMinute = minutes[nearestMinuteIdx];

    const itemH = 48.0;
    const visibleItems = 3;

    Widget drum({
      required FixedExtentScrollController ctrl,
      required List<String> items,
      required void Function(int) onChanged,
    }) {
      return SizedBox(
        height: itemH * visibleItems,
        child: Stack(
          children: [
            Positioned(
              top: itemH,
              left: 0,
              right: 0,
              child: Container(
                height: itemH,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: itemH,
              diameterRatio: 2.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (context, index) {
                  final isSel = ctrl.hasClients
                      ? ctrl.selectedItem == index
                      : false;
                  return Center(
                    child: Text(
                      items[index],
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w400,
                        fontSize: isSel ? 20 : 16,
                        color: isSel
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 40,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.07),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFromTime ? 'From Time' : 'To Time',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Available: 8:00 AM  5:00 PM',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Column labels
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: Text(
                            'Hour',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            'Minute',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Drums
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: drum(
                          ctrl: hourCtrl,
                          items: hourLabels,
                          onChanged: (i) => setD(() => selectedHourIdx = i),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          ':',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: drum(
                          ctrl: minuteCtrl,
                          items: minutes
                              .map((m) => m.toString().padLeft(2, '0'))
                              .toList(),
                          onChanged: (i) =>
                              setD(() => selectedMinute = minutes[i]),
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final hour24 = validHours[selectedHourIdx];
                            final formatted =
                                '${hour24.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
                            setState(() {
                              if (isFromTime) {
                                _fromTime = formatted;
                              } else {
                                _toTime = formatted;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    hourCtrl.dispose();
    minuteCtrl.dispose();
  }

  String _formatTimeTo12Hour(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    if (hour == 0) return '12:$minute AM';
    if (hour < 12) return '$hour:$minute AM';
    if (hour == 12) return '12:$minute PM';
    return '${hour - 12}:$minute PM';
  }

  Widget _buildSummaryCard({
    String? junkshopName,
    String? location,
    int itemCount = 0,
    double totalValue = 0.0,
    double totalValueMax = 0.0,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup Summary',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (junkshopName != null) ...[
            _buildSummaryRow(
              icon: Icons.store_rounded,
              label: 'Junk Shop',
              value: junkshopName,
            ),
            const SizedBox(height: 12),
          ],
          if (location != null) ...[
            _buildSummaryRow(
              icon: Icons.location_on_rounded,
              label: 'Address',
              value: location,
            ),
            const SizedBox(height: 12),
          ],
          _buildSummaryRow(
            icon: Icons.block_rounded,
            label: 'Unavailable Dates',
            value: _selectedDates.isNotEmpty
                ? _selectedDates
                      .map(
                        (d) =>
                            '${_getDayName(d.weekday).substring(0, 3)} ${d.day} ${_getShortMonthName(d.month)}',
                      )
                      .join(', ')
                : 'None blocked',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.access_time_rounded,
            label: 'Time Window',
            value:
                '${_formatTimeTo12Hour(_fromTime)} – ${_formatTimeTo12Hour(_toTime)}',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.inventory_2_rounded,
            label: 'Items',
            value: '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
          ),
          if (totalValue > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.payments_rounded,
              label: 'Estimated Value',
              value: (totalValueMax - totalValue).abs() < 0.01
                  ? '₱${totalValue.toStringAsFixed(2)}'
                  : '₱${totalValue.toStringAsFixed(2)} – ₱${totalValueMax.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmPost() async {
    final scheduleData = {
      'dates': _selectedDates,
      'fromTime': _fromTime,
      'toTime': _toTime,
      'specialInstructions': _instructionsController.text.trim(),
    };
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    Navigator.pop(context, scheduleData);
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getShortMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}
