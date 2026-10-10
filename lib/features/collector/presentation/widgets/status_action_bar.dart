import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class StatusActionBar extends StatelessWidget {
  final String status;
  final void Function(String) onUpdateStatus;
  final void Function(String prevStatus)? onGoBack;
  const StatusActionBar({
    super.key,
    required this.status,
    required this.onUpdateStatus,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    const order = [
      'assigned',
      'in_transit',
      'arrived',
      'collecting',
      'completed',
    ];
    final currentIndex = order.indexOf(status);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < order.length - 1;
    final String? nextStatus = hasNext ? order[currentIndex + 1] : null;
    final String? prevStatus = hasPrev ? order[currentIndex - 1] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (hasPrev)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGoBack != null
                    ? () => onGoBack!(prevStatus!)
                    : () => onUpdateStatus(prevStatus!),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.borderLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (hasPrev) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasNext ? () => onUpdateStatus(nextStatus!) : null,
              icon: Icon(_iconFor(nextStatus ?? 'completed')),
              label: Text(_labelFor(nextStatus ?? 'completed')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.collectorPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String status) {
  switch (status) {
    case 'in_transit':
      return Icons.local_shipping_outlined;
    case 'arrived':
      return Icons.place_outlined;
    case 'collecting':
      return Icons.recycling_outlined;
    case 'completed':
    default:
      return Icons.check_circle_outline;
  }
}

String _labelFor(String status) {
  switch (status) {
    case 'in_transit':
      return 'On The Way';
    case 'arrived':
      return 'Arrived';
    case 'collecting':
      return 'Collecting';
    case 'completed':
      return 'Complete';
    default:
      return 'Next';
  }
}
