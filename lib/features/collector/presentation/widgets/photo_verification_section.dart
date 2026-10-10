import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';

class PhotoVerificationSection extends StatelessWidget {
  final String status; // arrived, collecting, completed
  final Map<String, List> photos; // before, after, items
  final void Function(String category, List<String> photos) onPhotosUpdated;
  const PhotoVerificationSection({
    super.key,
    required this.status,
    required this.photos,
    required this.onPhotosUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final arrivalCount = (photos['arrival'] ?? []).length;
    final collectionCount = (photos['collection'] ?? []).length;
    final paymentCount = (photos['payment'] ?? []).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.collectorPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.collectorPrimary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Verification',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Take clear photos as proof of collection',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                if (status == 'arrived' ||
                    status == 'collecting' ||
                    status == 'completed') ...[
                  _PhotoStepCard(
                    stepNumber: 1,
                    label: 'Proof of Arrival',
                    subtitle: 'Photo at the pickup location',
                    accentColor: AppColors.collectorPrimary,
                    photoCount: arrivalCount,
                    onEdit: () => _openEditor('arrival', context),
                  ),
                  const SizedBox(height: 10),
                ],
                if (status == 'collecting' || status == 'completed') ...[
                  _PhotoStepCard(
                    stepNumber: 2,
                    label: 'Proof of Collection',
                    subtitle: 'Photo of items being collected',
                    accentColor: AppColors.primaryGreen,
                    photoCount: collectionCount,
                    onEdit: () => _openEditor('collection', context),
                  ),
                  const SizedBox(height: 10),
                  _PhotoStepCard(
                    stepNumber: 3,
                    label: 'Proof of Payment',
                    subtitle: 'Photo of payment receipt',
                    accentColor: const Color(0xFFF59E0B),
                    photoCount: paymentCount,
                    onEdit: () => _openEditor('payment', context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(String category, BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _PhotoEditorSheet(
          category: category,
          initialPhotos: List<String>.from(photos[category] ?? const []),
          onChanged: (updated) => onPhotosUpdated(category, updated),
        );
      },
    );
  }
}

class _PhotoStepCard extends StatelessWidget {
  final int stepNumber;
  final String label;
  final String subtitle;
  final Color accentColor;
  final int photoCount;
  final VoidCallback onEdit;

  const _PhotoStepCard({
    required this.stepNumber,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.photoCount,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPhotos = photoCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: hasPhotos
            ? accentColor.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPhotos
              ? accentColor.withValues(alpha: 0.25)
              : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Step badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasPhotos ? accentColor : AppColors.borderLight,
                shape: BoxShape.circle,
              ),
              child: hasPhotos
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : Center(
                      child: Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Photo count + edit button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasPhotos)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$photoCount photo${photoCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasPhotos ? Colors.white : accentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasPhotos
                            ? accentColor.withValues(alpha: 0.3)
                            : accentColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPhotos
                              ? Icons.edit_outlined
                              : Icons.camera_alt_rounded,
                          size: 13,
                          color: hasPhotos ? accentColor : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPhotos ? 'Edit' : 'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasPhotos ? accentColor : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoEditorSheet extends StatefulWidget {
  final String category;
  final List<String> initialPhotos;
  final ValueChanged<List<String>> onChanged;
  const _PhotoEditorSheet({
    required this.category,
    required this.initialPhotos,
    required this.onChanged,
  });

  @override
  State<_PhotoEditorSheet> createState() => _PhotoEditorSheetState();
}

class _PhotoEditorSheetState extends State<_PhotoEditorSheet> {
  late List<String> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<String>.from(widget.initialPhotos);
  }

  Future<void> _addFromCamera() async {
    final picker = ImagePicker();
    XFile? image;
    try {
      image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } catch (_) {
      image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    }
    final path = image?.path;
    if (path != null) {
      setState(() => _photos.add(path));
      widget.onChanged(_photos);
    }
  }

  Future<void> _addFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    final path = image?.path;
    if (path != null) {
      setState(() => _photos.add(path));
      widget.onChanged(_photos);
    }
  }

  void _removeAt(int index) {
    setState(() => _photos.removeAt(index));
    widget.onChanged(_photos);
  }

  @override
  Widget build(BuildContext context) {
    // Resolve accent color per category
    final Color accent = widget.category == 'arrival'
        ? AppColors.collectorPrimary
        : widget.category == 'collection'
        ? AppColors.primaryGreen
        : const Color(0xFFF59E0B);

    final String stepTitle = widget.category == 'arrival'
        ? 'Proof of Arrival'
        : widget.category == 'collection'
        ? 'Proof of Collection'
        : 'Proof of Payment';

    final String stepHint = widget.category == 'arrival'
        ? 'Photo at the pickup location'
        : widget.category == 'collection'
        ? 'Photos of items being collected'
        : 'Photo of payment receipt';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 4),
            child: Center(
              child: SizedBox(
                width: 36,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stepTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        stepHint,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_photos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_photos.length} photo${_photos.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // ── Photo grid or empty state ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _photos.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 36,
                          color: accent.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No photos yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap a button below to add photos',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: _photos.length,
                    itemBuilder: (ctx, i) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _PhotoThumb(path: _photos[i]),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeAt(i),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // ── Action buttons ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _SheetActionButton(
                    onTap: _addFromCamera,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: accent,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetActionButton(
                    onTap: _addFromGallery,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: accent,
                    filled: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _SheetActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String path;
  const _PhotoThumb({required this.path});
  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      // Network image (already uploaded to Firebase Storage)
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, color: Colors.grey),
              const SizedBox(height: 4),
              Text(
                'Failed to load',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    // Local file image (not yet uploaded)
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, st) => Center(
        child: Text(
          'Preview unavailable',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
