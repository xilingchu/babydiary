import 'dart:typed_data';

bool isVideo(String path) {
  final lower = path.toLowerCase().split('?').first;
  return lower.endsWith('.mp4') || lower.endsWith('.mov') ||
      lower.endsWith('.avi') || lower.endsWith('.mkv') ||
      lower.endsWith('.m4v') || lower.endsWith('.3gp');
}

bool isMediaFile(String path, String? mimeType) {
  if (mimeType != null) {
    return mimeType.startsWith('image/') || mimeType.startsWith('video/');
  }
  if (isVideo(path)) return true;
  final lower = path.toLowerCase().split('?').first;
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
      lower.endsWith('.png') || lower.endsWith('.gif') ||
      lower.endsWith('.webp') || lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

Future<Uint8List?> generateVideoThumbnail(String path) async => null;
Future<String> compressVideoForUpload(String path) async => path;
