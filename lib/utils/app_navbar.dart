
import 'package:flutter/material.dart';
import 'package:seraeditor/utils/app_theme.dart';

class AppNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppNavbar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
  label: 'إضافة',
  icon: Icons.add_rounded,
  selectedIcon: Icons.add_circle_rounded,
),
    _NavItem(
      label: 'الشيتات',
      icon: Icons.history_rounded,
      selectedIcon: Icons.manage_history_rounded,
    ),
    _NavItem(
      label: 'البادئات',
      icon: Icons.sell_outlined,
      selectedIcon: Icons.sell_rounded,
    ),

    _NavItem(
  label: 'قراءة الصور',
  icon: Icons.document_scanner_outlined,
  selectedIcon: Icons.document_scanner_rounded,
),


  _NavItem(
    label: 'عن التطبيق',
    icon: Icons.info_outline_rounded,
    selectedIcon: Icons.info_rounded,
  ),

  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return _buildDesktopSidebar();
        }

        return _buildMobileNavbar();
      },
    );
  }

  // ================= DESKTOP SIDEBAR =================

  Widget _buildDesktopSidebar() {
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(
            color: AppTheme.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.button.withOpacity(0.30),
                          AppTheme.surfaceLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppTheme.borderHover.withOpacity(0.55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.08),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.diamond_rounded,
                      color: AppTheme.goldBright,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SERA',
                          style: TextStyle(
                            color: AppTheme.goldBright,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'EDITOR STUDIO',
                          style: TextStyle(
                            color: AppTheme.mutedText,
                            fontSize: 9,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 1,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'WORKSPACE',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            ...List.generate(
              _items.length,
              _buildSidebarItem,
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.divider,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.successLight,
                      size: 21,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'النظام يعمل',
                            style: TextStyle(
                              color: AppTheme.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'بيئة العمل جاهزة',
                            style: TextStyle(
                              color: AppTheme.mutedText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.circle,
                      color: AppTheme.successLight,
                      size: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final item = _items[index];
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppTheme.accent.withOpacity(0.16),
                        AppTheme.accent.withOpacity(0.035),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? AppTheme.borderHover.withOpacity(0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent.withOpacity(0.14)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected
                        ? AppTheme.goldBright
                        : AppTheme.mutedText,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.goldBright
                          : AppTheme.text,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.goldBright,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= MOBILE NAVBAR =================

Widget _buildMobileNavbar() {
  return Container(
    height: 66,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: AppTheme.borderHover.withOpacity(0.45),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.20),
          blurRadius: 22,
          offset: const Offset(0, 7),
        ),
        BoxShadow(
          color: AppTheme.accent.withOpacity(0.05),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
    ),
   
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: List.generate(_items.length, (index) {
        final item = _items[index];
        final selected = selectedIndex == index;

        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onDestinationSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withOpacity(0.09)
                      : Colors.transparent,
                  border: Border(
                    top: BorderSide(
                      color: selected
                          ? AppTheme.goldBright
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 22,
                        color: selected
                            ? AppTheme.goldBright
                            : AppTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.goldBright
                              : AppTheme.mutedText,
                          fontSize: 9,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}