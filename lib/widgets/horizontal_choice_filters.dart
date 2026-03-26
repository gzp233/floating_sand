import 'package:flutter/material.dart';

/// 横向可滚动的分类筛选条，避免分类过多时把首屏撑高。
class HorizontalChoiceFilters extends StatelessWidget {
  const HorizontalChoiceFilters({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.title = '分类筛选',
    this.allLabel = '全部',
  });

  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String?> onSelected;
  final String title;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              title,
              style: theme.labelLarge?.copyWith(
                color: const Color(0xFF61706A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${options.length} 项',
              style: theme.bodySmall?.copyWith(color: const Color(0xFF83908B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: Text(allLabel),
                selected: selectedValue == null,
                showCheckmark: false,
                onSelected: (_) => onSelected(null),
              ),
              for (final option in options) ...<Widget>[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(option),
                  selected: selectedValue == option,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(option),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
