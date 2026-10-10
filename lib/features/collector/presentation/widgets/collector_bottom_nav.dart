import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../core/theme/app_colors.dart';

class CollectorBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool isAvailable;
  final VoidCallback onToggleAvailability;

  const CollectorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.isAvailable,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return _HybridNav(
      currentIndex: currentIndex,
      onSelect: onSelect,
      isAvailable: isAvailable,
      onToggleAvailability: onToggleAvailability,
    );
  }
}

class _HybridNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool isAvailable;
  final VoidCallback onToggleAvailability;

  const _HybridNav({
    required this.currentIndex,
    required this.onSelect,
    required this.isAvailable,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ModernNavItem(
                activeIcon: FluentIcons.vehicle_truck_profile_24_filled,
                inactiveIcon: FluentIcons.vehicle_truck_profile_24_regular,
                label: 'Collections',
                index: 0,
                currentIndex: currentIndex,
                onTap: onSelect,
              ),
              _ModernNavItem(
                activeIcon: FluentIcons.archive_24_filled,
                inactiveIcon: FluentIcons.archive_24_regular,
                label: 'History',
                index: 1,
                currentIndex: currentIndex,
                onTap: onSelect,
              ),
              _ModernNavItem(
                activeIcon: FluentIcons.mail_24_filled,
                inactiveIcon: FluentIcons.mail_24_regular,
                label: 'Inbox',
                index: 2,
                currentIndex: currentIndex,
                onTap: onSelect,
              ),
              _ModernNavItem(
                activeIcon: FluentIcons.person_24_filled,
                inactiveIcon: FluentIcons.person_24_regular,
                label: 'Profile',
                index: 3,
                currentIndex: currentIndex,
                onTap: onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _NavIcon/_FaNavIcon removed; using Fluent UI via _FluentNavIcon.

class _ModernNavItem extends StatefulWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ModernNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_ModernNavItem> createState() => _ModernNavItemState();
}

class _ModernNavItemState extends State<_ModernNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentIndex == widget.index;
    final color = isActive ? AppColors.primaryBlue : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0);
        widget.onTap(widget.index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                isActive ? widget.activeIcon : widget.inactiveIcon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FluentNavIcon extends StatefulWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;
  final Color inactiveColor;

  const _FluentNavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  State<_FluentNavIcon> createState() => _FluentNavIconState();
}

class _FluentNavIconState extends State<_FluentNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.index == widget.currentIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _controller.forward(from: 0);
        widget.onTap(widget.index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 34,
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Icon(
                  isActive ? widget.activeIcon : widget.inactiveIcon,
                  size: 26,
                  color: isActive ? widget.activeColor : widget.inactiveColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 0),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isActive ? widget.activeColor : widget.inactiveColor,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 10,
              height: 1.0,
            ),
            child: Transform.translate(
              offset: const Offset(0, -3.0),
              child: Text(widget.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPowerButton extends StatefulWidget {
  final bool isAvailable;
  final VoidCallback onCompletedToggle;

  const _CenterPowerButton({
    required this.isAvailable,
    required this.onCompletedToggle,
  });

  @override
  State<_CenterPowerButton> createState() => _CenterPowerButtonState();
}

class _CenterPowerButtonState extends State<_CenterPowerButton>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pressController;
  late final AnimationController _bounceController;
  late final Animation<double> _pressScale;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onCompletedToggle();
              _controller.reset();
              // Trigger a subtle bounce when the 3s hold completes
              if (mounted) {
                _bounceController.forward(from: 0);
              }
            }
          });

    // Press grow: smoothly scale to 1.05 while holding
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_pressController);

    // Completion bounce: small pop then settle back
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.03,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.03,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (!mounted) return;
    _controller.forward(from: 0);
    _pressController.forward();
  }

  void _cancelHold() {
    if (_controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
    // Return to normal size if released early
    if (mounted && _pressController.status != AnimationStatus.dismissed) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: widget.isAvailable
          ? [AppColors.successColor, const Color(0xFF22C55E)]
          : [AppColors.textSecondary, const Color(0xFF9CA3AF)],
    );
    final progressColor = widget.isAvailable
        ? AppColors.successColor
        : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(64, 64),
                  painter: _RingPainter(
                    progress: _controller.value,
                    color: progressColor,
                    trackColor: Colors.white.withValues(alpha: 0.6),
                    strokeWidth: 2.5,
                  ),
                );
              },
            ),
            // Center circle button
            ScaleTransition(
              scale: _pressScale,
              child: ScaleTransition(
                scale: _bounceScale,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ), // thinner stroke
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.power_settings_new, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide / 2) - strokeWidth;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw track
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc (start from top: -90 degrees)
    final startAngle = -90 * (3.1415926535 / 180);
    final sweep = 2 * 3.1415926535 * progress;
    final rectCircle = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rectCircle, startAngle, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
