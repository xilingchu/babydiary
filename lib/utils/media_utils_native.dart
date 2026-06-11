import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

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

// video_compress only works on iOS/Android
bool get _canCompress => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

Future<Uint8List?> generateVideoThumbnail(String path) async {
  if (!_canCompress || path.startsWith('http')) return null;
  try {
    return await VideoCompress.getByteThumbnail(path, quality: 75);
  } catch (_) {
    return null;
  }
}

Future<String> compressVideoForUpload(String path) async {
  if (!_canCompress) return path;
  try {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    if (info?.path != null) {
      final originalSize = await File(path).length();
      final compressedSize = await File(info!.path!).length();
      return compressedSize < originalSize ? info.path! : path;
    }
  } catch (_) {}
  return path;
}
