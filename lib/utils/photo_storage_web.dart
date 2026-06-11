import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String> savePickedPhoto(XFile xfile, String subdir) async {
  final bytes = await xfile.readAsBytes();
  final base64Str = base64Encode(bytes);
  final name = xfile.name.toLowerCase();
  final mime = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
  return 'data:$mime;base64,$base64Str';
}

Future<void> deletePhotoFile(String path) async {
  // No file system on web; data URLs are just strings in the DB
}
