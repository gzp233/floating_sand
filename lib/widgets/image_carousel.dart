import 'package:flutter/material.dart';

import 'tappable_image.dart';

/// 详情页多图轮播，支持点击预览与页码指示。
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    super.key,
    required this.paths,
    this.height = 260,
    this.borderRadius = 28,
    this.itemSpacing = 8,
    this.placeholderIcon = Icons.collections_outlined,
    this.placeholderColor = const Color(0xFFE7EEE8),
    this.iconColor = const Color(0xFF55716A),
  });

  final List<String> paths;
  final double height;
  final double borderRadius;
  final double itemSpacing;
  final IconData placeholderIcon;
  final Color placeholderColor;
  final Color iconColor;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.paths.length,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.paths.length - 1 ? 0 : widget.itemSpacing,
                ),
                child: TappableImage(
                  path: widget.paths[index],
                  width: double.infinity,
                  height: widget.height,
                  borderRadius: widget.borderRadius,
                  fit: BoxFit.cover,
                  placeholderIcon: widget.placeholderIcon,
                  placeholderColor: widget.placeholderColor,
                  iconColor: widget.iconColor,
                ),
              );
            },
          ),
        ),
        if (widget.paths.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                '${_currentIndex + 1} / ${widget.paths.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List<Widget>.generate(widget.paths.length, (int index) {
                    final isActive = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: isActive ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}