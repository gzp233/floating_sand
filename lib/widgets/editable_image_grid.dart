import 'package:flutter/material.dart';

import 'tappable_image.dart';

/// 编辑器里的图片缩略图网格，支持逐张移除。
class EditableImageGrid extends StatelessWidget {
  const EditableImageGrid({
    super.key,
    required this.paths,
    required this.onRemove,
    this.maxItemWidth = 100,
  });

  final List<String> paths;
  final ValueChanged<int> onRemove;
  final double maxItemWidth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List<Widget>.generate(paths.length, (int index) {
        final path = paths[index];
        return Stack(
          children: <Widget>[
            SizedBox(
              width: maxItemWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TappableImage(
                    path: path,
                    width: maxItemWidth,
                    height: maxItemWidth,
                    borderRadius: 18,
                    fit: BoxFit.cover,
                    placeholderIcon: Icons.image_outlined,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '第 ${index + 1} 张',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.48),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onRemove(index),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}