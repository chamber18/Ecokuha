import 'package:flutter/material.dart';
import '../../../core/utils/app_image_provider.dart';

/// A widget that displays multiple profile pictures stacked on top of each other
/// Similar to Facebook Messenger group chat avatars
class StackedAvatars extends StatelessWidget {
  final List<AvatarData> avatars;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final bool showOnlineStatus;
  final bool isOnline;

  const StackedAvatars({
    super.key,
    required this.avatars,
    this.size = 56.0,
    this.borderWidth = 2.0,
    this.borderColor = Colors.white,
    this.showOnlineStatus = true,
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    // Limit to max 3 avatars
    final displayAvatars = avatars.take(3).toList();

    if (displayAvatars.isEmpty) {
      return _buildEmptyAvatar();
    }

    if (displayAvatars.length == 1) {
      return _buildSingleAvatar(displayAvatars[0]);
    }

    return _buildStackedAvatars(displayAvatars);
  }

  Widget _buildEmptyAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Icon(Icons.person, color: Colors.grey[600], size: size * 0.5),
    );
  }

  Widget _buildSingleAvatar(AvatarData avatar) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: CircleAvatar(
            radius: (size - borderWidth * 2) / 2,
            backgroundColor: avatar.backgroundColor,
            backgroundImage:
                avatar.imageUrl != null &&
                    avatar.imageUrl!.isNotEmpty &&
                    !avatar.imageUrl!.startsWith('data:image')
                ? AppImageProvider(avatar.imageUrl!) as ImageProvider
                : null,
            onBackgroundImageError: avatar.imageUrl != null
                ? (exception, stackTrace) {
                    debugPrint('Failed to load avatar: $exception');
                  }
                : null,
            child:
                avatar.imageUrl == null ||
                    avatar.imageUrl!.isEmpty ||
                    avatar.imageUrl!.startsWith('data:image')
                ? Text(
                    avatar.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.35,
                    ),
                  )
                : null,
          ),
        ),
        // Online status indicator
        if (showOnlineStatus)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF10B981)
                    : const Color(0xFF9CA3AF),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStackedAvatars(List<AvatarData> displayAvatars) {
    // For 2 avatars: position diagonally within the same circle size
    // - First avatar (junkshop): upper-right (background)
    // - Second avatar (collector): lower-left (foreground)
    // Both are 70% of original size to overlap nicely
    // This leaves lower-right corner free for active status indicator

    final double avatarSize = size * 0.7; // 70% size for diagonal overlap

    if (displayAvatars.length == 2) {
      // Diagonal stacking for 2 participants
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // First avatar - upper-right position (background)
            Positioned(
              right: 0,
              top: 0,
              child: _buildAvatar(displayAvatars[0], avatarSize),
            ),
            // Second avatar - lower-left position (foreground)
            Positioned(
              left: 0,
              bottom: 0,
              child: _buildAvatar(displayAvatars[1], avatarSize),
            ),
            // Online status indicator
            if (showOnlineStatus)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size * 0.28,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFF9CA3AF),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                ),
              ),
          ],
        ),
      );
    } // For 3+ avatars: horizontal stacking (original behavior)
    final int count = displayAvatars.length;
    final double smallAvatarSize = size * 0.5;
    final double overlapOffset = smallAvatarSize * 0.4;
    final double totalWidth = smallAvatarSize + (overlapOffset * (count - 1));

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: displayAvatars.asMap().entries.map((entry) {
          final index = entry.key;
          final avatar = entry.value;
          final leftPosition = index * overlapOffset;

          return Positioned(
            left: leftPosition,
            top: (size - smallAvatarSize) / 2,
            child: _buildAvatar(avatar, smallAvatarSize),
          );
        }).toList(),
      ),
    );
  }

  /// Helper method to build a single avatar with border and shadow
  Widget _buildAvatar(AvatarData avatar, double avatarSize) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: (avatarSize - borderWidth * 2) / 2,
        backgroundColor: avatar.backgroundColor,
        backgroundImage:
            avatar.imageUrl != null &&
                avatar.imageUrl!.isNotEmpty &&
                !avatar.imageUrl!.startsWith('data:image')
            ? AppImageProvider(avatar.imageUrl!) as ImageProvider
            : null,
        onBackgroundImageError: avatar.imageUrl != null
            ? (exception, stackTrace) {
                debugPrint('Failed to load stacked avatar: $exception');
              }
            : null,
        child:
            avatar.imageUrl == null ||
                avatar.imageUrl!.isEmpty ||
                avatar.imageUrl!.startsWith('data:image')
            ? Text(
                avatar.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: avatarSize * 0.35,
                ),
              )
            : null,
      ),
    );
  }
}

/// Data class for avatar information
class AvatarData {
  final String? imageUrl;
  final String initials;
  final Color backgroundColor;
  final String? role; // Optional role identifier

  const AvatarData({
    this.imageUrl,
    required this.initials,
    required this.backgroundColor,
    this.role,
  });

  factory AvatarData.fromParticipant({
    required String name,
    String? profileImage,
    String? role,
  }) {
    final initials = name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : '??';

    Color backgroundColor;
    switch (role) {
      case 'collector':
        backgroundColor = const Color(0xFF10B981); // Green
        break;
      case 'junkshop':
        backgroundColor = const Color(0xFF8B5CF6); // Purple
        break;
      case 'household':
        backgroundColor = const Color(0xFF3B82F6); // Blue
        break;
      default:
        backgroundColor = const Color(0xFF6B7280); // Gray
    }

    return AvatarData(
      imageUrl: profileImage,
      initials: initials,
      backgroundColor: backgroundColor,
      role: role,
    );
  }
}
