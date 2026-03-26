import 'package:flutter/material.dart';

/// 页面顶部标题区，提供简洁而明确的信息层级。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
    this.caption,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2DBCF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          eyebrow,
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF60716A),
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF16302B),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Text(
                        description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5C6A65),
                          height: 1.6,
                        ),
                      ),
                    ),
                    if (caption != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.schedule_outlined,
                            size: 15,
                            color: Color(0xFF7D8984),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            caption!,
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7D8984),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
