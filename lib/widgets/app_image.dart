import 'dart:convert';
import 'package:flutter/material.dart';
import '_app_image_io.dart' if (dart.library.html) '_app_image_stub.dart';

class AppImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AppImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return _placeholder(context);

    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }

    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma == -1) return _placeholder(context);
      try {
        final bytes = base64Decode(path.substring(comma + 1));
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      } catch (_) {
        return _placeholder(context);
      }
    }

    return buildFileImage(path, fit, width, height);
  }

  Widget _placeholder(BuildContext context) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.photo_outlined)),
      );
}
