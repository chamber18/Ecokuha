import 'package:flutter/material.dart';

class TaskStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final Function(String) onStatusTap;

  const TaskStatusTimeline({
    super.key,
    required this.currentStatus,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      {'id': 'assigned', 'label': 'Assigned', 'icon': Icons.assignment},
      {'id': 'in_transit', 'label': 'In Transit', 'icon': Icons.local_shipping},
      {'id': 'arrived', 'label': 'Arrived', 'icon': Icons.location_on},
      {'id': 'collecting', 'label': 'Collecting', 'icon': Icons.recycling},
      {'id': 'completed', 'label': 'Completed', 'icon': Icons.check_circle},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Expanded(
                child: Text(
                  'Task Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  _statusLabel(currentStatus),
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isActive = _isStatusActive(status['id'] as String);
              final isCompleted = _isStatusCompleted(status['id'] as String);
              final isCurrent = currentStatus == status['id'];

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onStatusTap(status['id'] as String),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFF10B981)
                                    : isCurrent
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                                border: isCurrent
                                    ? Border.all(
                                        color: const Color(0xFF3B82F6),
                                        width: 3,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                status['icon'] as IconData,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (index < statuses.length - 1) ...[
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE2E8F0),
                          margin: const EdgeInsets.symmetric(vertical: 19),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _isStatusActive(String status) {
    return _isStatusCompleted(status) || currentStatus == status;
  }

  bool _isStatusCompleted(String status) {
    final statusOrder = [
      'assigned',
      'in_transit',
      'arrived',
      'collecting',
      'completed',
    ];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final statusIndex = statusOrder.indexOf(status);
    return statusIndex < currentIndex;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_transit':
        return 'In Transit';
      case 'arrived':
        return 'Arrived';
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      case 'assigned':
      default:
        return 'Assigned';
    }
  }
}
