import 'package:flutter/material.dart';
import '../models/game_with_priority.dart';
import '../utils/app_theme.dart';

class FilterChipsRow extends StatelessWidget {
  final PriorityTier? selectedTier;
  final Function(PriorityTier?) onTierChanged;
  final Map<PriorityTier, int> tierCounts;

  const FilterChipsRow({
    super.key,
    this.selectedTier,
    required this.onTierChanged,
    required this.tierCounts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            count: tierCounts.values.fold(0, (a, b) => a + b),
            isSelected: selectedTier == null,
            color: AppTheme.primaryColor,
            onTap: () => onTierChanged(null),
          ),
          const SizedBox(width: 8),
          ...PriorityTier.values.map((tier) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildFilterChip(
              label: tier.displayName,
              count: tierCounts[tier] ?? 0,
              isSelected: selectedTier == tier,
              color: AppTheme.getTierColor(tier),
              emoji: tier.emoji,
              onTap: () => onTierChanged(selectedTier == tier ? null : tier),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    String? emoji,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? color.withValues(alpha: 0.3)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? color : AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
