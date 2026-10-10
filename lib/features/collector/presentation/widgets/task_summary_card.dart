import 'package:flutter/material.dart';

class TaskSummaryCard extends StatelessWidget {
  final String title;
  final String address;
  final double estimatedEarnings;
  final String timeSlot;
  final String status;
  final String priority;
  final VoidCallback onTap;

  const TaskSummaryCard({
    super.key,
    required this.title,
    required this.address,
    required this.estimatedEarnings,
    required this.timeSlot,
    required this.status,
    required this.priority,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: priority == 'high'
                ? const Color(0xFFEF4444)
                : const Color(0xFFE2E8F0),
            width: priority == 'high' ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority Banner
            if (priority == 'high') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'HIGH PRIORITY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₱${estimatedEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.access_time,
                    'Time Slot',
                    timeSlot,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    Icons.assignment_turned_in,
                    'Status',
                    _getStatusText(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _getStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getActionIcon(), color: _getStatusColor(), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _getActionText(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'assigned':
        return const Color(0xFF3B82F6);
      case 'in_transit':
        return const Color(0xFFF59E0B);
      case 'collecting':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'assigned':
        return Icons.assignment;
      case 'in_transit':
        return Icons.local_shipping;
      case 'collecting':
        return Icons.recycling;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusText() {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
        return 'In Transit';
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  IconData _getActionIcon() {
    switch (status) {
      case 'assigned':
        return Icons.navigation;
      case 'in_transit':
        return Icons.location_on;
      case 'collecting':
        return Icons.camera_alt;
      case 'completed':
        return Icons.receipt;
      default:
        return Icons.info;
    }
  }

  String _getActionText() {
    switch (status) {
      case 'assigned':
        return 'Start Navigation';
      case 'in_transit':
        return 'View on Map';
      case 'collecting':
        return 'Take Photos';
      case 'completed':
        return 'View Receipt';
      default:
        return 'View Details';
    }
  }
}
