import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class NavigationControls extends StatelessWidget {
  final String status;
  final bool isNavigating;
  final VoidCallback onNavigationToggle;
  final void Function(String newStatus) onStatusUpdate;
  final String destination;
  final Map<String, dynamic> coordinates;
  final bool showStatusButtons;

  const NavigationControls({
    super.key,
    required this.status,
    required this.isNavigating,
    required this.onNavigationToggle,
    required this.onStatusUpdate,
    required this.destination,
    required this.coordinates,
    this.showStatusButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    // Status flow order and helpers
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [AppColors.cardShadow],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation toggle only; destination label is shown elsewhere to avoid duplication
          Row(
            children: [
              const Icon(
                Icons.navigation_outlined,
                color: AppColors.collectorPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Open navigation to destination',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: isNavigating,
                onChanged: (_) => onNavigationToggle(),
                activeColor: AppColors.collectorPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Step-wise status controls: moved under Map; optionally shown here for legacy
          if (showStatusButtons)
            Row(
              children: [
                if (hasPrev)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onStatusUpdate(prevStatus!),
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
                    onPressed: hasNext
                        ? () => onStatusUpdate(nextStatus!)
                        : null,
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
