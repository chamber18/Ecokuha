import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';

class ExcelPreviewSheet extends StatefulWidget {
  final String filePath;
  final String fileName;

  const ExcelPreviewSheet({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<ExcelPreviewSheet> createState() => _ExcelPreviewSheetState();
}

class _ExcelPreviewSheetState extends State<ExcelPreviewSheet> {
  List<List<String>> _tableData = [];
  List<String> _headers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExcelPreview();
  }

  Future<void> _loadExcelPreview() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        setState(() {
          _errorMessage = 'No sheets found in Excel file';
          _isLoading = false;
        });
        return;
      }

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        setState(() {
          _errorMessage = 'No data found in Excel file';
          _isLoading = false;
        });
        return;
      }

      final rows = sheet.rows;
      if (rows.isEmpty) {
        setState(() {
          _errorMessage = 'Excel file is empty';
          _isLoading = false;
        });
        return;
      }

      // Skip title rows and find header row
      int headerRowIndex = 0;
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].any(
          (cell) =>
              (cell?.value.toString().contains('Date') ?? false) ||
              (cell?.value.toString().contains('Material') ?? false) ||
              (cell?.value.toString().contains('Customer') ?? false) ||
              (cell?.value.toString().contains('Transaction') ?? false),
        )) {
          headerRowIndex = i;
          break;
        }
      }

      _headers = rows[headerRowIndex]
          .map((cell) => cell?.value?.toString() ?? '')
          .where((h) => h.isNotEmpty)
          .toList();

      // Find where data ends (before summary rows)
      int dataEndIndex = rows.length;
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final firstCell = rows[i].isNotEmpty
            ? rows[i][0]?.value?.toString() ?? ''
            : '';
        // Stop if we hit summary rows (Total, Summary, etc.)
        if (firstCell.toLowerCase().contains('total') ||
            firstCell.toLowerCase().contains('summary') ||
            firstCell.toLowerCase().contains('grand total')) {
          dataEndIndex = i;
          break;
        }
      }

      _tableData = rows
          .skip(headerRowIndex + 1)
          .take(dataEndIndex - headerRowIndex - 1)
          .take(20)
          .map(
            (row) => row
                .take(_headers.length)
                .map((cell) => cell?.value?.toString() ?? '')
                .toList(),
          )
          .where((row) => row.any((cell) => cell.isNotEmpty))
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load preview: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFile() async {
    try {
      await Share.shareXFiles([
        XFile(widget.filePath),
      ], text: 'Share ${widget.fileName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.table_chart, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.fileName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareFile(),
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: InteractiveViewer(
                minScale: 0.1,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(20),
                panEnabled: true,
                scaleEnabled: true,
                constrained: false,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.primaryGreen.withValues(alpha: 0.1),
                  ),
                  columns: _headers
                      .map(
                        (header) => DataColumn(
                          label: Text(
                            header,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  rows: _tableData
                      .map(
                        (row) => DataRow(
                          cells: row
                              .map(
                                (cell) => DataCell(
                                  Text(
                                    cell,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (!_isLoading && _errorMessage == null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Text(
                'Showing first ${_tableData.length} rows',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
