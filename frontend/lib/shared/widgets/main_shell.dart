import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/opportunities')) return 1;
    if (location.startsWith('/career-twin')) return 2;
    if (location.startsWith('/agents')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final currentIndex = _selectedIndex(context);

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Row(
          children: [
            _SideNav(currentIndex: currentIndex),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: child,
      bottomNavigationBar: _BottomNav(currentIndex: currentIndex),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int currentIndex;
  const _SideNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final items = _navItems;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.primaryGradient),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('FillFormAI', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Nav items
            ...items.asMap().entries.map((e) => _SideNavItem(
              icon: e.value.$1,
              label: e.value.$2,
              route: e.value.$3,
              isSelected: currentIndex == e.key,
            )),
            const Spacer(),
            // Secondary shortcuts (not part of the primary 5-tab nav)
            _SideNavItem(
              icon: Icons.folder_outlined,
              label: 'Documents',
              route: '/documents',
              isSelected: false,
            ),
            _SideNavItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              route: '/notifications',
              isSelected: false,
            ),
            _SideNavItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription',
              route: '/payments',
              isSelected: false,
            ),
            _SideNavItem(
              icon: Icons.description_outlined,
              label: 'SOP Writer',
              route: '/sop-writer',
              isSelected: false,
            ),
            _SideNavItem(
              icon: Icons.gavel_outlined,
              label: 'Appeal Writer',
              route: '/appeal-writer',
              isSelected: false,
            ),
            _SideNavItem(
              icon: Icons.route_outlined,
              label: 'Roadmap',
              route: '/roadmap',
              isSelected: false,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.route),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.isSelected
                ? AppColors.primary.withOpacity(0.15)
                : _isHovered
                    ? AppColors.bgCardLight
                    : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                widget.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: widget.isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (widget.isSelected)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final items = _navItems;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((e) => _BottomNavItem(
              icon: e.value.$1,
              label: e.value.$2,
              route: e.value.$3,
              isSelected: currentIndex == e.key,
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared nav items definition
const _navItems = [
  (Icons.home_outlined, 'Home', '/dashboard'),
  (Icons.search_outlined, 'Discover', '/opportunities'),
  (Icons.smart_toy_outlined, 'AI Twin', '/career-twin'),
  (Icons.people_outline, 'Agents', '/agents'),
  (Icons.person_outline, 'Profile', '/profile'),
];
