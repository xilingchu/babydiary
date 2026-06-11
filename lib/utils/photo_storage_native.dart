import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Future<String> savePickedPhoto(XFile xfile, String subdir) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(dir.path, subdir));
  await photosDir.create(recursive: true);

  final ext = p.extension(xfile.path).isNotEmpty ? p.extension(xfile.path) : '.jpg';
  final fileName = '${_uuid.v4()}$ext';
  final destPath = p.join(photosDir.path, fileName);

  await File(xfile.path).copy(destPath);
  return destPath;
}

Future<void> deletePhotoFile(String path) async {
  if (path.startsWith('data:') || path.startsWith('http')) return;
  final file = File(path);
  if (file.existsSync()) await file.delete();
}
