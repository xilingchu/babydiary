import 'dart:typed_data';

bool isVideo(String path) {
  final lower = path.toLowerCase().split('?').first;
  return lower.endsWith('.mp4') || lower.endsWith('.mov') ||
      lower.endsWith('.avi') || lower.endsWith('.mkv') ||
      lower.endsWith('.m4v') || lower.endsWith('.3gp');
}

Future<Uint8List?> generateVideoThumbnail(String path) async => null;
Future<String> compressVideoForUpload(String path) async => path;
