import 'package:flutter/material.dart';

Widget buildFileImage(String path, BoxFit fit, double? width, double? height) {
  return SizedBox(
    width: width,
    height: height,
    child: const Center(child: Icon(Icons.broken_image)),
  );
}
