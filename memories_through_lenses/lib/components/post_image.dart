import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Post photo with disk caching, size-appropriate decoding, download progress
/// and tap-to-retry.
///
/// The post detail screen used a plain Image.network: no disk cache (every
/// open re-downloaded the full-resolution upload) and no retry, so a slow or
/// interrupted download left a broken image. The feed decoded every 1920px
/// upload at full size. Both now share the disk cache and decode at the size
/// actually displayed.
class PostImage extends StatefulWidget {
  const PostImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<PostImage> {
  int _attempt = 0;

  Future<void> _retry() async {
    try {
      await CachedNetworkImage.evictFromCache(widget.url);
    } catch (_) {}
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return const _ImageError();
    return LayoutBuilder(builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final logicalWidth = widget.width ?? constraints.maxWidth;
      final int? decodeWidth = logicalWidth.isFinite && logicalWidth > 0
          ? math.min((logicalWidth * dpr).round(), 2048)
          : null;
      return CachedNetworkImage(
        key: ValueKey('${widget.url}#$_attempt'),
        imageUrl: widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: decodeWidth,
        fadeInDuration: const Duration(milliseconds: 150),
        progressIndicatorBuilder: (context, url, progress) => Center(
          child: CircularProgressIndicator(value: progress.progress),
        ),
        errorWidget: (context, url, error) => _ImageError(onRetry: _retry),
      );
    });
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError({this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
        const SizedBox(height: 6),
        Text(
          onRetry == null ? 'Image unavailable' : 'Image failed to load',
          style: const TextStyle(color: Colors.grey),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
      ],
    );
    return Center(child: content);
  }
}
