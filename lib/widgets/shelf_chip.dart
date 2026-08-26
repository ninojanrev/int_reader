import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single horizontally-scrolling shelf/collection filter chip.
class ShelfChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ShelfChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
