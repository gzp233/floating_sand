import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ImageProvider<Object>? imageProviderFromPath(String path) {
  if (path.trim().isEmpty) {
    return null;
  }
  if (path.startsWith('data:image/')) {
    return NetworkImage(path);
  }
  if (!kIsWeb) {
    return FileImage(File(path));
  }
  return null;
}

/// 统一图片展示，负责占位、点击预览和本地/数据 URI 兼容。
class TappableImage extends StatelessWidget {
  const TappableImage({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderColor = const Color(0xFFE7EEE8),
    this.iconColor = const Color(0xFF55716A),
    this.previewEnabled = true,
  });

  final String path;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;
  final Color placeholderColor;
  final Color iconColor;
  final bool previewEnabled;

  bool get _hasImage => path.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: _buildImageContent(),
      ),
    );

    if (!_hasImage || !previewEnabled) {
      return imageWidget;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: () => _openPreview(context),
        child: Stack(
          children: <Widget>[
            imageWidget,
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.open_in_full, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '预览',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (!_hasImage) {
      return _ImagePlaceholder(
        icon: placeholderIcon,
        backgroundColor: placeholderColor,
        iconColor: iconColor,
      );
    }

    if (path.startsWith('data:image/')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        frameBuilder: _frameBuilder,
        loadingBuilder: _loadingBuilder,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _buildErrorPlaceholder(),
      );
    }

    if (!kIsWeb) {
      final provider = imageProviderFromPath(path);
      final file = provider is FileImage ? provider.file : File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          frameBuilder: _frameBuilder,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  _buildErrorPlaceholder(),
        );
      }
    }

    return _buildErrorPlaceholder();
  }

  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _ImagePlaceholder(
          icon: placeholderIcon,
          backgroundColor: placeholderColor,
          iconColor: iconColor,
        ),
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    );
  }

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _ImagePlaceholder(
          icon: placeholderIcon,
          backgroundColor: placeholderColor,
          iconColor: iconColor,
        ),
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorPlaceholder() {
    return _ImagePlaceholder(
      icon: Icons.broken_image_outlined,
      backgroundColor: placeholderColor,
      iconColor: iconColor,
    );
  }

  Future<void> _openPreview(BuildContext context) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => _FullscreenImagePage(path: path),
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              );
            },
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: Center(child: Icon(icon, color: iconColor)),
    );
  }
}

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.92),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.9,
                    maxScale: 4.5,
                    child: _PreviewImageBody(path: path),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: SafeArea(
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewImageBody extends StatelessWidget {
  const _PreviewImageBody({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('data:image/')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
      );
    }

    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
        );
      }
    }

    return const Icon(
      Icons.broken_image_outlined,
      color: Colors.white70,
      size: 48,
    );
  }
}
