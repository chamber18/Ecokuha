import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../data/services/junkshop_query.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedLogType = 'All';
  final List<String> _logTypes = [
    'All',
    'Purchase',
    'Sale',
    'Price Update',
    'Collection',
    'Collector',
    'Settings',
    'Stock',
  ];

  // Pagination
  static const int _itemsPerPage = 10;
  int _currentPage = 0;
  List<JDoc> _allLogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to no date filter (overall)
    _startDate = null;
    _endDate = null;
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
    });

    final uid = currentUid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    var query = supabase.from('activity_logs').select().eq('junkshop_id', uid);

    // Apply date range filter
    if (_startDate != null) {
      query = query.gte('created_at', _startDate!.toUtc().toIso8601String());
    }
    if (_endDate != null) {
      final endOfDay = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
      query = query.lte('created_at', endOfDay.toUtc().toIso8601String());
    }

    // Apply log type filter
    if (_selectedLogType != 'All') {
      final typeFilter = _mapLogTypeToDbType(_selectedLogType);
      if (typeFilter.isNotEmpty) {
        query = query.eq('type', typeFilter);
      }
    }

    final rows = await query.order('created_at', ascending: false);
    final snapshot = JSnap(
      rowsToDocs('activity_logs', rows).map(JDoc.new).toList(),
    );
    setState(() {
      _allLogs = snapshot.docs;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.junkshopPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _fetchLogs();
    }
  }

  List<JDoc> _getCurrentPageLogs() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _allLogs.length);
    if (startIndex >= _allLogs.length) return [];
    return _allLogs.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_allLogs.length / _itemsPerPage).ceil();

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  String _mapLogTypeToDbType(String displayType) {
    switch (displayType) {
      case 'Purchase':
        return 'purchase';
      case 'Sale':
        return 'sale';
      case 'Price Update':
        return 'price_update';
      case 'Collection':
        return 'collection_completed';
      case 'Collector':
        return 'collector_assigned';
      case 'Settings':
        return 'settings_updated';
      case 'Stock':
        return 'stock_adjustment';
      default:
        return '';
    }
  }

  Color _getLogTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'purchase':
        return AppColors.warningColor;
      case 'sale':
      case 'bulk_sale':
        return AppColors.successColor;
      case 'price_update':
        return AppColors.junkshopPrimary;
      case 'collection_completed':
      case 'collection_declined':
      case 'new_request':
        return AppColors.primaryBlue;
      case 'collector_assigned':
      case 'collector_approved':
      case 'collector_rejected':
        return AppColors.junkshopPrimary;
      case 'material_updated':
      case 'stock_adjustment':
        return AppColors.infoColor;
      case 'settings_updated':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.junkshopPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity Logs',
          style: AppTextStyles.h5.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              children: [
                // Date Range and Log Type Filter - Side by Side
                Row(
                  children: [
                    // Date Range Filter
                    Expanded(
                      child: InkWell(
                        onTap: _selectDateRange,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.date_range,
                                color: AppColors.junkshopPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _startDate != null && _endDate != null
                                      ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                                      : 'Overall',
                                  style: AppTextStyles.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Log Type Filter - Dropdown
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedLogType,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          items: _logTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Row(
                                children: [
                                  if (type != 'All')
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: _getLogTypeColor(
                                          type.toLowerCase(),
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      type,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: _selectedLogType == type
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) async {
                            if (newValue != null) {
                              setState(() {
                                _selectedLogType = newValue;
                              });
                              await _fetchLogs();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.junkshopPrimary,
              onRefresh: () async {
                await _fetchLogs();
              },
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.junkshopPrimary,
                      ),
                    )
                  : _allLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 64,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs found',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      itemCount:
                          _getCurrentPageLogs().length +
                          (_totalPages > 1 ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Pagination controls at the end
                        if (index == _getCurrentPageLogs().length) {
                          return Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            alignment: Alignment.center,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _currentPage > 0
                                        ? () => _goToPage(_currentPage - 1)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    color: AppColors.junkshopPrimary,
                                    disabledColor: Colors.grey[300],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Page ${_currentPage + 1} of $_totalPages',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${_allLogs.length} items)',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _currentPage < _totalPages - 1
                                        ? () => _goToPage(_currentPage + 1)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                    color: AppColors.junkshopPrimary,
                                    disabledColor: Colors.grey[300],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final logs = _getCurrentPageLogs();
                        final log = logs[index].data();
                        final timestamp = toDateTime(log['timestamp']);
                        final type = log['type'] as String? ?? 'system';
                        final message =
                            log['title'] as String? ??
                            log['message'] as String? ??
                            'No message';
                        final details = log['details'] as Map<String, dynamic>?;

                        return Column(
                          children: [
                            InkWell(
                              onTap: details != null
                                  ? () => _showLogDetails(context, log)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Log Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Message
                                          Text(
                                            message,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),

                                          // Timestamp and Type
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Timestamp
                                              Text(
                                                timestamp != null
                                                    ? DateFormat(
                                                        'MMM d, y • h:mm a',
                                                      ).format(timestamp)
                                                    : 'Unknown time',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                              // Log Type Badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getLogTypeColor(
                                                    type,
                                                  ).withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  type
                                                      .replaceAll('_', ' ')
                                                      .toUpperCase(),
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        color: _getLogTypeColor(
                                                          type,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Divider line
                            if (index < _getCurrentPageLogs().length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.borderLight,
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(BuildContext context, Map<String, dynamic> log) {
    final details = log['details'] as Map<String, dynamic>?;
    if (details == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Log Details',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Details Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Basic info
                  _buildDetailRow('Type', log['type'] ?? 'Unknown'),
                  _buildDetailRow('Message', log['message'] ?? 'No message'),
                  _buildDetailRow(
                    'Timestamp',
                    toDateTime(log['timestamp']) != null
                        ? DateFormat(
                            'MMMM d, y • h:mm:ss a',
                          ).format(toDateTime(log['timestamp'])!)
                        : 'Unknown',
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  Text(
                    'Additional Details',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // All detail fields
                  ...details.entries.map((entry) {
                    return _buildDetailRow(
                      entry.key,
                      entry.value?.toString() ?? 'N/A',
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
