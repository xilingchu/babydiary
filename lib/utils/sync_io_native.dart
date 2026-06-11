import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'media_utils.dart';

Future<http.MultipartFile?> photoToMultipart(String localPath, String fieldName) async {
  if (localPath.isEmpty || localPath.startsWith('http')) return null;

  final uploadPath = isVideo(localPath)
      ? await compressVideoForUpload(localPath)
      : localPath;

  final file = File(uploadPath);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  return http.MultipartFile.fromBytes(fieldName, bytes, filename: p.basename(localPath));
}

Future<String> downloadAndSaveFile(String url, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final localPath = p.join(dir.path, 'synced_photos', fileName);
  final file = File(localPath);
  if (file.existsSync()) return localPath;

  await Directory(p.dirname(localPath)).create(recursive: true);
  final response = await http.get(Uri.parse(url));
  await file.writeAsBytes(response.bodyBytes);
  return localPath;
}

bool localFileExists(String path) {
  if (path.startsWith('http') || path.startsWith('data:') || path.isEmpty) return false;
  return File(path).existsSync();
}
