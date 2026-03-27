import 'package:flutter/material.dart';

import 'tappable_image.dart';

class RecordGridCard extends StatefulWidget {
  const RecordGridCard({
    super.key,
    required this.title,
    required this.category,
    required this.imagePath,
    required this.placeholderIcon,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
    this.placeholderChild,
    this.children = const <Widget>[],
  });

  final String title;
  final String category;
  final String imagePath;
  final IconData placeholderIcon;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? placeholderChild;
  final List<Widget> children;

  @override
  State<RecordGridCard> createState() => _RecordGridCardState();
}

class _RecordGridCardState extends State<RecordGridCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: widget.onOpen,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          splashColor: colorScheme.primary.withValues(alpha: 0.05),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _RecordCardCover(
                title: widget.title,
                imagePath: widget.imagePath,
                placeholderIcon: widget.placeholderIcon,
                placeholderChild: widget.placeholderChild,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  widget.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.children.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ],
              if (widget.onEdit != null && widget.onDelete != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        widget.onEdit?.call();
                      } else {
                        widget.onDelete?.call();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('删除'),
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

class RecordMetaPill extends StatelessWidget {
  const RecordMetaPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecordCardCover extends StatelessWidget {
  const _RecordCardCover({
    required this.title,
    required this.imagePath,
    required this.placeholderIcon,
    this.placeholderChild,
  });

  final String title;
  final String imagePath;
  final IconData placeholderIcon;
  final Widget? placeholderChild;

  @override
  Widget build(BuildContext context) {
    if (imagePath.trim().isNotEmpty) {
      return _AdaptiveRecordImage(
        path: imagePath,
        placeholderIcon: placeholderIcon,
      );
    }

    if (placeholderChild != null) {
      return placeholderChild!;
    }

    final previewHeight = 140.0 + (title.length % 4) * 18.0;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      constraints: BoxConstraints(minHeight: previewHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.secondaryContainer,
            colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _AdaptiveRecordImage extends StatefulWidget {
  const _AdaptiveRecordImage({
    required this.path,
    required this.placeholderIcon,
  });

  final String path;
  final IconData placeholderIcon;

  @override
  State<_AdaptiveRecordImage> createState() => _AdaptiveRecordImageState();
}

class _AdaptiveRecordImageState extends State<_AdaptiveRecordImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveRecordImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _aspectRatio = null;
      _detachListener();
      _resolveImageSize();
    }
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  void _resolveImageSize() {
    final provider = imageProviderFromPath(widget.path);
    if (provider == null) {
      return;
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (!mounted || width <= 0 || height <= 0) {
        return;
      }
      setState(() {
        _aspectRatio = width / height;
      });
      _detachListener();
    });
    _imageStream = stream;
    stream.addListener(_listener!);
  }

  void _detachListener() {
    final stream = _imageStream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 40;
        final height = _aspectRatio == null ? 160.0 : width / _aspectRatio!;
        return TappableImage(
          path: widget.path,
          width: width,
          height: height,
          borderRadius: 0,
          fit: BoxFit.cover,
          placeholderIcon: widget.placeholderIcon,
          previewEnabled: false,
        );
      },
    );
  }
}