import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class ReschedulePickupDialog extends StatefulWidget {
  const ReschedulePickupDialog({super.key});

  @override
  State<ReschedulePickupDialog> createState() => _ReschedulePickupDialogState();
}

class _ReschedulePickupDialogState extends State<ReschedulePickupDialog> {
  final List<String> _selectedReasons = [];
  final TextEditingController _detailController = TextEditingController();

  final Map<String, Map<String, dynamic>> _rescheduleReasons = {
    'bad_weather': {
      'label': 'Bad weather conditions',
      'icon': Icons.cloud,
      'color': Colors.blue,
    },
    'traffic_delay': {
      'label': 'Severe traffic delay',
      'icon': Icons.traffic,
      'color': Colors.red,
    },
    'vehicle_issue': {
      'label': 'Vehicle maintenance',
      'icon': Icons.build,
      'color': Colors.brown,
    },
    'time_conflict': {
      'label': 'Schedule conflict',
      'icon': Icons.event_busy,
      'color': Colors.purple,
    },
    'personal_emergency': {
      'label': 'Personal emergency',
      'icon': Icons.emergency,
      'color': Colors.deepOrange,
    },
    'route_optimization': {
      'label': 'Route optimization',
      'icon': Icons.route,
      'color': Colors.teal,
    },
    'late_running': {
      'label': 'Running late',
      'icon': Icons.schedule,
      'color': Colors.indigo,
    },
    'equipment_needed': {
      'label': 'Special equipment needed',
      'icon': Icons.handyman,
      'color': Colors.cyan,
    },
    'other': {
      'label': 'Other reason',
      'icon': Icons.more_horiz,
      'color': Colors.grey,
    },
  };

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  void _toggleReason(String reason) {
    setState(() {
      if (_selectedReasons.contains(reason)) {
        _selectedReasons.remove(reason);
      } else {
        _selectedReasons.add(reason);
      }
    });
  }

  bool _canSubmit() {
    return _selectedReasons.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Request Reschedule',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reschedule reasons - simplified cards
                    ..._rescheduleReasons.entries.map((entry) {
                      final isSelected = _selectedReasons.contains(entry.key);
                      final reasonData = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleReason(entry.key),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.grey.shade100
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.orange
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    reasonData['icon'] as IconData,
                                    color: isSelected
                                        ? Colors.orange
                                        : Colors.grey.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      reasonData['label'] as String,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.orange.shade900
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? Colors.orange
                                        : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Additional details text field
                    TextField(
                      controller: _detailController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Additional Details (Optional)',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        hintText: 'Add context...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canSubmit()
                          ? () {
                              Navigator.pop(context, {
                                'selectedReasons': _selectedReasons,
                                'detail': _detailController.text.trim(),
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text(
                        'Request Reschedule',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
