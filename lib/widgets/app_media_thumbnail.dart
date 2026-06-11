import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'app_image.dart';
import '../utils/media_utils.dart';

class AppMediaThumbnail extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppMediaThumbnail(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<AppMediaThumbnail> createState() => _AppMediaThumbnailState();
}

class _AppMediaThumbnailState extends State<AppMediaThumbnail> {
  Uint8List? _thumb;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (isVideo(widget.path)) {
      _loadThumb();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadThumb() async {
    final data = await generateVideoThumbnail(widget.path);
    if (mounted) setState(() { _thumb = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (!isVideo(widget.path)) {
      return AppImage(widget.path, fit: widget.fit, width: widget.width, height: widget.height);
    }

    Widget bg;
    if (_loading) {
      bg = Container(width: widget.width, height: widget.height, color: Colors.black26);
    } else if (_thumb != null) {
      bg = Image.memory(_thumb!, fit: widget.fit, width: widget.width, height: widget.height);
    } else {
      bg = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black87,
        child: const Icon(Icons.videocam_outlined, color: Colors.white54, size: 32),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        bg,
        const Icon(
          Icons.play_circle_outline,
          color: Colors.white,
          size: 36,
          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
        ),
      ],
    );
  }
}
