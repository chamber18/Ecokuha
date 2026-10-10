import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_text_styles.dart';

class CancelPickupDialog extends StatefulWidget {
  const CancelPickupDialog({super.key});

  @override
  State<CancelPickupDialog> createState() => _CancelPickupDialogState();
}

class _CancelPickupDialogState extends State<CancelPickupDialog> {
  final List<String> _selectedReasons = [];
  final TextEditingController _detailController = TextEditingController();
  File? _proofPhoto;
  final ImagePicker _picker = ImagePicker();

  final Map<String, Map<String, dynamic>> _cancellationReasons = {
    'household_not_home': {
      'label': 'Household not home',
      'icon': Icons.home_outlined,
      'color': Colors.orange,
    },
    'items_mismatch': {
      'label': 'Items do not match posting',
      'icon': Icons.compare_arrows,
      'color': Colors.purple,
    },
    'items_not_recyclable': {
      'label': 'Items not recyclable',
      'icon': Icons.block,
      'color': Colors.red,
    },
    'incorrect_address': {
      'label': 'Incorrect address',
      'icon': Icons.location_off,
      'color': Colors.blue,
    },
    'unsafe_location': {
      'label': 'Unsafe location/area',
      'icon': Icons.warning_amber,
      'color': Colors.deepOrange,
    },
    'items_already_collected': {
      'label': 'Already collected',
      'icon': Icons.check_circle_outline,
      'color': Colors.teal,
    },
    'items_too_contaminated': {
      'label': 'Items too contaminated',
      'icon': Icons.dirty_lens,
      'color': Colors.brown,
    },
    'household_changed_mind': {
      'label': 'Household cancelled',
      'icon': Icons.person_off,
      'color': Colors.indigo,
    },
    'duplicate_posting': {
      'label': 'Duplicate posting',
      'icon': Icons.content_copy,
      'color': Colors.cyan,
    },
    'other': {
      'label': 'Other reason',
      'icon': Icons.more_horiz,
      'color': Colors.grey,
    },
  };

  bool get _requiresProofPhoto =>
      _selectedReasons.contains('household_not_home');

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _takeProofPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _proofPhoto = File(photo.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  void _toggleReason(String reason) {
    setState(() {
      if (_selectedReasons.contains(reason)) {
        _selectedReasons.remove(reason);
        // Clear proof photo if household_not_home is deselected
        if (reason == 'household_not_home') {
          _proofPhoto = null;
        }
      } else {
        _selectedReasons.add(reason);
      }
    });
  }

  bool _canSubmit() {
    if (_selectedReasons.isEmpty) return false;
    if (_requiresProofPhoto && _proofPhoto == null) return false;
    return true;
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
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: Colors.red.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cancel Pickup',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
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
                    // Proof photo warning banner
                    if (_requiresProofPhoto)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: Colors.orange.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Photo proof required',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Cancellation reasons - simplified cards
                    ..._cancellationReasons.entries.map((entry) {
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
                                      ? Colors.red
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
                                        ? Colors.red
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
                                            ? Colors.red.shade900
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? Colors.red
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

                    // Proof photo capture
                    if (_requiresProofPhoto) ...[
                      if (_proofPhoto != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _proofPhoto!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _proofPhoto = null),
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _takeProofPhoto,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Take Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            minimumSize: const Size(double.infinity, 40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

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
                            color: Colors.red,
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
                        'Back',
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
                                'proofPhoto': _proofPhoto,
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text(
                        'Cancel Pickup',
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
