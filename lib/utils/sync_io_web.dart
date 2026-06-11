import 'dart:convert';
import 'package:http/http.dart' as http;

Future<http.MultipartFile?> photoToMultipart(String localPath, String fieldName) async {
  if (localPath.isEmpty) return null;
  if (localPath.startsWith('data:')) {
    final comma = localPath.indexOf(',');
    if (comma == -1) return null;
    final bytes = base64Decode(localPath.substring(comma + 1));
    return http.MultipartFile.fromBytes(fieldName, bytes, filename: 'photo.jpg');
  }
  return null;
}

// On web, return the URL directly so AppImage can load it via Image.network
Future<String> downloadAndSaveFile(String url, String fileName) async => url;

bool localFileExists(String path) => false;
