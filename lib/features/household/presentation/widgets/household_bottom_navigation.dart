import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../core/theme/app_colors.dart';

class HouseholdBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const HouseholdBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HouseholdHybridNav(currentIndex: currentIndex, onTap: onTap);
  }
}

class _HouseholdHybridNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _HouseholdHybridNav({required this.currentIndex, required this.onTap});

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
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ModernNavItem(
                      activeIcon: FluentIcons.home_24_filled,
                      inactiveIcon: FluentIcons.home_24_regular,
                      label: 'Home',
                      index: 0,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _ModernNavItem(
                      activeIcon: FluentIcons.mail_24_filled,
                      inactiveIcon: FluentIcons.mail_24_regular,
                      label: 'Inbox',
                      index: 3,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
              _CenterPostButton(
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ModernNavItem(
                      activeIcon: FluentIcons.location_24_filled,
                      inactiveIcon: FluentIcons.location_24_regular,
                      label: 'Track',
                      index: 2,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _ModernNavItem(
                      activeIcon: FluentIcons.person_24_filled,
                      inactiveIcon: FluentIcons.person_24_regular,
                      label: 'Profile',
                      index: 4,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernNavItem extends StatefulWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

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
    final color = isActive
        ? AppColors.householdPrimary
        : const Color(0xFF94A3B8);

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
  final Function(int) onTap;
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
              color: isActive
                  ? widget.activeColor
                  : Colors.black.withValues(alpha: 0.6),
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

class _CenterPostButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CenterPostButton({required this.isActive, required this.onTap});

  @override
  State<_CenterPostButton> createState() => _CenterPostButtonState();
}

class _CenterPostButtonState extends State<_CenterPostButton>
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.householdPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.householdPrimary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _controller.forward(from: 0);
                  widget.onTap();
                },
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppColors.householdPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
