import 'dart:io';
import 'package:flutter/material.dart';

Widget buildFileImage(String path, BoxFit fit, double? width, double? height) {
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) => _broken(width, height),
  );
}

Widget _broken(double? width, double? height) => SizedBox(
      width: width,
      height: height,
      child: const Center(child: Icon(Icons.broken_image)),
    );
